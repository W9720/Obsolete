//
//  BaseAddressScriptManager.m
//  基址脚本管理器实现
//

#import "BaseAddressScriptManager.h"
#import <CommonCrypto/CommonDigest.h>

// 通知名称
NSString * const BaseAddressScriptDidAddNotification = @"BaseAddressScriptDidAddNotification";
NSString * const BaseAddressScriptDidRemoveNotification = @"BaseAddressScriptDidRemoveNotification";
NSString * const BaseAddressScriptDidUpdateNotification = @"BaseAddressScriptDidUpdateNotification";
NSString * const BaseAddressScriptDidExecuteNotification = @"BaseAddressScriptDidExecuteNotification";

// 存储键
static NSString * const kScriptsStorageKey = @"BaseAddressScripts";
static NSString * const kCategoriesStorageKey = @"BaseAddressScriptCategories";

@interface BaseAddressScriptManager ()

@property (nonatomic, strong) NSMutableArray<BaseAddressScript *> *mutableScripts;
@property (nonatomic, strong) NSMutableArray<NSString *> *mutableCategories;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSTimer *> *executingScripts;

@end

@implementation BaseAddressScriptManager

+ (instancetype)sharedManager {
    static BaseAddressScriptManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BaseAddressScriptManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableScripts = [[NSMutableArray alloc] init];
        _mutableCategories = [[NSMutableArray alloc] initWithObjects:@"默认", @"游戏", @"应用", nil];
        _executingScripts = [[NSMutableDictionary alloc] init];
        
        // 加载保存的脚本
        [self loadScripts];
    }
    return self;
}

#pragma mark - Properties

- (NSArray<BaseAddressScript *> *)scripts {
    return [self.mutableScripts copy];
}

- (NSArray<NSString *> *)categories {
    return [self.mutableCategories copy];
}

#pragma mark - 脚本管理

- (void)addScript:(BaseAddressScript *)script {
    if (!script) return;
    
    [self.mutableScripts addObject:script];
    [self saveScripts];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BaseAddressScriptDidAddNotification
                                                        object:self
                                                      userInfo:@{@"script": script}];
}

- (void)removeScript:(BaseAddressScript *)script {
    if (!script) return;
    
    [self removeScriptWithId:script.scriptId];
}

- (void)removeScriptWithId:(NSString *)scriptId {
    if (!scriptId) return;
    
    BaseAddressScript *scriptToRemove = nil;
    for (BaseAddressScript *script in self.mutableScripts) {
        if ([script.scriptId isEqualToString:scriptId]) {
            scriptToRemove = script;
            break;
        }
    }
    
    if (scriptToRemove) {
        // 停止执行中的脚本
        NSTimer *timer = self.executingScripts[scriptId];
        if (timer) {
            [timer invalidate];
            [self.executingScripts removeObjectForKey:scriptId];
        }
        
        [self.mutableScripts removeObject:scriptToRemove];
        [self saveScripts];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:BaseAddressScriptDidRemoveNotification
                                                            object:self
                                                          userInfo:@{@"script": scriptToRemove}];
    }
}

- (void)updateScript:(BaseAddressScript *)script {
    if (!script) return;
    
    script.modifiedDate = [NSDate date];
    [self saveScripts];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BaseAddressScriptDidUpdateNotification
                                                        object:self
                                                      userInfo:@{@"script": script}];
}

- (BaseAddressScript *)scriptWithId:(NSString *)scriptId {
    if (!scriptId) return nil;
    
    for (BaseAddressScript *script in self.mutableScripts) {
        if ([script.scriptId isEqualToString:scriptId]) {
            return script;
        }
    }
    return nil;
}

- (NSArray<BaseAddressScript *> *)scriptsInCategory:(NSString *)category {
    if (!category) return @[];
    
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (BaseAddressScript *script in self.mutableScripts) {
        if ([script.category isEqualToString:category]) {
            [result addObject:script];
        }
    }
    return result;
}

#pragma mark - 分类管理

- (void)addCategory:(NSString *)category {
    if (!category || [self.mutableCategories containsObject:category]) return;
    
    [self.mutableCategories addObject:category];
    [self saveCategories];
}

- (void)removeCategory:(NSString *)category {
    if (!category || [category isEqualToString:@"默认"]) return;
    
    // 将该分类下的脚本移动到默认分类
    for (BaseAddressScript *script in self.mutableScripts) {
        if ([script.category isEqualToString:category]) {
            script.category = @"默认";
        }
    }
    
    [self.mutableCategories removeObject:category];
    [self saveCategories];
    [self saveScripts];
}

