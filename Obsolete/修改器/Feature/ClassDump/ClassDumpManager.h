//
//  ClassDumpManager.h
//  Modifier
//
//  Created by AI Assistant on 2024/8/13.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^ClassDumpCompletionBlock)(BOOL success, NSString * _Nullable errorMessage);

@interface ClassDumpManager : NSObject

+ (instancetype)sharedManager;

- (void)dumpFile:(NSString *)inputPath
      outputPath:(NSString *)outputPath
      completion:(ClassDumpCompletionBlock)completion;

- (BOOL)isValidMachOFile:(NSString *)filePath;

@end

NS_ASSUME_NONNULL_END
