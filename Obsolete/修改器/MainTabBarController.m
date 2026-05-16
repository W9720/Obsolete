#import "MainTabBarController.h"
#import "Process/ProcessViewController.h"
#import "Search/SearchViewController.h"
#import "Record/RecordViewController.h"
#import "Feature/FeatureViewController.h"
#import "Settings/SettingsViewController.h"
#import "UpdateManager.h"

@implementation MainTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];

    // 监听功能禁用通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(allFeaturesDisabled:)
                                                 name:@"AllFeaturesDisabled"
                                               object:nil];

    // 设置现代化TabBar样式
    [self setupModernTabBarAppearance];

    ProcessViewController *processVC = [[ProcessViewController alloc] init];
    processVC.tabBarItem.title = @"进程";
    processVC.tabBarItem.image = [UIImage systemImageNamed:@"list.bullet.rectangle"];
    processVC.tabBarItem.selectedImage = [UIImage systemImageNamed:@"list.bullet.rectangle.fill"];
    UINavigationController *processNavVC = [[UINavigationController alloc] initWithRootViewController:processVC];
    processNavVC.navigationBar.hidden = YES;

    SearchViewController *searchVC = [[SearchViewController alloc] init];
    searchVC.tabBarItem.title = @"搜索";
    searchVC.tabBarItem.image = [UIImage systemImageNamed:@"magnifyingglass"];
    searchVC.tabBarItem.selectedImage = [UIImage systemImageNamed:@"magnifyingglass.circle.fill"];
    UINavigationController *searchNavVC = [[UINavigationController alloc] initWithRootViewController:searchVC];
    searchNavVC.navigationBar.hidden = YES;

    RecordViewController *recordVC = [[RecordViewController alloc] init];
    recordVC.tabBarItem.title = @"记录";
    recordVC.tabBarItem.image = [UIImage systemImageNamed:@"bookmark"];
    recordVC.tabBarItem.selectedImage = [UIImage systemImageNamed:@"bookmark.fill"];
    UINavigationController *recordNavVC = [[UINavigationController alloc] initWithRootViewController:recordVC];
    recordNavVC.navigationBar.hidden = YES;

    FeatureViewController *featureVC = [[FeatureViewController alloc] init];
    featureVC.tabBarItem.title = @"功能";
    featureVC.tabBarItem.image = [UIImage systemImageNamed:@"bolt"];
    featureVC.tabBarItem.selectedImage = [UIImage systemImageNamed:@"bolt.fill"];
    UINavigationController *featureNavVC = [[UINavigationController alloc] initWithRootViewController:featureVC];
    featureNavVC.navigationBar.hidden = YES;

    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    settingsVC.tabBarItem.title = @"设置";
    settingsVC.tabBarItem.image = [UIImage systemImageNamed:@"slider.horizontal.3"];
    settingsVC.tabBarItem.selectedImage = [UIImage systemImageNamed:@"slider.horizontal.3"];
    UINavigationController *settingsNavVC = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    settingsNavVC.navigationBar.hidden = YES;

    self.viewControllers = @[processNavVC, searchNavVC, recordNavVC, featureNavVC, settingsNavVC];
}

// 设置现代化TabBar外观
- (void)setupModernTabBarAppearance {
    if (@available(iOS 13.0, *)) {
        UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];

        // 设置背景色 - 使用更轻微的背景
        appearance.backgroundColor = [UIColor systemBackgroundColor];
        
        // 添加细微的阴影效果
        appearance.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.1];
        appearance.shadowImage = nil;

        // 设置选中状态的颜色 - 使用更鲜明的蓝色
        UIColor *accentColor = [UIColor systemBlueColor];
        appearance.selectionIndicatorTintColor = accentColor;

        // 设置正常状态的图标和文字颜色 - 使用更淡的灰色
        UIColor *normalColor = [UIColor systemGray3Color];
        appearance.stackedLayoutAppearance.normal.iconColor = normalColor;
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = @{
            NSForegroundColorAttributeName: normalColor,
            NSFontAttributeName: [UIFont systemFontOfSize:10 weight:UIFontWeightRegular]
        };

        // 设置选中状态的图标和文字颜色 - 使用系统蓝色
        appearance.stackedLayoutAppearance.selected.iconColor = accentColor;
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = @{
            NSForegroundColorAttributeName: accentColor,
            NSFontAttributeName: [UIFont systemFontOfSize:10 weight:UIFontWeightMedium]
        };

        // 应用外观
        self.tabBar.standardAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            self.tabBar.scrollEdgeAppearance = appearance;
        }
        
        // 移除顶部边框线
        self.tabBar.backgroundImage = [UIImage new];
        self.tabBar.shadowImage = [UIImage new];
    } else {
        // iOS 13以下的兼容性设置
        self.tabBar.barTintColor = [UIColor whiteColor];
        self.tabBar.tintColor = [UIColor systemBlueColor];
        self.tabBar.unselectedItemTintColor = [UIColor systemGray3Color];
        
        // 移除顶部边框线
        self.tabBar.backgroundImage = [UIImage new];
        self.tabBar.shadowImage = [UIImage new];
    }
}