- (void)renameCategory:(NSString *)oldName toName:(NSString *)newName {
    if (!oldName || !newName || [oldName isEqualToString:@"默认"]) return;
    
    NSInteger index = [self.mutableCategories indexOfObject:oldName];
    if (index != NSNotFound) {
        self.mutableCategories[index] = newName;
        
        // 更新脚本的分类
        for (BaseAddressScript *script in self.mutableScripts) {
            if ([script.category isEqualToString:oldName]) {
                script.category = newName;
            }
        }
        
        [self saveCategories];
        [self saveScripts];
    }
}

- (NSInteger)scriptsCountInCategory:(NSString *)category {
    if (!category) return 0;

    NSInteger count = 0;
    for (BaseAddressScript *script in self.mutableScripts) {
        if ([script.category isEqualToString:category]) {
            count++;
        }
    }
    return count;
}

#pragma mark - 脚本执行

- (BOOL)executeScript:(BaseAddressScript *)script {
    if (!script) return NO;

    BOOL success = [script executeScript];

    // 保存脚本状态变化
    [self saveScripts];

    if (success && script.autoExecute && script.executeInterval > 0) {
        // 停止之前的定时器
        NSTimer *oldTimer = self.executingScripts[script.scriptId];
        if (oldTimer) {
            [oldTimer invalidate];
        }

        // 创建新的定时器
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:script.executeInterval
                                                          target:self
                                                        selector:@selector(executeScriptTimer:)
                                                        userInfo:@{@"scriptId": script.scriptId}
                                                         repeats:YES];
        self.executingScripts[script.scriptId] = timer;
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:BaseAddressScriptDidExecuteNotification
                                                        object:self
                                                      userInfo:@{@"script": script, @"success": @(success)}];

    return success;
}

- (BOOL)executeScriptWithId:(NSString *)scriptId {
    BaseAddressScript *script = [self scriptWithId:scriptId];
    return [self executeScript:script];
}

- (void)executeScriptTimer:(NSTimer *)timer {
    NSString *scriptId = timer.userInfo[@"scriptId"];
    [self executeScriptWithId:scriptId];
}

- (void)stopScript:(BaseAddressScript *)script {
    if (!script) return;

    // 停止定时器
    NSTimer *timer = self.executingScripts[script.scriptId];
    if (timer) {
        [timer invalidate];
        [self.executingScripts removeObjectForKey:script.scriptId];
    }

    // 更新脚本状态
    script.status = BaseAddressScriptStatusInactive;

    // 保存状态变化
    [self saveScripts];

    // 发送通知
    [[NSNotificationCenter defaultCenter] postNotificationName:BaseAddressScriptDidExecuteNotification
                                                        object:self
                                                      userInfo:@{@"script": script, @"success": @NO}];
}

- (void)stopAllScripts {
    for (NSTimer *timer in self.executingScripts.allValues) {
        [timer invalidate];
    }
    [self.executingScripts removeAllObjects];

    for (BaseAddressScript *script in self.mutableScripts) {
        script.status = BaseAddressScriptStatusInactive;
    }
}

#pragma mark - 数据持久化

- (BOOL)saveScripts {
    NSLog(@"[BaseAddressScriptManager] 开始保存脚本，数量: %lu", (unsigned long)self.mutableScripts.count);

    NSError *error;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.mutableScripts
                                         requiringSecureCoding:YES
                                                         error:&error];

    if (error) {
        NSLog(@"[BaseAddressScriptManager] 保存脚本失败: %@", error.localizedDescription);
        return NO;
    }

    if (!data) {
        NSLog(@"[BaseAddressScriptManager] 序列化数据为空");
        return NO;
    }

    [[NSUserDefaults standardUserDefaults] setObject:data forKey:kScriptsStorageKey];
    BOOL syncResult = [[NSUserDefaults standardUserDefaults] synchronize];

    NSLog(@"[BaseAddressScriptManager] 脚本保存完成，数据大小: %lu, 同步结果: %@",
          (unsigned long)data.length, syncResult ? @"成功" : @"失败");

    return YES;
}

