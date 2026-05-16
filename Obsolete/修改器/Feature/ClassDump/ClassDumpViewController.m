//
//  ClassDumpViewController.m
//  Modifier
//
//  Created by AI Assistant on 2024/8/13.
//

#import "ClassDumpViewController.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "ClassDumpResultViewController.h"
#import "ClassDumpFileManagerViewController.h"
#import "ClassDumpManager.h"
#import "UnityDumpManager.h"
#import "UnityAppSelectionViewController.h"

@interface ClassDumpViewController () <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate, UnityAppSelectionDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSString *selectedFilePath;
@property (nonatomic, strong) NSString *dumpOutputPath;
@property (nonatomic, strong) NSMutableArray *menuItems;
@property (nonatomic, strong) NSMutableArray *unityMenuItems;
@property (nonatomic, strong) UnityAppInfo *selectedUnityApp;
@property (nonatomic, strong) NSString *unityDumpOutputPath;

@end

@implementation ClassDumpViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor systemBackgroundColor];

    // 初始化数据
    [self setupData];

    // 设置UI
    [self setupUI];

    // 创建dump输出目录
    [self createDumpDirectory];
    [self createUnityDumpDirectory];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // 确保导航栏可见
    self.navigationController.navigationBar.hidden = NO;
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    self.title = @"Dump";
}

#pragma mark - Setup Methods

- (void)setupData {
    // ClassDump菜单项
    self.menuItems = [NSMutableArray arrayWithArray:@[
        @{@"title": @"选择文件", @"subtitle": @"选择要dump的可执行文件或dylib", @"icon": @"folder", @"action": @"selectFile"},
        @{@"title": @"开始Dump", @"subtitle": @"执行ClassDump操作", @"icon": @"play.circle", @"action": @"startDump"},
        @{@"title": @"管理文件", @"subtitle": @"管理dump输出目录", @"icon": @"folder.badge.gear", @"action": @"manageFiles"}
    ]];

    // Unity Dump菜单项
    self.unityMenuItems = [NSMutableArray arrayWithArray:@[
        @{@"title": @"选择Unity应用", @"subtitle": @"选择要dump的Unity游戏或应用", @"icon": @"gamecontroller", @"action": @"selectUnityApp"},
        @{@"title": @"开始Unity Dump", @"subtitle": @"执行Il2Cpp转储操作", @"icon": @"play.circle.fill", @"action": @"startUnityDump"},
        @{@"title": @"管理Unity输出", @"subtitle": @"管理Unity dump输出目录", @"icon": @"folder.badge.gear", @"action": @"manageUnityFiles"}
    ]];
}

- (void)setupUI {
    // 设置表格
    [self setupTableView];
}



- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
}

#pragma mark - Directory Management

- (void)createDumpDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    self.dumpOutputPath = [documentsDirectory stringByAppendingPathComponent:@"Dump"];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:self.dumpOutputPath]) {
        NSError *error;
        [fileManager createDirectoryAtPath:self.dumpOutputPath
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
        if (error) {
            NSLog(@"创建Dump目录失败: %@", error.localizedDescription);
        }
    }
}

