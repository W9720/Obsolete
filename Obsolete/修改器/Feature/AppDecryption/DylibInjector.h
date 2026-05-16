//
//  DylibInjector.h
//  Obsolete
//
//  Created by Assistant on 2024/01/16.
//  基于SignTools的动态库注入功能
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 注入类型枚举
typedef NS_ENUM(NSInteger, DylibInjectType) {
    DylibInjectTypeStrong = 0,  // LC_LOAD_DYLIB (强依赖)
    DylibInjectTypeWeak = 1     // LC_LOAD_WEAK_DYLIB (弱依赖)
};

// Framework位置类型枚举
typedef NS_ENUM(NSInteger, FrameworkLocationType) {
    FrameworkLocationTypeRoot = 0,      // 放在应用根目录
    FrameworkLocationTypeFrameworks = 1 // 放在Frameworks文件夹下
};

// 日志回调函数类型
typedef void (^DylibInjectorLogCallback)(NSString *message);

@interface DylibInjector : NSObject

@property (nonatomic, copy, nullable) DylibInjectorLogCallback logCallback;
@property (nonatomic, strong, readonly, nullable) NSString *lastError;

/**
 * 注入动态库到IPA文件
 * @param ipaPath IPA文件路径
 * @param dylibPath 动态库文件路径 (.dylib 或 .framework)
 * @param injectType 注入类型 (强依赖或弱依赖)
 * @param frameworkLocation Framework位置 (根目录或Frameworks文件夹)
 * @param completion 完成回调，返回处理后的IPA路径或错误信息
 */
- (void)injectDylibToIPA:(NSString *)ipaPath
               dylibPath:(NSString *)dylibPath
              injectType:(DylibInjectType)injectType
       frameworkLocation:(FrameworkLocationType)frameworkLocation
              completion:(void(^)(NSString * _Nullable outputPath, NSString * _Nullable error))completion;

/**
 * 简化版本：使用默认参数注入动态库
 * @param ipaPath IPA文件路径
 * @param dylibPath 动态库文件路径
 * @param completion 完成回调
 */
- (void)injectDylibToIPA:(NSString *)ipaPath
               dylibPath:(NSString *)dylibPath
              completion:(void(^)(NSString * _Nullable outputPath, NSString * _Nullable error))completion;

/**
 * 检查IPA文件是否有效
 */
- (BOOL)validateIPAFile:(NSString *)ipaPath;

/**
 * 检查动态库文件是否有效
 */
- (BOOL)validateDylibFile:(NSString *)dylibPath;

@end

NS_ASSUME_NONNULL_END
