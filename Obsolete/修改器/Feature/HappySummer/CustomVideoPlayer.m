//
//  CustomVideoPlayer.m
//  修改器
//
//  Created by MacXK on 2025/8/7.
//

#import "CustomVideoPlayer.h"
#import <AVKit/AVKit.h>
#import <Photos/Photos.h>

@interface CustomVideoPlayer ()

// 播放器
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;

// 控制视图
@property (nonatomic, strong) UIView *controlView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UIButton *refreshButton;
@property (nonatomic, strong) UILabel *historyLabel;

// 加载指示器
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

// 控制视图显示状态
@property (nonatomic, assign) BOOL controlsVisible;
@property (nonatomic, strong) NSTimer *hideControlsTimer;

@end

@implementation CustomVideoPlayer

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [self setupPlayer];
    [self updateHistoryLabel];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.playerLayer.frame = self.view.bounds;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    // 确保不会影响父视图控制器的导航栏状态
    // 这里不做任何导航栏相关的操作
}

- (void)setupUI {
    self.view.backgroundColor = [UIColor blackColor];
    
    // 创建控制视图
    self.controlView = [[UIView alloc] init];
    self.controlView.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.5];
    self.controlView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.controlView];
    
    // 标题标签
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = self.videoType;
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlView addSubview:self.titleLabel];
    
    // 关闭按钮
    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.closeButton setTitle:@"关闭" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.closeButton.backgroundColor = [UIColor.redColor colorWithAlphaComponent:0.7];
    self.closeButton.layer.cornerRadius = 8;
    [self.closeButton addTarget:self action:@selector(closeButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    self.closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlView addSubview:self.closeButton];
    
    // 保存按钮
    self.saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.saveButton setTitle:@"保存" forState:UIControlStateNormal];
    [self.saveButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.saveButton.backgroundColor = [UIColor.blueColor colorWithAlphaComponent:0.7];
    self.saveButton.layer.cornerRadius = 8;
    [self.saveButton addTarget:self action:@selector(saveButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    self.saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlView addSubview:self.saveButton];
    
    // 播放/暂停按钮
    self.playPauseButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.playPauseButton setTitle:@"⏸" forState:UIControlStateNormal];
    [self.playPauseButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.playPauseButton.titleLabel.font = [UIFont systemFontOfSize:24];
    [self.playPauseButton addTarget:self action:@selector(playPauseButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    self.playPauseButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlView addSubview:self.playPauseButton];
    

    
    // 刷新按钮
    self.refreshButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.refreshButton setTitle:@"🔄" forState:UIControlStateNormal];
    [self.refreshButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.refreshButton.titleLabel.font = [UIFont systemFontOfSize:20];
    [self.refreshButton addTarget:self action:@selector(refreshButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlView addSubview:self.refreshButton];
    
    // 历史标签
    self.historyLabel = [[UILabel alloc] init];
    self.historyLabel.textColor = [UIColor whiteColor];
    self.historyLabel.font = [UIFont systemFontOfSize:14];
    self.historyLabel.textAlignment = NSTextAlignmentCenter;
    self.historyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlView addSubview:self.historyLabel];
    
    // 加载指示器
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.color = [UIColor whiteColor];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.loadingIndicator];
    
    [self setupConstraints];
    [self setupGestureRecognizers];
    
    // 初始显示控制视图
    self.controlsVisible = YES;
    [self startHideControlsTimer];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // 控制视图约束
        [self.controlView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.controlView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.controlView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.controlView.heightAnchor constraintEqualToConstant:120],
        
        // 标题标签约束
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.controlView.topAnchor constant:10],
        [self.titleLabel.centerXAnchor constraintEqualToAnchor:self.controlView.centerXAnchor],
        
        // 关闭和保存按钮约束
        [self.closeButton.topAnchor constraintEqualToAnchor:self.controlView.topAnchor constant:10],
        [self.closeButton.leadingAnchor constraintEqualToAnchor:self.controlView.leadingAnchor constant:20],
        [self.closeButton.widthAnchor constraintEqualToConstant:60],
        [self.closeButton.heightAnchor constraintEqualToConstant:35],
        
        [self.saveButton.topAnchor constraintEqualToAnchor:self.controlView.topAnchor constant:10],
        [self.saveButton.trailingAnchor constraintEqualToAnchor:self.controlView.trailingAnchor constant:-20],
        [self.saveButton.widthAnchor constraintEqualToConstant:60],
        [self.saveButton.heightAnchor constraintEqualToConstant:35],
        
        // 播放控制按钮约束
        [self.playPauseButton.centerXAnchor constraintEqualToAnchor:self.controlView.centerXAnchor],
        [self.playPauseButton.bottomAnchor constraintEqualToAnchor:self.controlView.bottomAnchor constant:-20],
        [self.playPauseButton.widthAnchor constraintEqualToConstant:50],
        [self.playPauseButton.heightAnchor constraintEqualToConstant:50],
        
        [self.refreshButton.leadingAnchor constraintEqualToAnchor:self.playPauseButton.trailingAnchor constant:20],
        [self.refreshButton.centerYAnchor constraintEqualToAnchor:self.playPauseButton.centerYAnchor],
        [self.refreshButton.widthAnchor constraintEqualToConstant:40],
        [self.refreshButton.heightAnchor constraintEqualToConstant:40],
        
        // 历史标签约束
        [self.historyLabel.centerXAnchor constraintEqualToAnchor:self.controlView.centerXAnchor],
        [self.historyLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:10],
        
        // 加载指示器约束
        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

- (void)setupGestureRecognizers {
    // 添加点击手势来显示/隐藏控制视图
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [self.view addGestureRecognizer:tapGesture];

    // 添加左右滑动手势
    UISwipeGestureRecognizer *leftSwipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    leftSwipe.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.view addGestureRecognizer:leftSwipe];

    UISwipeGestureRecognizer *rightSwipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    rightSwipe.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:rightSwipe];
}

