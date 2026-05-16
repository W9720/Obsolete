//
//  AppDecryptionViewController.m
//  修改器
//
//  Created by AI Assistant on 2025-01-08.
//

#import "AppDecryptionViewController.h"
#import "DumpDecrypted.h"
#import "ProcessManager.h"
#import "PidModel.h"
#import "NSTask.h"
#import "IPAFileExplorerViewController.h"
#import "DylibInjector.h"
#import "InjectionOptionsView.h"
#import "InjectionProgressView.h"
#import "SSZipArchive.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <mach-o/loader.h>
#include <mach-o/dyld_images.h>
#include <fcntl.h>
#include <mach/task_info.h>

#define PROC_PIDPATHINFO		11
#define PROC_PIDPATHINFO_SIZE		(MAXPATHLEN)
#define PROC_PIDPATHINFO_MAXSIZE	(4*MAXPATHLEN)
int proc_pidpath(int pid, void * buffer, uint32_t  buffersize);

#define PORT 31336
#undef DEBUG
#define DEBUG(...) {}

// 添加私有API声明
@interface UIImage (Private)
+ (instancetype)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier
                                                  format:(int)format
                                                   scale:(CGFloat)scale;
@end



// 解密文件模型
@interface DecryptedFileModel : NSObject
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) NSDate *createDate;
@property (nonatomic, assign) long long fileSize;
@end

@implementation DecryptedFileModel
@end

// 解压文件模型
@interface ExtractedFileModel : NSObject
@property (nonatomic, strong) NSString *folderName;
@property (nonatomic, strong) NSString *folderPath;
@property (nonatomic, strong) NSDate *createDate;
@property (nonatomic, assign) long long folderSize;
@property (nonatomic, assign) NSInteger fileCount;
@end

@implementation ExtractedFileModel
@end

static UIWindow *alertWindow = NULL;
static UIWindow *kw = NULL;
static UIViewController *root = NULL;
static UIAlertController *alertController = NULL;
static UIAlertController *ncController = NULL;
static UIAlertController *errorController = NULL;

// 全局变量，用于在C函数中访问当前的解密控制器
static AppDecryptionViewController *currentDecryptionController = nil;

// 进度更新辅助函数
void updateDecryptionProgress(float progress, NSString *status) {
    if (currentDecryptionController) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [currentDecryptionController updateProgress:progress status:status];
        });
    }
}

// 解密完成回调函数
void onDecryptionComplete(BOOL success, NSString *message) {
    if (currentDecryptionController) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [currentDecryptionController updateProgress:1.0 status:@"解密完成！"];
                // 延迟一秒后隐藏进度界面并刷新文件列表
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [currentDecryptionController hideProgressView];
                    // 直接刷新解密文件列表，不显示弹窗
                    [currentDecryptionController loadDecryptedFiles];
                });
            } else {
                [currentDecryptionController hideProgressView];
                [currentDecryptionController showAlert:@"解密失败" message:message];
            }
        });
    }
}

void bfinject_rocknroll(pid_t pid) {
    // 验证 PID 是否有效
    if (pid <= 0) {
        onDecryptionComplete(NO, @"无效的PID");
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 更新进度：验证应用权限
        updateDecryptionProgress(0.05, @"正在验证应用权限...");

		char pathbuf[PROC_PIDPATHINFO_MAXSIZE];
        memset(pathbuf, 0, sizeof(pathbuf)); // 清零缓冲区
    	int ret = proc_pidpath(pid, pathbuf, sizeof(pathbuf));

        if (ret <= 0) {
            onDecryptionComplete(NO, [NSString stringWithFormat:@"无法获取应用路径，PID: %d 可能无效", pid]);
            return;
        }

        // 更新进度：获取应用路径
        updateDecryptionProgress(0.10, @"正在获取应用路径...");

		const char *fullPathStr = pathbuf;
        NSString *pathString = [NSString stringWithUTF8String:fullPathStr];

        // 更新进度：创建解密实例
        updateDecryptionProgress(0.15, @"正在创建解密实例...");

        DumpDecrypted *dd = [[DumpDecrypted alloc] initWithPathToBinary:pathString];
        if(!dd) {
            onDecryptionComplete(NO, @"无法创建解密实例");
            return;
        }

        // 更新进度：分析应用结构
        updateDecryptionProgress(0.25, @"正在分析应用结构...");

        @try {
            // 更新进度：准备解密环境
            updateDecryptionProgress(0.30, @"正在准备解密环境...");

            // 模拟一些准备时间
            [NSThread sleepForTimeInterval:0.5];

            // 更新进度：开始解密
            updateDecryptionProgress(0.40, @"正在解密应用二进制文件...");

            // Do the decryption
            [dd createIPAFile:pid];

            // 更新进度：处理加密段
            updateDecryptionProgress(0.70, @"正在处理加密段...");
            [NSThread sleepForTimeInterval:0.3];

            // 更新进度：重建应用结构
            updateDecryptionProgress(0.85, @"正在重建应用结构...");
            [NSThread sleepForTimeInterval:0.2];

            // 更新进度：生成IPA文件
            updateDecryptionProgress(0.95, @"正在生成IPA文件...");
            [NSThread sleepForTimeInterval:0.3];

        }
        @catch (NSException *exception) {
            onDecryptionComplete(NO, [NSString stringWithFormat:@"解密异常: %@", exception.reason]);
            return;
        }

        // 解密成功完成
        // 构建完成消息
        NSString *message = @"解密完成！是否要启动文件服务器以便通过NetCat获取IPA文件？\n\n可用地址:\n";
        NSDictionary *addresses = [dd getIPAddresses];

        id key;
        NSString *ip;
        for(key in addresses) {
            ip = [addresses objectForKey:key];
            message = [NSString stringWithFormat:@"%@%@:31336\n", message, ip];
        }
        message = [NSString stringWithFormat:@"%@\n使用示例:\nnc %@:31336 > /tmp/decrypted.ipa", message, ip];

        // 调用完成回调
        onDecryptionComplete(YES, message);

    }); // dispatch in background
}

@interface AppDecryptionViewController () <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate, InjectionOptionsViewDelegate, InjectionProgressViewDelegate>
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) UITableView *processTableView;
@property (nonatomic, strong) UITableView *filesTableView;
@property (nonatomic, strong) UITableView *extractedTableView;
@property (nonatomic, strong) NSArray *runningProcesses;
@property (nonatomic, strong) NSArray *decryptedFiles;
@property (nonatomic, strong) NSArray *extractedFiles;
@property (nonatomic, strong) UIRefreshControl *processRefreshControl;
@property (nonatomic, strong) UIRefreshControl *filesRefreshControl;
@property (nonatomic, strong) UIRefreshControl *extractedRefreshControl;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) NSIndexPath *selectedProcessIndexPath;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *decryptButton;
@property (nonatomic, strong) InjectionOptionsView *currentOptionsView;
@property (nonatomic, strong) InjectionProgressView *currentProgressView;
@property (nonatomic, strong) DecryptedFileModel *currentFileModel;
@property (nonatomic, strong) NSString *currentDylibPath;
@property (nonatomic, strong) NSDictionary *appInfoCache; // 缓存应用信息

// 解密进度相关属性
@property (nonatomic, strong) UIView *progressContainerView;
@property (nonatomic, strong) UIView *progressBackgroundView;
@property (nonatomic, strong) UILabel *progressTitleLabel;
@property (nonatomic, strong) UILabel *progressStatusLabel;
@property (nonatomic, strong) UIProgressView *progressBar;
@property (nonatomic, strong) UILabel *progressPercentLabel;

