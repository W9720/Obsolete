//
//  UnityAppSelectionViewController.h
//  Obsolete
//
//  Created by Assistant on 2024/8/16.
//  Unity应用选择界面
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UnityAppInfo : NSObject
@property (nonatomic, strong) NSString *bundleId;
@property (nonatomic, strong) NSString *displayName;
@property (nonatomic, strong) NSString *executablePath;
@property (nonatomic, strong) NSString *version;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) pid_t processId;
@end

@protocol UnityAppSelectionDelegate <NSObject>
- (void)didSelectUnityApp:(UnityAppInfo *)appInfo;
@end

@interface UnityAppSelectionViewController : UIViewController

@property (nonatomic, weak) id<UnityAppSelectionDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
