//
//  UnityDumpManager.h
//  Obsolete
//
//  Created by Assistant on 2024/8/16.
//  Unity Il2Cpp转储管理器
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^UnityDumpProgressCallback)(NSString *message);
typedef void(^UnityDumpCompletionCallback)(BOOL success, NSString * _Nullable errorMessage, NSString * _Nullable outputPath);

@interface UnityDumpManager : NSObject

+ (instancetype)sharedManager;

/**
 * 转储指定Bundle ID的Unity应用
 * @param bundleId 应用的Bundle ID
 * @param outputPath 输出目录路径
 * @param progressCallback 进度回调
 * @param completion 完成回调
 */
- (void)dumpUnityApp:(NSString *)bundleId
          outputPath:(NSString *)outputPath
            progress:(nullable UnityDumpProgressCallback)progressCallback
          completion:(UnityDumpCompletionCallback)completion;

/**
 * 检查Unity应用是否支持转储
 * @param bundleId 应用的Bundle ID
 * @return 是否支持转储
 */
- (BOOL)canDumpUnityApp:(NSString *)bundleId;

/**
 * 获取Unity应用的框架路径
 * @param bundleId 应用的Bundle ID
 * @return Unity框架路径
 */
- (nullable NSString *)getUnityFrameworkPath:(NSString *)bundleId;

/**
 * 停止当前的转储操作
 */
- (void)stopDumping;

@property (nonatomic, assign, readonly) BOOL isDumping;

@end

NS_ASSUME_NONNULL_END
