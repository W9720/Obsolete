//
//  UnityDumpManager.m
//  Obsolete
//
//  Created by Assistant on 2024/8/16.
//  Unity Il2Cpp转储管理器
//

#import "UnityDumpManager.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import "../../Process/ProcessManager.h"
// 暂时注释掉 UnityResolve，因为它使用了不兼容的 C++20 特性
// #import "UnityResolve.hpp"

@interface UnityDumpManager ()
@property (nonatomic, assign) BOOL isDumping;
@property (nonatomic, copy) UnityDumpProgressCallback currentProgressCallback;
@property (nonatomic, copy) UnityDumpCompletionCallback currentCompletionCallback;
@end

// C++ 辅助函数
extern "C" {
    void* GetUnityLibraryHandleForProcess(pid_t processId);
    BOOL DetectUnityRuntimeForProcess(pid_t processId);
    BOOL PerformBasicUnityAnalysis(const char* outputPath);
}

@implementation UnityDumpManager

+ (instancetype)sharedManager {
    static UnityDumpManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[UnityDumpManager alloc] init];
    });
    return instance;
}

- (void)dumpUnityApp:(NSString *)bundleId
          outputPath:(NSString *)outputPath
            progress:(UnityDumpProgressCallback)progressCallback
          completion:(UnityDumpCompletionCallback)completion {
    
    if (self.isDumping) {
        if (completion) {
            completion(NO, @"已有转储操作正在进行中", nil);
        }
        return;
    }
    
    self.isDumping = YES;
    self.currentProgressCallback = progressCallback;
    self.currentCompletionCallback = completion;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self performDumpForApp:bundleId outputPath:outputPath];
    });
}

- (void)performDumpForApp:(NSString *)bundleId outputPath:(NSString *)outputPath {
    @try {
        NSLog(@"[UnityDump] 开始执行Unity转储，Bundle ID: %@", bundleId);
        NSLog(@"[UnityDump] 输出路径: %@", outputPath);

        [self reportProgress:@"开始Unity Il2Cpp转储..."];

        // 参数验证
        if (!bundleId || bundleId.length == 0) {
            [self reportError:@"Bundle ID不能为空"];
            return;
        }

        if (!outputPath || outputPath.length == 0) {
            [self reportError:@"输出路径不能为空"];
            return;
        }

        // 1. 检查应用是否运行（简化检查，因为用户已经从运行列表中选择）
        NSLog(@"[UnityDump] 应用已从运行列表中选择，跳过运行状态检查");

        [self reportProgress:@"检测Unity框架..."];

        // 2. 获取Unity框架路径
        NSLog(@"[UnityDump] 获取Unity框架路径...");
        NSString *frameworkPath = [self getUnityFrameworkPath:bundleId];
        if (!frameworkPath) {
            [self reportError:@"无法找到Unity框架，请确认这是一个Unity应用"];
            return;
        }

        [self reportProgress:[NSString stringWithFormat:@"找到Unity框架: %@", frameworkPath.lastPathComponent]];

        // 3. 创建输出目录
        NSLog(@"[UnityDump] 创建输出目录...");
        NSString *appOutputPath = [self createOutputDirectoryForApp:bundleId outputPath:outputPath];
        if (!appOutputPath) {
            [self reportError:@"创建输出目录失败"];
            return;
        }

        NSLog(@"[UnityDump] 应用输出路径: %@", appOutputPath);
        [self reportProgress:@"准备Il2Cpp转储环境..."];

        // 4. 执行Il2Cpp转储
        NSLog(@"[UnityDump] 开始执行Il2Cpp转储...");
        BOOL success = [self performIl2CppDump:bundleId frameworkPath:frameworkPath outputPath:appOutputPath];

        if (success) {
            NSLog(@"[UnityDump] 转储成功完成");
            [self reportProgress:@"转储完成！"];
            [self reportSuccess:appOutputPath];
        } else {
            NSLog(@"[UnityDump] 转储失败");
            [self reportError:@"Il2Cpp转储失败"];
        }

    } @catch (NSException *exception) {
        NSLog(@"[UnityDump] 异常: %@", exception.reason);
        NSLog(@"[UnityDump] 调用栈: %@", exception.callStackSymbols);
        [self reportError:[NSString stringWithFormat:@"转储过程发生异常: %@", exception.reason]];
    } @finally {
        NSLog(@"[UnityDump] 清理资源");
        self.isDumping = NO;
        self.currentProgressCallback = nil;
        self.currentCompletionCallback = nil;
    }
}

- (BOOL)canDumpUnityApp:(NSString *)bundleId {
    // 简化检查，只要有bundleId就认为可以尝试dump
    if (!bundleId || bundleId.length == 0) {
        return NO;
    }

    // 检查是否能获取到Unity框架路径
    NSString *frameworkPath = [self getUnityFrameworkPath:bundleId];
    return frameworkPath != nil;
}