- (void)createUnityDumpDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    self.unityDumpOutputPath = [documentsDirectory stringByAppendingPathComponent:@"UnityDump"];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:self.unityDumpOutputPath]) {
        NSError *error;
        [fileManager createDirectoryAtPath:self.unityDumpOutputPath
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
        if (error) {
            NSLog(@"创建UnityDump目录失败: %@", error.localizedDescription);
        }
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return self.menuItems.count;
    } else {
        return self.unityMenuItems.count;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"ClassDump";
    } else {
        return @"Unity Dump";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"ClassDumpCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    NSDictionary *item;
    if (indexPath.section == 0) {
        item = self.menuItems[indexPath.row];

        // ClassDump状态调整
        if (indexPath.row == 1) { // 开始Dump
            cell.textLabel.textColor = self.selectedFilePath ? [UIColor systemBlueColor] : [UIColor systemGrayColor];
            cell.selectionStyle = self.selectedFilePath ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
        } else {
            cell.textLabel.textColor = [UIColor labelColor];
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
    } else {
        item = self.unityMenuItems[indexPath.row];

        // Unity Dump状态调整
        if (indexPath.row == 1) { // 开始Unity Dump
            BOOL canDump = self.selectedUnityApp && self.selectedUnityApp.isRunning;
            cell.textLabel.textColor = canDump ? [UIColor systemBlueColor] : [UIColor systemGrayColor];
            cell.selectionStyle = canDump ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
        } else {
            cell.textLabel.textColor = [UIColor labelColor];
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
    }

    cell.textLabel.text = item[@"title"];
    cell.detailTextLabel.text = item[@"subtitle"];
    cell.imageView.image = [UIImage systemImageNamed:item[@"icon"]];

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *item;
    if (indexPath.section == 0) {
        item = self.menuItems[indexPath.row];
    } else {
        item = self.unityMenuItems[indexPath.row];
    }

    NSString *action = item[@"action"];

    // ClassDump actions
    if ([action isEqualToString:@"selectFile"]) {
        [self selectFile];
    } else if ([action isEqualToString:@"startDump"]) {
        [self startDump];
    } else if ([action isEqualToString:@"manageFiles"]) {
        [self manageFiles];
    }
    // Unity Dump actions
    else if ([action isEqualToString:@"selectUnityApp"]) {
        [self selectUnityApp];
    } else if ([action isEqualToString:@"startUnityDump"]) {
        [self startUnityDump];
    } else if ([action isEqualToString:@"manageUnityFiles"]) {
        [self manageUnityFiles];
    }
}

#pragma mark - Action Methods

- (void)selectFile {
    // 使用兼容的文档选择器
    UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data", @"public.item", @"public.executable"] inMode:UIDocumentPickerModeOpen];
    documentPicker.delegate = self;
    documentPicker.allowsMultipleSelection = NO;
    documentPicker.modalPresentationStyle = UIModalPresentationFormSheet;

    [self presentViewController:documentPicker animated:YES completion:nil];
}

- (void)startDump {
    if (!self.selectedFilePath) {
        [self showAlertWithTitle:@"提示" message:@"请先选择要dump的文件"];
        return;
    }

    // 显示进度提示
    UIAlertController *progressAlert = [UIAlertController alertControllerWithTitle:@"正在处理"
                                                                           message:@"正在执行ClassDump，请稍候..."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:progressAlert animated:YES completion:nil];

    // 在后台线程执行dump操作
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self performClassDump];

        dispatch_async(dispatch_get_main_queue(), ^{
            [progressAlert dismissViewControllerAnimated:YES completion:^{
                [self showAlertWithTitle:@"完成" message:@"ClassDump执行完成！"];
                [self.tableView reloadData];
            }];
        });
    });
}

- (void)manageFiles {
    // 创建文件管理界面
    ClassDumpFileManagerViewController *managerVC = [[ClassDumpFileManagerViewController alloc] initWithDumpPath:self.dumpOutputPath];
    [self.navigationController pushViewController:managerVC animated:YES];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count > 0) {
        NSURL *selectedURL = urls.firstObject;

        // 获取文件访问权限
        BOOL startAccessing = [selectedURL startAccessingSecurityScopedResource];

        // 复制文件到应用沙盒
        NSString *fileName = selectedURL.lastPathComponent;
        NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];

        NSError *error;
        NSFileManager *fileManager = [NSFileManager defaultManager];

        // 如果临时文件已存在，先删除
        if ([fileManager fileExistsAtPath:tempPath]) {
            [fileManager removeItemAtPath:tempPath error:nil];
        }

        // 复制文件
        if ([fileManager copyItemAtURL:selectedURL toURL:[NSURL fileURLWithPath:tempPath] error:&error]) {
            self.selectedFilePath = tempPath;

            // 更新UI显示选中的文件
            NSMutableDictionary *firstItem = [self.menuItems[0] mutableCopy];
            firstItem[@"subtitle"] = [NSString stringWithFormat:@"已选择: %@", fileName];
            self.menuItems[0] = firstItem;

            [self.tableView reloadData];

            [self showAlertWithTitle:@"成功" message:[NSString stringWithFormat:@"已选择文件: %@", fileName]];
        } else {
            [self showAlertWithTitle:@"错误" message:[NSString stringWithFormat:@"文件复制失败: %@", error.localizedDescription]];
        }

        if (startAccessing) {
            [selectedURL stopAccessingSecurityScopedResource];
        }
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    // 用户取消选择
}

#pragma mark - ClassDump Core

