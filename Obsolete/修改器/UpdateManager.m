//
//  UpdateManager.m
//  Modifier
//
//  Created by Assistant on 2025/1/21.
//

#import "UpdateManager.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <sys/sysctl.h>
#import <objc/runtime.h>

// 更新检查的远程URL - 你需要替换为实际的服务器地址
#define UPDATE_CHECK_URL @"https://rocket.xkcc.vip/advanced_update_api.php"

@interface UpdateManager () <NSURLSessionDownloadDelegate>

@property (nonatomic, strong) NSURLSession *downloadSession;
@property (nonatomic, weak) UIViewController *currentController;
@property (nonatomic, strong) UIView *customAlertView;
@property (nonatomic, strong) UIView *downloadProgressView;
@property (nonatomic, strong) UIProgressView *progressBar;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, assign) BOOL isForceUpdate;

@end

@implementation UpdateManager

+ (instancetype)sharedManager {
    static UpdateManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[UpdateManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isUpdateCheckEnabled = YES;
        _allFeaturesDisabled = NO;

        // 创建下载会话
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        _downloadSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];

        // 启动时检查是否被hook
        if ([self isHooked]) {
            [self disableAllFeatures];
        }
    }
    return self;
}

#pragma mark - 版本检查

- (void)checkForUpdatesWithCompletion:(void(^)(BOOL hasUpdate, NSString *latestVersion, NSString *downloadURL, NSString *updateDescription, BOOL forceUpdate))completion {
    if (!self.isUpdateCheckEnabled || self.allFeaturesDisabled) {
        if (completion) {
            completion(NO, nil, nil, nil, NO);
        }
        return;
    }
    
    // 再次检查hook状态
    if ([self isHooked]) {
        [self disableAllFeatures];
        if (completion) {
            completion(NO, nil, nil, nil, NO);
        }
        return;
    }
    
    NSString *currentVersion = [self getCurrentVersion];

    NSString *urlString = [NSString stringWithFormat:@"%@?current_version=%@",
                          UPDATE_CHECK_URL,
                          [currentVersion stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 10.0;
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(NO, nil, nil, nil, NO);
                }
            });
            return;
        }
        
        NSError *jsonError;
        NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (jsonError || !responseDict) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(NO, nil, nil, nil, NO);
                }
            });
            return;
        }
        
        BOOL hasUpdate = [responseDict[@"has_update"] boolValue];
        NSString *latestVersion = responseDict[@"latest_version"];
        NSString *downloadURL = responseDict[@"download_url"];
        NSString *updateDescription = responseDict[@"description"];
        BOOL forceUpdate = [responseDict[@"force_update"] boolValue];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(hasUpdate, latestVersion, downloadURL, updateDescription, forceUpdate);
            }
        });
    }];
    
    [task resume];
}

- (NSString *)getCurrentVersion {
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString *version = infoDictionary[@"CFBundleShortVersionString"];
    return version ?: @"2.3";
}

#pragma mark - 自定义更新弹窗

