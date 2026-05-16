//
//  BitSlicerStringSearcher.h
//  Modifier
//
//  Created by AI Assistant on 2023-07-23.
//

#import <Foundation/Foundation.h>
#import "MemModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface BitSlicerStringSearcher : NSObject

+ (instancetype)sharedInstance;

// 搜索字符串
- (void)searchString:(NSString *)string 
     caseInsensitive:(BOOL)caseInsensitive
              utf16:(BOOL)isUTF16
           callback:(void(^)(NSInteger count, NSArray<MemModel *> *results, NSTimeInterval timeUsed))callback;

// 比较搜索（用于缩小范围）
- (void)narrowSearchWithString:(NSString *)string
               caseInsensitive:(BOOL)caseInsensitive
                        utf16:(BOOL)isUTF16
                     callback:(void(^)(NSInteger count, NSArray<MemModel *> *results, NSTimeInterval timeUsed))callback;

// 重置搜索状态
- (void)reset;

// 附加到进程
- (BOOL)attachToProcess:(pid_t)pid;

// 获取当前进程ID
- (pid_t)currentPid;

@end

NS_ASSUME_NONNULL_END 