//
//  DylibInjector.m
//  Obsolete
//
//  Created by Assistant on 2024/01/16.
//  基于SignTools的动态库注入功能
//

#import "DylibInjector.h"
#import "SSZipArchive.h"
#import <mach-o/loader.h>
#import <mach-o/fat.h>

@interface DylibInjector ()
@property (nonatomic, strong, readwrite) NSString *lastError;
@end

@implementation DylibInjector

#pragma mark - Public Methods

- (void)injectDylibToIPA:(NSString *)ipaPath
               dylibPath:(NSString *)dylibPath
              completion:(void(^)(NSString * _Nullable outputPath, NSString * _Nullable error))completion {
    [self injectDylibToIPA:ipaPath
                 dylibPath:dylibPath
                injectType:DylibInjectTypeStrong
         frameworkLocation:FrameworkLocationTypeFrameworks
                completion:completion];
}

- (void)injectDylibToIPA:(NSString *)ipaPath
               dylibPath:(NSString *)dylibPath
              injectType:(DylibInjectType)injectType
       frameworkLocation:(FrameworkLocationType)frameworkLocation
              completion:(void(^)(NSString * _Nullable outputPath, NSString * _Nullable error))completion {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self log:@"开始处理IPA文件"];
        
        // 验证输入文件
        if (![self validateIPAFile:ipaPath]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, self.lastError);
            });
            return;
        }
        
        if (![self validateDylibFile:dylibPath]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, self.lastError);
            });
            return;
        }
        
        // 执行注入流程
        NSString *outputPath = [self performInjection:ipaPath
                                            dylibPath:dylibPath
                                           injectType:injectType
                                    frameworkLocation:frameworkLocation];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (outputPath) {
                [self log:@"动态库注入完成"];
                completion(outputPath, nil);
            } else {
                completion(nil, self.lastError ?: @"注入失败");
            }
        });
    });
}

- (BOOL)validateIPAFile:(NSString *)ipaPath {
    if (![[NSFileManager defaultManager] fileExistsAtPath:ipaPath]) {
        self.lastError = @"IPA文件不存在";
        [self log:self.lastError];
        return NO;
    }
    
    if (![ipaPath.pathExtension.lowercaseString isEqualToString:@"ipa"]) {
        self.lastError = @"文件不是有效的IPA格式";
        [self log:self.lastError];
        return NO;
    }
    
    return YES;
}

- (BOOL)validateDylibFile:(NSString *)dylibPath {
    if (![[NSFileManager defaultManager] fileExistsAtPath:dylibPath]) {
        self.lastError = @"动态库文件不存在";
        [self log:self.lastError];
        return NO;
    }
    
    NSString *extension = dylibPath.pathExtension.lowercaseString;
    if (![extension isEqualToString:@"dylib"] && ![extension isEqualToString:@"framework"]) {
        self.lastError = @"文件不是有效的动态库格式 (.dylib 或 .framework)";
        [self log:self.lastError];
        return NO;
    }
    
    return YES;
}

#pragma mark - Private Methods

- (NSString *)performInjection:(NSString *)ipaPath
                     dylibPath:(NSString *)dylibPath
                    injectType:(DylibInjectType)injectType
             frameworkLocation:(FrameworkLocationType)frameworkLocation {
    
    // 创建临时工作目录
    NSString *tempDir = [self createTemporaryDirectory];
    if (!tempDir) {
        return nil;
    }
    
    @try {
        // 1. 解压IPA
        [self log:@"正在解压IPA文件"];
        NSString *appPath = [self unzipIPA:ipaPath toDirectory:tempDir];
        if (!appPath) {
            return nil;
        }
        
        // 2. 注入动态库
        [self log:@"正在注入动态库"];
        if (![self injectDylibToApp:appPath
                          dylibPath:dylibPath
                         injectType:injectType
                  frameworkLocation:frameworkLocation]) {
            return nil;
        }
        
        // 3. 重新打包
        [self log:@"正在重新打包IPA"];
        NSString *outputPath = [self repackageIPA:tempDir originalPath:ipaPath];
        
        return outputPath;
        
    } @finally {
        // 清理临时目录
        [self cleanupDirectory:tempDir];
    }
}

- (NSString *)createTemporaryDirectory {
    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"DylibInjector_%@", [[NSUUID UUID] UUIDString]]];
    
    NSError *error;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:&error]) {
        self.lastError = [NSString stringWithFormat:@"创建临时目录失败: %@", error.localizedDescription];
        [self log:self.lastError];
        return nil;
    }
    
    return tempDir;
}