- (void)showUpdateAlertWithVersion:(NSString *)version
                       downloadURL:(NSString *)downloadURL
                       description:(NSString *)description
                       forceUpdate:(BOOL)forceUpdate
                    fromController:(UIViewController *)controller {

    if (self.allFeaturesDisabled) {
        return;
    }

    // 保存强制更新状态
    self.isForceUpdate = forceUpdate;

    // 确保在主窗口上显示，而不是特定的控制器
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) {
        keyWindow = [UIApplication sharedApplication].windows.firstObject;
    }

    self.currentController = controller;

    // 创建背景遮罩
    UIView *backgroundView = [[UIView alloc] initWithFrame:keyWindow.bounds];
    backgroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
    backgroundView.alpha = 0;

    // 创建弹窗容器 - 更简洁美观
    CGFloat alertWidth = 320;
    CGFloat alertHeight = 320;
    UIView *alertView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, alertWidth, alertHeight)];
    alertView.center = backgroundView.center;
    alertView.backgroundColor = [UIColor systemBackgroundColor];
    alertView.layer.cornerRadius = 20;
    alertView.layer.shadowColor = [UIColor blackColor].CGColor;
    alertView.layer.shadowOffset = CGSizeMake(0, 10);
    alertView.layer.shadowOpacity = 0.25;
    alertView.layer.shadowRadius = 20;
    alertView.transform = CGAffineTransformMakeScale(0.7, 0.7);

    // 顶部装饰条
    UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, alertWidth, 4)];
    topBar.backgroundColor = [UIColor systemBlueColor];
    CALayer *topBarMask = [CALayer layer];
    topBarMask.frame = topBar.bounds;
    topBarMask.cornerRadius = 20;
    topBarMask.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    topBar.layer.mask = topBarMask;

    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 40, alertWidth - 40, 30)];
    titleLabel.text = @"发现新版本";
    titleLabel.font = [UIFont boldSystemFontOfSize:22];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = [UIColor labelColor];

    // 版本信息
    UILabel *versionLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 80, alertWidth - 40, 25)];
    versionLabel.text = [NSString stringWithFormat:@"最新版本: %@", version];
    versionLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    versionLabel.textAlignment = NSTextAlignmentCenter;
    versionLabel.textColor = [UIColor systemBlueColor];

    // 更新描述容器
    UIView *descriptionContainer = [[UIView alloc] initWithFrame:CGRectMake(20, 115, alertWidth - 40, 140)];
    descriptionContainer.backgroundColor = [UIColor secondarySystemBackgroundColor];
    descriptionContainer.layer.cornerRadius = 12;

    // 更新描述 - 支持换行
    UILabel *descriptionLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 15, descriptionContainer.frame.size.width - 30, descriptionContainer.frame.size.height - 30)];

    // 处理换行符，将\n替换为真正的换行
    NSString *processedDescription = description ?: @"请更新到最新版本以获得更好的体验";
    processedDescription = [processedDescription stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];

    descriptionLabel.text = processedDescription;
    descriptionLabel.font = [UIFont systemFontOfSize:15];
    descriptionLabel.textColor = [UIColor secondaryLabelColor];
    descriptionLabel.numberOfLines = 0; // 支持多行
    descriptionLabel.lineBreakMode = NSLineBreakByWordWrapping;
    descriptionLabel.textAlignment = NSTextAlignmentLeft;
    [descriptionContainer addSubview:descriptionLabel];

    // 下载按钮 - 单个按钮，全宽
    UIButton *downloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
    downloadButton.frame = CGRectMake(20, 275, alertWidth - 40, 50);
    [downloadButton setTitle:@"立即下载" forState:UIControlStateNormal];
    [downloadButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    downloadButton.backgroundColor = [UIColor systemBlueColor];
    downloadButton.layer.cornerRadius = 12;
    downloadButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];

    // 添加按钮点击效果
    [downloadButton addTarget:self action:@selector(downloadButtonPressed:) forControlEvents:UIControlEventTouchDown];
    [downloadButton addTarget:self action:@selector(downloadButtonReleased:) forControlEvents:UIControlEventTouchUpInside];
    [downloadButton addTarget:self action:@selector(downloadButtonReleased:) forControlEvents:UIControlEventTouchUpOutside];

    // 存储下载URL
    objc_setAssociatedObject(downloadButton, "downloadURL", downloadURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 添加子视图
    [alertView addSubview:topBar];
    [alertView addSubview:titleLabel];
    [alertView addSubview:versionLabel];
    [alertView addSubview:descriptionContainer];
    [alertView addSubview:downloadButton];

    [backgroundView addSubview:alertView];
    [keyWindow addSubview:backgroundView];

    self.customAlertView = backgroundView;

    // 动画显示
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.3 options:UIViewAnimationOptionCurveEaseOut animations:^{
        backgroundView.alpha = 1;
        alertView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

// 按钮按下效果
- (void)downloadButtonPressed:(UIButton *)sender {
    [UIView animateWithDuration:0.1 animations:^{
        sender.transform = CGAffineTransformMakeScale(0.95, 0.95);
        sender.alpha = 0.8;
    }];
}

// 按钮释放效果和下载处理
- (void)downloadButtonReleased:(UIButton *)sender {
    [UIView animateWithDuration:0.1 animations:^{
        sender.transform = CGAffineTransformIdentity;
        sender.alpha = 1.0;
    } completion:^(BOOL finished) {
        NSString *downloadURL = objc_getAssociatedObject(sender, "downloadURL");
        if (downloadURL) {
            [self downloadUpdateFromURL:downloadURL fromController:self.currentController];
        }
    }];
}

// 取消按钮处理
- (void)cancelButtonTapped:(UIButton *)sender {
    [self hideCustomAlert];
}

#pragma mark - 下载功能

- (void)downloadUpdateFromURL:(NSString *)urlString fromController:(UIViewController *)controller {
    if (self.allFeaturesDisabled) {
        NSLog(@"UpdateManager: 所有功能已禁用，取消下载");
        return;
    }

    NSLog(@"UpdateManager: 开始下载更新，URL: %@", urlString);

    // 隐藏更新弹窗
    [self hideCustomAlert];

    // 显示下载进度弹窗
    [self showDownloadProgressFromController:controller];

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        NSLog(@"UpdateManager: 无效的下载URL");
        [self hideDownloadProgress];
        [self showErrorMessage:@"下载链接无效" fromController:controller];
        return;
    }

    NSLog(@"UpdateManager: 创建下载任务");
    NSURLSessionDownloadTask *downloadTask = [self.downloadSession downloadTaskWithURL:url];
    [downloadTask resume];
    NSLog(@"UpdateManager: 下载任务已启动");
}

- (void)showDownloadProgressFromController:(UIViewController *)controller {
    // 确保在主窗口上显示
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) {
        keyWindow = [UIApplication sharedApplication].windows.firstObject;
    }

    // 创建背景遮罩
    UIView *backgroundView = [[UIView alloc] initWithFrame:keyWindow.bounds];
    backgroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];

    // 创建进度弹窗 - 更简洁的设计
    CGFloat alertWidth = 260;
    CGFloat alertHeight = 120;
    UIView *alertView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, alertWidth, alertHeight)];
    alertView.center = backgroundView.center;
    alertView.backgroundColor = [UIColor systemBackgroundColor];
    alertView.layer.cornerRadius = 16;
    alertView.layer.shadowColor = [UIColor blackColor].CGColor;
    alertView.layer.shadowOffset = CGSizeMake(0, 8);
    alertView.layer.shadowOpacity = 0.2;
    alertView.layer.shadowRadius = 16;

    // 顶部装饰条
    UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, alertWidth, 3)];
    topBar.backgroundColor = [UIColor systemGreenColor];
    CALayer *topBarMask = [CALayer layer];
    topBarMask.frame = topBar.bounds;
    topBarMask.cornerRadius = 16;
    topBarMask.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    topBar.layer.mask = topBarMask;

    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 25, alertWidth - 40, 25)];
    titleLabel.text = @"正在下载更新";
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = [UIColor labelColor];

    // 进度条
    UIProgressView *progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(30, 60, alertWidth - 60, 4)];
    progressView.progressTintColor = [UIColor systemGreenColor];
    progressView.trackTintColor = [UIColor tertiarySystemBackgroundColor];
    progressView.progress = 0.0;
    progressView.layer.cornerRadius = 2;

    // 进度标签
    UILabel *progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 80, alertWidth - 40, 20)];
    progressLabel.text = @"0%";
    progressLabel.font = [UIFont systemFontOfSize:14];
    progressLabel.textAlignment = NSTextAlignmentCenter;
    progressLabel.textColor = [UIColor secondaryLabelColor];

    [alertView addSubview:topBar];
    [alertView addSubview:titleLabel];
    [alertView addSubview:progressView];
    [alertView addSubview:progressLabel];

    [backgroundView addSubview:alertView];
    [keyWindow addSubview:backgroundView];

    self.downloadProgressView = backgroundView;
    self.progressBar = progressView;
    self.progressLabel = progressLabel;

    // 添加进入动画
    alertView.transform = CGAffineTransformMakeScale(0.8, 0.8);
    alertView.alpha = 0;
    [UIView animateWithDuration:0.3 animations:^{
        alertView.transform = CGAffineTransformIdentity;
        alertView.alpha = 1;
    }];
}

