//
//  HappySummerViewController.m
//  修改器
//
//  Created by MacXK on 2025/8/7.
//

#import "HappySummerViewController.h"
#import "VideoHistoryManager.h"
#import "CustomVideoPlayer.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <Photos/Photos.h>

// 自定义集合视图单元格
@interface ToolCollectionViewCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *titleLabel;
- (void)configureWithTitle:(NSString *)title imageName:(NSString *)imageName;
@end

@interface HappySummerViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

// UI Components
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UICollectionView *toolsCollectionView;

// Tools data
@property (nonatomic, strong) NSArray<NSArray<NSString *> *> *tools;

// Video player reference
@property (nonatomic, weak) CustomVideoPlayer *currentVideoPlayer;

@end

@implementation HappySummerViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // 设置标题（模仿应用搜索界面的简单做法）
    self.title = @"API 工具箱";

    [self setupTools];
    [self setupUI];
    [self setupCollectionView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // 确保导航栏可见（模仿应用搜索界面的简单做法）
    self.navigationController.navigationBar.hidden = NO;

    // 隐藏自定义标题，使用导航栏标题
    self.titleLabel.hidden = YES;
    self.titleLabel.alpha = 0.0;
}







- (void)refreshUIElements {
    // 确保自定义标题隐藏
    if (self.titleLabel) {
        self.titleLabel.hidden = YES;
        self.titleLabel.alpha = 0.0;
    }

    // 确保集合视图显示
    if (self.toolsCollectionView) {
        self.toolsCollectionView.hidden = NO;
        self.toolsCollectionView.alpha = 1.0;
        [self.toolsCollectionView reloadData];
    }
}



- (void)setupTools {
    self.tools = @[
        @[@"小姐姐视频", @"video.fill"],
        @[@"黑丝图片", @"photo.fill"],
        @[@"黑丝视频", @"film.fill"],
        @[@"白丝视频", @"film.fill"],
        @[@"漫展视频", @"tv.fill"],
        @[@"完美身材", @"person.fill"],
        @[@"极品狱卒", @"shield.fill"],
        @[@"慢摇系列", @"music.note.list"],
        @[@"吊带系列", @"person.crop.circle.fill"],
        @[@"COS系列", @"star.circle.fill"],
        @[@"双倍快乐", @"heart.circle.fill"],
        @[@"玉足美腿", @"figure.walk"],
        @[@"热舞视频", @"flame.fill"],
        @[@"随机黑丝", @"graduationcap.fill"],
        @[@"你的欲梦", @"moon.stars.fill"]
    ];
}

- (void)setupUI {
    // 设置渐变背景
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.colors = @[
        (id)[UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:1].CGColor,
        (id)[UIColor colorWithRed:0.4 green:0.7 blue:1.0 alpha:1].CGColor
    ];
    gradientLayer.locations = @[@0.0, @1.0];
    gradientLayer.frame = self.view.bounds;
    [self.view.layer insertSublayer:gradientLayer atIndex:0];
    
    // 创建UI组件
    [self createUIComponents];
    [self setupConstraints];
}

- (void)createUIComponents {
    // 标题
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"API 工具箱";
    self.titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.textColor = [UIColor whiteColor];
}

- (void)setupConstraints {
    // 添加标题到父视图
    [self.view addSubview:self.titleLabel];

    // 设置translatesAutoresizingMaskIntoConstraints为NO
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        // 标题约束
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [self.titleLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]
    ]];
}