@property (nonatomic, strong) UIButton *progressCancelButton;
@property (nonatomic, strong) UIImageView *progressIconView;
@property (nonatomic, assign) BOOL isDecrypting;

// 全局引用，用于在C函数中访问
@property (nonatomic, weak) AppDecryptionViewController *currentDecryptionController;

@end

@implementation AppDecryptionViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"App解密";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    // 设置导航栏
    [self setupNavigationBar];

    [self setupUI];
    [self setupProgressView];
    [self setupConstraints];
    [self fetchRunningProcesses];
    // 暂时注释掉loadDecryptedFiles
    // [self loadDecryptedFiles];

    // 监听应用选择通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(processSelectedNotification:)
                                                 name:@"ProcessManagerSelectedProcessChangedNotification"
                                               object:nil];

    // 注册应用进入前台的通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // 确保导航栏可见
    self.navigationController.navigationBar.hidden = NO;
}

// 每次视图出现时都刷新应用列表
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // 确保导航栏可见
    self.navigationController.navigationBar.hidden = NO;

    // 每次视图出现时刷新应用列表
    [self fetchRunningProcesses];
}

// 应用从后台回到前台时调用
- (void)appWillEnterForeground {
    // 应用回到前台时刷新应用列表
    [self fetchRunningProcesses];
}

- (void)setupNavigationBar {
    // 确保导航栏可见
    self.navigationController.navigationBar.hidden = NO;

    // 设置导航栏样式
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithDefaultBackground];

        // 适配深色/浅色模式
        appearance.backgroundColor = [UIColor systemBackgroundColor];
        appearance.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor labelColor]};

        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
        self.navigationController.navigationBar.tintColor = [UIColor systemBlueColor];
    } else {
        self.navigationController.navigationBar.barTintColor = [UIColor whiteColor];
        self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor blackColor]};
        self.navigationController.navigationBar.tintColor = [UIColor blueColor];
    }
}

- (void)setupProgressView {
    // 创建进度容器视图（全屏遮罩）
    self.progressContainerView = [[UIView alloc] init];
    self.progressContainerView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    self.progressContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressContainerView.hidden = YES;
    [self.view addSubview:self.progressContainerView];

    // 创建进度背景视图（卡片样式）
    self.progressBackgroundView = [[UIView alloc] init];
    self.progressBackgroundView.backgroundColor = [UIColor systemBackgroundColor];
    self.progressBackgroundView.layer.cornerRadius = 16;
    self.progressBackgroundView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.progressBackgroundView.layer.shadowOffset = CGSizeMake(0, 4);
    self.progressBackgroundView.layer.shadowRadius = 12;
    self.progressBackgroundView.layer.shadowOpacity = 0.15;
    // 添加边框
    self.progressBackgroundView.layer.borderWidth = 0.5;
    self.progressBackgroundView.layer.borderColor = [[UIColor separatorColor] colorWithAlphaComponent:0.3].CGColor;
    self.progressBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.progressContainerView addSubview:self.progressBackgroundView];

    // 创建进度图标
    self.progressIconView = [[UIImageView alloc] init];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:32 weight:UIImageSymbolWeightMedium];
        self.progressIconView.image = [UIImage systemImageNamed:@"lock.open.fill" withConfiguration:config];
    } else {
        self.progressIconView.image = [UIImage imageNamed:@"lock.open.fill"];
    }
    self.progressIconView.tintColor = [UIColor systemBlueColor];
    self.progressIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.progressIconView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.progressBackgroundView addSubview:self.progressIconView];

    // 创建进度标题
    self.progressTitleLabel = [[UILabel alloc] init];
    self.progressTitleLabel.text = @"正在解密应用";
    self.progressTitleLabel.font = [UIFont boldSystemFontOfSize:20];
    self.progressTitleLabel.textColor = [UIColor labelColor];
    self.progressTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.progressTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.progressBackgroundView addSubview:self.progressTitleLabel];

    // 创建进度状态标签
    self.progressStatusLabel = [[UILabel alloc] init];
    self.progressStatusLabel.text = @"正在初始化解密进程...";
    self.progressStatusLabel.font = [UIFont systemFontOfSize:16];
    self.progressStatusLabel.textColor = [UIColor secondaryLabelColor];
    self.progressStatusLabel.textAlignment = NSTextAlignmentCenter;
    self.progressStatusLabel.numberOfLines = 0;
    self.progressStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.progressBackgroundView addSubview:self.progressStatusLabel];

    // 创建进度条
    self.progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressBar.progressTintColor = [UIColor systemBlueColor];
    self.progressBar.trackTintColor = [[UIColor systemGray5Color] colorWithAlphaComponent:0.8];
    self.progressBar.layer.cornerRadius = 3;
    self.progressBar.clipsToBounds = YES;
    self.progressBar.transform = CGAffineTransformMakeScale(1.0, 2.5); // 适中的高度
    self.progressBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.progressBackgroundView addSubview:self.progressBar];

    // 创建进度百分比标签
    self.progressPercentLabel = [[UILabel alloc] init];
    self.progressPercentLabel.text = @"0%";
    self.progressPercentLabel.font = [UIFont monospacedDigitSystemFontOfSize:18 weight:UIFontWeightMedium];
    self.progressPercentLabel.textColor = [UIColor systemBlueColor];
    self.progressPercentLabel.textAlignment = NSTextAlignmentCenter;
    self.progressPercentLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.progressBackgroundView addSubview:self.progressPercentLabel];



    // 创建取消按钮
    self.progressCancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.progressCancelButton setTitle:@"取消" forState:UIControlStateNormal];
    self.progressCancelButton.titleLabel.font = [UIFont systemFontOfSize:15];
    [self.progressCancelButton setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
    self.progressCancelButton.backgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.08];
    self.progressCancelButton.layer.cornerRadius = 6;
    self.progressCancelButton.layer.borderWidth = 0.5;
    self.progressCancelButton.layer.borderColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.2].CGColor;
    self.progressCancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.progressCancelButton addTarget:self action:@selector(cancelDecryption) forControlEvents:UIControlEventTouchUpInside];
    [self.progressBackgroundView addSubview:self.progressCancelButton];

    // 设置进度视图约束
    [NSLayoutConstraint activateConstraints:@[
        // 容器视图约束
        [self.progressContainerView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.progressContainerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.progressContainerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.progressContainerView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        // 背景视图约束
        [self.progressBackgroundView.centerXAnchor constraintEqualToAnchor:self.progressContainerView.centerXAnchor],
        [self.progressBackgroundView.centerYAnchor constraintEqualToAnchor:self.progressContainerView.centerYAnchor],
        [self.progressBackgroundView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.progressContainerView.leadingAnchor constant:32],
        [self.progressBackgroundView.trailingAnchor constraintLessThanOrEqualToAnchor:self.progressContainerView.trailingAnchor constant:-32],
        [self.progressBackgroundView.widthAnchor constraintEqualToConstant:280],
        [self.progressBackgroundView.heightAnchor constraintEqualToConstant:220],

        // 图标约束
        [self.progressIconView.topAnchor constraintEqualToAnchor:self.progressBackgroundView.topAnchor constant:24],
        [self.progressIconView.centerXAnchor constraintEqualToAnchor:self.progressBackgroundView.centerXAnchor],
        [self.progressIconView.widthAnchor constraintEqualToConstant:40],
        [self.progressIconView.heightAnchor constraintEqualToConstant:40],

        // 标题约束
        [self.progressTitleLabel.topAnchor constraintEqualToAnchor:self.progressIconView.bottomAnchor constant:12],
        [self.progressTitleLabel.leadingAnchor constraintEqualToAnchor:self.progressBackgroundView.leadingAnchor constant:20],
        [self.progressTitleLabel.trailingAnchor constraintEqualToAnchor:self.progressBackgroundView.trailingAnchor constant:-20],

        // 状态标签约束
        [self.progressStatusLabel.topAnchor constraintEqualToAnchor:self.progressTitleLabel.bottomAnchor constant:8],
        [self.progressStatusLabel.leadingAnchor constraintEqualToAnchor:self.progressBackgroundView.leadingAnchor constant:20],
        [self.progressStatusLabel.trailingAnchor constraintEqualToAnchor:self.progressBackgroundView.trailingAnchor constant:-20],

        // 进度条约束
        [self.progressBar.topAnchor constraintEqualToAnchor:self.progressStatusLabel.bottomAnchor constant:16],
        [self.progressBar.leadingAnchor constraintEqualToAnchor:self.progressBackgroundView.leadingAnchor constant:24],
        [self.progressBar.trailingAnchor constraintEqualToAnchor:self.progressBackgroundView.trailingAnchor constant:-24],

        // 百分比标签约束（隐藏但保留约束）
        [self.progressPercentLabel.topAnchor constraintEqualToAnchor:self.progressBar.bottomAnchor constant:0],
        [self.progressPercentLabel.centerXAnchor constraintEqualToAnchor:self.progressBackgroundView.centerXAnchor],
        [self.progressPercentLabel.heightAnchor constraintEqualToConstant:0],

        // 取消按钮约束
        [self.progressCancelButton.topAnchor constraintEqualToAnchor:self.progressBar.bottomAnchor constant:20],
        [self.progressCancelButton.centerXAnchor constraintEqualToAnchor:self.progressBackgroundView.centerXAnchor],
        [self.progressCancelButton.widthAnchor constraintEqualToConstant:80],
        [self.progressCancelButton.heightAnchor constraintEqualToConstant:32]
    ]];
}