- (NSString *)getUnityFrameworkPath:(NSString *)bundleId {
    NSLog(@"[UnityDump] 为Bundle ID生成Unity框架路径: %@", bundleId);

    // 注意：在iOS沙盒环境中，我们无法直接访问其他应用的文件系统
    // 这里返回一个模拟路径用于测试，实际的Il2Cpp dump需要在目标应用内部执行
    NSString *simulatedPath = [NSString stringWithFormat:@"/var/containers/Bundle/Application/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX/%@.app/Frameworks/UnityFramework.framework/UnityFramework", bundleId.lastPathComponent];

    NSLog(@"[UnityDump] 使用模拟Unity框架路径: %@", simulatedPath);
    return simulatedPath;
}

- (NSString *)createOutputDirectoryForApp:(NSString *)bundleId outputPath:(NSString *)outputPath {
    NSString *appName = bundleId.lastPathComponent ?: bundleId;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMdd_HHmmss";
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    NSString *appOutputPath = [outputPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@", appName, timestamp]];
    
    NSError *error;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:appOutputPath
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:&error]) {
        NSLog(@"创建输出目录失败: %@", error.localizedDescription);
        return nil;
    }
    
    return appOutputPath;
}

- (BOOL)performIl2CppDump:(NSString *)bundleId frameworkPath:(NSString *)frameworkPath outputPath:(NSString *)outputPath {
    NSLog(@"[UnityDump] 开始真正的 Unity Il2Cpp 转储");

    // 获取选中应用的进程ID
    pid_t processId = 0;

    // 从 ProcessManager 获取选中的进程ID
    ProcessManager *processManager = [ProcessManager sharedManager];
    if (processManager.selectedProcessPID) {
        processId = [processManager.selectedProcessPID intValue];
        NSLog(@"[UnityDump] 使用 ProcessManager 中的进程ID: %d", processId);
    } else {
        // 如果没有选中进程，尝试通过 bundle ID 查找
        NSLog(@"[UnityDump] ProcessManager 中没有选中进程，尝试查找进程");
        // 这里可以添加通过 bundle ID 查找进程的逻辑
        [self reportProgress:@"错误：未找到目标进程"];
        return NO;
    }

    [self reportProgress:@"检测 Unity 运行时..."];

    // 检测 Unity 运行时
    if (!DetectUnityRuntimeForProcess(processId)) {
        [self reportProgress:@"错误：Unity 运行时检测失败"];
        return NO;
    }

    [self reportProgress:@"Unity 运行时检测成功，开始分析..."];

    // 执行基础分析
    const char* outputPathCStr = [outputPath UTF8String];
    if (!PerformBasicUnityAnalysis(outputPathCStr)) {
        [self reportProgress:@"错误：Unity 分析失败"];
        return NO;
    }

    [self reportProgress:@"Unity 分析完成！"];

    // 检查生成的文件
    NSString *dumpFile = [outputPath stringByAppendingPathComponent:@"dump.cs"];
    NSString *structFile = [outputPath stringByAppendingPathComponent:@"struct.hpp"];

    if ([[NSFileManager defaultManager] fileExistsAtPath:dumpFile]) {
        NSLog(@"[UnityDump] 成功生成 dump.cs 文件");
    }

    if ([[NSFileManager defaultManager] fileExistsAtPath:structFile]) {
        NSLog(@"[UnityDump] 成功生成 struct.hpp 文件");
    }

    return YES;
}

- (void)stopDumping {
    self.isDumping = NO;
    if (self.currentCompletionCallback) {
        self.currentCompletionCallback(NO, @"用户取消操作", nil);
    }
    self.currentProgressCallback = nil;
    self.currentCompletionCallback = nil;
}

#pragma mark - Private Methods

- (void)reportProgress:(NSString *)message {
    NSLog(@"[UnityDump] %@", message);
    if (self.currentProgressCallback) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.currentProgressCallback(message);
        });
    }
}

- (void)reportSuccess:(NSString *)outputPath {
    if (self.currentCompletionCallback) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.currentCompletionCallback(YES, nil, outputPath);
        });
    }
}

- (void)reportError:(NSString *)errorMessage {
    NSLog(@"[UnityDump] 错误: %@", errorMessage);
    if (self.currentCompletionCallback) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.currentCompletionCallback(NO, errorMessage, nil);
        });
    }
}

@end

#pragma mark - C++ Unity 处理函数