- (void)setupCollectionView {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;

    self.toolsCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.toolsCollectionView.backgroundColor = [UIColor clearColor];
    self.toolsCollectionView.delegate = self;
    self.toolsCollectionView.dataSource = self;
    [self.toolsCollectionView registerClass:[ToolCollectionViewCell class] forCellWithReuseIdentifier:@"ToolCell"];
    self.toolsCollectionView.showsVerticalScrollIndicator = NO;

    [self.view addSubview:self.toolsCollectionView];
    self.toolsCollectionView.translatesAutoresizingMaskIntoConstraints = NO;

    // 集合视图约束
    [NSLayoutConstraint activateConstraints:@[
        [self.toolsCollectionView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [self.toolsCollectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.toolsCollectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.toolsCollectionView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20]
    ]];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.tools.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    ToolCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ToolCell" forIndexPath:indexPath];
    NSArray *tool = self.tools[indexPath.item];
    [cell configureWithTitle:tool[0] imageName:tool[1]];
    return cell;
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat width = (collectionView.bounds.size.width - 40) / 3; // 3列
    return CGSizeMake(width, width * 0.9);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 10;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 10;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *selectedTool = self.tools[indexPath.item];
    NSString *toolName = selectedTool[0];

    // 清空历史记录，因为用户选择了新工具
    [[VideoHistoryManager shared] clearHistory];
    self.isFromHistory = NO;

    // 根据选择的工具执行不同操作
    if ([toolName isEqualToString:@"小姐姐视频"]) {
        [self fetchBeautyVideo];
    } else if ([toolName isEqualToString:@"黑丝图片"]) {
        [self fetchBlackSilkImage];
    } else if ([toolName isEqualToString:@"黑丝视频"]) {
        [self fetchBlackSilkVideo];
    } else if ([toolName isEqualToString:@"白丝视频"]) {
        [self fetchWhiteSilkVideo];
    } else if ([toolName isEqualToString:@"漫展视频"]) {
        [self fetchCosplayVideo];
    } else if ([toolName isEqualToString:@"完美身材"]) {
        [self fetchPerfectBodyVideo];
    } else if ([toolName isEqualToString:@"极品狱卒"]) {
        [self fetchPrisonGuardVideo];
    } else if ([toolName isEqualToString:@"慢摇系列"]) {
        [self fetchSlowDanceVideo];
    } else if ([toolName isEqualToString:@"吊带系列"]) {
        [self fetchSuspenderVideo];
    } else if ([toolName isEqualToString:@"COS系列"]) {
        [self fetchCOSVideo];
    } else if ([toolName isEqualToString:@"双倍快乐"]) {
        [self fetchDoubleHappinessVideo];
    } else if ([toolName isEqualToString:@"玉足美腿"]) {
        [self fetchBeautifulLegsVideo];
    } else if ([toolName isEqualToString:@"热舞视频"]) {
        [self fetchHotDanceVideo];
    } else if ([toolName isEqualToString:@"随机黑丝"]) {
        [self fetchJKLolitaVideo];
    } else if ([toolName isEqualToString:@"你的欲梦"]) {
        [self fetchDreamVideo];
    }
}

#pragma mark - 网络请求方法

- (void)fetchBeautyVideo {
    self.currentVideoType = @"小姐姐视频";

    // 如果不是从历史记录播放，添加到历史
    if (!self.isFromHistory) {
        [[VideoHistoryManager shared] addVideo:self.currentVideoType];
    }
    self.isFromHistory = NO;

    // 构建请求URL
    NSURL *url = [NSURL URLWithString:@"http://api.yujn.cn/api/xjj.php?type=video"];
    if (!url) {
        [self showErrorAlert:@"无效的视频地址"];
        return;
    }

    [self performVideoRequest:url];
}

- (void)fetchBlackSilkVideo {
    self.currentVideoType = @"黑丝视频";

    if (!self.isFromHistory) {
        [[VideoHistoryManager shared] addVideo:self.currentVideoType];
    }
    self.isFromHistory = NO;

    NSURL *url = [NSURL URLWithString:@"http://api.yujn.cn/api/heisis.php?type=video"];
    if (!url) {
        [self showErrorAlert:@"无效的视频地址"];
        return;
    }

    [self performVideoRequest:url];
}

- (void)fetchWhiteSilkVideo {
    self.currentVideoType = @"白丝视频";

    if (!self.isFromHistory) {
        [[VideoHistoryManager shared] addVideo:self.currentVideoType];
    }
    self.isFromHistory = NO;

    NSURL *url = [NSURL URLWithString:@"http://api.yujn.cn/api/baisis.php?type=video"];
    if (!url) {
        [self showErrorAlert:@"无效的视频地址"];
        return;
    }

    [self performVideoRequest:url];
}

- (void)fetchCosplayVideo {
    self.currentVideoType = @"漫展视频";

    if (!self.isFromHistory) {
        [[VideoHistoryManager shared] addVideo:self.currentVideoType];
    }
    self.isFromHistory = NO;

    NSURL *url = [NSURL URLWithString:@"https://api.yujn.cn/api/manzhan.php?type=video"];
    if (!url) {
        [self showErrorAlert:@"无效的视频地址"];
        return;
    }

    [self performVideoRequest:url];
}

- (void)fetchPerfectBodyVideo {
    self.currentVideoType = @"完美身材";

    if (!self.isFromHistory) {
        [[VideoHistoryManager shared] addVideo:self.currentVideoType];
    }
    self.isFromHistory = NO;

    NSURL *url = [NSURL URLWithString:@"http://api.yujn.cn/api/wmsc.php?type=video"];
    if (!url) {
        [self showErrorAlert:@"无效的视频地址"];
        return;
    }

    [self performVideoRequest:url];
}

- (void)fetchPrisonGuardVideo {
    self.currentVideoType = @"极品狱卒";

    if (!self.isFromHistory) {
        [[VideoHistoryManager shared] addVideo:self.currentVideoType];
    }
    self.isFromHistory = NO;

    NSURL *url = [NSURL URLWithString:@"http://api.yujn.cn/api/jpmt.php?type=video"];
    if (!url) {
        [self showErrorAlert:@"无效的视频地址"];
        return;
    }

    [self performVideoRequest:url];
}

- (void)fetchSlowDanceVideo {
    self.currentVideoType = @"慢摇系列";

    if (!self.isFromHistory) {
        [[VideoHistoryManager shared] addVideo:self.currentVideoType];
    }
    self.isFromHistory = NO;

    NSURL *url = [NSURL URLWithString:@"http://api.yujn.cn/api/manyao.php?type=video"];
    if (!url) {
        [self showErrorAlert:@"无效的视频地址"];
        return;
    }

    [self performVideoRequest:url];
}

- (void)fetchSuspenderVideo {
    self.currentVideoType = @"吊带系列";

    if (!self.isFromHistory) {
        [[VideoHistoryManager shared] addVideo:self.currentVideoType];
    }
    self.isFromHistory = NO;

    NSURL *url = [NSURL URLWithString:@"http://api.yujn.cn/api/diaodai.php?type=video"];
    if (!url) {
        [self showErrorAlert:@"无效的视频地址"];
        return;
    }

    [self performVideoRequest:url];
}

- (void)fetchCOSVideo {
    self.currentVideoType = @"COS系列";

    if (!self.isFromHistory) {
        [[VideoHistoryManager shared] addVideo:self.currentVideoType];
    }
    self.isFromHistory = NO;

    NSURL *url = [NSURL URLWithString:@"http://api.yujn.cn/api/COS.php?type=video"];
    if (!url) {
        [self showErrorAlert:@"无效的视频地址"];
        return;
    }

    [self performVideoRequest:url];
}

- (void)fetchDoubleHappinessVideo {
    self.currentVideoType = @"双倍快乐";

    if (!self.isFromHistory) {
        [[VideoHistoryManager shared] addVideo:self.currentVideoType];
    }
    self.isFromHistory = NO;

    NSURL *url = [NSURL URLWithString:@"http://api.yujn.cn/api/sbkl.php?type=video"];
    if (!url) {
        [self showErrorAlert:@"无效的视频地址"];
        return;
    }

    [self performVideoRequest:url];
}

- (void)fetchBeautifulLegsVideo {
    self.currentVideoType = @"玉足美腿";

    if (!self.isFromHistory) {
        [[VideoHistoryManager shared] addVideo:self.currentVideoType];
    }
    self.isFromHistory = NO;

    NSURL *url = [NSURL URLWithString:@"http://api.yujn.cn/api/yuzu.php?type=video"];
    if (!url) {
        [self showErrorAlert:@"无效的视频地址"];
        return;
    }

    [self performVideoRequest:url];
}

- (void)fetchHotDanceVideo {
    self.currentVideoType = @"热舞视频";

    if (!self.isFromHistory) {
        [[VideoHistoryManager shared] addVideo:self.currentVideoType];
    }
    self.isFromHistory = NO;

    NSURL *url = [NSURL URLWithString:@"http://api.yujn.cn/api/rewu.php?type=video"];
    if (!url) {
        [self showErrorAlert:@"无效的视频地址"];
        return;
    }

    [self performVideoRequest:url];
}

- (void)fetchJKLolitaVideo {
    self.currentVideoType = @"随机黑丝";

    if (!self.isFromHistory) {
        [[VideoHistoryManager shared] addVideo:self.currentVideoType];
    }
    self.isFromHistory = NO;

    NSURL *url = [NSURL URLWithString:@"http://api.yujn.cn/api/heisis.php?type=video"];
    if (!url) {
        [self showErrorAlert:@"无效的视频地址"];
        return;
    }

    [self performVideoRequest:url];
}

- (void)fetchDreamVideo {
    self.currentVideoType = @"你的欲梦";

    if (!self.isFromHistory) {
        [[VideoHistoryManager shared] addVideo:self.currentVideoType];
    }
    self.isFromHistory = NO;

    NSURL *url = [NSURL URLWithString:@"http://api.yujn.cn/api/ndym.php?type=video"];
    if (!url) {
        [self showErrorAlert:@"无效的视频地址"];
        return;
    }

    [self performVideoRequest:url];
}

- (void)fetchBlackSilkImage {
    // 构建请求URL
    NSURL *url = [NSURL URLWithString:@"http://api.yujn.cn/api/heisi.php?"];
    if (!url) {
        [self showErrorAlert:@"无效的图片地址"];
        return;
    }

    // 创建加载指示器
    UIActivityIndicatorView *loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    loadingIndicator.center = self.view.center;
    loadingIndicator.color = [UIColor whiteColor];
    [self.view addSubview:loadingIndicator];
    [loadingIndicator startAnimating];

    // 创建URLSession数据任务
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        // 移除加载指示器
        dispatch_async(dispatch_get_main_queue(), ^{
            [loadingIndicator stopAnimating];
            [loadingIndicator removeFromSuperview];
        });

        // 检查是否有错误
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showErrorAlert:[NSString stringWithFormat:@"网络请求失败: %@", error.localizedDescription]];
            });
            return;
        }

        // 检查HTTP响应状态码
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showErrorAlert:@"服务器返回错误"];
            });
            return;
        }

        // 检查数据
        if (!data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showErrorAlert:@"没有收到图片数据"];
            });
            return;
        }

        UIImage *image = [UIImage imageWithData:data];
        if (!image) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showErrorAlert:@"图片数据无效"];
            });
            return;
        }

        // 在主线程显示图片
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showFullScreenImage:image];
        });
    }];

    // 开始网络请求
    [task resume];
}