- (BOOL)loadScripts {
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:kScriptsStorageKey];
    if (!data) {
        NSLog(@"[BaseAddressScriptManager] 没有找到保存的脚本数据");
        return YES;
    }

    NSLog(@"[BaseAddressScriptManager] 开始加载脚本数据，数据大小: %lu", (unsigned long)data.length);

    NSError *error;
    NSSet *allowedClasses = [NSSet setWithObjects:[NSArray class], [NSMutableArray class], [BaseAddressScript class], [BaseAddressPointerChain class], [BaseAddressPointerNode class], nil];
    NSArray *scripts = [NSKeyedUnarchiver unarchivedObjectOfClasses:allowedClasses
                                                           fromData:data
                                                              error:&error];

    if (error) {
        NSLog(@"[BaseAddressScriptManager] 加载脚本失败: %@", error.localizedDescription);
        return NO;
    }

    if (scripts) {
        [self.mutableScripts removeAllObjects];
        [self.mutableScripts addObjectsFromArray:scripts];
        NSLog(@"[BaseAddressScriptManager] 成功加载 %lu 个脚本", (unsigned long)scripts.count);
    } else {
        NSLog(@"[BaseAddressScriptManager] 脚本数据为空");
    }

    [self loadCategories];
    return YES;
}

- (void)saveCategories {
    [[NSUserDefaults standardUserDefaults] setObject:self.mutableCategories forKey:kCategoriesStorageKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)loadCategories {
    NSArray *categories = [[NSUserDefaults standardUserDefaults] objectForKey:kCategoriesStorageKey];
    if (categories) {
        [self.mutableCategories removeAllObjects];
        [self.mutableCategories addObjectsFromArray:categories];
    }
}

- (void)clearAllScripts {
    [self stopAllScripts];
    [self.mutableScripts removeAllObjects];
    [self saveScripts];
}

#pragma mark - 导入导出

- (NSString *)exportScript:(BaseAddressScript *)script {
    if (!script) return nil;

    // 加密脚本必须使用加密导出
    if (script.isEncrypted) {
        NSLog(@"[BaseAddressScriptManager] 警告：尝试普通导出加密脚本，返回加密状态信息");
    }

    return [script exportToString];
}

- (NSString *)exportScript:(BaseAddressScript *)script encrypted:(BOOL)encrypted password:(NSString *)password {
    if (!script) return nil;
    return [script exportToStringWithEncryption:encrypted password:password];
}

- (NSString *)exportAllScripts {
    NSMutableArray *scriptsData = [[NSMutableArray alloc] init];

    NSLog(@"[BaseAddressScriptManager] 开始导出脚本，总数: %lu", (unsigned long)self.mutableScripts.count);

    // 检查是否包含加密脚本
    BOOL hasEncryptedScript = NO;
    for (BaseAddressScript *script in self.mutableScripts) {
        if (script.isEncrypted) {
            hasEncryptedScript = YES;
            break;
        }
    }

    for (BaseAddressScript *script in self.mutableScripts) {
        NSString *scriptString = [script exportToString];
        if (scriptString) {
            [scriptsData addObject:scriptString];
            NSLog(@"[BaseAddressScriptManager] 导出脚本: %@%@", script.name, script.isEncrypted ? @" (加密)" : @"");
        } else {
            NSLog(@"[BaseAddressScriptManager] 脚本导出失败: %@", script.name);
        }
    }

    NSLog(@"[BaseAddressScriptManager] 成功导出脚本数: %lu", (unsigned long)scriptsData.count);

    // 确保日期可以序列化
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    NSString *dateString = [formatter stringFromDate:[NSDate date]];

    NSMutableDictionary *exportData = [@{
        @"scripts": scriptsData,
        @"categories": self.mutableCategories ?: @[],
        @"exportDate": dateString,
        @"version": @"1.0"
    } mutableCopy];

    // 如果包含加密脚本，标记整个导出为包含加密内容
    if (hasEncryptedScript) {
        exportData[@"containsEncryptedScripts"] = @YES;
    }

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:exportData
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];

    if (error) {
        NSLog(@"[BaseAddressScriptManager] JSON序列化失败: %@", error.localizedDescription);
        return nil;
    }

    NSString *result = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSLog(@"[BaseAddressScriptManager] 导出完成，数据长度: %lu", (unsigned long)result.length);

    return result;
}