- (void)setupUI {
    // 创建分段控制器
    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"选择应用", @"解密文件", @"解压文件"]];
    self.segmentedControl.selectedSegmentIndex = 0;
    self.segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.segmentedControl];

    // 状态标签
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"请选择要解密的应用";
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.textColor = [UIColor secondaryLabelColor];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusLabel];

    // 解密按钮
    self.decryptButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.decryptButton setTitle:@"开始解密" forState:UIControlStateNormal];
    self.decryptButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.decryptButton.backgroundColor = [UIColor systemBlueColor];
    [self.decryptButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.decryptButton.layer.cornerRadius = 8;
    self.decryptButton.enabled = NO;
    self.decryptButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.decryptButton addTarget:self action:@selector(decryptButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.decryptButton];

    // 应用表格视图
    self.processTableView = [[UITableView alloc] init];
    self.processTableView.delegate = self;
    self.processTableView.dataSource = self;
    self.processTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.processTableView.rowHeight = 80; // 增加行高以适应新设计
    self.processTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.processTableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    [self.view addSubview:self.processTableView];

    // 应用刷新控制器
    self.processRefreshControl = [[UIRefreshControl alloc] init];
    [self.processRefreshControl addTarget:self action:@selector(refreshProcesses:) forControlEvents:UIControlEventValueChanged];
    [self.processTableView addSubview:self.processRefreshControl];

    // 文件表格视图
    self.filesTableView = [[UITableView alloc] init];
    self.filesTableView.delegate = self;
    self.filesTableView.dataSource = self;
    self.filesTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.filesTableView.hidden = YES;
    [self.view addSubview:self.filesTableView];

    // 文件刷新控制器
    self.filesRefreshControl = [[UIRefreshControl alloc] init];
    [self.filesRefreshControl addTarget:self action:@selector(refreshFiles:) forControlEvents:UIControlEventValueChanged];
    [self.filesTableView addSubview:self.filesRefreshControl];

    // 解压文件表格视图
    self.extractedTableView = [[UITableView alloc] init];
    self.extractedTableView.delegate = self;
    self.extractedTableView.dataSource = self;
    self.extractedTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.extractedTableView.hidden = YES;
    [self.view addSubview:self.extractedTableView];

    // 解压文件刷新控制器
    self.extractedRefreshControl = [[UIRefreshControl alloc] init];
    [self.extractedRefreshControl addTarget:self action:@selector(refreshExtractedFiles:) forControlEvents:UIControlEventValueChanged];
    [self.extractedTableView addSubview:self.extractedRefreshControl];

    // 加载指示器
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.loadingIndicator];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // 分段控制器约束
        [self.segmentedControl.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10],
        [self.segmentedControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.segmentedControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        // 状态标签约束
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.segmentedControl.bottomAnchor constant:10],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        // 解密按钮约束
        [self.decryptButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20],
        [self.decryptButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.decryptButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.decryptButton.heightAnchor constraintEqualToConstant:50],

        // 应用表格视图约束
        [self.processTableView.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:10],
        [self.processTableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.processTableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.processTableView.bottomAnchor constraintEqualToAnchor:self.decryptButton.topAnchor constant:-20],

        // 文件表格视图约束
        [self.filesTableView.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:10],
        [self.filesTableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.filesTableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.filesTableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],

        // 解压文件表格视图约束
        [self.extractedTableView.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:10],
        [self.extractedTableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.extractedTableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.extractedTableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],

        // 加载指示器约束
        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    if (sender.selectedSegmentIndex == 0) {
        // 显示应用选择界面
        self.processTableView.hidden = NO;
        self.filesTableView.hidden = YES;
        self.extractedTableView.hidden = YES;
        self.decryptButton.hidden = NO;
        self.statusLabel.text = @"请选择要解密的应用";
        [self updateDecryptButtonState];
        // 切换到应用选择时刷新应用列表
        [self fetchRunningProcesses];
    } else if (sender.selectedSegmentIndex == 1) {
        // 显示解密文件界面
        self.processTableView.hidden = YES;
        self.filesTableView.hidden = NO;
        self.extractedTableView.hidden = YES;
        self.decryptButton.hidden = YES;
        self.statusLabel.text = [NSString stringWithFormat:@"共 %lu 个解密文件", (unsigned long)self.decryptedFiles.count];
        [self loadDecryptedFiles];
    } else {
        // 显示解压文件界面
        self.processTableView.hidden = YES;
        self.filesTableView.hidden = YES;
        self.extractedTableView.hidden = NO;
        self.decryptButton.hidden = YES;
        self.statusLabel.text = [NSString stringWithFormat:@"共 %lu 个解压文件", (unsigned long)self.extractedFiles.count];
        [self loadExtractedFiles];
    }
}

- (void)refreshProcesses:(UIRefreshControl *)sender {
    [self fetchRunningProcesses];
}

- (void)refreshFiles:(UIRefreshControl *)sender {
    [self loadDecryptedFiles];
}

- (void)refreshExtractedFiles:(UIRefreshControl *)sender {
    [self loadExtractedFiles];
}