#pragma mark - 通用视频请求方法

- (void)performVideoRequest:(NSURL *)url {
    // 创建URLSession配置
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.timeoutIntervalForRequest = 10.0; // 设置超时时间
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];

    // 创建加载指示器
    UIActivityIndicatorView *loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    loadingIndicator.center = self.view.center;
    loadingIndicator.color = [UIColor whiteColor];
    [self.view addSubview:loadingIndicator];
    [loadingIndicator startAnimating];

    // 创建URLSession数据任务
    NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        // 移除加载指示器
        dispatch_async(dispatch_get_main_queue(), ^{
            [loadingIndicator stopAnimating];
            [loadingIndicator removeFromSuperview];
        });

        // 检查是否有错误
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showErrorAlert:[NSString stringWithFormat:@"网络请求失败: %@", error.localizedDescription]];
            });
            return;
        }

        // 检查HTTP响应状态码
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showErrorAlert:@"服务器返回错误"];
            });
            return;
        }

        // 检查数据
        if (!data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showErrorAlert:@"没有收到视频数据"];
            });
            return;
        }

        // 在主线程播放视频
        dispatch_async(dispatch_get_main_queue(), ^{
            [self playVideo:data];
        });
    }];

    // 开始网络请求
    [task resume];
}

- (void)playVideo:(NSData *)data {
    // 创建唯一的临时文件URL
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsPath = [paths objectAtIndex:0];

    // 使用时间戳和随机数创建唯一文件名
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    NSInteger randomNum = arc4random() % 10000;
    NSString *fileName = [NSString stringWithFormat:@"video_%.0f_%ld.mp4", timestamp, (long)randomNum];
    NSString *videoPath = [documentsPath stringByAppendingPathComponent:fileName];
    NSURL *videoURL = [NSURL fileURLWithPath:videoPath];

    // 清理旧的视频文件（保留最近的5个）
    [self cleanupOldVideoFiles:documentsPath];

    NSError *error;
    BOOL success = [data writeToURL:videoURL options:NSDataWritingAtomic error:&error];
    if (!success) {
        [self showErrorAlert:[NSString stringWithFormat:@"视频保存失败: %@", error.localizedDescription]];
        return;
    }

    // 如果已经有播放器在显示，更新它的视频
    if (self.currentVideoPlayer && self.currentVideoPlayer.presentingViewController) {
        self.currentVideoPlayer.videoURL = videoURL;
        self.currentVideoPlayer.videoType = self.currentVideoType;
        self.currentVideoPlayer.currentIndex = [[VideoHistoryManager shared] getCurrentIndex];
        self.currentVideoPlayer.totalCount = [[VideoHistoryManager shared] getHistoryCount];
        [self.currentVideoPlayer setupPlayer];
        [self.currentVideoPlayer updateHistoryLabel];
        [self.currentVideoPlayer hideLoadingIndicator];
        return;
    }

    // 创建新的自定义视频播放控制器
    CustomVideoPlayer *customPlayerVC = [[CustomVideoPlayer alloc] init];
    customPlayerVC.videoURL = videoURL;
    customPlayerVC.videoType = self.currentVideoType;
    customPlayerVC.delegate = self;
    customPlayerVC.currentIndex = [[VideoHistoryManager shared] getCurrentIndex];
    customPlayerVC.totalCount = [[VideoHistoryManager shared] getHistoryCount];

    // 保存播放器引用
    self.currentVideoPlayer = customPlayerVC;

    // 以模态方式展示视频播放器
    customPlayerVC.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:customPlayerVC animated:YES completion:nil];
}

