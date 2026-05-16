//
//  PluginFileManager.h
//  修改器
//
//  Created by AI Assistant on 2025-01-08.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PluginFileManager : NSObject

+ (instancetype)sharedManager;

/**
 * 列出目录中的文件
 * @param directoryPath 目录路径
 * @return 文件名数组
 */
- (NSArray<NSString *> *)listFilesInDirectory:(NSString *)directoryPath;

/**
 * 创建文件
 * @param filePath 文件路径
 * @param content 文件内容
 * @param error 错误信息
 * @return 是否创建成功
 */
- (BOOL)createFileAtPath:(NSString *)filePath withContent:(NSString *)content error:(NSError **)error;

/**
 * 读取文件内容
 * @param filePath 文件路径
 * @param error 错误信息
 * @return 文件内容
 */
- (NSString *)readFileAtPath:(NSString *)filePath error:(NSError **)error;

/**
 * 写入文件内容
 * @param content 文件内容
 * @param filePath 文件路径
 * @param error 错误信息
 * @return 是否写入成功
 */
- (BOOL)writeContent:(NSString *)content toFile:(NSString *)filePath error:(NSError **)error;

/**
 * 删除文件或目录
 * @param filePath 文件路径
 * @param error 错误信息
 * @return 是否删除成功
 */
- (BOOL)deleteFileAtPath:(NSString *)filePath error:(NSError **)error;

/**
 * 检查文件是否存在
 * @param filePath 文件路径
 * @return 是否存在
 */
- (BOOL)fileExistsAtPath:(NSString *)filePath;

/**
 * 获取文件属性
 * @param filePath 文件路径
 * @return 文件属性字典
 */
- (NSDictionary *)attributesOfFileAtPath:(NSString *)filePath;

@end

NS_ASSUME_NONNULL_END
