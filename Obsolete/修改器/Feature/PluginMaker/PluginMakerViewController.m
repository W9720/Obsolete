//
//  PluginMakerViewController.m
//  修改器
//
//  Created by AI Assistant on 2025-01-08.
//

#import "PluginMakerViewController.h"
#import "TheosProjectCreatorViewController.h"
#import "PluginFileManagerViewController.h"

@interface PluginMakerViewController ()

@property (nonatomic, strong) UISegmentedControl *modeControl;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) TheosProjectCreatorViewController *projectCreatorVC;
@property (nonatomic, strong) PluginFileManagerViewController *fileManagerVC;

@end

@implementation PluginMakerViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"插件制作";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    [self setupUI];
    [self setupChildViewControllers];
    [self switchToMode:0]; // 默认显示项目创建界面

    // 监听文件管理器的导航更新通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleFileManagerNavigationUpdate:)
                                                 name:@"PluginFileManagerNavigationUpdate"
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupUI {
    // 创建模式切换控件
    self.modeControl = [[UISegmentedControl alloc] initWithItems:@[@"创建项目", @"文件管理"]];
    self.modeControl.selectedSegmentIndex = 0;
    self.modeControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.modeControl addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.modeControl];
    
    // 创建容器视图
    self.containerView = [[UIView alloc] init];
    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.containerView];
    
    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        [self.modeControl.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [self.modeControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.modeControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.modeControl.heightAnchor constraintEqualToConstant:32],
        
        [self.containerView.topAnchor constraintEqualToAnchor:self.modeControl.bottomAnchor constant:16],
        [self.containerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.containerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.containerView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)setupChildViewControllers {
    // 创建项目创建控制器
    self.projectCreatorVC = [[TheosProjectCreatorViewController alloc] init];
    [self addChildViewController:self.projectCreatorVC];
    [self.containerView addSubview:self.projectCreatorVC.view];
    self.projectCreatorVC.view.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.projectCreatorVC.view.topAnchor constraintEqualToAnchor:self.containerView.topAnchor],
        [self.projectCreatorVC.view.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor],
        [self.projectCreatorVC.view.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor],
        [self.projectCreatorVC.view.bottomAnchor constraintEqualToAnchor:self.containerView.bottomAnchor]
    ]];
    [self.projectCreatorVC didMoveToParentViewController:self];
    
    // 创建文件管理控制器
    self.fileManagerVC = [[PluginFileManagerViewController alloc] init];
    [self addChildViewController:self.fileManagerVC];
    [self.containerView addSubview:self.fileManagerVC.view];
    self.fileManagerVC.view.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.fileManagerVC.view.topAnchor constraintEqualToAnchor:self.containerView.topAnchor],
        [self.fileManagerVC.view.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor],
        [self.fileManagerVC.view.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor],
        [self.fileManagerVC.view.bottomAnchor constraintEqualToAnchor:self.containerView.bottomAnchor]
    ]];
    [self.fileManagerVC didMoveToParentViewController:self];
}

- (void)modeChanged:(UISegmentedControl *)sender {
    [self switchToMode:sender.selectedSegmentIndex];

    // 切换模式时清除右侧按钮
    if (sender.selectedSegmentIndex == 0) {
        // 项目创建模式，清除返回按钮
        self.navigationItem.rightBarButtonItem = nil;
    }
}

- (void)switchToMode:(NSInteger)mode {
    // 添加切换动画
    [UIView transitionWithView:self.containerView
                      duration:0.3
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        switch (mode) {
            case 0: // 项目创建
                self.projectCreatorVC.view.hidden = NO;
                self.fileManagerVC.view.hidden = YES;
                break;
            case 1: // 文件管理
                self.projectCreatorVC.view.hidden = YES;
                self.fileManagerVC.view.hidden = NO;
                [self.fileManagerVC refreshFileList];
                break;
        }
    } completion:nil];
}

- (void)handleFileManagerNavigationUpdate:(NSNotification *)notification {
    NSDictionary *userInfo = notification.object;
    BOOL canGoBack = [userInfo[@"canGoBack"] boolValue];
    BOOL canShare = [userInfo[@"canShare"] boolValue];

    // 只在文件管理模式下显示按钮
    if (self.modeControl.selectedSegmentIndex == 1) {
        NSMutableArray *rightBarButtonItems = [NSMutableArray array];

        if (canShare) {
            // 添加分享按钮
            UIBarButtonItem *shareButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                                         target:self
                                                                                         action:@selector(shareCurrentProject)];
            [rightBarButtonItems addObject:shareButton];
        }

        if (canGoBack) {
            // 添加返回按钮
            UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:@"返回上级"
                                                                           style:UIBarButtonItemStylePlain
                                                                          target:self
                                                                          action:@selector(goBackInFileManager)];
            [rightBarButtonItems addObject:backButton];
        }

        self.navigationItem.rightBarButtonItems = rightBarButtonItems.count > 0 ? rightBarButtonItems : nil;
    } else {
        self.navigationItem.rightBarButtonItems = nil;
    }
}

- (void)goBackInFileManager {
    [self.fileManagerVC goBack];
}

- (void)shareCurrentProject {
    [self.fileManagerVC shareCurrentProject];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // 确保导航栏可见
    self.navigationController.navigationBar.hidden = NO;

    // 重新设置标题，防止消失
    self.title = @"插件制作";
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // 再次确保标题正确显示
    self.title = @"插件制作";
}

@end