- (NSString *)exportAllScriptsWithEncryption:(BOOL)encrypted password:(NSString *)password {
    NSMutableArray *scriptsData = [[NSMutableArray alloc] init];

    NSLog(@"[BaseAddressScriptManager] 开始导出脚本，总数: %lu，加密: %@",
          (unsigned long)self.mutableScripts.count, encrypted ? @"是" : @"否");

    for (BaseAddressScript *script in self.mutableScripts) {
        NSString *scriptString;

        if (encrypted && password.length > 0) {
            // 使用加密导出，指针链会被加密
            scriptString = [script exportToStringWithEncryption:YES password:password];
        } else {
            // 普通导出
            scriptString = [script exportToString];
        }

        if (scriptString) {
            [scriptsData addObject:scriptString];
            NSLog(@"[BaseAddressScriptManager] 导出脚本: %@", script.name);
        } else {
            NSLog(@"[BaseAddressScriptManager] 脚本导出失败: %@", script.name);
        }
    }

    NSLog(@"[BaseAddressScriptManager] 成功导出脚本数: %lu", (unsigned long)scriptsData.count);

    // 确保日期可以序列化
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    NSString *dateString = [formatter stringFromDate:[NSDate date]];

    NSDictionary *exportData = @{
        @"scripts": scriptsData,
        @"categories": self.mutableCategories ?: @[],
        @"exportDate": dateString,
        @"version": @"1.0",
        @"encrypted": encrypted ? @YES : @NO
    };

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:exportData
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];

    if (error) {
        NSLog(@"[BaseAddressScriptManager] JSON序列化失败: %@", error.localizedDescription);
        return nil;
    }

    NSString *result = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSLog(@"[BaseAddressScriptManager] 导出完成，数据长度: %lu", (unsigned long)result.length);

    return result;
}

// 带作者信息的加密导出方法
- (NSString *)exportAllScriptsWithEncryption:(BOOL)encrypted
                                    password:(NSString *)password
                                  authorName:(NSString *)authorName
                             authorDescription:(NSString *)authorDescription {
    NSMutableArray *scriptsData = [[NSMutableArray alloc] init];

    NSLog(@"[BaseAddressScriptManager] 开始导出脚本，总数: %lu，加密: %@，作者: %@",
          (unsigned long)self.mutableScripts.count, encrypted ? @"是" : @"否", authorName ?: @"未设置");

    for (BaseAddressScript *script in self.mutableScripts) {
        NSString *scriptString;

        // 临时更新脚本的作者信息
        NSString *originalAuthor = script.author;
        NSString *originalDescription = script.scriptDescription;

        if (authorName && authorName.length > 0) {
            script.author = authorName;
        }
        if (authorDescription && authorDescription.length > 0) {
            script.scriptDescription = authorDescription;
        }

        if (encrypted && password.length > 0) {
            // 使用加密导出，指针链会被加密
            scriptString = [script exportToStringWithEncryption:YES password:password];
        } else {
            // 普通导出
            scriptString = [script exportToString];
        }

        // 恢复原始作者信息
        script.author = originalAuthor;
        script.scriptDescription = originalDescription;

        if (scriptString) {
            [scriptsData addObject:scriptString];
            NSLog(@"[BaseAddressScriptManager] 导出脚本: %@", script.name);
        } else {
            NSLog(@"[BaseAddressScriptManager] 脚本导出失败: %@", script.name);
        }
    }

    NSLog(@"[BaseAddressScriptManager] 成功导出脚本数: %lu", (unsigned long)scriptsData.count);

    // 确保日期可以序列化
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    NSString *dateString = [formatter stringFromDate:[NSDate date]];

    NSMutableDictionary *exportData = [@{
        @"scripts": scriptsData,
        @"categories": self.mutableCategories ?: @[],
        @"exportDate": dateString,
        @"version": @"1.0",
        @"encrypted": encrypted ? @YES : @NO
    } mutableCopy];

    // 添加作者信息
    if (authorName && authorName.length > 0) {
        exportData[@"authorName"] = authorName;
    }
    if (authorDescription && authorDescription.length > 0) {
        exportData[@"authorDescription"] = authorDescription;
    }

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:exportData
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];

    if (error) {
        NSLog(@"[BaseAddressScriptManager] JSON序列化失败: %@", error.localizedDescription);
        return nil;
    }

    NSString *result = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSLog(@"[BaseAddressScriptManager] 导出完成，数据长度: %lu", (unsigned long)result.length);

    return result;
}

- (BOOL)importScriptFromString:(NSString *)scriptString {
    if (!scriptString) return NO;

    BaseAddressScript *script = [[BaseAddressScript alloc] initWithName:@"导入脚本"
                                                                    type:BaseAddressScriptTypePointerChain];

    if ([script importFromString:scriptString]) {
        [self addScript:script];
        return YES;
    }

    return NO;
}

