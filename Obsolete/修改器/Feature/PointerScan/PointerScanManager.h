//
//  PointerScanManager.h
//  指针扫描管理器 - 基于 libptrscan.a 静态库
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 扫描参数配置
@interface PointerScanConfig : NSObject
@property (nonatomic, assign) uintptr_t targetAddress;     // 目标地址
@property (nonatomic, assign) uintptr_t maxDepth;          // 最大扫描深度
@property (nonatomic, assign) uintptr_t scanRangeLeft;     // 向前偏移范围
@property (nonatomic, assign) uintptr_t scanRangeRight;    // 向后偏移范围
@property (nonatomic, assign) uintptr_t maxResults;        // 最大结果数
@property (nonatomic, assign) uintptr_t minDepth;          // 最小深度（可选）
@property (nonatomic, assign) BOOL enableCycleDetection;   // 是否启用循环检测

+ (instancetype)defaultConfig;
@end

// 模块信息
@interface ModuleInfo : NSObject
@property (nonatomic, assign) uintptr_t startAddress;
@property (nonatomic, assign) uintptr_t endAddress;
@property (nonatomic, strong) NSString *pathname;
@property (nonatomic, strong) NSString *name;
@end

// 进度回调
typedef void(^PointerScanProgressBlock)(float progress, NSString *status);

// 指针扫描管理器
@interface PointerScanManager : NSObject

@property (nonatomic, readonly) BOOL isAttached;
@property (nonatomic, readonly) pid_t currentPid;

+ (instancetype)sharedManager;
+ (NSString *)pointerScanDirectory;

// 初始化和清理
- (BOOL)initializeWithError:(NSError **)error;
- (void)cleanup;

// 进程管理
- (BOOL)attachToProcess:(pid_t)pid error:(NSError **)error;
- (void)detachFromProcess;

// 模块管理
- (NSArray<ModuleInfo *> *)getModuleList:(NSError **)error;
- (NSArray<ModuleInfo *> *)getModuleList:(NSError **)error forceRefresh:(BOOL)forceRefresh;
- (void)clearModuleCache;
- (BOOL)createPointerMapWithModules:(NSArray<ModuleInfo *> *)modules error:(NSError **)error;

// 新增：指针映射管理
- (BOOL)createPointerMapFileWithModules:(NSArray<ModuleInfo *> *)modules 
                             outputPath:(NSString *)outputPath 
                                  error:(NSError **)error;
- (BOOL)loadPointerMapFromFile:(NSString *)path error:(NSError **)error;
- (BOOL)isPointerMapLoaded;
- (BOOL)compressPointerMapFile:(NSString *)inputPath 
                    outputPath:(NSString *)outputPath 
                         error:(NSError **)error;
- (BOOL)decompressPointerMapFile:(NSString *)inputPath 
                      outputPath:(NSString *)outputPath 
                           error:(NSError **)error;
- (NSString *)getPointerMapCachePath:(NSString *)identifier;
- (NSArray<NSDictionary *> *)getAvailablePointerMaps;
- (void)clearPointerMapCache;

// 指针扫描
- (BOOL)scanPointerChain:(PointerScanConfig *)config
            outputPath:(NSString *)outputPath
         progressBlock:(nullable PointerScanProgressBlock)progressBlock
                 error:(NSError **)error;

// 工具方法
- (NSString *)getVersion;
- (NSData *)readMemory:(uintptr_t)address size:(uintptr_t)size error:(NSError **)error;
- (void)cleanupTemporaryFiles;

// 获取底层扫描器指针（用于直接调用 libptrs API）
- (struct FFIPointerScan *)getScannerPtr;

@end

NS_ASSUME_NONNULL_END