- (void)setupPlayer {
    if (!self.videoURL) return;

    // 清理旧的播放器
    if (self.player) {
        [self.player pause];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:self.player.currentItem];
        [self.playerLayer removeFromSuperlayer];
    }

    // 创建播放器
    self.player = [AVPlayer playerWithURL:self.videoURL];
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.playerLayer.frame = self.view.bounds;
    [self.view.layer insertSublayer:self.playerLayer atIndex:0];

    // 添加播放状态观察
    [self.player addObserver:self forKeyPath:@"timeControlStatus" options:NSKeyValueObservingOptionNew context:nil];

    // 添加播放结束通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerDidFinishPlaying:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.player.currentItem];

    // 添加播放失败通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemFailedToPlay:)
                                                 name:AVPlayerItemFailedToPlayToEndTimeNotification
                                               object:self.player.currentItem];

    // 播放视频
    [self.player play];
}

- (void)updateHistoryLabel {
    if (self.totalCount > 0) {
        self.historyLabel.text = [NSString stringWithFormat:@"%ld/%ld", (long)(self.currentIndex + 1), (long)self.totalCount];
    } else {
        self.historyLabel.text = @"";
    }
}

#pragma mark - 按钮事件

- (void)closeButtonTapped {
    // 通知代理视频播放器即将关闭
    if ([self.delegate respondsToSelector:@selector(videoPlayerWillClose:)]) {
        [self.delegate videoPlayerWillClose:self];
    }

    [self dismissViewControllerAnimated:YES completion:^{
        // 关闭完成后，确保父视图控制器的导航栏状态正确
        NSLog(@"CustomVideoPlayer 已完全关闭");
    }];
}

- (void)saveButtonTapped {
    if (!self.videoURL) return;

    // 显示保存确认对话框
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"保存视频"
                                                                   message:@"确定要保存这个视频到相册吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *saveAction = [UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self saveVideoToPhotoLibrary];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];

    [alert addAction:saveAction];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)saveVideoToPhotoLibrary {
    // 首先检查相册访问权限
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];

    if (status == PHAuthorizationStatusNotDetermined) {
        // 请求权限
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited) {
                    [self performVideoSave];
                } else {
                    [self showSaveResult:NO message:@"需要相册访问权限才能保存视频"];
                }
            });
        }];
    } else if (status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited) {
        [self performVideoSave];
    } else {
        [self showSaveResult:NO message:@"请在设置中允许访问相册"];
    }
}

- (void)performVideoSave {
    // 显示保存中的提示
    UIAlertController *savingAlert = [UIAlertController alertControllerWithTitle:@"保存中..."
                                                                         message:@"正在保存视频到相册，请稍候..."
                                                                  preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:savingAlert animated:YES completion:nil];

    // 直接使用当前播放的本地视频文件
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *videoPath = self.videoURL.path;

        // 检查文件是否存在
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:videoPath]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [savingAlert dismissViewControllerAnimated:YES completion:^{
                    [self showSaveResult:NO message:@"视频文件不存在"];
                }];
            });
            return;
        }

        // 检查文件大小
        NSError *attributeError;
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:videoPath error:&attributeError];
        NSNumber *fileSize = attributes[NSFileSize];
        if (!fileSize || [fileSize longLongValue] == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [savingAlert dismissViewControllerAnimated:YES completion:^{
                    [self showSaveResult:NO message:@"视频文件为空"];
                }];
            });
            return;
        }

        // 检查视频是否可以保存到相册
        if (!UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(videoPath)) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [savingAlert dismissViewControllerAnimated:YES completion:^{
                    [self showSaveResult:NO message:@"视频格式不兼容，无法保存到相册"];
                }];
            });
            return;
        }

        // 在主线程执行保存操作
        dispatch_async(dispatch_get_main_queue(), ^{
            [savingAlert dismissViewControllerAnimated:YES completion:^{
                // 保存视频到相册
                UISaveVideoAtPathToSavedPhotosAlbum(videoPath, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
            }];
        });
    });
}

- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    if (error) {
        NSString *errorMessage = [NSString stringWithFormat:@"错误代码: %ld, %@", (long)error.code, error.localizedDescription];
        [self showSaveResult:NO message:[NSString stringWithFormat:@"保存失败: %@", errorMessage]];
    } else {
        [self showSaveResult:YES message:@"视频已成功保存到相册"];
    }
}

- (void)showSaveResult:(BOOL)success message:(NSString *)message {
    UIAlertController *resultAlert = [UIAlertController alertControllerWithTitle:success ? @"保存成功" : @"保存失败"
                                                                          message:message
                                                                   preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
    [resultAlert addAction:okAction];

    [self presentViewController:resultAlert animated:YES completion:nil];
}

- (void)playPauseButtonTapped {
    if (self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying) {
        [self.player pause];
        [self.playPauseButton setTitle:@"▶️" forState:UIControlStateNormal];
    } else {
        [self.player play];
        [self.playPauseButton setTitle:@"⏸" forState:UIControlStateNormal];
    }
}



- (void)refreshButtonTapped {
    [self showLoadingIndicator];
    [self.delegate playNextFromCurrentType];
}

#pragma mark - 手势处理

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    [self toggleControlsVisibility];
}

- (void)handleSwipe:(UISwipeGestureRecognizer *)gesture {
    // 滑动手势暂时禁用，只保留点击切换控制栏
}

#pragma mark - 控制视图显示/隐藏

- (void)toggleControlsVisibility {
    self.controlsVisible = !self.controlsVisible;

    [UIView animateWithDuration:0.3 animations:^{
        self.controlView.alpha = self.controlsVisible ? 1.0 : 0.0;
    }];

    if (self.controlsVisible) {
        [self startHideControlsTimer];
    } else {
        [self stopHideControlsTimer];
    }
}

- (void)startHideControlsTimer {
    [self stopHideControlsTimer];
    self.hideControlsTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                              target:self
                                                            selector:@selector(hideControlsTimerFired)
                                                            userInfo:nil
                                                             repeats:NO];
}

- (void)stopHideControlsTimer {
    if (self.hideControlsTimer) {
        [self.hideControlsTimer invalidate];
        self.hideControlsTimer = nil;
    }
}

- (void)hideControlsTimerFired {
    if (self.controlsVisible) {
        [self toggleControlsVisibility];
    }
}

#pragma mark - 加载指示器

- (void)showLoadingIndicator {
    [self.loadingIndicator startAnimating];
}

- (void)hideLoadingIndicator {
    [self.loadingIndicator stopAnimating];
}

#pragma mark - KVO 和通知处理

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"timeControlStatus"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            switch (self.player.timeControlStatus) {
                case AVPlayerTimeControlStatusPlaying:
                    [self hideLoadingIndicator];
                    [self.playPauseButton setTitle:@"⏸" forState:UIControlStateNormal];
                    break;
                case AVPlayerTimeControlStatusPaused:
                    [self hideLoadingIndicator];
                    [self.playPauseButton setTitle:@"▶️" forState:UIControlStateNormal];
                    break;
                case AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate:
                    [self showLoadingIndicator];
                    break;
            }
        });
    }
}

- (void)playerDidFinishPlaying:(NSNotification *)notification {
    // 播放完成后自动播放下一个
    [self refreshButtonTapped];
}

- (void)playerItemFailedToPlay:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self hideLoadingIndicator];
        NSLog(@"视频播放失败: %@", notification.userInfo);

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"播放失败"
                                                                       message:@"视频播放出现问题，是否重新加载？"
                                                                preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *retryAction = [UIAlertAction actionWithTitle:@"重试" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self refreshButtonTapped];
        }];

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];

        [alert addAction:retryAction];
        [alert addAction:cancelAction];

        [self presentViewController:alert animated:YES completion:nil];
    });
}

- (void)dealloc {
    if (self.player) {
        [self.player removeObserver:self forKeyPath:@"timeControlStatus"];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopHideControlsTimer];
}

@end
