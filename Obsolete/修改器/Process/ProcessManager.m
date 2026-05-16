#import "ProcessManager.h"

@interface ProcessManager ()

@property (nonatomic, strong, readwrite) NSString *selectedProcessPID;
@property (nonatomic, strong, readwrite) NSString *selectedProcessName;

@end

@implementation ProcessManager

+ (instancetype)sharedManager {
    static ProcessManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)selectProcessWithPID:(NSString *)pid processName:(NSString *)processName {
    self.selectedProcessPID = pid;
    self.selectedProcessName = processName;
    
    // 发送全局通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ProcessManagerSelectedProcessChangedNotification" 
                                                        object:nil 
                                                      userInfo:@{@"pid": pid, 
                                                                 @"appName": processName}];
    
    // 持久化存储
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:pid forKey:@"LastSelectedProcessPID"];
    [defaults setObject:processName forKey:@"LastSelectedProcessName"];
    [defaults synchronize];
}

- (void)clearSelectedProcess {
    self.selectedProcessPID = nil;
    self.selectedProcessName = nil;
    
    // 清除持久化存储
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"LastSelectedProcessPID"];
    [defaults removeObjectForKey:@"LastSelectedProcessName"];
    [defaults synchronize];
    
    // 发送通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ProcessManagerSelectedProcessChangedNotification" 
                                                        object:nil 
                                                      userInfo:@{}];
}

- (pid_t)selectedPid {
    // 如果 selectedProcessPID 为 nil，返回 0
    if (!self.selectedProcessPID) {
        NSLog(@"错误：未选择进程");
        return 0;
    }
    
    // 尝试将字符串转换为 pid_t
    pid_t pid = [self.selectedProcessPID intValue];
    
    // 验证转换后的 PID 是否有效
    if (pid <= 0) {
        NSLog(@"错误：无效的进程ID字符串 %@", self.selectedProcessPID);
        return 0;
    }
    
    return pid;
}

@end 
