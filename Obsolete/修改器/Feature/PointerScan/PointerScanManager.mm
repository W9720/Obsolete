//
//  PointerScanManager.mm
//  指针扫描管理器实现 - 重写版本
//

#import "PointerScanManager.h"
#import "ProcessManager.h"

extern "C" {
#import "libptrs.h"
#import "lz4.h"
}

// 错误域
NSString * const PointerScanErrorDomain = @"PointerScanErrorDomain";

@implementation PointerScanConfig

+ (instancetype)defaultConfig {
    PointerScanConfig *config = [[PointerScanConfig alloc] init];
    config.maxDepth = 3;             // 修改默认扫描层数为3
    config.scanRangeLeft = 0;        // 0 向前 (与Mac端 --range 0:3000 一致)
    config.scanRangeRight = 3000;    // 3000 向后 (与Mac端 --range 0:3000 一致)
    config.maxResults = 1000;        // 修改默认结果数为1000
    config.minDepth = 1;             // 修改为0，不限制最短长度
    config.enableCycleDetection = NO;
    return config;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"PointerScanConfig: target=0x%lX, depth=%lu, range=±%lu, maxResults=%lu",
            (unsigned long)self.targetAddress, (unsigned long)self.maxDepth,
            (unsigned long)self.scanRangeLeft, (unsigned long)self.maxResults];
}

@end

@implementation ModuleInfo

- (NSString *)description {
    return [NSString stringWithFormat:@"Module: %@ (0x%lX-0x%lX)",
            self.name, (unsigned long)self.startAddress, (unsigned long)self.endAddress];
}

@end

@implementation PointerScanManager {
    FFIPointerScan *_scanner;
    pid_t _currentPid;
    BOOL _isInitialized;
    BOOL _isAttached;
    NSArray<ModuleInfo *> *_cachedModules;
}

+ (instancetype)sharedManager {
    static PointerScanManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PointerScanManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _scanner = NULL;
        _currentPid = 0;
        _isInitialized = NO;
        _isAttached = NO;
        _cachedModules = nil;
    }
    return self;
}

- (void)dealloc {
    [self cleanup];
}

- (BOOL)initializeWithError:(NSError **)error {
    if (_isInitialized) {
        return YES;
    }

    _scanner = ptrscan_init();
    if (!_scanner) {
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"初始化指针扫描器失败"}];
        }
        return NO;
    }

    _isInitialized = YES;
    return YES;
}

- (void)cleanup {
    if (_isAttached) {
        [self detachFromProcess];
    }

    if (_scanner) {
        ptrscan_free(_scanner);
        _scanner = NULL;
    }

    _isInitialized = NO;
    _cachedModules = nil;
}

- (BOOL)attachToProcess:(pid_t)pid error:(NSError **)error {
    if (!_isInitialized) {
        if (![self initializeWithError:error]) {
            return NO;
        }
    }

    // 如果已经附加到相同进程，直接返回成功
    if (_isAttached && _currentPid == pid) {
        return YES;
    }

    // 如果附加到不同进程，先分离
    if (_isAttached) {
        [self detachFromProcess];
    }

    int result = ptrscan_attach_process(_scanner, (int32_t)pid);
    if (result != SUCCESS) {
        const char *errorMsg = get_last_error(result);
        NSString *message = errorMsg ? [NSString stringWithUTF8String:errorMsg] : @"附加进程失败";

        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:result
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        return NO;
    }

    _currentPid = pid;
    _isAttached = YES;
    _cachedModules = nil; // 清除缓存的模块列表
    return YES;
}

- (void)detachFromProcess {
    if (_isAttached) {
        _isAttached = NO;
        _currentPid = 0;
        _cachedModules = nil;
    }
}

- (NSArray<ModuleInfo *> *)getModuleList:(NSError **)error {
    return [self getModuleList:error forceRefresh:NO];
}