- (void)fetchRunningProcesses {
    // 不显示加载指示器，静默刷新
    // [self.loadingIndicator startAnimating];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self buildAppInfoCache];
        @try {
            NSTask *task = [NSTask new];
            [task setLaunchPath:@"/bin/ps"];
            [task setArguments:@[@"aux"]];

            NSPipe *pipe = [NSPipe pipe];
            NSPipe *errorPipe = [NSPipe pipe];
            [task setStandardOutput:pipe];
            [task setStandardError:errorPipe];

            [task launch];

            NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
            [[errorPipe fileHandleForReading] readDataToEndOfFile];
            [task waitUntilExit];

            if (task.terminationStatus != 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.processRefreshControl endRefreshing];
                    // [self.loadingIndicator stopAnimating];
                });
                return;
            }

            NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (!string || string.length == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.processRefreshControl endRefreshing];
                    // [self.loadingIndicator stopAnimating];
                });
                return;
            }

            NSArray *processGroups = [self modelArray:string];
            NSMutableArray *userProcesses = [processGroups.firstObject mutableCopy];

            if (!userProcesses || userProcesses.count == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.processRefreshControl endRefreshing];
                    // [self.loadingIndicator stopAnimating];
                });
                return;
            }

            [userProcesses sortUsingComparator:^NSComparisonResult(PidModel *obj1, PidModel *obj2) {
                return [@(obj2.pidValue) compare:@(obj1.pidValue)];
            }];

            dispatch_async(dispatch_get_main_queue(), ^{
                self.runningProcesses = [userProcesses copy];
                [self.processTableView reloadData];
                [self.processRefreshControl endRefreshing];
                // [self.loadingIndicator stopAnimating];
            });
        } @catch (NSException *exception) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.processRefreshControl endRefreshing];
                // [self.loadingIndicator stopAnimating];
            });
        }
    });
}

// 构建应用信息缓存
- (void)buildAppInfoCache {
    @try {
        NSMutableDictionary *cache = [NSMutableDictionary dictionary];

        // 使用运行时调用LSApplicationWorkspace
        Class LSApplicationWorkspaceClass = NSClassFromString(@"LSApplicationWorkspace");
        if (!LSApplicationWorkspaceClass) {
            self.appInfoCache = @{};
            return;
        }

        id workspace = [LSApplicationWorkspaceClass performSelector:@selector(defaultWorkspace)];
        if (!workspace) {
            self.appInfoCache = @{};
            return;
        }

        NSArray *allApps = [workspace performSelector:@selector(allApplications)];
        if (!allApps) {
            self.appInfoCache = @{};
            return;
        }

        for (id proxy in allApps) {
            @try {
                NSString *bundleIdentifier = [proxy performSelector:@selector(applicationIdentifier)];
                NSString *localizedName = [proxy performSelector:@selector(localizedName)];
                NSURL *bundleURL = [proxy performSelector:@selector(bundleURL)];

                if (bundleIdentifier && localizedName && bundleURL) {
                    // 使用应用名称作为key
                    cache[localizedName] = bundleIdentifier;

                    // 也使用bundle路径的最后一个组件作为key（去掉.app扩展名）
                    NSString *bundleName = [[bundleURL lastPathComponent] stringByDeletingPathExtension];
                    if (bundleName && ![bundleName isEqualToString:localizedName]) {
                        cache[bundleName] = bundleIdentifier;
                    }
                }
            } @catch (NSException *exception) {
                // 忽略单个应用的异常，继续处理其他应用
            }
        }

        self.appInfoCache = [cache copy];
    } @catch (NSException *exception) {
        self.appInfoCache = @{};
    }
}

- (NSArray *)modelArray:(NSString *)string {
    NSArray *arr = [string componentsSeparatedByString:@"\n"];

    NSMutableArray *marr = @[].mutableCopy;
    NSMutableArray *marr1 = @[].mutableCopy;
    NSString *pre = @" /var/containers/Bundle/Application/";
    NSString *pre1 = @" /Applications/";

    for (NSString *s in arr) {
        if ([s containsString:pre]) {
            [marr addObject:s];
        } else if ([s containsString:pre1]) {
            [marr1 addObject:s];
        }
    }

    NSArray *arr1 = [self getModel:marr pre:pre];
    NSArray *arr2 = [self getModel:marr1 pre:pre1];

    return @[arr1, arr2];
}

- (NSArray *)getModel:(NSArray *)marr pre:(NSString *)pre {
    NSMutableArray *result = @[].mutableCopy;

    for (NSString *s in marr) {
        NSArray *arr = [s componentsSeparatedByString:pre];

        if (arr.count < 2) continue;

        NSMutableArray *strs = [arr[0] componentsSeparatedByString:@" "].mutableCopy;
        [strs removeObject:@""];

        if (strs.count < 2) continue;

        NSString *name = [[arr[1] componentsSeparatedByString:@".app/"] lastObject];

        if ([name containsString:@"/"]) {
            continue;
        }

        NSString *appPath = arr[1];
        NSString *bundleIdentifier = [self getBundleIdentifierFromPath:appPath];

        PidModel *model = [[PidModel alloc] init];
        model.name = name;
        model.pid = strs[1];
        model.pidValue = [strs[1] integerValue];
        model.bundleIdentifier = bundleIdentifier;

        [self loadIconForModel:model];

        [result addObject:model];
    }

    return result;
}

- (NSString *)getBundleIdentifierFromPath:(NSString *)appPath {
    NSString *appName = [[appPath lastPathComponent] stringByDeletingPathExtension];

    NSString *bundleIdentifier = self.appInfoCache[appName];
    if (bundleIdentifier) {
        return bundleIdentifier;
    }

    NSString *infoPlistPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
    bundleIdentifier = infoPlist[@"CFBundleIdentifier"];

    return bundleIdentifier;
}

- (void)loadIconForModel:(PidModel *)model {
    if (!model.bundleIdentifier) {
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *icon = [UIImage _applicationIconImageForBundleIdentifier:model.bundleIdentifier
                                                                   format:0
                                                                    scale:[UIScreen mainScreen].scale];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (icon) {
                model.appIcon = icon;
                [self refreshCellForModel:model];
            }
        });
    });
}

- (void)refreshCellForModel:(PidModel *)model {
    NSInteger index = [self.runningProcesses indexOfObject:model];
    if (index != NSNotFound) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
        // 由于我们每次都重新创建cell内容，直接重新加载这个cell
        [self.processTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (void)loadDecryptedFiles {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *decryptedDir = [documentsPath stringByAppendingPathComponent:@"解密文件"];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error;
        NSArray *files = [fileManager contentsOfDirectoryAtPath:decryptedDir error:&error];

        NSMutableArray *fileModels = [NSMutableArray array];

        for (NSString *fileName in files) {
            if ([fileName.pathExtension isEqualToString:@"ipa"]) {
                NSString *filePath = [decryptedDir stringByAppendingPathComponent:fileName];
                NSDictionary *attributes = [fileManager attributesOfItemAtPath:filePath error:nil];

                DecryptedFileModel *fileModel = [[DecryptedFileModel alloc] init];
                fileModel.fileName = fileName;
                fileModel.filePath = filePath;
                fileModel.createDate = attributes[NSFileCreationDate];
                fileModel.fileSize = [attributes[NSFileSize] longLongValue];

                [fileModels addObject:fileModel];
            }
        }

        // 按创建时间排序，最新的在前面
        [fileModels sortUsingComparator:^NSComparisonResult(DecryptedFileModel *obj1, DecryptedFileModel *obj2) {
            return [obj2.createDate compare:obj1.createDate];
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.decryptedFiles = [fileModels copy];
            [self.filesTableView reloadData];
            [self.filesRefreshControl endRefreshing];
            self.statusLabel.text = [NSString stringWithFormat:@"共 %lu 个解密文件", (unsigned long)self.decryptedFiles.count];
        });
    });
}

