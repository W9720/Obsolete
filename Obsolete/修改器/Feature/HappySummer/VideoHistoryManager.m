//
//  VideoHistoryManager.m
//  修改器
//
//  Created by MacXK on 2025/8/7.
//

#import "VideoHistoryManager.h"

@interface VideoHistoryManager ()
@property (nonatomic, strong) NSMutableArray<NSString *> *history;
@property (nonatomic, assign) NSInteger currentIndex;
@end

@implementation VideoHistoryManager

+ (instancetype)shared {
    static VideoHistoryManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[VideoHistoryManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _history = [[NSMutableArray alloc] init];
        _currentIndex = -1;
    }
    return self;
}

- (void)addVideo:(NSString *)type {
    // 调试输出
    NSLog(@"尝试添加视频: %@, 当前索引: %ld, 历史长度: %lu", type, (long)self.currentIndex, (unsigned long)self.history.count);
    
    // 如果在浏览历史中间，截断历史
    if (self.currentIndex < (NSInteger)self.history.count - 1 && self.currentIndex >= 0) {
        NSRange range = NSMakeRange(0, self.currentIndex + 1);
        self.history = [[self.history subarrayWithRange:range] mutableCopy];
        NSLog(@"截断历史记录至索引 %ld", (long)self.currentIndex);
    }
    
    // 添加新视频
    [self.history addObject:type];
    self.currentIndex = (NSInteger)self.history.count - 1;
    
    // 调试输出
    NSLog(@"添加后 - 当前索引: %ld, 历史长度: %lu", (long)self.currentIndex, (unsigned long)self.history.count);
    NSLog(@"当前历史: %@", self.history);
}

- (nullable NSString *)getPreviousVideo {
    NSLog(@"获取上一个视频 - 当前索引: %ld, 历史长度: %lu", (long)self.currentIndex, (unsigned long)self.history.count);
    
    if (self.currentIndex > 0) {
        self.currentIndex--;
        NSString *videoType = self.history[self.currentIndex];
        NSLog(@"返回上一个视频: %@, 新索引: %ld", videoType, (long)self.currentIndex);
        return videoType;
    }
    
    NSLog(@"没有上一个视频");
    return nil;
}

- (nullable NSString *)getNextVideo {
    NSLog(@"获取下一个视频 - 当前索引: %ld, 历史长度: %lu", (long)self.currentIndex, (unsigned long)self.history.count);
    
    if (self.currentIndex < (NSInteger)self.history.count - 1) {
        self.currentIndex++;
        NSString *videoType = self.history[self.currentIndex];
        NSLog(@"返回下一个视频: %@, 新索引: %ld", videoType, (long)self.currentIndex);
        return videoType;
    }
    
    NSLog(@"没有下一个视频");
    return nil;
}

- (NSInteger)getCurrentIndex {
    return self.currentIndex;
}

- (NSInteger)getHistoryCount {
    return (NSInteger)self.history.count;
}

- (nullable NSString *)getCurrentVideoType {
    if (self.currentIndex >= 0 && self.currentIndex < (NSInteger)self.history.count) {
        return self.history[self.currentIndex];
    }
    return nil;
}

- (void)clearHistory {
    [self.history removeAllObjects];
    self.currentIndex = -1;
    NSLog(@"历史记录已清空");
}

- (void)printStatus {
    NSLog(@"======= VideoHistoryManager 状态 =======");
    NSLog(@"当前索引: %ld", (long)self.currentIndex);
    NSLog(@"历史长度: %lu", (unsigned long)self.history.count);
    NSLog(@"历史记录: %@", self.history);
    if (self.currentIndex >= 0 && self.currentIndex < (NSInteger)self.history.count) {
        NSLog(@"当前视频: %@", self.history[self.currentIndex]);
    } else {
        NSLog(@"当前视频: 无");
    }
    NSLog(@"=====================================");
}

@end
