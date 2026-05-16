//
//  TheosProjectManager.h
//  修改器
//
//  Created by AI Assistant on 2025-01-08.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TheosProjectManager : NSObject

+ (instancetype)sharedManager;

/**
 * 创建Theos项目
 * @param config 项目配置字典，包含projectName、packageName、author、description、targetBundle等
 * @param error 错误信息
 * @return 是否创建成功
 */
- (BOOL)createProjectWithConfig:(NSDictionary *)config error:(NSError **)error;

/**
 * 获取项目根目录路径
 */
- (NSString *)getProjectsRootPath;

/**
 * 获取所有项目列表
 */
- (NSArray<NSString *> *)getAllProjects;

/**
 * 删除项目
 * @param projectName 项目名称
 * @param error 错误信息
 * @return 是否删除成功
 */
- (BOOL)deleteProject:(NSString *)projectName error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