- (BOOL)importScriptFromString:(NSString *)scriptString encrypted:(BOOL)encrypted password:(NSString *)password {
    if (!scriptString) return NO;

    BaseAddressScript *script = [[BaseAddressScript alloc] initWithName:@"导入脚本"
                                                                    type:BaseAddressScriptTypePointerChain];

    if (encrypted && password.length > 0) {
        if ([script importFromString:scriptString withPassword:password]) {
            // 确保加密脚本标记正确
            script.isEncrypted = YES;
            [self addScript:script];
            return YES;
        }
    } else {
        if ([script importFromString:scriptString]) {
            [self addScript:script];
            return YES;
        }
    }

    return NO;
}

- (BOOL)importScriptsFromString:(NSString *)scriptsString {
    if (!scriptsString) {
        NSLog(@"[BaseAddressScriptManager] 导入失败: 输入字符串为空");
        return NO;
    }

    NSLog(@"[BaseAddressScriptManager] 开始导入脚本，数据长度: %lu", (unsigned long)scriptsString.length);

    NSError *error;
    NSData *jsonData = [scriptsString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *importData = [NSJSONSerialization JSONObjectWithData:jsonData
                                                               options:0
                                                                 error:&error];

    if (error || !importData) {
        NSLog(@"[BaseAddressScriptManager] JSON解析失败: %@", error.localizedDescription);
        return NO;
    }

    NSArray *scriptsData = importData[@"scripts"];
    NSArray *categories = importData[@"categories"];

    NSLog(@"[BaseAddressScriptManager] 解析到脚本数: %lu, 分类数: %lu",
          (unsigned long)scriptsData.count, (unsigned long)categories.count);

    // 导入分类
    if (categories) {
        for (NSString *category in categories) {
            [self addCategory:category];
            NSLog(@"[BaseAddressScriptManager] 导入分类: %@", category);
        }
    }

    // 检查是否为加密脚本
    BOOL isEncrypted = [importData[@"encrypted"] boolValue];

    // 导入脚本
    BOOL success = YES;
    NSInteger successCount = 0;
    for (NSString *scriptString in scriptsData) {
        if ([self importScriptFromString:scriptString encrypted:isEncrypted password:nil]) {
            successCount++;
        } else {
            success = NO;
            NSLog(@"[BaseAddressScriptManager] 脚本导入失败");
        }
    }

    NSLog(@"[BaseAddressScriptManager] 导入完成，成功: %ld/%lu",
          (long)successCount, (unsigned long)scriptsData.count);

    // 发送通知更新界面
    [[NSNotificationCenter defaultCenter] postNotificationName:BaseAddressScriptDidAddNotification object:nil];

    return success;
}

- (BOOL)importScriptsFromStringWithPassword:(NSString *)scriptsString password:(NSString *)password {
    if (!scriptsString) {
        NSLog(@"[BaseAddressScriptManager] 导入失败: 输入字符串为空");
        return NO;
    }

    NSLog(@"[BaseAddressScriptManager] 开始导入加密脚本，数据长度: %lu", (unsigned long)scriptsString.length);

    NSError *error;
    NSData *jsonData = [scriptsString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *importData = [NSJSONSerialization JSONObjectWithData:jsonData
                                                               options:0
                                                                 error:&error];

    if (error || !importData) {
        NSLog(@"[BaseAddressScriptManager] JSON解析失败: %@", error.localizedDescription);
        return NO;
    }

    NSArray *scriptsData = importData[@"scripts"];
    NSArray *categories = importData[@"categories"];
    BOOL isEncrypted = [importData[@"encrypted"] boolValue];

    NSLog(@"[BaseAddressScriptManager] 解析到脚本数: %lu, 分类数: %lu, 加密: %@",
          (unsigned long)scriptsData.count, (unsigned long)categories.count, isEncrypted ? @"是" : @"否");

    // 导入分类
    if (categories) {
        for (NSString *category in categories) {
            [self addCategory:category];
            NSLog(@"[BaseAddressScriptManager] 导入分类: %@", category);
        }
    }

    // 导入脚本 - 通过密码导入的脚本强制标记为加密
    BOOL success = YES;
    NSInteger successCount = 0;
    for (NSString *scriptString in scriptsData) {
        if ([self importScriptFromString:scriptString encrypted:YES password:password]) {  // 强制设置为加密
            successCount++;
        } else {
            success = NO;
            NSLog(@"[BaseAddressScriptManager] 脚本导入失败");
        }
    }

    NSLog(@"[BaseAddressScriptManager] 导入完成，成功: %ld/%lu",
          (long)successCount, (unsigned long)scriptsData.count);

    // 发送通知更新界面
    [[NSNotificationCenter defaultCenter] postNotificationName:BaseAddressScriptDidAddNotification object:nil];

    return success;
}

#pragma mark - 分享功能

- (void)shareScript:(BaseAddressScript *)script 
     fromController:(UIViewController *)controller 
         completion:(void(^)(BOOL success))completion {
    
    NSString *scriptString = [self exportScript:script];
    if (!scriptString) {
        if (completion) completion(NO);
        return;
    }
    
    // 创建临时文件
    NSString *fileName = [NSString stringWithFormat:@"%@.bas", script.name];
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    
    NSError *error;
    BOOL writeSuccess = [scriptString writeToFile:tempPath
                                        atomically:YES
                                          encoding:NSUTF8StringEncoding
                                             error:&error];
    
    if (!writeSuccess) {
        if (completion) completion(NO);
        return;
    }
    
    NSURL *fileURL = [NSURL fileURLWithPath:tempPath];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] 
                                           initWithActivityItems:@[fileURL]
                                           applicationActivities:nil];
    
    activityVC.completionWithItemsHandler = ^(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        // 清理临时文件
        [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];
        
        if (completion) completion(completed);
    };
    
    // iPad 支持
    if (activityVC.popoverPresentationController) {
        activityVC.popoverPresentationController.sourceView = controller.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(controller.view.bounds.size.width/2, 
                                                                         controller.view.bounds.size.height/2, 
                                                                         0, 0);
    }
    
    [controller presentViewController:activityVC animated:YES completion:nil];
}