- (NSArray<ModuleInfo *> *)getModuleList:(NSError **)error forceRefresh:(BOOL)forceRefresh {
    if (!_isAttached) {
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"未附加到进程"}];
        }
        return nil;
    }

    // 如果有缓存且不强制刷新，返回缓存
    if (_cachedModules && !forceRefresh) {
        return _cachedModules;
    }

    const FFIModule *modules = NULL;
    uintptr_t size = 0;

    int result = ptrscan_list_modules(_scanner, &modules, &size);
    if (result != SUCCESS) {
        const char *errorMsg = get_last_error(result);
        NSString *message = errorMsg ? [NSString stringWithUTF8String:errorMsg] : @"获取模块列表失败";

        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:result
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        return nil;
    }

    NSMutableArray<ModuleInfo *> *moduleList = [NSMutableArray array];
    for (uintptr_t i = 0; i < size; i++) {
        ModuleInfo *moduleInfo = [[ModuleInfo alloc] init];
        moduleInfo.startAddress = modules[i].start;
        moduleInfo.endAddress = modules[i].end;
        moduleInfo.pathname = modules[i].pathname ? [NSString stringWithUTF8String:modules[i].pathname] : @"";

        // 提取模块名称（文件名部分）
        moduleInfo.name = [moduleInfo.pathname lastPathComponent];
        if (moduleInfo.name.length == 0) {
            moduleInfo.name = [NSString stringWithFormat:@"module_%lu", (unsigned long)i];
        }

        [moduleList addObject:moduleInfo];
    }

    _cachedModules = [moduleList copy];
    return _cachedModules;
}

- (BOOL)createPointerMapWithModules:(NSArray<ModuleInfo *> *)modules error:(NSError **)error {
    if (!_isAttached) {
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"未附加到进程"}];
        }
        return NO;
    }

    // 清理可能存在的临时文件
    [self cleanupTemporaryFiles];

    if (modules.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"模块列表为空"}];
        }
        return NO;
    }

    // 转换模块数组为 C 结构体
    FFIModule *cModules = (FFIModule *)malloc(modules.count * sizeof(FFIModule));
    if (!cModules) {
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"内存分配失败"}];
        }
        return NO;
    }

    // 填充模块信息
    for (NSUInteger i = 0; i < modules.count; i++) {
        ModuleInfo *module = modules[i];
        cModules[i].start = module.startAddress;
        cModules[i].end = module.endAddress;
        cModules[i].pathname = [module.name UTF8String]; // 使用模块名而不是完整路径
    }

    int result = ptrscan_create_pointer_map(_scanner, cModules, modules.count);
    free(cModules);

    if (result != SUCCESS) {
        const char *errorMsg = get_last_error(result);
        NSString *message = errorMsg ? [NSString stringWithUTF8String:errorMsg] : @"创建指针映射失败";

        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:result
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        return NO;
    }

    return YES;
}

- (BOOL)createPointerMapFileWithModules:(NSArray<ModuleInfo *> *)modules 
                             outputPath:(NSString *)outputPath 
                                  error:(NSError **)error {
    if (!_isAttached) {
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"未附加到进程"}];
        }
        return NO;
    }
    
    // 清理可能存在的临时文件
    [self cleanupTemporaryFiles];
    
    if (modules.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"模块列表为空"}];
        }
        return NO;
    }
    
    // 转换模块数组为 C 结构体
    FFIModule *cModules = (FFIModule *)malloc(modules.count * sizeof(FFIModule));
    if (!cModules) {
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"内存分配失败"}];
        }
        return NO;
    }
    
    // 填充模块信息
    for (NSUInteger i = 0; i < modules.count; i++) {
        ModuleInfo *module = modules[i];
        cModules[i].start = module.startAddress;
        cModules[i].end = module.endAddress;
        cModules[i].pathname = [module.name UTF8String]; // 使用模块名而不是完整路径
    }
    
    // 确保输出目录存在
    NSString *outputDir = [outputPath stringByDeletingLastPathComponent];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *dirError = nil;
    
    if (![fileManager fileExistsAtPath:outputDir]) {
        if (![fileManager createDirectoryAtPath:outputDir withIntermediateDirectories:YES attributes:nil error:&dirError]) {
            if (error) {
                *error = dirError;
            }
            free(cModules);
            return NO;
        }
    }
    
    // 确保输出文件不存在
    if ([fileManager fileExistsAtPath:outputPath]) {
        [fileManager removeItemAtPath:outputPath error:&dirError];
    }
    
    // 执行创建指针映射文件
    int result = ptrscan_create_pointer_map_file(_scanner, cModules, modules.count, [outputPath UTF8String]);
    free(cModules);
    
    if (result != SUCCESS) {
        const char *errorMsg = get_last_error(result);
        NSString *message = errorMsg ? [NSString stringWithUTF8String:errorMsg] : @"创建指针映射文件失败";
        
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:result
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        return NO;
    }
    
    return YES;
}