- (void)cleanupOldVideoFiles:(NSString *)documentsPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSArray *files = [fileManager contentsOfDirectoryAtPath:documentsPath error:&error];

    if (error) {
        NSLog(@"清理视频文件时出错: %@", error.localizedDescription);
        return;
    }

    // 过滤出视频文件
    NSMutableArray *videoFiles = [NSMutableArray array];
    for (NSString *file in files) {
        if ([file hasPrefix:@"video_"] && [file hasSuffix:@".mp4"]) {
            NSString *filePath = [documentsPath stringByAppendingPathComponent:file];
            NSDictionary *attributes = [fileManager attributesOfItemAtPath:filePath error:nil];
            NSDate *creationDate = attributes[NSFileCreationDate];

            [videoFiles addObject:@{
                @"path": filePath,
                @"name": file,
                @"date": creationDate ?: [NSDate distantPast]
            }];
        }
    }

    // 按创建时间排序，最新的在前
    [videoFiles sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        NSDate *date1 = obj1[@"date"];
        NSDate *date2 = obj2[@"date"];
        return [date2 compare:date1]; // 降序排列
    }];

    // 删除超过5个的旧文件
    if (videoFiles.count > 5) {
        for (NSInteger i = 5; i < videoFiles.count; i++) {
            NSString *filePath = videoFiles[i][@"path"];
            [fileManager removeItemAtPath:filePath error:nil];
            NSLog(@"删除旧视频文件: %@", videoFiles[i][@"name"]);
        }
    }
}