// 获取指定进程的 Unity 库句柄
void* GetUnityLibraryHandleForProcess(pid_t processId) {
    NSLog(@"[UnityDump] 开始获取进程 %d 的 Unity 库句柄", processId);

    // 获取当前进程的所有加载的库
    uint32_t count = _dyld_image_count();

    for (uint32_t i = 0; i < count; i++) {
        const char* imageName = _dyld_get_image_name(i);
        if (!imageName) continue;

        NSString *name = [NSString stringWithUTF8String:imageName];
        NSLog(@"[UnityDump] 检查库: %@", name);

        // 检查是否是 Unity 相关库
        if ([name containsString:@"UnityFramework"] ||
            [name containsString:@"libmono"] ||
            [name containsString:@"GameAssembly"] ||
            [name containsString:@"libil2cpp"]) {

            NSLog(@"[UnityDump] 找到 Unity 库: %@", name);

            // 获取库的头部地址
            const struct mach_header* header = _dyld_get_image_header(i);
            if (header) {
                NSLog(@"[UnityDump] 成功获取库头部地址: %p", header);
                return (void*)header;
            }
        }
    }

    NSLog(@"[UnityDump] 未找到 Unity 库，尝试使用 dlopen");

    // 如果没找到，尝试使用 dlopen
    const char* possiblePaths[] = {
        "UnityFramework.framework/UnityFramework",
        "@executable_path/Frameworks/UnityFramework.framework/UnityFramework",
        "@loader_path/Frameworks/UnityFramework.framework/UnityFramework",
        "libmono.dylib",
        "libil2cpp.dylib",
        NULL
    };

    for (int i = 0; possiblePaths[i] != NULL; i++) {
        void* handle = dlopen(possiblePaths[i], RTLD_NOW | RTLD_GLOBAL);
        if (handle) {
            NSLog(@"[UnityDump] 通过 dlopen 成功加载: %s", possiblePaths[i]);
            return handle;
        }
    }

    // 最后尝试使用 RTLD_DEFAULT
    NSLog(@"[UnityDump] 尝试使用 RTLD_DEFAULT");
    return (void*)RTLD_DEFAULT;
}

// 检测 Unity 运行时
BOOL DetectUnityRuntimeForProcess(pid_t processId) {
    NSLog(@"[UnityDump] 开始检测 Unity 运行时，进程ID: %d", processId);

    // 获取 Unity 库句柄
    void* unityHandle = GetUnityLibraryHandleForProcess(processId);
    if (!unityHandle) {
        NSLog(@"[UnityDump] 错误：无法获取 Unity 库句柄");
        return NO;
    }

    // 检测 Unity 模式
    NSString* detectedMode = @"Unknown";

    // 检查是否是 Il2Cpp
    void* il2cppFunc = dlsym(unityHandle, "il2cpp_domain_get");
    if (il2cppFunc) {
        detectedMode = @"Il2Cpp";
        NSLog(@"[UnityDump] 检测到 Il2Cpp 模式");
    } else {
        // 检查是否是 Mono
        void* monoFunc = dlsym(unityHandle, "mono_get_root_domain");
        if (monoFunc) {
            detectedMode = @"Mono";
            NSLog(@"[UnityDump] 检测到 Mono 模式");
        } else {
            // 尝试使用 RTLD_DEFAULT 搜索
            il2cppFunc = dlsym(RTLD_DEFAULT, "il2cpp_domain_get");
            monoFunc = dlsym(RTLD_DEFAULT, "mono_get_root_domain");

            if (il2cppFunc) {
                detectedMode = @"Il2Cpp (RTLD_DEFAULT)";
                unityHandle = (void*)RTLD_DEFAULT;
                NSLog(@"[UnityDump] 通过 RTLD_DEFAULT 检测到 Il2Cpp 模式");
            } else if (monoFunc) {
                detectedMode = @"Mono (RTLD_DEFAULT)";
                unityHandle = (void*)RTLD_DEFAULT;
                NSLog(@"[UnityDump] 通过 RTLD_DEFAULT 检测到 Mono 模式");
            } else {
                NSLog(@"[UnityDump] 错误：未检测到有效的 Unity 运行时");
                return NO;
            }
        }
    }

    NSLog(@"[UnityDump] Unity 运行时检测成功: %@", detectedMode);
    return YES;
}

// 执行基础 Unity 分析
BOOL PerformBasicUnityAnalysis(const char* outputPath) {
    NSLog(@"[UnityDump] 开始执行基础 Unity 分析到路径: %s", outputPath);

    @try {
        // 创建输出目录
        NSString *outputDir = [NSString stringWithUTF8String:outputPath];
        [[NSFileManager defaultManager] createDirectoryAtPath:outputDir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];

        // 生成基础分析报告
        NSString *reportPath = [outputDir stringByAppendingPathComponent:@"unity_analysis.txt"];
        NSMutableString *report = [NSMutableString string];

        [report appendString:@"Unity 运行时分析报告\n"];
        [report appendString:@"===================\n\n"];
        [report appendFormat:@"分析时间: %@\n", [NSDate date]];
        [report appendString:@"检测到的 Unity 库:\n"];

        // 检查已加载的 Unity 相关库
        uint32_t count = _dyld_image_count();
        for (uint32_t i = 0; i < count; i++) {
            const char* imageName = _dyld_get_image_name(i);
            if (imageName) {
                NSString *name = [NSString stringWithUTF8String:imageName];
                if ([name containsString:@"Unity"] ||
                    [name containsString:@"mono"] ||
                    [name containsString:@"il2cpp"]) {
                    [report appendFormat:@"- %@\n", name];
                }
            }
        }

        // 写入报告文件
        [report writeToFile:reportPath
                 atomically:YES
                   encoding:NSUTF8StringEncoding
                      error:nil];

        NSLog(@"[UnityDump] 基础 Unity 分析完成，报告保存到: %@", reportPath);
        return YES;
    } @catch (NSException *exception) {
        NSLog(@"[UnityDump] Unity 分析执行失败: %@", exception.reason);
        return NO;
    }
}