- (BOOL)scanPointerChain:(PointerScanConfig *)config
            outputPath:(NSString *)outputPath
         progressBlock:(nullable PointerScanProgressBlock)progressBlock
                 error:(NSError **)error {

    // 扫描前清理临时文件
    [self cleanupTemporaryFiles];

    if (!_isAttached) {
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"未附加到进程"}];
        }
        return NO;
    }

    // 验证配置参数
    if (config.targetAddress == 0) {
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"目标地址无效"}];
        }
        return NO;
    }

    // 创建扫描参数
    uintptr_t maxResultsValue = config.maxResults;

    FFIParam scanParam = {
        .addr = config.targetAddress,
        .depth = config.maxDepth,
        .srange = {
            .left = config.scanRangeLeft,
            .right = config.scanRangeRight
        },
        .lrange = NULL,
        .node = NULL,
        .last = NULL,
        .max = &maxResultsValue,
        .cycle = config.enableCycleDetection,
        .raw1 = false,
        .raw2 = false,
        .raw3 = false
    };



    // 通知进度
    if (progressBlock) {
        progressBlock(0.0, @"开始扫描指针链...");
    }

    // 确保输出目录存在
    NSString *outputDir = [outputPath stringByDeletingLastPathComponent];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *dirError = nil;

    // 创建指针扫描专用目录
    if (![fileManager fileExistsAtPath:outputDir]) {
        if (![fileManager createDirectoryAtPath:outputDir withIntermediateDirectories:YES attributes:nil error:&dirError]) {
            if (error) {
                *error = dirError;
            }
            return NO;
        }
    }

    // 确保输出文件不存在（libptrs 会自己创建）
    if ([fileManager fileExistsAtPath:outputPath]) {
        [fileManager removeItemAtPath:outputPath error:&dirError];
    }

    // 执行扫描
    int result = ptrscan_scan_pointer_chain(_scanner, scanParam, [outputPath UTF8String]);

    if (result != SUCCESS) {
        const char *errorMsg = get_last_error(result);
        NSString *message = errorMsg ? [NSString stringWithUTF8String:errorMsg] : @"指针扫描失败";

        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:result
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        return NO;
    }



    // 通知完成
    if (progressBlock) {
        progressBlock(1.0, @"扫描完成");
    }

    return YES;
}

- (NSString *)getVersion {
    const char *version = ptrscan_version();
    return version ? [NSString stringWithUTF8String:version] : @"未知版本";
}

- (NSData *)readMemory:(uintptr_t)address size:(uintptr_t)size error:(NSError **)error {
    if (!_isAttached) {
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"未附加到进程"}];
        }
        return nil;
    }

    if (size == 0) {
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"读取大小无效"}];
        }
        return nil;
    }

    void *buffer = malloc(size);
    if (!buffer) {
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"内存分配失败"}];
        }
        return nil;
    }

    int result = ptrscan_read_memory_exact(_scanner, address, (uint8_t *)buffer, size);
    if (result != SUCCESS) {
        free(buffer);
        const char *errorMsg = get_last_error(result);
        NSString *message = errorMsg ? [NSString stringWithUTF8String:errorMsg] : @"读取内存失败";

        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:result
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        return nil;
    }

    NSData *data = [NSData dataWithBytes:buffer length:size];
    free(buffer);
    return data;
}

// 添加一些便利方法
- (BOOL)isAttached {
    return _isAttached;
}

- (pid_t)currentPid {
    return _currentPid;
}

- (void)clearModuleCache {
    _cachedModules = nil;
}

#pragma mark - 临时文件管理

- (void)cleanupTemporaryFiles {
    // 清理指针扫描专用目录
    NSString *pointerScanDir = [PointerScanManager pointerScanDirectory];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;

    // 获取指针扫描目录中的所有文件
    NSArray *scanFiles = [fileManager contentsOfDirectoryAtPath:pointerScanDir error:&error];
    if (!error && scanFiles) {
        // 清理指针扫描目录中的所有文件
        for (NSString *fileName in scanFiles) {
            NSString *filePath = [pointerScanDir stringByAppendingPathComponent:fileName];
            [fileManager removeItemAtPath:filePath error:nil];
        }
    }

    // 同时清理系统临时目录中的相关文件
    NSString *tempDir = NSTemporaryDirectory();
    NSArray *tempFiles = [fileManager contentsOfDirectoryAtPath:tempDir error:&error];
    if (!error && tempFiles) {
        // 清理指针扫描相关的临时文件
        for (NSString *fileName in tempFiles) {
            if ([fileName hasPrefix:@"pointer_scan_"] ||
                [fileName hasPrefix:@"pointer_map_"] ||
                [fileName hasSuffix:@".ptrscan"] ||
                [fileName hasSuffix:@".ptrmap"] ||
                [fileName containsString:@"libptrs"] ||
                [fileName containsString:@"ptrscan"]) {

                NSString *filePath = [tempDir stringByAppendingPathComponent:fileName];
                [fileManager removeItemAtPath:filePath error:nil];
            }
        }
    }
}

