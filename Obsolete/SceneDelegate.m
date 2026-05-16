//
//  SceneDelegate.m
//  Modifier
//
//  Created by 李良林 on 2024/2/2.
//

#import "SceneDelegate.h"
#import "修改器/UpdateManager.h"

@interface SceneDelegate ()

@end

@implementation SceneDelegate


- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
    // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
    // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
    
    // 创建窗口
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    
    // 创建主标签栏控制器
    MainTabBarController *mainTabBarController = [[MainTabBarController alloc] init];
    
    // 设置根视图控制器
    self.window.rootViewController = mainTabBarController;
    
    // 显示窗口
    [self.window makeKeyAndVisible];
}


- (void)sceneDidDisconnect:(UIScene *)scene {
    // Called as the scene is being released by the system.
    // This occurs shortly after the scene enters the background, or when its session is discarded.
    // Release any resources associated with this scene that can be re-created the next time the scene connects.
    // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
}


- (void)sceneDidBecomeActive:(UIScene *)scene {
    // Called when the scene has moved from an inactive state to an active state.
    // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.

    // 检查更新
    [self checkForUpdates];
}

- (void)checkForUpdates {
    UpdateManager *updateManager = [UpdateManager sharedManager];

    // 如果功能被禁用，直接返回
    if (updateManager.allFeaturesDisabled) {
        return;
    }

    [updateManager checkForUpdatesWithCompletion:^(BOOL hasUpdate, NSString *latestVersion, NSString *downloadURL, NSString *updateDescription, BOOL forceUpdate) {
        if (hasUpdate && latestVersion && downloadURL) {
            // 获取当前显示的视图控制器
            UIViewController *currentVC = self.window.rootViewController;
            if ([currentVC isKindOfClass:[UITabBarController class]]) {
                UITabBarController *tabBarController = (UITabBarController *)currentVC;
                currentVC = tabBarController.selectedViewController;
                if ([currentVC isKindOfClass:[UINavigationController class]]) {
                    UINavigationController *navController = (UINavigationController *)currentVC;
                    currentVC = navController.topViewController;
                }
            }

            // 显示更新弹窗
            [updateManager showUpdateAlertWithVersion:latestVersion
                                          downloadURL:downloadURL
                                          description:updateDescription
                                          forceUpdate:forceUpdate
                                       fromController:currentVC];
        }
    }];
}


- (void)sceneWillResignActive:(UIScene *)scene {
    // Called when the scene will move from an active state to an inactive state.
    // This may occur due to temporary interruptions (ex. an incoming phone call).
}


- (void)sceneWillEnterForeground:(UIScene *)scene {
    // Called as the scene transitions from the background to the foreground.
    // Use this method to undo the changes made on entering the background.
}


- (void)sceneDidEnterBackground:(UIScene *)scene {
    // Called as the scene transitions from the foreground to the background.
    // Use this method to save data, release shared resources, and store enough scene-specific state information
    // to restore the scene back to its current state.
}


@end
