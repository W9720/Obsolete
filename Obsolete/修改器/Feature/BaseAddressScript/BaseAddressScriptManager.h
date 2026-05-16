//
//  BaseAddressScriptManager.h
//  基址脚本管理器
//

#import <Foundation/Foundation.h>
#import "BaseAddressScript.h"

NS_ASSUME_NONNULL_BEGIN

// 脚本管理器通知
extern NSString * const BaseAddressScriptDidAddNotification;
extern NSString * const BaseAddressScriptDidRemoveNotification;
extern NSString * const BaseAddressScriptDidUpdateNotification;
extern NSString * const BaseAddressScriptDidExecuteNotification;

@interface BaseAddressScriptManager : NSObject

@property (nonatomic, strong, readonly) NSArray<BaseAddressScript *> *scripts;
@property (nonatomic, strong, readonly) NSArray<NSString *> *categories;

+ (instancetype)sharedManager;

// 脚本管理
- (void)addScript:(BaseAddressScript *)script;
- (void)removeScript:(BaseAddressScript *)script;
- (void)removeScriptWithId:(NSString *)scriptId;
- (void)updateScript:(BaseAddressScript *)script;
- (BaseAddressScript * _Nullable)scriptWithId:(NSString *)scriptId;
- (NSArray<BaseAddressScript *> *)scriptsInCategory:(NSString *)category;

// 分类管理
- (void)addCategory:(NSString *)category;
- (void)removeCategory:(NSString *)category;
- (void)renameCategory:(NSString *)oldName toName:(NSString *)newName;
- (NSInteger)scriptsCountInCategory:(NSString *)category;

// 脚本执行
- (BOOL)executeScript:(BaseAddressScript *)script;
- (BOOL)executeScriptWithId:(NSString *)scriptId;
- (void)stopScript:(BaseAddressScript *)script;
- (void)stopAllScripts;

// 数据持久化
- (BOOL)saveScripts;
- (BOOL)loadScripts;
- (void)clearAllScripts;

// 导入导出
- (NSString * _Nullable)exportScript:(BaseAddressScript *)script;
- (NSString * _Nullable)exportAllScripts;
- (NSString * _Nullable)exportAllScriptsWithEncryption:(BOOL)encrypted
                                              password:(NSString *)password
                                            authorName:(NSString *)authorName
                                       authorDescription:(NSString *)authorDescription;
- (BOOL)importScriptFromString:(NSString *)scriptString;
- (BOOL)importScriptsFromString:(NSString *)scriptsString;
- (BOOL)importScriptsFromStringWithPassword:(NSString *)scriptsString password:(NSString *)password;

// 分享功能
- (void)shareScript:(BaseAddressScript *)script
     fromController:(UIViewController *)controller
         completion:(void(^)(BOOL success))completion;

- (void)shareScript:(BaseAddressScript *)script
     fromController:(UIViewController *)controller
          encrypted:(BOOL)encrypted
           password:(NSString *)password
         completion:(void(^)(BOOL success))completion;

- (void)shareScript:(BaseAddressScript *)script
     fromController:(UIViewController *)controller
          encrypted:(BOOL)encrypted
           password:(NSString *)password
         authorName:(NSString *)authorName
    authorDescription:(NSString *)authorDescription
         completion:(void(^)(BOOL success))completion;

- (void)shareAllScripts:(UIViewController *)controller
             completion:(void(^)(BOOL success))completion;

- (void)shareAllScripts:(UIViewController *)controller
              encrypted:(BOOL)encrypted
               password:(NSString *)password
             completion:(void(^)(BOOL success))completion;

- (void)shareAllScripts:(UIViewController *)controller
              encrypted:(BOOL)encrypted
               password:(NSString *)password
             authorName:(NSString *)authorName
        authorDescription:(NSString *)authorDescription
             completion:(void(^)(BOOL success))completion;

// 加密解密功能
- (NSString *)decryptString:(NSString *)encryptedString withPassword:(NSString *)password;

@end

NS_ASSUME_NONNULL_END
