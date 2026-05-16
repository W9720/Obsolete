//
//  UpdateManager.h
//  Modifier
//
//  Created by Assistant on 2025/1/21.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UpdateManager : NSObject <NSURLSessionDownloadDelegate>

+ (instancetype)sharedManager;

// 检查更新
- (void)checkForUpdatesWithCompletion:(void(^)(BOOL hasUpdate, NSString *latestVersion, NSString *downloadURL, NSString *updateDescription, BOOL forceUpdate))completion;

// 显示更新弹窗
- (void)showUpdateAlertWithVersion:(NSString *)version
                       downloadURL:(NSString *)downloadURL
                       description:(NSString *)description
                       forceUpdate:(BOOL)forceUpdate
                    fromController:(UIViewController *)controller;

// 下载更新
- (void)downloadUpdateFromURL:(NSString *)urlString 
               fromController:(UIViewController *)controller;

// 获取当前版本
- (NSString *)getCurrentVersion;

// 检查是否被hook（反调试检测）
- (BOOL)isHooked;

// 禁用所有功能
- (void)disableAllFeatures;

@property (nonatomic, assign) BOOL isUpdateCheckEnabled;
@property (nonatomic, assign) BOOL allFeaturesDisabled;

@end

NS_ASSUME_NONNULL_END