- (void)shareScript:(BaseAddressScript *)script
     fromController:(UIViewController *)controller
          encrypted:(BOOL)encrypted
           password:(NSString *)password
         authorName:(NSString *)authorName
    authorDescription:(NSString *)authorDescription
         completion:(void(^)(BOOL success))completion {

    NSString *scriptString;

    if (encrypted && password.length > 0) {
        // 临时更新脚本的作者信息
        NSString *originalAuthor = script.author;
        NSString *originalDescription = script.scriptDescription;

        if (authorName && authorName.length > 0) {
            script.author = authorName;
        }
        if (authorDescription && authorDescription.length > 0) {
            script.scriptDescription = authorDescription;
        }

        // 使用加密导出，指针链会被加密
        scriptString = [self exportScript:script encrypted:YES password:password];

        // 恢复原始作者信息
        script.author = originalAuthor;
        script.scriptDescription = originalDescription;

        if (!scriptString) {
            if (completion) completion(NO);
            return;
        }
        // 再对整个内容进行加密
        scriptString = [self encryptString:scriptString withPassword:password];
        if (!scriptString) {
            if (completion) completion(NO);
            return;
        }
    } else {
        // 普通导出
        scriptString = [self exportScript:script];
        if (!scriptString) {
            if (completion) completion(NO);
            return;
        }
    }

    // 创建临时文件
    NSString *fileName = [NSString stringWithFormat:@"%@.bas", script.name];
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];

    NSError *error;
    BOOL writeSuccess = [scriptString writeToFile:tempPath
                                        atomically:YES
                                          encoding:NSUTF8StringEncoding
                                             error:&error];

    if (!writeSuccess) {
        if (completion) completion(NO);
        return;
    }

    NSURL *fileURL = [NSURL fileURLWithPath:tempPath];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc]
                                           initWithActivityItems:@[fileURL]
                                           applicationActivities:nil];

    activityVC.completionWithItemsHandler = ^(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        // 清理临时文件
        [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];

        if (completion) completion(completed);
    };

    // iPad 支持
    if (activityVC.popoverPresentationController) {
        activityVC.popoverPresentationController.sourceView = controller.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(controller.view.bounds.size.width/2,
                                                                         controller.view.bounds.size.height/2,
                                                                         0, 0);
    }

    [controller presentViewController:activityVC animated:YES completion:nil];
}