- (void)performClassDump {
    if (!self.selectedFilePath) {
        NSLog(@"[ClassDumpVC] 错误: 没有选择文件");
        return;
    }

    NSLog(@"[ClassDumpVC] 开始执行ClassDump，文件: %@", self.selectedFilePath);
    NSLog(@"[ClassDumpVC] 输出路径: %@", self.dumpOutputPath);

    // 使用ClassDumpManager执行dump操作
    [[ClassDumpManager sharedManager] dumpFile:self.selectedFilePath
                                    outputPath:self.dumpOutputPath
                                    completion:^(BOOL success, NSString * _Nullable errorMessage) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                NSLog(@"[ClassDumpVC] ClassDump成功完成，输出路径: %@", self.dumpOutputPath);
            } else {
                NSLog(@"[ClassDumpVC] ClassDump失败: %@", errorMessage ?: @"未知错误");
            }
        });
    }];
}

#pragma mark - Unity Dump Methods

- (void)selectUnityApp {
    // 创建Unity应用选择界面
    UnityAppSelectionViewController *selectionVC = [[UnityAppSelectionViewController alloc] init];
    selectionVC.delegate = self;

    // 包装在导航控制器中
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:selectionVC];
    navController.modalPresentationStyle = UIModalPresentationFormSheet;

    [self presentViewController:navController animated:YES completion:nil];
}

#pragma mark - UnityAppSelectionDelegate

- (void)didSelectUnityApp:(UnityAppInfo *)appInfo {
    self.selectedUnityApp = appInfo;

    // 更新UI显示选中的应用
    NSMutableDictionary *firstItem = [self.unityMenuItems[0] mutableCopy];
    NSString *statusText = appInfo.isRunning ? @"(运行中)" : @"(未运行)";
    firstItem[@"subtitle"] = [NSString stringWithFormat:@"已选择: %@ %@", appInfo.displayName, statusText];
    self.unityMenuItems[0] = firstItem;

    [self.tableView reloadData];

    [self showAlertWithTitle:@"成功" message:[NSString stringWithFormat:@"已选择Unity应用: %@", appInfo.displayName]];
}



- (void)startUnityDump {
    if (!self.selectedUnityApp) {
        [self showAlertWithTitle:@"提示" message:@"请先选择要转储的Unity应用"];
        return;
    }

    // 检查应用是否正在运行
    if (!self.selectedUnityApp.isRunning) {
        [self showAlertWithTitle:@"提示" message:@"请先启动选中的Unity应用，然后再执行转储操作"];
        return;
    }

    // 显示进度提示
    UIAlertController *progressAlert = [UIAlertController alertControllerWithTitle:@"正在处理"
                                                                           message:@"正在执行Unity Il2Cpp转储，请稍候..."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:progressAlert animated:YES completion:nil];

    // 在后台线程执行Unity dump操作
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self performUnityDump];

        dispatch_async(dispatch_get_main_queue(), ^{
            [progressAlert dismissViewControllerAnimated:YES completion:^{
                [self showAlertWithTitle:@"完成" message:@"Unity Il2Cpp转储执行完成！"];
                [self.tableView reloadData];
            }];
        });
    });
}

- (BOOL)isAppRunning:(NSString *)bundleId {
    // 简化实现，因为应用是从运行列表中选择的，所以认为是运行中的
    return bundleId != nil && bundleId.length > 0;
}

- (void)performUnityDump {
    [[UnityDumpManager sharedManager] dumpUnityApp:self.selectedUnityApp.bundleId
                                        outputPath:self.unityDumpOutputPath
                                          progress:^(NSString *message) {
        NSLog(@"[UnityDump] %@", message);
    } completion:^(BOOL success, NSString * _Nullable errorMessage, NSString * _Nullable outputPath) {
        if (success) {
            NSLog(@"[UnityDump] Unity转储成功完成，输出路径: %@", outputPath);
        } else {
            NSLog(@"[UnityDump] Unity转储失败: %@", errorMessage ?: @"未知错误");
        }
    }];
}

- (void)manageUnityFiles {
    // 打开Unity文件管理界面
    // 这里可以复用ClassDumpFileManagerViewController或创建新的
    [self showAlertWithTitle:@"Unity文件管理" message:@"Unity文件管理功能开发中..."];
}

#pragma mark - Helper Methods

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    [alert addAction:okAction];

    [self presentViewController:alert animated:YES completion:nil];
}

@end