- (void)hideCustomAlert {
    if (self.customAlertView) {
        UIView *alertView = self.customAlertView.subviews.firstObject;
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.3 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.customAlertView.alpha = 0;
            if (alertView) {
                alertView.transform = CGAffineTransformMakeScale(0.8, 0.8);
            }
        } completion:^(BOOL finished) {
            [self.customAlertView removeFromSuperview];
            self.customAlertView = nil;
        }];
    }
}

- (void)hideDownloadProgress {
    if (self.downloadProgressView) {
        UIView *alertView = self.downloadProgressView.subviews.firstObject;
        [UIView animateWithDuration:0.3 animations:^{
            self.downloadProgressView.alpha = 0;
            if (alertView) {
                alertView.transform = CGAffineTransformMakeScale(0.9, 0.9);
            }
        } completion:^(BOOL finished) {
            [self.downloadProgressView removeFromSuperview];
            self.downloadProgressView = nil;
            self.progressBar = nil;
            self.progressLabel = nil;
        }];
    }
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {

    if (totalBytesExpectedToWrite > 0) {
        float progress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;

        NSLog(@"UpdateManager: 下载进度 %.1f%% (%lld/%lld bytes)", progress * 100, totalBytesWritten, totalBytesExpectedToWrite);

        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.progressBar) {
                self.progressBar.progress = progress;
                NSLog(@"UpdateManager: 更新进度条到 %.1f%%", progress * 100);
            } else {
                NSLog(@"UpdateManager: 警告 - progressBar 为 nil");
            }
            if (self.progressLabel) {
                self.progressLabel.text = [NSString stringWithFormat:@"%.0f%%", progress * 100];
            } else {
                NSLog(@"UpdateManager: 警告 - progressLabel 为 nil");
            }
        });
    } else {
        NSLog(@"UpdateManager: 无法获取文件总大小，totalBytesExpectedToWrite = %lld", totalBytesExpectedToWrite);
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    
    // 将下载的文件移动到Documents目录
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *fileName = [downloadTask.response suggestedFilename] ?: @"update.ipa";
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:fileName];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    
    // 如果文件已存在，先删除
    if ([fileManager fileExistsAtPath:filePath]) {
        [fileManager removeItemAtPath:filePath error:nil];
    }
    
    // 移动文件
    BOOL success = [fileManager moveItemAtURL:location toURL:[NSURL fileURLWithPath:filePath] error:&error];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self hideDownloadProgress];

        if (success) {
            if (self.isForceUpdate) {
                // 强制更新：显示安装提示并继续限制使用
                [self showForceUpdateInstallPromptWithFilePath:filePath fromController:self.currentController];
            } else {
                // 普通更新：直接分享文件
                [self shareFile:filePath fromController:self.currentController];
            }
        } else {
            // 下载失败
            [self showErrorMessage:@"下载失败，请重试" fromController:self.currentController];
        }
    });
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didCompleteWithError:(NSError *)error {
    if (error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideDownloadProgress];
            [self showErrorMessage:@"下载失败，请检查网络连接" fromController:self.currentController];
        });
    }
}

