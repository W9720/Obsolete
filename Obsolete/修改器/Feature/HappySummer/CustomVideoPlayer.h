//
//  CustomVideoPlayer.h
//  修改器
//
//  Created by MacXK on 2025/8/7.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@class CustomVideoPlayer;

@protocol CustomVideoPlayerDelegate <NSObject>

- (NSInteger)getCurrentHistoryIndex;
- (NSInteger)getHistoryCount;
- (void)playNextFromCurrentType;

@optional
- (void)videoPlayerWillClose:(CustomVideoPlayer *)player;

@end

@interface CustomVideoPlayer : UIViewController

// 视频URL
@property (nonatomic, strong, nullable) NSURL *videoURL;

// 视频类型
@property (nonatomic, strong) NSString *videoType;

// 当前索引和总数
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, assign) NSInteger totalCount;

// 委托
@property (nonatomic, weak, nullable) id<CustomVideoPlayerDelegate> delegate;

// 公开方法
- (void)setupPlayer;
- (void)updateHistoryLabel;
- (void)hideLoadingIndicator;

@end

NS_ASSUME_NONNULL_END