+ (NSString *)pointerScanDirectory {
    // 获取Documents目录
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];

    // 创建指针扫描专用目录
    NSString *pointerScanDir = [documentsDirectory stringByAppendingPathComponent:@"PointerScan"];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;

    if (![fileManager fileExistsAtPath:pointerScanDir]) {
        if (![fileManager createDirectoryAtPath:pointerScanDir withIntermediateDirectories:YES attributes:nil error:&error]) {
            // 如果创建失败，回退到Documents目录
            return documentsDirectory;
        }
    }

    return pointerScanDir;
}

- (BOOL)loadPointerMapFromFile:(NSString *)path error:(NSError **)error {
    if (!_isInitialized) {
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"扫描器未初始化"}];
        }
        return NO;
    }
    
    // 检查文件是否存在
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"指针映射文件不存在"}];
        }
        return NO;
    }
    
    // 加载指针映射文件
    int result = ptrscan_load_pointer_map_file(_scanner, [path UTF8String]);
    
    if (result != SUCCESS) {
        const char *errorMsg = get_last_error(result);
        NSString *message = errorMsg ? [NSString stringWithUTF8String:errorMsg] : @"加载指针映射文件失败";
        
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:result
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        return NO;
    }
    
    return YES;
}

- (BOOL)isPointerMapLoaded {
    // 这个方法需要libptrscan提供额外的API支持
    // 目前我们简单返回YES，实际使用时可能需要根据实际情况调整
    return _isInitialized && _isAttached;
}

- (BOOL)compressPointerMapFile:(NSString *)inputPath 
                    outputPath:(NSString *)outputPath 
                         error:(NSError **)error {
    // 检查输入文件是否存在
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:inputPath]) {
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"输入文件不存在"}];
        }
        return NO;
    }
    
    // 确保输出目录存在
    NSString *outputDir = [outputPath stringByDeletingLastPathComponent];
    if (![fileManager fileExistsAtPath:outputDir]) {
        NSError *dirError = nil;
        if (![fileManager createDirectoryAtPath:outputDir withIntermediateDirectories:YES attributes:nil error:&dirError]) {
            if (error) {
                *error = dirError;
            }
            return NO;
        }
    }
    
    // 读取输入文件
    NSData *inputData = [NSData dataWithContentsOfFile:inputPath options:NSDataReadingMappedIfSafe error:error];
    if (!inputData) {
        return NO;
    }
    
    // 计算压缩后的最大大小
    int maxCompressedSize = LZ4_compressBound((int)inputData.length);
    
    // 分配压缩缓冲区
    char *compressedBuffer = (char *)malloc(maxCompressedSize);
    if (!compressedBuffer) {
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"内存分配失败"}];
        }
        return NO;
    }
    
    // 执行压缩
    int compressedSize = LZ4_compress_default(
        (const char *)inputData.bytes,
        compressedBuffer,
        (int)inputData.length,
        maxCompressedSize
    );
    
    if (compressedSize <= 0) {
        free(compressedBuffer);
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"压缩失败"}];
        }
        return NO;
    }
    
    // 创建头部信息，包含原始大小
    uint32_t originalSize = (uint32_t)inputData.length;
    NSMutableData *outputData = [NSMutableData dataWithBytes:&originalSize length:sizeof(uint32_t)];
    
    // 添加压缩后的数据
    [outputData appendBytes:compressedBuffer length:compressedSize];
    free(compressedBuffer);
    
    // 写入输出文件
    BOOL success = [outputData writeToFile:outputPath options:NSDataWritingAtomic error:error];
    
    return success;
}