#pragma mark - 强制更新处理

- (void)showForceUpdateInstallPromptWithFilePath:(NSString *)filePath fromController:(UIViewController *)controller {
    // 确保在主窗口上显示
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) {
        keyWindow = [UIApplication sharedApplication].windows.firstObject;
    }

    // 创建背景遮罩 - 不可取消
    UIView *backgroundView = [[UIView alloc] initWithFrame:keyWindow.bounds];
    backgroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];

    // 创建弹窗容器
    CGFloat alertWidth = 300;
    CGFloat alertHeight = 200;
    UIView *alertView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, alertWidth, alertHeight)];
    alertView.center = backgroundView.center;
    alertView.backgroundColor = [UIColor systemBackgroundColor];
    alertView.layer.cornerRadius = 16;
    alertView.layer.shadowColor = [UIColor blackColor].CGColor;
    alertView.layer.shadowOffset = CGSizeMake(0, 8);
    alertView.layer.shadowOpacity = 0.3;
    alertView.layer.shadowRadius = 16;

    // 顶部装饰条 - 红色表示强制
    UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, alertWidth, 4)];
    topBar.backgroundColor = [UIColor systemRedColor];
    CALayer *topBarMask = [CALayer layer];
    topBarMask.frame = topBar.bounds;
    topBarMask.cornerRadius = 16;
    topBarMask.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    topBar.layer.mask = topBarMask;

    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 30, alertWidth - 40, 30)];
    titleLabel.text = @"请安装更新";
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = [UIColor labelColor];

    // 描述
    UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 70, alertWidth - 40, 60)];
    descLabel.text = @"更新文件已下载完成\n请通过分享安装新版本\n安装完成后重新打开应用";
    descLabel.font = [UIFont systemFontOfSize:14];
    descLabel.textAlignment = NSTextAlignmentCenter;
    descLabel.textColor = [UIColor secondaryLabelColor];
    descLabel.numberOfLines = 0;

    // 安装按钮
    UIButton *installButton = [UIButton buttonWithType:UIButtonTypeSystem];
    installButton.frame = CGRectMake(20, 145, alertWidth - 40, 40);
    [installButton setTitle:@"立即安装" forState:UIControlStateNormal];
    [installButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    installButton.backgroundColor = [UIColor systemRedColor];
    installButton.layer.cornerRadius = 8;
    installButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];

    // 存储文件路径
    objc_setAssociatedObject(installButton, "filePath", filePath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [installButton addTarget:self action:@selector(forceInstallButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    [alertView addSubview:topBar];
    [alertView addSubview:titleLabel];
    [alertView addSubview:descLabel];
    [alertView addSubview:installButton];

    [backgroundView addSubview:alertView];
    [keyWindow addSubview:backgroundView];

    self.customAlertView = backgroundView;

    // 动画显示
    alertView.transform = CGAffineTransformMakeScale(0.8, 0.8);
    alertView.alpha = 0;
    [UIView animateWithDuration:0.3 animations:^{
        alertView.transform = CGAffineTransformIdentity;
        alertView.alpha = 1;
    }];
}

- (void)forceInstallButtonTapped:(UIButton *)sender {
    NSString *filePath = objc_getAssociatedObject(sender, "filePath");
    if (filePath) {
        // 分享文件进行安装
        [self shareFile:filePath fromController:self.currentController];

        // 注意：不隐藏弹窗，因为这是强制更新
        // 用户必须安装更新才能继续使用应用

        // 可以添加一个定时器来定期检查版本，如果版本更新了就隐藏弹窗
        [self startForceUpdateVersionCheck];
    }
}

- (void)startForceUpdateVersionCheck {
    // 每5秒检查一次版本是否已更新
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self checkForUpdatesWithCompletion:^(BOOL hasUpdate, NSString *latestVersion, NSString *downloadURL, NSString *updateDescription, BOOL forceUpdate) {
            if (!hasUpdate) {
                // 版本已更新，隐藏强制更新弹窗
                [self hideCustomAlert];
                self.isForceUpdate = NO;
            } else if (forceUpdate) {
                // 仍然需要强制更新，继续检查
                [self startForceUpdateVersionCheck];
            }
        }];
    });
}

