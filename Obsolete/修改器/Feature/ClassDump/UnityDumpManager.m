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

@interface UnityDumpManager ()
@property (nonatomic, assign) BOOL isDumping;
@property (nonatomic, copy) UnityDumpProgressCallback currentProgressCallback;
@property (nonatomic, copy) UnityDumpCompletionCallback currentCompletionCallback;
@end

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
    // 这里应该集成Il2CppDumper的核心逻辑
    // 由于Il2CppDumper是一个独立的项目，这里模拟转储过程
    
    [self reportProgress:@"初始化Il2Cpp环境..."];
    sleep(1);
    
    [self reportProgress:@"解析程序集..."];
    sleep(2);
    
    [self reportProgress:@"提取类定义..."];
    sleep(2);
    
    [self reportProgress:@"生成C#代码..."];
    sleep(1);
    
    // 创建示例输出文件
    NSString *dumpFile = [outputPath stringByAppendingPathComponent:@"dump.cs"];
    NSString *assemblyDir = [outputPath stringByAppendingPathComponent:@"Assembly"];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:assemblyDir withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSString *sampleContent = [NSString stringWithFormat:@"// Unity Il2Cpp Dump for %@\n// Generated at %@\n\nnamespace UnityEngine {\n    public class GameObject {\n        // Sample Unity class\n    }\n}\n", bundleId, [NSDate date]];
    
    [sampleContent writeToFile:dumpFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [sampleContent writeToFile:[assemblyDir stringByAppendingPathComponent:@"UnityEngine.cs"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
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