#pragma mark - 功能禁用处理

- (void)allFeaturesDisabled:(NSNotification *)notification {
    // 当检测到hook时，禁用所有功能
    dispatch_async(dispatch_get_main_queue(), ^{
        // 显示一个空白的视图控制器，提示用户应用已被禁用
        UIViewController *disabledVC = [[UIViewController alloc] init];
        disabledVC.view.backgroundColor = [UIColor systemBackgroundColor];

        UILabel *messageLabel = [[UILabel alloc] init];
        messageLabel.text = @"检测到异常环境\n应用功能已被禁用";
        messageLabel.textAlignment = NSTextAlignmentCenter;
        messageLabel.numberOfLines = 0;
        messageLabel.font = [UIFont systemFontOfSize:18];
        messageLabel.textColor = [UIColor systemRedColor];
        messageLabel.translatesAutoresizingMaskIntoConstraints = NO;

        [disabledVC.view addSubview:messageLabel];

        [NSLayoutConstraint activateConstraints:@[
            [messageLabel.centerXAnchor constraintEqualToAnchor:disabledVC.view.centerXAnchor],
            [messageLabel.centerYAnchor constraintEqualToAnchor:disabledVC.view.centerYAnchor],
            [messageLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:disabledVC.view.leadingAnchor constant:20],
            [messageLabel.trailingAnchor constraintLessThanOrEqualToAnchor:disabledVC.view.trailingAnchor constant:-20]
        ]];

        // 替换所有标签页的内容
        NSMutableArray *disabledControllers = [NSMutableArray array];
        for (UIViewController *vc in self.viewControllers) {
            UIViewController *newDisabledVC = [[UIViewController alloc] init];
            newDisabledVC.view.backgroundColor = [UIColor systemBackgroundColor];
            newDisabledVC.tabBarItem = vc.tabBarItem;

            UILabel *newMessageLabel = [[UILabel alloc] init];
            newMessageLabel.text = @"功能已禁用";
            newMessageLabel.textAlignment = NSTextAlignmentCenter;
            newMessageLabel.font = [UIFont systemFontOfSize:16];
            newMessageLabel.textColor = [UIColor systemRedColor];
            newMessageLabel.translatesAutoresizingMaskIntoConstraints = NO;

            [newDisabledVC.view addSubview:newMessageLabel];

            [NSLayoutConstraint activateConstraints:@[
                [newMessageLabel.centerXAnchor constraintEqualToAnchor:newDisabledVC.view.centerXAnchor],
                [newMessageLabel.centerYAnchor constraintEqualToAnchor:newDisabledVC.view.centerYAnchor]
            ]];

            [disabledControllers addObject:newDisabledVC];
        }

        self.viewControllers = disabledControllers;
    });
}

#pragma mark - 屏幕旋转支持

// 支持所有方向
- (BOOL)shouldAutorotate {
    return YES;
}

// 支持的屏幕方向
- (UIInterfaceOrientationMask)supportedInterfaceOrientationMask {
    return UIInterfaceOrientationMaskAll;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    // 在旋转动画完成后更新UI
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        // 旋转过程中的动画
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        // 通知子视图控制器屏幕已旋转
        UIViewController *selectedVC = self.selectedViewController;
        if ([selectedVC isKindOfClass:[UINavigationController class]]) {
            UINavigationController *navController = (UINavigationController *)selectedVC;
            UIViewController *topVC = navController.topViewController;
            if ([topVC respondsToSelector:@selector(handleScreenRotation)]) {
                [topVC performSelector:@selector(handleScreenRotation)];
            }
        }
    }];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end