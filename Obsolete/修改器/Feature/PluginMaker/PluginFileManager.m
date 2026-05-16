//
//  PluginFileManager.m
//  修改器
//
//  Created by AI Assistant on 2025-01-08.
//

#import "PluginFileManager.h"

@implementation PluginFileManager

+ (instancetype)sharedManager {
    static PluginFileManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (NSArray<NSString *> *)listFilesInDirectory:(NSString *)directoryPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:directoryPath error:&error];
    
    if (error) {
        NSLog(@"Error listing files in directory %@: %@", directoryPath, error.localizedDescription);
        return @[];
    }
    
    return contents ?: @[];
}

- (BOOL)createFileAtPath:(NSString *)filePath withContent:(NSString *)content error:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // 确保父目录存在
    NSString *parentDirectory = [filePath stringByDeletingLastPathComponent];
    if (![fileManager fileExistsAtPath:parentDirectory]) {
        BOOL success = [fileManager createDirectoryAtPath:parentDirectory 
                                  withIntermediateDirectories:YES 
                                                   attributes:nil 
                                                        error:error];
        if (!success) {
            return NO;
        }
    }
    
    NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
    return [fileManager createFileAtPath:filePath contents:data attributes:nil];
}

- (NSString *)readFileAtPath:(NSString *)filePath error:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:filePath]) {
        if (error) {
            *error = [NSError errorWithDomain:@"PluginFileManager" 
                                         code:1001 
                                     userInfo:@{NSLocalizedDescriptionKey: @"文件不存在"}];
        }
        return nil;
    }
    
    NSData *data = [NSData dataWithContentsOfFile:filePath options:0 error:error];
    if (!data) {
        return nil;
    }
    
    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!content) {
        // 尝试其他编码
        content = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    }
    
    return content;
}

- (BOOL)writeContent:(NSString *)content toFile:(NSString *)filePath error:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // 确保父目录存在
    NSString *parentDirectory = [filePath stringByDeletingLastPathComponent];
    if (![fileManager fileExistsAtPath:parentDirectory]) {
        BOOL success = [fileManager createDirectoryAtPath:parentDirectory 
                                  withIntermediateDirectories:YES 
                                                   attributes:nil 
                                                        error:error];
        if (!success) {
            return NO;
        }
    }
    
    return [content writeToFile:filePath 
                     atomically:YES 
                       encoding:NSUTF8StringEncoding 
                          error:error];
}

- (BOOL)deleteFileAtPath:(NSString *)filePath error:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:filePath]) {
        if (error) {
            *error = [NSError errorWithDomain:@"PluginFileManager" 
                                         code:1001 
                                     userInfo:@{NSLocalizedDescriptionKey: @"文件不存在"}];
        }
        return NO;
    }
    
    return [fileManager removeItemAtPath:filePath error:error];
}

- (BOOL)fileExistsAtPath:(NSString *)filePath {
    return [[NSFileManager defaultManager] fileExistsAtPath:filePath];
}

- (NSDictionary *)attributesOfFileAtPath:(NSString *)filePath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSDictionary *attributes = [fileManager attributesOfItemAtPath:filePath error:&error];
    
    if (error) {
        NSLog(@"Error getting attributes for file %@: %@", filePath, error.localizedDescription);
        return @{};
    }
    
    return attributes ?: @{};
}

@end