- (void)loadExtractedFiles {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *extractedDir = [documentsPath stringByAppendingPathComponent:@"解压文件"];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error;
        NSArray *folders = [fileManager contentsOfDirectoryAtPath:extractedDir error:&error];

        NSMutableArray *folderModels = [NSMutableArray array];

        for (NSString *folderName in folders) {
            NSString *folderPath = [extractedDir stringByAppendingPathComponent:folderName];
            BOOL isDirectory;
            if ([fileManager fileExistsAtPath:folderPath isDirectory:&isDirectory] && isDirectory) {
                NSDictionary *attributes = [fileManager attributesOfItemAtPath:folderPath error:nil];

                ExtractedFileModel *folderModel = [[ExtractedFileModel alloc] init];
                folderModel.folderName = folderName;
                folderModel.folderPath = folderPath;
                folderModel.createDate = attributes[NSFileCreationDate];

                // 同步计算文件夹大小和文件数量
                NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtPath:folderPath];
                long long totalSize = 0;
                NSInteger fileCount = 0;

                for (NSString *fileName in enumerator) {
                    NSString *filePath = [folderPath stringByAppendingPathComponent:fileName];
                    NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:filePath error:nil];

                    if (![fileAttributes[NSFileType] isEqualToString:NSFileTypeDirectory]) {
                        totalSize += [fileAttributes[NSFileSize] longLongValue];
                        fileCount++;
                    }
                }

                folderModel.folderSize = totalSize;
                folderModel.fileCount = fileCount;

                [folderModels addObject:folderModel];
            }
        }

        // 按创建时间排序，最新的在前面
        [folderModels sortUsingComparator:^NSComparisonResult(ExtractedFileModel *obj1, ExtractedFileModel *obj2) {
            return [obj2.createDate compare:obj1.createDate];
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.extractedFiles = [folderModels copy];
            [self.extractedTableView reloadData];
            [self.extractedRefreshControl endRefreshing];
            self.statusLabel.text = [NSString stringWithFormat:@"共 %lu 个解压文件", (unsigned long)self.extractedFiles.count];
        });
    });
}

- (void)processSelectedNotification:(NSNotification *)notification {
    [self updateDecryptButtonState];
}

- (void)updateDecryptButtonState {
    NSString *selectedPID = [ProcessManager sharedManager].selectedProcessPID;
    NSString *selectedName = [ProcessManager sharedManager].selectedProcessName;

    if (selectedPID && selectedName) {
        self.decryptButton.enabled = YES;
        self.statusLabel.text = [NSString stringWithFormat:@"已选择: %@ (PID: %@)", selectedName, selectedPID];
    } else {
        self.decryptButton.enabled = NO;
        self.statusLabel.text = @"请选择要解密的应用";
    }
}

- (void)decryptButtonPressed:(UIButton *)sender {
    pid_t selectedPid = [[ProcessManager sharedManager] selectedPid];

    if (selectedPid == 0) {
        [self showAlert:@"错误" message:@"请先选择要解密的应用"];
        return;
    }

    [self startDecryption:selectedPid];
}

- (void)startDecryption:(pid_t)pid {
    // 先测试 task_for_pid 权限
    vm_map_t testTask = 0;
    kern_return_t kr = task_for_pid(mach_task_self(), pid, &testTask);
    if (kr != KERN_SUCCESS) {
        [self showAlert:@"权限错误" message:[NSString stringWithFormat:@"无法获取应用权限，错误代码: %d\n请确保应用有正确的权限配置", kr]];
        return;
    }

    // 显示进度界面
    [self showProgressView];

    // 开始解密进程
    [self performDecryptionWithPid:pid];
}

#pragma mark - 进度控制方法

- (void)showProgressView {
    self.isDecrypting = YES;
    self.progressContainerView.hidden = NO;
    self.progressContainerView.alpha = 0;

    // 重置进度状态
    [self.progressBar setProgress:0.0 animated:NO];
    self.progressPercentLabel.text = @""; // 隐藏百分比显示
    self.progressStatusLabel.text = @"正在初始化解密进程...";

    // 动画显示
    [UIView animateWithDuration:0.3 animations:^{
        self.progressContainerView.alpha = 1.0;
    }];

    // 不再需要模拟进度，真实进度会通过解密过程更新
}

- (void)hideProgressView {
    self.isDecrypting = NO;

    [UIView animateWithDuration:0.3 animations:^{
        self.progressContainerView.alpha = 0;
    } completion:^(BOOL finished) {
        self.progressContainerView.hidden = YES;
    }];
}

- (void)updateProgress:(float)progress status:(NSString *)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.progressBar setProgress:progress animated:YES];
        // 隐藏百分比显示
        self.progressPercentLabel.text = @"";
        self.progressStatusLabel.text = status;

        // 添加进度条动画效果
        [UIView animateWithDuration:0.2 animations:^{
            self.progressBar.transform = CGAffineTransformMakeScale(1.02, 3.2);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.2 animations:^{
                self.progressBar.transform = CGAffineTransformMakeScale(1.0, 3.0);
            }];
        }];
    });
}

- (void)startProgressAnimation {
    // 模拟解密进度
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 阶段1: 初始化 (0-10%)
        [self updateProgress:0.05 status:@"正在验证应用权限..."];
        [NSThread sleepForTimeInterval:0.5];

        [self updateProgress:0.10 status:@"正在获取应用路径..."];
        [NSThread sleepForTimeInterval:0.3];

        // 阶段2: 准备解密 (10-30%)
        [self updateProgress:0.15 status:@"正在创建解密实例..."];
        [NSThread sleepForTimeInterval:0.4];

        [self updateProgress:0.25 status:@"正在分析应用结构..."];
        [NSThread sleepForTimeInterval:0.6];

        [self updateProgress:0.30 status:@"正在准备解密环境..."];
        [NSThread sleepForTimeInterval:0.3];

        // 阶段3: 执行解密 (30-90%)
        [self updateProgress:0.40 status:@"正在解密应用二进制文件..."];
        [NSThread sleepForTimeInterval:0.8];

        [self updateProgress:0.55 status:@"正在处理加密段..."];
        [NSThread sleepForTimeInterval:1.0];

        [self updateProgress:0.70 status:@"正在重建应用结构..."];
        [NSThread sleepForTimeInterval:0.7];

        [self updateProgress:0.85 status:@"正在生成IPA文件..."];
        [NSThread sleepForTimeInterval:0.5];

        // 阶段4: 准备完成 (90-95%)
        [self updateProgress:0.95 status:@"正在验证解密结果..."];
        [NSThread sleepForTimeInterval:0.3];

        // 不在这里设置完成状态，等待实际解密完成回调
    });
}

- (void)cancelDecryption {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"取消解密"
                                                                   message:@"确定要取消当前的解密进程吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"继续解密"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确定取消"
                                                            style:UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction *action) {
        [self hideProgressView];
        // 这里可以添加实际的取消解密逻辑
    }];

    [alert addAction:cancelAction];
    [alert addAction:confirmAction];
    [self presentViewController:alert animated:YES completion:nil];
}



- (void)performDecryptionWithPid:(pid_t)pid {
    // 设置全局控制器引用
    currentDecryptionController = self;

    // 开始进度动画
    [self startProgressAnimation];

    // 在后台线程调用解密函数
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        bfinject_rocknroll(pid);
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.processTableView) {
        return self.runningProcesses.count;
    } else if (tableView == self.filesTableView) {
        return self.decryptedFiles.count;
    } else {
        return self.extractedFiles.count;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.processTableView) {
        return [self processTableView:tableView cellForRowAtIndexPath:indexPath];
    } else if (tableView == self.filesTableView) {
        return [self filesTableView:tableView cellForRowAtIndexPath:indexPath];
    } else {
        return [self extractedTableView:tableView cellForRowAtIndexPath:indexPath];
    }
}