- (void)shareScript:(BaseAddressScript *)script
     fromController:(UIViewController *)controller
          encrypted:(BOOL)encrypted
           password:(NSString *)password
         completion:(void(^)(BOOL success))completion {

    NSString *scriptString;

    if (encrypted && password.length > 0) {
        // 使用加密导出，指针链会被加密
        scriptString = [self exportScript:script encrypted:YES password:password];
        if (!scriptString) {
            if (completion) completion(NO);
            return;
        }
        // 再对整个内容进行加密
        scriptString = [self encryptString:scriptString withPassword:password];
        if (!scriptString) {
            if (completion) completion(NO);
            return;
        }
    } else {
        // 普通导出
        scriptString = [self exportScript:script];
        if (!scriptString) {
            if (completion) completion(NO);
            return;
        }
    }

    // 创建临时文件
    NSString *fileName = encrypted ?
        [NSString stringWithFormat:@"%@_加密.bas", script.name] :
        [NSString stringWithFormat:@"%@.bas", script.name];
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];

    NSError *error;
    BOOL writeSuccess = [scriptString writeToFile:tempPath
                                        atomically:YES
                                          encoding:NSUTF8StringEncoding
                                             error:&error];

    if (!writeSuccess) {
        if (completion) completion(NO);
        return;
    }

    NSURL *fileURL = [NSURL fileURLWithPath:tempPath];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc]
                                           initWithActivityItems:@[fileURL]
                                           applicationActivities:nil];

    activityVC.completionWithItemsHandler = ^(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        // 清理临时文件
        [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];

        if (completion) completion(completed);
    };

    // iPad 支持
    if (activityVC.popoverPresentationController) {
        activityVC.popoverPresentationController.sourceView = controller.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(controller.view.bounds.size.width/2,
                                                                         controller.view.bounds.size.height/2,
                                                                         0, 0);
    }

    [controller presentViewController:activityVC animated:YES completion:nil];
}

- (void)shareAllScripts:(UIViewController *)controller
             completion:(void(^)(BOOL success))completion {
    
    NSString *scriptsString = [self exportAllScripts];
    if (!scriptsString) {
        if (completion) completion(NO);
        return;
    }
    
    // 创建临时文件
    NSString *fileName = @"基址脚本集合.bas";
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    
    NSError *error;
    BOOL writeSuccess = [scriptsString writeToFile:tempPath
                                        atomically:YES
                                          encoding:NSUTF8StringEncoding
                                             error:&error];
    
    if (!writeSuccess) {
        if (completion) completion(NO);
        return;
    }
    
    NSURL *fileURL = [NSURL fileURLWithPath:tempPath];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] 
                                           initWithActivityItems:@[fileURL]
                                           applicationActivities:nil];
    
    activityVC.completionWithItemsHandler = ^(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        // 清理临时文件
        [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];
        
        if (completion) completion(completed);
    };
    
    // iPad 支持
    if (activityVC.popoverPresentationController) {
        activityVC.popoverPresentationController.sourceView = controller.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(controller.view.bounds.size.width/2, 
                                                                         controller.view.bounds.size.height/2, 
                                                                         0, 0);
    }
    
    [controller presentViewController:activityVC animated:YES completion:nil];
}

- (void)shareAllScripts:(UIViewController *)controller
              encrypted:(BOOL)encrypted
               password:(NSString *)password
             completion:(void(^)(BOOL success))completion {

    NSString *scriptsString;

    if (encrypted && password.length > 0) {
        // 使用加密导出，指针链会被加密
        scriptsString = [self exportAllScriptsWithEncryption:YES password:password];
        if (!scriptsString) {
            if (completion) completion(NO);
            return;
        }
        // 再对整个内容进行加密
        scriptsString = [self encryptString:scriptsString withPassword:password];
        if (!scriptsString) {
            if (completion) completion(NO);
            return;
        }
    } else {
        // 普通导出
        scriptsString = [self exportAllScripts];
        if (!scriptsString) {
            if (completion) completion(NO);
            return;
        }
    }

    // 创建临时文件
    NSString *fileName = encrypted ? @"指针脚本集合_加密.bas" : @"指针脚本集合.bas";
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];

    NSError *error;
    BOOL writeSuccess = [scriptsString writeToFile:tempPath
                                        atomically:YES
                                          encoding:NSUTF8StringEncoding
                                             error:&error];

    if (!writeSuccess) {
        if (completion) completion(NO);
        return;
    }

    NSURL *fileURL = [NSURL fileURLWithPath:tempPath];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc]
                                           initWithActivityItems:@[fileURL]
                                           applicationActivities:nil];

    activityVC.completionWithItemsHandler = ^(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        // 清理临时文件
        [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];

        if (completion) completion(completed);
    };

    // iPad 支持
    if (activityVC.popoverPresentationController) {
        activityVC.popoverPresentationController.sourceView = controller.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(controller.view.bounds.size.width/2,
                                                                         controller.view.bounds.size.height/2,
                                                                         0, 0);
    }

    [controller presentViewController:activityVC animated:YES completion:nil];
}