- (NSString *)unzipIPA:(NSString *)ipaPath toDirectory:(NSString *)tempDir {
    if (![SSZipArchive unzipFileAtPath:ipaPath toDestination:tempDir]) {
        self.lastError = @"解压IPA文件失败";
        [self log:self.lastError];
        return nil;
    }
    
    // 查找.app文件
    NSString *payloadPath = [tempDir stringByAppendingPathComponent:@"Payload"];
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:payloadPath error:nil];
    
    for (NSString *item in contents) {
        if ([item.pathExtension isEqualToString:@"app"]) {
            return [payloadPath stringByAppendingPathComponent:item];
        }
    }
    
    self.lastError = @"在IPA中找不到.app文件";
    [self log:self.lastError];
    return nil;
}

- (BOOL)injectDylibToApp:(NSString *)appPath
               dylibPath:(NSString *)dylibPath
              injectType:(DylibInjectType)injectType
       frameworkLocation:(FrameworkLocationType)frameworkLocation {
    
    // 1. 复制动态库到app目录
    NSString *targetPath;
    NSString *injectionPath;
    
    if ([dylibPath.pathExtension.lowercaseString isEqualToString:@"framework"]) {
        // 处理Framework
        NSString *frameworkName = [dylibPath lastPathComponent];
        
        if (frameworkLocation == FrameworkLocationTypeFrameworks) {
            // 放在Frameworks文件夹下
            NSString *frameworksDir = [appPath stringByAppendingPathComponent:@"Frameworks"];
            [[NSFileManager defaultManager] createDirectoryAtPath:frameworksDir withIntermediateDirectories:YES attributes:nil error:nil];
            targetPath = [frameworksDir stringByAppendingPathComponent:frameworkName];
            
            NSString *frameworkBinaryName = [frameworkName stringByDeletingPathExtension];
            injectionPath = [NSString stringWithFormat:@"@executable_path/Frameworks/%@/%@", frameworkName, frameworkBinaryName];
        } else {
            // 放在应用根目录
            targetPath = [appPath stringByAppendingPathComponent:frameworkName];
            
            NSString *frameworkBinaryName = [frameworkName stringByDeletingPathExtension];
            injectionPath = [NSString stringWithFormat:@"@executable_path/%@/%@", frameworkName, frameworkBinaryName];
        }
    } else {
        // 处理dylib
        NSString *dylibName = [dylibPath lastPathComponent];
        targetPath = [appPath stringByAppendingPathComponent:dylibName];
        injectionPath = [NSString stringWithFormat:@"@executable_path/%@", dylibName];
    }
    
    // 删除可能存在的旧文件
    [[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
    
    // 复制文件
    NSError *copyError;
    if (![[NSFileManager defaultManager] copyItemAtPath:dylibPath toPath:targetPath error:&copyError]) {
        self.lastError = [NSString stringWithFormat:@"复制动态库失败: %@", copyError.localizedDescription];
        [self log:self.lastError];
        return NO;
    }
    
    [self log:[NSString stringWithFormat:@"已复制动态库到: %@", targetPath.lastPathComponent]];
    
    // 2. 注入到主可执行文件
    NSString *executablePath = [self findExecutableInApp:appPath];
    if (!executablePath) {
        return NO;
    }
    
    return [self injectDylibToMachO:executablePath dylibPath:injectionPath injectType:injectType];
}

- (NSString *)findExecutableInApp:(NSString *)appPath {
    // 读取Info.plist找到可执行文件名
    NSString *infoPlistPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
    
    NSString *executableName = infoPlist[@"CFBundleExecutable"];
    if (!executableName) {
        self.lastError = @"无法从Info.plist中获取可执行文件名";
        [self log:self.lastError];
        return nil;
    }
    
    NSString *executablePath = [appPath stringByAppendingPathComponent:executableName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:executablePath]) {
        self.lastError = [NSString stringWithFormat:@"可执行文件不存在: %@", executableName];
        [self log:self.lastError];
        return nil;
    }
    
    return executablePath;
}

- (BOOL)injectDylibToMachO:(NSString *)executablePath
                 dylibPath:(NSString *)dylibPath
                injectType:(DylibInjectType)injectType {
    
    [self log:[NSString stringWithFormat:@"正在注入到: %@", executablePath.lastPathComponent]];
    [self log:[NSString stringWithFormat:@"注入路径: %@", dylibPath]];
    
    NSString *injectTypeStr = (injectType == DylibInjectTypeWeak) ? @"弱依赖 (LC_LOAD_WEAK_DYLIB)" : @"强依赖 (LC_LOAD_DYLIB)";
    [self log:[NSString stringWithFormat:@"注入类型: %@", injectTypeStr]];
    
    int fd = open(executablePath.UTF8String, O_RDWR, 0777);
    if (fd < 0) {
        self.lastError = [NSString stringWithFormat:@"无法打开可执行文件: %@", executablePath];
        [self log:self.lastError];
        return NO;
    }
    
    @try {
        // 读取文件头判断架构
        uint32_t magic;
        if (read(fd, &magic, sizeof(magic)) != sizeof(magic)) {
            self.lastError = @"读取文件头失败";
            [self log:self.lastError];
            return NO;
        }
        
        lseek(fd, 0, SEEK_SET);
        
        if (magic == FAT_MAGIC || magic == FAT_CIGAM) {
            // Fat binary - 处理多架构
            return [self injectFatBinary:fd dylibPath:dylibPath injectType:injectType];
        } else if (magic == MH_MAGIC_64 || magic == MH_CIGAM_64) {
            // 64位单架构
            return [self injectSingleArchitecture:fd dylibPath:dylibPath injectType:injectType];
        } else {
            self.lastError = @"不支持的文件格式";
            [self log:self.lastError];
            return NO;
        }
        
    } @finally {
        close(fd);
    }
}

- (NSString *)repackageIPA:(NSString *)tempDir originalPath:(NSString *)originalPath {
    // 生成简洁的输出文件名
    NSString *directory = [originalPath stringByDeletingLastPathComponent];
    NSString *filename = [[originalPath lastPathComponent] stringByDeletingPathExtension];

    // 去掉_decrypted后缀（如果存在）
    if ([filename hasSuffix:@"_decrypted"]) {
        filename = [filename substringToIndex:filename.length - 10];
    }

    NSString *outputFilename = [NSString stringWithFormat:@"%@_injected.ipa", filename];
    NSString *outputPath = [directory stringByAppendingPathComponent:outputFilename];

    // 如果文件已存在，添加数字后缀
    int counter = 1;
    while ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
        outputFilename = [NSString stringWithFormat:@"%@_injected_%d.ipa", filename, counter];
        outputPath = [directory stringByAppendingPathComponent:outputFilename];
        counter++;
    }
    
    // 删除可能存在的输出文件
    [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
    
    // 重新打包
    if (![SSZipArchive createZipFileAtPath:outputPath withContentsOfDirectory:tempDir]) {
        self.lastError = @"重新打包IPA失败";
        [self log:self.lastError];
        return nil;
    }
    
    [self log:[NSString stringWithFormat:@"输出文件: %@", outputFilename]];
    return outputPath;
}

- (void)cleanupDirectory:(NSString *)directory {
    [[NSFileManager defaultManager] removeItemAtPath:directory error:nil];
}

- (void)log:(NSString *)message {
    NSLog(@"[DylibInjector] %@", message);
    if (self.logCallback) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.logCallback(message);
        });
    }
}

