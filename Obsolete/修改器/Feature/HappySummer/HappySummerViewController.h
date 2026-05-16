//
//  HappySummerViewController.h
//  修改器
//
//  Created by MacXK on 2025/8/7.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class VideoHistoryManager;
@class CustomVideoPlayer;
@protocol CustomVideoPlayerDelegate;

@interface HappySummerViewController : UIViewController <CustomVideoPlayerDelegate>

// 当前视频工具类型
@property (nonatomic, strong) NSString *currentVideoType;

// 是否从历史记录播放
@property (nonatomic, assign) BOOL isFromHistory;

// 网络请求方法
- (void)fetchBeautyVideo;
- (void)fetchBlackSilkVideo;
- (void)fetchWhiteSilkVideo;
- (void)fetchCosplayVideo;
- (void)fetchPerfectBodyVideo;
- (void)fetchPrisonGuardVideo;
- (void)fetchSlowDanceVideo;
- (void)fetchSuspenderVideo;
- (void)fetchCOSVideo;
- (void)fetchDoubleHappinessVideo;
- (void)fetchBeautifulLegsVideo;
- (void)fetchHotDanceVideo;
- (void)fetchJKLolitaVideo;
- (void)fetchDreamVideo;
- (void)fetchBlackSilkImage;

@end

NS_ASSUME_NONNULL_END
