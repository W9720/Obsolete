//
//  VideoHistoryManager.h
//  修改器
//
//  Created by MacXK on 2025/8/7.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VideoHistoryManager : NSObject

// 单例模式
+ (instancetype)shared;

// 视频历史记录
@property (nonatomic, strong, readonly) NSMutableArray<NSString *> *history;

// 添加视频类型到历史
- (void)addVideo:(NSString *)type;

// 获取上一个视频
- (nullable NSString *)getPreviousVideo;

// 获取下一个视频
- (nullable NSString *)getNextVideo;

// 获取当前索引
- (NSInteger)getCurrentIndex;

// 获取历史长度
- (NSInteger)getHistoryCount;

// 获取当前视频类型
- (nullable NSString *)getCurrentVideoType;

// 清空历史
- (void)clearHistory;

// 打印历史记录状态
- (void)printStatus;

@end

NS_ASSUME_NONNULL_END