#pragma mark - Mach-O Injection

- (BOOL)injectSingleArchitecture:(int)fd
                       dylibPath:(NSString *)dylibPath
                      injectType:(DylibInjectType)injectType {

    [self log:@"注入到单架构二进制文件"];

    off_t archPoint = lseek(fd, 0, SEEK_CUR);
    struct mach_header_64 header;
    if (read(fd, &header, sizeof(header)) != sizeof(header)) {
        self.lastError = @"读取Mach-O头失败";
        return NO;
    }

    // 检查是否已经注入过
    if ([self isDylibAlreadyInjected:fd dylibPath:dylibPath header:&header archPoint:archPoint]) {
        [self log:[NSString stringWithFormat:@"动态库已存在: %@", dylibPath]];
        return YES;
    }

    // 执行注入
    return [self performInjectionToArchitecture:fd dylibPath:dylibPath injectType:injectType header:&header archPoint:archPoint];
}

- (BOOL)injectFatBinary:(int)fd
              dylibPath:(NSString *)dylibPath
             injectType:(DylibInjectType)injectType {

    [self log:@"注入到Fat二进制文件"];

    struct fat_header fatHeader;
    lseek(fd, 0, SEEK_SET);
    if (read(fd, &fatHeader, sizeof(fatHeader)) != sizeof(fatHeader)) {
        self.lastError = @"读取Fat头失败";
        return NO;
    }

    uint32_t nfat_arch = OSSwapBigToHostInt32(fatHeader.nfat_arch);

    for (uint32_t i = 0; i < nfat_arch; i++) {
        struct fat_arch fatArch;
        if (read(fd, &fatArch, sizeof(fatArch)) != sizeof(fatArch)) {
            self.lastError = @"读取Fat架构信息失败";
            return NO;
        }

        uint32_t offset = OSSwapBigToHostInt32(fatArch.offset);
        lseek(fd, offset, SEEK_SET);

        if (![self injectSingleArchitecture:fd dylibPath:dylibPath injectType:injectType]) {
            return NO;
        }
    }

    [self log:@"Fat二进制注入完成"];
    return YES;
}