- (UITableViewCell *)processTableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"AppCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        // 设置cell的基本属性，这些只需要设置一次
        cell.backgroundColor = [UIColor clearColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }

    // 清理之前的内容（为了重用）
    [cell.contentView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

    // 创建自定义容器视图
    UIView *containerView = [[UIView alloc] init];
    containerView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    containerView.layer.cornerRadius = 16;
    containerView.layer.shadowColor = [UIColor blackColor].CGColor;
    containerView.layer.shadowOffset = CGSizeMake(0, 2);
    containerView.layer.shadowRadius = 4;
    containerView.layer.shadowOpacity = 0.1;
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:containerView];

    // 约束容器视图
    [NSLayoutConstraint activateConstraints:@[
        [containerView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:6],
        [containerView.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-6],
        [containerView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [containerView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16]
    ]];

    PidModel *process = self.runningProcesses[indexPath.row];

    // 创建应用图标
    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.tag = 1000; // 设置tag以便后续更新
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.layer.cornerRadius = 8;
    iconView.layer.masksToBounds = YES;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;

    // 设置默认图标或真实图标
    if (process.appIcon) {
        iconView.image = process.appIcon;
    } else {
        // 使用默认的应用图标
        if (@available(iOS 13.0, *)) {
            iconView.image = [UIImage systemImageNamed:@"app.fill"];
            iconView.tintColor = [UIColor systemBlueColor];
        } else {
            iconView.backgroundColor = [UIColor systemBlueColor];
        }
    }

    // 创建标签
    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.text = process.name;
    nameLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    nameLabel.textColor = [UIColor labelColor];
    nameLabel.numberOfLines = 1;
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *pidLabel = [[UILabel alloc] init];
    pidLabel.text = [NSString stringWithFormat:@"PID: %@", process.pid];
    pidLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    pidLabel.textColor = [UIColor secondaryLabelColor];
    pidLabel.translatesAutoresizingMaskIntoConstraints = NO;

    // 添加所有视图到容器
    [containerView addSubview:iconView];
    [containerView addSubview:nameLabel];
    [containerView addSubview:pidLabel];

    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        // 图标约束
        [iconView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:16],
        [iconView.centerYAnchor constraintEqualToAnchor:containerView.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:40],
        [iconView.heightAnchor constraintEqualToConstant:40],

        // 应用名称标签约束
        [nameLabel.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:16],
        [nameLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:12],
        [nameLabel.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-60], // 为选中标记留空间

        // PID标签约束
        [pidLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:4],
        [pidLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:12],
        [pidLabel.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-60],
        [pidLabel.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor constant:-16]
    ]];

    // 设置选中状态
    NSString *selectedPID = [ProcessManager sharedManager].selectedProcessPID;
    BOOL isSelected = [process.pid isEqualToString:selectedPID];
    [self updateCellSelectionState:cell isSelected:isSelected];

    return cell;
}

- (void)updateCellSelectionState:(UITableViewCell *)cell isSelected:(BOOL)isSelected {
    // 找到容器视图
    UIView *containerView = nil;
    for (UIView *subview in cell.contentView.subviews) {
        if ([subview isKindOfClass:[UIView class]] && subview.layer.cornerRadius > 0) {
            containerView = subview;
            break;
        }
    }

    if (!containerView) return;

    // 移除之前可能存在的选中标记
    UIView *existingCheckmarkView = [containerView viewWithTag:1001];
    [existingCheckmarkView removeFromSuperview];

    if (isSelected) {
        // 创建选中标记 - 放在右侧中央
        UIImageView *checkmarkView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.circle.fill"]];
        checkmarkView.tag = 1001;
        checkmarkView.tintColor = [UIColor systemBlueColor];
        checkmarkView.translatesAutoresizingMaskIntoConstraints = NO;
        [containerView addSubview:checkmarkView];

        // 约束选中标记 - 放在右侧中央
        [NSLayoutConstraint activateConstraints:@[
            [checkmarkView.centerYAnchor constraintEqualToAnchor:containerView.centerYAnchor],
            [checkmarkView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-16],
            [checkmarkView.widthAnchor constraintEqualToConstant:24],
            [checkmarkView.heightAnchor constraintEqualToConstant:24]
        ]];

        // 高亮容器 - 使用蓝色主题
        [UIView animateWithDuration:0.2 animations:^{
            containerView.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.1];
            containerView.layer.borderWidth = 1.5;
            containerView.layer.borderColor = [UIColor systemBlueColor].CGColor;
        }];
    } else {
        // 恢复原始状态
        [UIView animateWithDuration:0.2 animations:^{
            containerView.backgroundColor = [UIColor secondarySystemBackgroundColor];
            containerView.layer.borderWidth = 0.0;
            containerView.layer.borderColor = [UIColor clearColor].CGColor;
        }];
    }
}

- (UITableViewCell *)filesTableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"FileCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    DecryptedFileModel *fileModel = self.decryptedFiles[indexPath.row];

    cell.textLabel.text = fileModel.fileName;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:16];

    // 格式化文件大小
    NSString *sizeString = [self formatFileSize:fileModel.fileSize];

    // 格式化创建时间
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *dateString = [formatter stringFromDate:fileModel.createDate];

    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ | %@", sizeString, dateString];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];

    // 设置图标
    if (@available(iOS 13.0, *)) {
        cell.imageView.image = [UIImage systemImageNamed:@"doc.zipper"];
        cell.imageView.tintColor = [UIColor systemOrangeColor];
    }

    return cell;
}

- (UITableViewCell *)extractedTableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"ExtractedCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    ExtractedFileModel *folderModel = self.extractedFiles[indexPath.row];

    cell.textLabel.text = folderModel.folderName;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:16];

    // 格式化创建时间
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *dateString = [formatter stringFromDate:folderModel.createDate];

    cell.detailTextLabel.text = [NSString stringWithFormat:@"解压时间: %@", dateString];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];

    // 设置图标
    if (@available(iOS 13.0, *)) {
        cell.imageView.image = [UIImage systemImageNamed:@"folder.fill"];
        cell.imageView.tintColor = [UIColor systemBlueColor];
    }

    return cell;
}