- (BOOL)decompressPointerMapFile:(NSString *)inputPath 
                      outputPath:(NSString *)outputPath 
                           error:(NSError **)error {
    // 检查输入文件是否存在
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:inputPath]) {
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"输入文件不存在"}];
        }
        return NO;
    }
    
    // 确保输出目录存在
    NSString *outputDir = [outputPath stringByDeletingLastPathComponent];
    if (![fileManager fileExistsAtPath:outputDir]) {
        NSError *dirError = nil;
        if (![fileManager createDirectoryAtPath:outputDir withIntermediateDirectories:YES attributes:nil error:&dirError]) {
            if (error) {
                *error = dirError;
            }
            return NO;
        }
    }
    
    // 读取输入文件
    NSData *inputData = [NSData dataWithContentsOfFile:inputPath options:NSDataReadingMappedIfSafe error:error];
    if (!inputData || inputData.length <= sizeof(uint32_t)) {
        if (error && !*error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"输入文件格式无效"}];
        }
        return NO;
    }
    
    // 读取头部信息中的原始大小
    uint32_t originalSize;
    [inputData getBytes:&originalSize length:sizeof(uint32_t)];
    
    // 分配解压缓冲区
    char *decompressedBuffer = (char *)malloc(originalSize);
    if (!decompressedBuffer) {
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"内存分配失败"}];
        }
        return NO;
    }
    
    // 执行解压缩
    int decompressedSize = LZ4_decompress_safe(
        (const char *)inputData.bytes + sizeof(uint32_t),
        decompressedBuffer,
        (int)inputData.length - sizeof(uint32_t),
        originalSize
    );
    
    if (decompressedSize <= 0 || decompressedSize != originalSize) {
        free(decompressedBuffer);
        if (error) {
            *error = [NSError errorWithDomain:PointerScanErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"解压缩失败"}];
        }
        return NO;
    }
    
    // 创建解压后的数据
    NSData *outputData = [NSData dataWithBytes:decompressedBuffer length:decompressedSize];
    free(decompressedBuffer);
    
    // 写入输出文件
    BOOL success = [outputData writeToFile:outputPath options:NSDataWritingAtomic error:error];
    
    return success;
}

- (NSString *)getPointerMapCachePath:(NSString *)identifier {
    NSString *pointerScanDir = [PointerScanManager pointerScanDirectory];
    return [pointerScanDir stringByAppendingPathComponent:[NSString stringWithFormat:@"ptrmap_%@.bin", identifier]];
}

- (NSArray<NSDictionary *> *)getAvailablePointerMaps {
    NSString *pointerScanDir = [PointerScanManager pointerScanDirectory];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSError *error = nil;
    NSArray *files = [fileManager contentsOfDirectoryAtPath:pointerScanDir error:&error];
    
    if (error || !files) {
        return @[];
    }
    
    NSMutableArray *pointerMaps = [NSMutableArray array];
    
    for (NSString *fileName in files) {
        if ([fileName hasPrefix:@"ptrmap_"] && [fileName hasSuffix:@".bin"]) {
            NSString *filePath = [pointerScanDir stringByAppendingPathComponent:fileName];
            NSDictionary *attributes = [fileManager attributesOfItemAtPath:filePath error:nil];
            
            if (attributes) {
                NSDate *creationDate = attributes[NSFileCreationDate];
                NSNumber *fileSize = attributes[NSFileSize];
                
                [pointerMaps addObject:@{
                    @"name": fileName,
                    @"path": filePath,
                    @"date": creationDate ?: [NSDate date],
                    @"size": fileSize ?: @0
                }];
            }
        }
    }
    
    // 按日期排序，最新的在前
    return [pointerMaps sortedArrayUsingDescriptors:@[
        [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]
    ]];
}

- (void)clearPointerMapCache {
    NSString *pointerScanDir = [PointerScanManager pointerScanDirectory];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSError *error = nil;
    NSArray *files = [fileManager contentsOfDirectoryAtPath:pointerScanDir error:&error];

    if (error || !files) {
        return;
    }

    for (NSString *fileName in files) {
        if ([fileName hasPrefix:@"ptrmap_"] && [fileName hasSuffix:@".bin"]) {
            NSString *filePath = [pointerScanDir stringByAppendingPathComponent:fileName];
            [fileManager removeItemAtPath:filePath error:nil];
        }
    }
}

- (struct FFIPointerScan *)getScannerPtr {
    return _scanner;
}

@end