- (void)showFullScreenImage:(UIImage *)image {
    // 创建图片视图控制器
    UIViewController *imageViewController = [[UIViewController alloc] init];
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:imageViewController.view.bounds];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.image = image;
    [imageViewController.view addSubview:imageView];

    // 添加关闭按钮
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [closeButton setTitle:@"关闭" forState:UIControlStateNormal];
    [closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeButton.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.5];
    closeButton.layer.cornerRadius = 10;
    closeButton.frame = CGRectMake(20, 50, 60, 40);
    [closeButton addTarget:self action:@selector(dismissFullScreenImage) forControlEvents:UIControlEventTouchUpInside];
    [imageViewController.view addSubview:closeButton];

    // 模态方式展示
    imageViewController.modalPresentationStyle = UIModalPresentationFullScreen;
    imageViewController.view.backgroundColor = [UIColor blackColor];
    [self presentViewController:imageViewController animated:YES completion:nil];
}

- (void)dismissFullScreenImage {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showErrorAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误" message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - CustomVideoPlayerDelegate

- (NSInteger)getCurrentHistoryIndex {
    return [[VideoHistoryManager shared] getCurrentIndex];
}

- (NSInteger)getHistoryCount {
    return [[VideoHistoryManager shared] getHistoryCount];
}



- (void)playNextFromCurrentType {
    // 根据当前类型播放下一个视频
    if ([self.currentVideoType isEqualToString:@"小姐姐视频"]) {
        [self fetchBeautyVideo];
    } else if ([self.currentVideoType isEqualToString:@"黑丝视频"]) {
        [self fetchBlackSilkVideo];
    } else if ([self.currentVideoType isEqualToString:@"白丝视频"]) {
        [self fetchWhiteSilkVideo];
    } else if ([self.currentVideoType isEqualToString:@"漫展视频"]) {
        [self fetchCosplayVideo];
    } else if ([self.currentVideoType isEqualToString:@"完美身材"]) {
        [self fetchPerfectBodyVideo];
    } else if ([self.currentVideoType isEqualToString:@"极品狱卒"]) {
        [self fetchPrisonGuardVideo];
    } else if ([self.currentVideoType isEqualToString:@"慢摇系列"]) {
        [self fetchSlowDanceVideo];
    } else if ([self.currentVideoType isEqualToString:@"吊带系列"]) {
        [self fetchSuspenderVideo];
    } else if ([self.currentVideoType isEqualToString:@"COS系列"]) {
        [self fetchCOSVideo];
    } else if ([self.currentVideoType isEqualToString:@"双倍快乐"]) {
        [self fetchDoubleHappinessVideo];
    } else if ([self.currentVideoType isEqualToString:@"玉足美腿"]) {
        [self fetchBeautifulLegsVideo];
    } else if ([self.currentVideoType isEqualToString:@"热舞视频"]) {
        [self fetchHotDanceVideo];
    } else if ([self.currentVideoType isEqualToString:@"随机黑丝"]) {
        [self fetchJKLolitaVideo];
    } else if ([self.currentVideoType isEqualToString:@"你的欲梦"]) {
        [self fetchDreamVideo];
    }
}

- (void)videoPlayerWillClose:(CustomVideoPlayer *)player {
    // 视频播放器即将关闭，确保导航栏可见（模仿应用搜索界面的简单做法）
    NSLog(@"视频播放器即将关闭，准备恢复导航栏");

    // 清理播放器引用
    self.currentVideoPlayer = nil;

    // 简单设置导航栏可见
    self.navigationController.navigationBar.hidden = NO;
}

@end

@implementation ToolCollectionViewCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupCell];
    }
    return self;
}

- (void)setupCell {
    self.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.2];
    self.layer.cornerRadius = 10;
    self.layer.masksToBounds = YES;

    self.iconImageView = [[UIImageView alloc] init];
    self.iconImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconImageView.tintColor = [UIColor whiteColor];
    self.iconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.iconImageView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.titleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.iconImageView.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [self.iconImageView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:-10],
        [self.iconImageView.widthAnchor constraintEqualToConstant:40],
        [self.iconImageView.heightAnchor constraintEqualToConstant:40],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.iconImageView.bottomAnchor constant:5],
        [self.titleLabel.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:5],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-5]
    ]];
}

- (void)configureWithTitle:(NSString *)title imageName:(NSString *)imageName {
    self.titleLabel.text = title;
    self.iconImageView.image = [UIImage systemImageNamed:imageName];
}

@end