- (NSString *)formatFileSize:(long long)size {
    if (size < 1024) {
        return [NSString stringWithFormat:@"%lld B", size];
    } else if (size < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f KB", size / 1024.0];
    } else if (size < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f MB", size / (1024.0 * 1024.0)];
    } else {
        return [NSString stringWithFormat:@"%.1f GB", size / (1024.0 * 1024.0 * 1024.0)];
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (tableView == self.processTableView) {
        [self handleProcessSelection:indexPath];
    } else if (tableView == self.filesTableView) {
        [self handleFileSelection:indexPath];
    } else {
        [self handleExtractedSelection:indexPath];
    }
}

- (void)handleProcessSelection:(NSIndexPath *)indexPath {
    PidModel *selectedProcess = self.runningProcesses[indexPath.row];

    // 如果点击的是已选中的应用，则不做处理
    NSString *currentSelectedPID = [ProcessManager sharedManager].selectedProcessPID;
    if ([selectedProcess.pid isEqualToString:currentSelectedPID]) {
        return;
    }

    // 取消之前的选中
    if (self.selectedProcessIndexPath) {
        UITableViewCell *previousCell = [self.processTableView cellForRowAtIndexPath:self.selectedProcessIndexPath];
        [self updateCellSelectionState:previousCell isSelected:NO];
    }

    // 设置新的选中
    UITableViewCell *cell = [self.processTableView cellForRowAtIndexPath:indexPath];
    [self updateCellSelectionState:cell isSelected:YES];
    self.selectedProcessIndexPath = indexPath;

    // 更新ProcessManager
    [[ProcessManager sharedManager] selectProcessWithPID:selectedProcess.pid
                                              processName:selectedProcess.name];
}

- (void)handleFileSelection:(NSIndexPath *)indexPath {
    DecryptedFileModel *fileModel = self.decryptedFiles[indexPath.row];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:fileModel.fileName
                                                                   message:@"请选择操作"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    // 解压操作
    UIAlertAction *extractAction = [UIAlertAction actionWithTitle:@"解压"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * _Nonnull action) {
        [self extractFile:fileModel];
    }];

    // 注入动态库操作（仅对IPA文件显示）
    UIAlertAction *injectAction = nil;
    if ([fileModel.fileName.pathExtension.lowercaseString isEqualToString:@"ipa"]) {
        injectAction = [UIAlertAction actionWithTitle:@"注入动态库"
                                                style:UIAlertActionStyleDefault
                                              handler:^(UIAlertAction * _Nonnull action) {
            [self showInjectDylibAlert:fileModel];
        }];
    }

    // 分享操作
    UIAlertAction *shareAction = [UIAlertAction actionWithTitle:@"分享"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * _Nonnull action) {
        [self shareFile:fileModel];
    }];

    // 删除操作
    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"删除"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self deleteFile:fileModel atIndexPath:indexPath];
    }];

    // 取消操作
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [alert addAction:extractAction];
    if (injectAction) {
        [alert addAction:injectAction];
    }
    [alert addAction:shareAction];
    [alert addAction:deleteAction];
    [alert addAction:cancelAction];

    // 对于iPad，设置popover
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UITableViewCell *cell = [self.filesTableView cellForRowAtIndexPath:indexPath];
        alert.popoverPresentationController.sourceView = cell;
        alert.popoverPresentationController.sourceRect = cell.bounds;
    }

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)handleExtractedSelection:(NSIndexPath *)indexPath {
    ExtractedFileModel *folderModel = self.extractedFiles[indexPath.row];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:folderModel.folderName
                                                                   message:@"请选择操作"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    // 浏览操作
    UIAlertAction *browseAction = [UIAlertAction actionWithTitle:@"浏览文件"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self browseExtractedFolder:folderModel];
    }];

    // 删除操作
    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"删除"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self deleteExtractedFolder:folderModel atIndexPath:indexPath];
    }];

    // 取消操作
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [alert addAction:browseAction];
    [alert addAction:deleteAction];
    [alert addAction:cancelAction];

    // 对于iPad，设置popover
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UITableViewCell *cell = [self.extractedTableView cellForRowAtIndexPath:indexPath];
        alert.popoverPresentationController.sourceView = cell;
        alert.popoverPresentationController.sourceRect = cell.bounds;
    }

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)browseExtractedFolder:(ExtractedFileModel *)folderModel {
    IPAFileExplorerViewController *explorerVC = [[IPAFileExplorerViewController alloc] initWithRootPath:folderModel.folderPath fileName:folderModel.folderName];

    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:explorerVC];
    navController.modalPresentationStyle = UIModalPresentationFullScreen;

    [self presentViewController:navController animated:YES completion:nil];
}

- (void)deleteExtractedFolder:(ExtractedFileModel *)folderModel atIndexPath:(NSIndexPath *)indexPath {
    UIAlertController *confirmAlert = [UIAlertController alertControllerWithTitle:@"确认删除"
                                                                          message:[NSString stringWithFormat:@"确定要删除解压文件夹 %@ 吗？", folderModel.folderName]
                                                                   preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"删除"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self performDeleteExtractedFolder:folderModel atIndexPath:indexPath];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [confirmAlert addAction:deleteAction];
    [confirmAlert addAction:cancelAction];

    [self presentViewController:confirmAlert animated:YES completion:nil];
}

- (void)performDeleteExtractedFolder:(ExtractedFileModel *)folderModel atIndexPath:(NSIndexPath *)indexPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    BOOL success = [fileManager removeItemAtPath:folderModel.folderPath error:&error];

    if (success) {
        // 从数据源中移除
        NSMutableArray *mutableFiles = [self.extractedFiles mutableCopy];
        [mutableFiles removeObjectAtIndex:indexPath.row];
        self.extractedFiles = [mutableFiles copy];

        // 更新表格视图
        [self.extractedTableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];

        // 更新状态标签
        self.statusLabel.text = [NSString stringWithFormat:@"共 %lu 个解压文件", (unsigned long)self.extractedFiles.count];
    } else {
        [self showAlert:@"删除失败" message:error.localizedDescription];
    }
}

- (void)shareFile:(DecryptedFileModel *)fileModel {
    NSURL *fileURL = [NSURL fileURLWithPath:fileModel.filePath];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL]
                                                                             applicationActivities:nil];

    // 对于iPad，设置popover
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = self.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2,
                                                                         self.view.bounds.size.height/2,
                                                                         0, 0);
    }

    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)deleteFile:(DecryptedFileModel *)fileModel atIndexPath:(NSIndexPath *)indexPath {
    UIAlertController *confirmAlert = [UIAlertController alertControllerWithTitle:@"确认删除"
                                                                          message:[NSString stringWithFormat:@"确定要删除文件 %@ 吗？", fileModel.fileName]
                                                                   preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"删除"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction * _Nonnull action) {
        NSError *error;
        if ([[NSFileManager defaultManager] removeItemAtPath:fileModel.filePath error:&error]) {
            // 从数据源中移除
            NSMutableArray *mutableFiles = [self.decryptedFiles mutableCopy];
            [mutableFiles removeObjectAtIndex:indexPath.row];
            self.decryptedFiles = [mutableFiles copy];

            // 更新表格视图
            [self.filesTableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];

            // 更新状态标签
            self.statusLabel.text = [NSString stringWithFormat:@"共 %lu 个解密文件", (unsigned long)self.decryptedFiles.count];
        } else {
            [self showAlert:@"删除失败" message:error.localizedDescription];
        }
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [confirmAlert addAction:deleteAction];
    [confirmAlert addAction:cancelAction];

    [self presentViewController:confirmAlert animated:YES completion:nil];
}

- (void)extractFile:(DecryptedFileModel *)fileModel {
    // 检查文件是否为IPA格式
    if (![fileModel.fileName.lowercaseString hasSuffix:@".ipa"]) {
        [self showAlert:@"不支持的格式" message:@"只支持解压IPA文件"];
        return;
    }

    // 显示解压进度
    UIAlertController *progressAlert = [UIAlertController alertControllerWithTitle:@"正在解压"
                                                                           message:@"请稍候..."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:progressAlert animated:YES completion:nil];

    // 在后台线程执行解压
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *extractPath = [self extractIPAFile:fileModel];

        dispatch_async(dispatch_get_main_queue(), ^{
            [progressAlert dismissViewControllerAnimated:YES completion:^{
                if (extractPath) {
                    // 刷新解压文件列表
                    [self loadExtractedFiles];
                    // 显示解压成功提示
                    [self showAlert:@"解压成功" message:@"文件已解压完成，请到\"解压文件\"标签页查看"];
                } else {
                    [self showAlert:@"解压失败" message:@"无法解压该IPA文件"];
                }
            }];
        });
    });
}