#pragma mark - 分享功能

- (void)shareFile:(NSString *)filePath fromController:(UIViewController *)controller {
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
    
    // iPad适配
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = controller.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(controller.view.bounds.size.width/2, controller.view.bounds.size.height/2, 0, 0);
    }
    
    [controller presentViewController:activityVC animated:YES completion:nil];
}

- (void)showErrorMessage:(NSString *)message fromController:(UIViewController *)controller {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [controller presentViewController:alert animated:YES completion:nil];
}

#pragma mark - 反调试检测

- (BOOL)isHooked {
    // 检测1: 检查是否有调试器附加
    if ([self isDebuggerAttached]) {
        return YES;
    }
    
    // 检测2: 检查动态库注入
    if ([self hasInjectedLibraries]) {
        return YES;
    }
    
    // 检测3: 检查关键函数是否被hook
    if ([self areKeyFunctionsHooked]) {
        return YES;
    }
    
    return NO;
}

- (BOOL)isDebuggerAttached {
    int mib[4];
    struct kinfo_proc info;
    size_t size = sizeof(info);
    
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROC;
    mib[2] = KERN_PROC_PID;
    mib[3] = getpid();
    
    if (sysctl(mib, sizeof(mib) / sizeof(*mib), &info, &size, NULL, 0) != 0) {
        return NO;
    }
    
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

- (BOOL)hasInjectedLibraries {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name) {
            NSString *imageName = [NSString stringWithUTF8String:name];
            // 检查常见的hook框架
            if ([imageName containsString:@"substrate"] ||
                [imageName containsString:@"substitute"] ||
                [imageName containsString:@"fishhook"] ||
                [imageName containsString:@"frida"]) {
                return YES;
            }
        }
    }
    return NO;
}

- (BOOL)areKeyFunctionsHooked {
    // 检查关键系统函数是否被hook
    void *handle = dlopen(NULL, RTLD_NOW);
    if (!handle) {
        return NO;
    }
    
    // 检查一些关键函数的地址
    void *original_dlsym = dlsym(handle, "dlsym");
    void *original_dlopen = dlsym(handle, "dlopen");
    
    dlclose(handle);
    
    // 简单的地址检查（实际应用中可以更复杂）
    if (!original_dlsym || !original_dlopen) {
        return YES;
    }
    
    return NO;
}

- (void)disableAllFeatures {
    self.allFeaturesDisabled = YES;
    self.isUpdateCheckEnabled = NO;

    // 发送通知，让其他组件知道功能被禁用
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AllFeaturesDisabled" object:nil];
}



- (UIViewController *)getTopViewController {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) {
        keyWindow = [UIApplication sharedApplication].windows.firstObject;
    }

    UIViewController *topController = keyWindow.rootViewController;

    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }

    if ([topController isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabBarController = (UITabBarController *)topController;
        topController = tabBarController.selectedViewController;
    }

    if ([topController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navController = (UINavigationController *)topController;
        topController = navController.topViewController;
    }

    return topController;
}

#pragma mark - 设备信息







@end
