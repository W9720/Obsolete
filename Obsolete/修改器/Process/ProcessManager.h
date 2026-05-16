#import <Foundation/Foundation.h>

@interface ProcessManager : NSObject

@property (nonatomic, strong, readonly) NSString *selectedProcessPID;
@property (nonatomic, strong, readonly) NSString *selectedProcessName;

+ (instancetype)sharedManager;

- (void)selectProcessWithPID:(NSString *)pid processName:(NSString *)processName;
- (void)clearSelectedProcess;

- (pid_t)selectedPid;

@end