- (BOOL)isDylibAlreadyInjected:(int)fd
                     dylibPath:(NSString *)dylibPath
                        header:(struct mach_header_64 *)header
                     archPoint:(off_t)archPoint {

    lseek(fd, archPoint + sizeof(struct mach_header_64), SEEK_SET);

    const char *targetDylib = dylibPath.UTF8String;

    for (uint32_t i = 0; i < header->ncmds; i++) {
        struct load_command cmd;
        off_t cmdStart = lseek(fd, 0, SEEK_CUR);

        if (read(fd, &cmd, sizeof(cmd)) != sizeof(cmd)) {
            break;
        }

        if (cmd.cmd == LC_LOAD_DYLIB || cmd.cmd == LC_LOAD_WEAK_DYLIB) {
            struct dylib_command dylibCmd;
            lseek(fd, cmdStart, SEEK_SET);
            if (read(fd, &dylibCmd, sizeof(dylibCmd)) == sizeof(dylibCmd)) {

                // 读取dylib名称
                char *nameBuffer = malloc(cmd.cmdsize - sizeof(dylibCmd));
                if (nameBuffer && read(fd, nameBuffer, cmd.cmdsize - sizeof(dylibCmd)) > 0) {
                    if (strcmp(targetDylib, nameBuffer) == 0) {
                        free(nameBuffer);
                        return YES;
                    }
                }
                if (nameBuffer) free(nameBuffer);
            }
        }

        lseek(fd, cmdStart + cmd.cmdsize, SEEK_SET);
    }

    return NO;
}

- (BOOL)performInjectionToArchitecture:(int)fd
                             dylibPath:(NSString *)dylibPath
                            injectType:(DylibInjectType)injectType
                                header:(struct mach_header_64 *)header
                             archPoint:(off_t)archPoint {

    // 计算需要的空间
    const char *dylib = dylibPath.UTF8String;
    uint32_t dylibLen = (uint32_t)strlen(dylib);
    uint32_t cmdsize = sizeof(struct dylib_command) + dylibLen + 1;
    cmdsize = (cmdsize + 7) & ~7; // 8字节对齐

    // 读取所有load commands
    uint32_t totalCmdsSize = header->sizeofcmds;
    char *buffer = malloc(totalCmdsSize + cmdsize);
    if (!buffer) {
        self.lastError = @"内存分配失败";
        return NO;
    }

    lseek(fd, archPoint + sizeof(struct mach_header_64), SEEK_SET);
    if (read(fd, buffer, totalCmdsSize) != totalCmdsSize) {
        free(buffer);
        self.lastError = @"读取load commands失败";
        return NO;
    }

    // 找到合适的插入位置（在LC_LOAD_DYLIB命令之后）
    struct dylib_command *insertPoint = NULL;
    struct load_command *cmd = (struct load_command *)buffer;

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cmd->cmd == LC_LOAD_DYLIB || cmd->cmd == LC_LOAD_WEAK_DYLIB) {
            insertPoint = (struct dylib_command *)cmd;
        }
        cmd = (struct load_command *)((char *)cmd + cmd->cmdsize);
    }

    if (insertPoint) {
        // 计算插入位置
        char *insertPos = (char *)insertPoint + insertPoint->cmdsize;
        uint32_t moveSize = totalCmdsSize - (insertPos - buffer);

        // 移动后续数据
        memmove(insertPos + cmdsize, insertPos, moveSize);

        // 创建新的dylib_command
        struct dylib_command *newCmd = (struct dylib_command *)insertPos;
        memset(newCmd, 0, cmdsize);
        newCmd->cmd = (injectType == DylibInjectTypeWeak) ? LC_LOAD_WEAK_DYLIB : LC_LOAD_DYLIB;
        newCmd->cmdsize = cmdsize;
        newCmd->dylib.name.offset = sizeof(struct dylib_command);
        newCmd->dylib.timestamp = 2;
        newCmd->dylib.current_version = 0x00010000;
        newCmd->dylib.compatibility_version = 0x00010000;

        // 复制dylib路径
        strcpy((char *)newCmd + sizeof(struct dylib_command), dylib);

        // 更新header
        header->ncmds++;
        header->sizeofcmds += cmdsize;

        // 写回文件
        lseek(fd, archPoint, SEEK_SET);
        if (write(fd, header, sizeof(struct mach_header_64)) != sizeof(struct mach_header_64)) {
            free(buffer);
            self.lastError = @"写入header失败";
            return NO;
        }

        if (write(fd, buffer, totalCmdsSize + cmdsize) != totalCmdsSize + cmdsize) {
            free(buffer);
            self.lastError = @"写入load commands失败";
            return NO;
        }

        [self log:[NSString stringWithFormat:@"成功注入: %@", dylibPath]];
        free(buffer);
        return YES;
    }

    free(buffer);
    self.lastError = @"找不到合适的插入位置";
    return NO;
}

@end
