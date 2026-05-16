//
//  CodeTemplateManager.h
//  修改器
//
//  Created by AI Assistant on 2025-01-08.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CodeTemplateManager : NSObject

+ (instancetype)sharedManager;

/**
 * 获取指定文件扩展名的代码模板
 * @param fileExtension 文件扩展名
 * @return 模板数组
 */
- (NSArray<NSDictionary *> *)getTemplatesForFileExtension:(NSString *)fileExtension;

/**
 * 获取所有可用的代码模板
 * @return 模板字典，按类别分组
 */
- (NSDictionary *)getAllTemplates;

@end

NS_ASSUME_NONNULL_END