// 带作者信息的批量分享方法
- (void)shareAllScripts:(UIViewController *)controller
              encrypted:(BOOL)encrypted
               password:(NSString *)password
             authorName:(NSString *)authorName
        authorDescription:(NSString *)authorDescription
             completion:(void(^)(BOOL success))completion {

    NSString *scriptsString;

    if (encrypted && password.length > 0) {
        // 使用加密导出，指针链会被加密
        scriptsString = [self exportAllScriptsWithEncryption:YES
                                                    password:password
                                                  authorName:authorName
                                             authorDescription:authorDescription];
        if (!scriptsString) {
            if (completion) completion(NO);
            return;
        }
        // 再对整个内容进行加密
        scriptsString = [self encryptString:scriptsString withPassword:password];
        if (!scriptsString) {
            if (completion) completion(NO);
            return;
        }
    } else {
        // 普通导出
        scriptsString = [self exportAllScripts];
        if (!scriptsString) {
            if (completion) completion(NO);
            return;
        }
    }

    // 创建临时文件
    NSString *fileName = encrypted ? @"指针脚本集合_加密.bas" : @"指针脚本集合.bas";
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];

    NSError *error;
    BOOL writeSuccess = [scriptsString writeToFile:tempPath
                                        atomically:YES
                                          encoding:NSUTF8StringEncoding
                                             error:&error];

    if (!writeSuccess) {
        if (completion) completion(NO);
        return;
    }

    NSURL *fileURL = [NSURL fileURLWithPath:tempPath];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc]
                                           initWithActivityItems:@[fileURL]
                                           applicationActivities:nil];

    activityVC.completionWithItemsHandler = ^(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        // 清理临时文件
        [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];

        if (completion) completion(completed);
    };

    // iPad 支持
    if (activityVC.popoverPresentationController) {
        activityVC.popoverPresentationController.sourceView = controller.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(controller.view.bounds.size.width/2,
                                                                         controller.view.bounds.size.height/2,
                                                                         0, 0);
    }

    [controller presentViewController:activityVC animated:YES completion:nil];
}

// 简单的字符串加密方法
- (NSString *)encryptString:(NSString *)string withPassword:(NSString *)password {
    if (!string || !password) return nil;

    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *encryptedData = [NSMutableData dataWithLength:data.length];

    const char *passwordBytes = [password UTF8String];
    NSUInteger passwordLength = strlen(passwordBytes);

    const uint8_t *dataBytes = data.bytes;
    uint8_t *encryptedBytes = encryptedData.mutableBytes;

    // 简单的XOR加密
    for (NSUInteger i = 0; i < data.length; i++) {
        encryptedBytes[i] = dataBytes[i] ^ passwordBytes[i % passwordLength];
    }

    // 添加加密标识和密码验证
    NSString *header = [NSString stringWithFormat:@"ENCRYPTED_BAS_V1:%@\n", [self hashPassword:password]];
    NSMutableString *result = [NSMutableString stringWithString:header];
    [result appendString:[encryptedData base64EncodedStringWithOptions:0]];

    return result;
}

// 密码哈希（用于验证）
- (NSString *)hashPassword:(NSString *)password {
    NSData *data = [password dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);

    NSMutableString *hash = [NSMutableString string];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hash appendFormat:@"%02x", digest[i]];
    }
    return hash;
}

// 解密字符串
- (NSString *)decryptString:(NSString *)encryptedString withPassword:(NSString *)password {
    if (!encryptedString || !password) return nil;

    // 检查加密标识
    if (![encryptedString hasPrefix:@"ENCRYPTED_BAS_V1:"]) {
        return nil;
    }

    // 分离头部和数据
    NSArray *lines = [encryptedString componentsSeparatedByString:@"\n"];
    if (lines.count < 2) return nil;

    NSString *header = lines[0];
    NSString *encryptedData = lines[1];

    // 验证密码
    NSString *expectedHash = [header substringFromIndex:[@"ENCRYPTED_BAS_V1:" length]];
    NSString *actualHash = [self hashPassword:password];

    if (![expectedHash isEqualToString:actualHash]) {
        return nil; // 密码错误
    }

    // 解密数据
    NSData *data = [[NSData alloc] initWithBase64EncodedString:encryptedData options:0];
    if (!data) return nil;

    NSMutableData *decryptedData = [NSMutableData dataWithLength:data.length];

    const char *passwordBytes = [password UTF8String];
    NSUInteger passwordLength = strlen(passwordBytes);

    const uint8_t *dataBytes = data.bytes;
    uint8_t *decryptedBytes = decryptedData.mutableBytes;

    // XOR解密
    for (NSUInteger i = 0; i < data.length; i++) {
        decryptedBytes[i] = dataBytes[i] ^ passwordBytes[i % passwordLength];
    }

    return [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
}

@end