- (NSString *)extractIPAFile:(DecryptedFileModel *)fileModel {
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *extractedDir = [documentsPath stringByAppendingPathComponent:@"解压文件"];

    // 创建解压目录
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:extractedDir]) {
        [fileManager createDirectoryAtPath:extractedDir withIntermediateDirectories:YES attributes:nil error:nil];
    }

    // 创建以文件名命名的子目录
    NSString *fileName = [fileModel.fileName stringByDeletingPathExtension];
    NSString *targetPath = [extractedDir stringByAppendingPathComponent:fileName];

    // 如果目录已存在，先删除
    if ([fileManager fileExistsAtPath:targetPath]) {
        [fileManager removeItemAtPath:targetPath error:nil];
    }

    // 使用SSZipArchive解压
    BOOL success = [SSZipArchive unzipFileAtPath:fileModel.filePath toDestination:targetPath];

    return success ? targetPath : nil;
}

- (void)showFileExplorer:(NSString *)rootPath fileName:(NSString *)fileName {
    // 创建文件浏览器视图控制器
    IPAFileExplorerViewController *explorerVC = [[IPAFileExplorerViewController alloc] initWithRootPath:rootPath fileName:fileName];

    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:explorerVC];
    navController.modalPresentationStyle = UIModalPresentationFullScreen;

    [self presentViewController:navController animated:YES completion:nil];
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - 动态库注入功能

- (void)showInjectDylibAlert:(DecryptedFileModel *)fileModel {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"动态库注入"
                                                                   message:[NSString stringWithFormat:@"为 %@ 注入动态库", fileModel.fileName]
                                                            preferredStyle:UIAlertControllerStyleAlert];

    // 选择动态库文件
    UIAlertAction *selectDylibAction = [UIAlertAction actionWithTitle:@"选择动态库文件"
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * _Nonnull action) {
        [self selectDylibFileForInjection:fileModel];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [alert addAction:selectDylibAction];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)selectDylibFileForInjection:(DecryptedFileModel *)fileModel {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[
        [UTType typeWithFilenameExtension:@"dylib"],
        [UTType typeWithFilenameExtension:@"framework"]
    ]];

    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    picker.delegate = self;

    // 保存当前处理的文件模型
    objc_setAssociatedObject(picker, @"fileModel", fileModel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [self presentViewController:picker animated:YES completion:nil];
}

- (void)showInjectionOptionsForFile:(DecryptedFileModel *)fileModel dylibPath:(NSString *)dylibPath {
    // 保存当前处理的数据
    self.currentFileModel = fileModel;
    self.currentDylibPath = dylibPath;

    // 创建并显示自定义弹窗
    self.currentOptionsView = [[InjectionOptionsView alloc] initWithFileName:fileModel.fileName dylibName:dylibPath.lastPathComponent];
    self.currentOptionsView.delegate = self;
    [self.currentOptionsView showInView:self.view];
}

#pragma mark - InjectionOptionsViewDelegate

- (void)injectionOptionsView:(InjectionOptionsView *)optionsView
           didConfirmWithType:(DylibInjectType)injectType
            frameworkLocation:(FrameworkLocationType)frameworkLocation {

    [optionsView dismiss];
    self.currentOptionsView = nil;

    // 开始注入流程
    [self performInjectionWithProgress:self.currentFileModel
                             dylibPath:self.currentDylibPath
                            injectType:injectType
                     frameworkLocation:frameworkLocation];
}

- (void)injectionOptionsViewDidCancel:(InjectionOptionsView *)optionsView {
    [optionsView dismiss];
    self.currentOptionsView = nil;
    self.currentFileModel = nil;
    self.currentDylibPath = nil;
}

- (void)performInjectionWithProgress:(DecryptedFileModel *)fileModel
                            dylibPath:(NSString *)dylibPath
                           injectType:(DylibInjectType)injectType
                    frameworkLocation:(FrameworkLocationType)frameworkLocation {

    // 创建并显示进度弹窗
    self.currentProgressView = [[InjectionProgressView alloc] init];
    self.currentProgressView.delegate = self;
    [self.currentProgressView showInView:self.view];

    // 开始注入流程
    [self startInjectionProcess:fileModel
                      dylibPath:dylibPath
                     injectType:injectType
              frameworkLocation:frameworkLocation];
}

- (void)startInjectionProcess:(DecryptedFileModel *)fileModel
                    dylibPath:(NSString *)dylibPath
                   injectType:(DylibInjectType)injectType
            frameworkLocation:(FrameworkLocationType)frameworkLocation {

    // 创建注入工具实例
    DylibInjector *injector = [[DylibInjector alloc] init];

    // 设置日志回调来更新进度
    __weak typeof(self) weakSelf = self;
    injector.logCallback = ^(NSString *message) {
        // 根据消息内容更新进度
        float progress = 0.0;
        if ([message containsString:@"开始处理"]) {
            progress = 0.1;
        } else if ([message containsString:@"解压"]) {
            progress = 0.3;
        } else if ([message containsString:@"注入"]) {
            progress = 0.6;
        } else if ([message containsString:@"重新打包"]) {
            progress = 0.8;
        } else if ([message containsString:@"完成"]) {
            progress = 1.0;
        }

        [weakSelf.currentProgressView updateProgress:progress status:message];
    };

    // 执行注入
    [injector injectDylibToIPA:fileModel.filePath
                     dylibPath:dylibPath
                    injectType:injectType
             frameworkLocation:frameworkLocation
                    completion:^(NSString * _Nullable outputPath, NSString * _Nullable error) {

        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.currentProgressView dismiss];
            weakSelf.currentProgressView = nil;

            if (outputPath) {
                // 生成简洁的文件名
                NSString *simplifiedName = [weakSelf generateSimplifiedFileName:outputPath originalName:fileModel.fileName];
                NSString *successMessage = [NSString stringWithFormat:@"动态库注入成功！\n\n输出文件: %@\n注入库: %@", simplifiedName, dylibPath.lastPathComponent];

                [weakSelf showAlert:@"注入完成" message:successMessage];

                // 刷新文件列表
                [weakSelf loadDecryptedFiles];
            } else {
                [weakSelf showAlert:@"注入失败" message:error ?: @"未知错误"];
            }
        });
    }];
}

#pragma mark - InjectionProgressViewDelegate

- (void)injectionProgressViewDidCancel:(InjectionProgressView *)progressView {
    [progressView dismiss];
    self.currentProgressView = nil;
    // 这里可以添加取消注入的逻辑，比如停止正在进行的操作
}

- (NSString *)generateSimplifiedFileName:(NSString *)outputPath originalName:(NSString *)originalName {
    // 从原始文件名中提取应用名称（去掉_decrypted后缀）
    NSString *baseName = [originalName stringByDeletingPathExtension];
    if ([baseName hasSuffix:@"_decrypted"]) {
        baseName = [baseName substringToIndex:baseName.length - 10]; // 移除"_decrypted"
    }

    // 生成简洁的文件名：AppName_injected.ipa
    NSString *simplifiedName = [NSString stringWithFormat:@"%@_injected.ipa", baseName];

    // 重命名文件
    NSString *directory = [outputPath stringByDeletingLastPathComponent];
    NSString *newPath = [directory stringByAppendingPathComponent:simplifiedName];

    NSError *error;
    if ([[NSFileManager defaultManager] moveItemAtPath:outputPath toPath:newPath error:&error]) {
        return simplifiedName;
    } else {
        NSLog(@"重命名文件失败: %@", error.localizedDescription);
        return outputPath.lastPathComponent; // 如果重命名失败，返回原始文件名
    }
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count == 0) return;

    NSURL *selectedURL = urls.firstObject;
    NSString *dylibPath = selectedURL.path;

    // 获取关联的文件模型
    DecryptedFileModel *fileModel = objc_getAssociatedObject(controller, @"fileModel");
    if (fileModel) {
        [self showInjectionOptionsForFile:fileModel dylibPath:dylibPath];
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    // 用户取消选择，不做任何操作
}

@end
