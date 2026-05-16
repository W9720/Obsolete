//
//  PluginFileManagerViewController.m
//  修改器
//
//  Created by AI Assistant on 2025-01-08.
//

#import "PluginFileManagerViewController.h"
#import "TheosProjectManager.h"
#import "CodeEditorViewController.h"
#import "PluginFileManager.h"
#import "SSZipArchive/SSZipArchive.h"

@class PluginMakerViewController;

@interface PluginFileManagerViewController ()

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIBarButtonItem *backButton;

@end

@implementation PluginFileManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self setupUI];
    [self refreshFileList];
    
    // 监听项目创建通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshFileList)
                                                 name:@"PluginMakerProjectCreated"
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupUI {
    // 设置导航栏
    [self setupNavigationBar];

    // 创建表格视图
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];
    
    // 创建空状态标签
    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = @"暂无项目\n请先创建一个Theos项目";
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = [UIColor secondaryLabelColor];
    self.emptyLabel.font = [UIFont systemFontOfSize:16];
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];
    
    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

- (void)setupNavigationBar {
    // 创建返回按钮
    self.backButton = [[UIBarButtonItem alloc] initWithTitle:@"返回上级"
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(goBack)];

    // 初始时隐藏返回按钮
    self.backButton.enabled = NO;

    // 在PluginMaker中，我们通过通知来处理导航
}

- (void)updateNavigationBar {
    NSString *projectsRoot = [[TheosProjectManager sharedManager] getProjectsRootPath];
    BOOL canGoBack = ![self.currentPath isEqualToString:projectsRoot];

    self.backButton.enabled = canGoBack;

    // 检查当前是否在项目目录中（而不是根目录）
    BOOL isInProjectDirectory = canGoBack || [self isCurrentPathAProjectDirectory];

    // 发送通知更新父控制器的导航栏
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PluginFileManagerNavigationUpdate"
                                                        object:@{@"canGoBack": @(canGoBack), @"canShare": @(isInProjectDirectory)}];
}

- (void)refreshFileList {
    if (!self.currentPath) {
        // 显示项目根目录
        self.currentPath = [[TheosProjectManager sharedManager] getProjectsRootPath];
    }
    
    NSArray *files = [[PluginFileManager sharedManager] listFilesInDirectory:self.currentPath];
    
    // 过滤掉隐藏文件
    NSMutableArray *filteredFiles = [NSMutableArray array];
    for (NSString *file in files) {
        if (![file hasPrefix:@"."]) {
            [filteredFiles addObject:file];
        }
    }
    
    self.filesArray = [filteredFiles copy];
    
    // 更新UI
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
        self.emptyLabel.hidden = (self.filesArray.count > 0);
        self.tableView.hidden = (self.filesArray.count == 0);
        [self updateNavigationBar];
    });
}

- (void)goBack {
    NSString *parentPath = [self.currentPath stringByDeletingLastPathComponent];
    NSString *projectsRoot = [[TheosProjectManager sharedManager] getProjectsRootPath];

    // 检查是否可以返回上级目录
    if ([parentPath hasPrefix:projectsRoot] && ![parentPath isEqualToString:projectsRoot]) {
        self.currentPath = parentPath;
        [self refreshFileList];
    } else if ([parentPath isEqualToString:projectsRoot]) {
        // 返回到项目根目录
        self.currentPath = projectsRoot;
        [self refreshFileList];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filesArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"FileCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    NSString *fileName = self.filesArray[indexPath.row];
    NSString *filePath = [self.currentPath stringByAppendingPathComponent:fileName];
    
    // 检查是否为目录
    BOOL isDirectory;
    [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDirectory];
    
    cell.textLabel.text = fileName;
    
    if (isDirectory) {
        cell.imageView.image = [UIImage systemImageNamed:@"folder.fill"];
        cell.detailTextLabel.text = @"文件夹";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        // 根据文件扩展名设置图标
        NSString *extension = [fileName.pathExtension lowercaseString];
        if ([extension isEqualToString:@"xm"] || [extension isEqualToString:@"mm"]) {
            cell.imageView.image = [UIImage systemImageNamed:@"doc.text"];
            cell.detailTextLabel.text = @"Tweak源文件";
        } else if ([extension isEqualToString:@"h"]) {
            cell.imageView.image = [UIImage systemImageNamed:@"doc.text"];
            cell.detailTextLabel.text = @"头文件";
        } else if ([extension isEqualToString:@"plist"]) {
            cell.imageView.image = [UIImage systemImageNamed:@"doc.plaintext"];
            cell.detailTextLabel.text = @"配置文件";
        } else if ([extension isEqualToString:@"md"]) {
            cell.imageView.image = [UIImage systemImageNamed:@"doc.richtext"];
            cell.detailTextLabel.text = @"Markdown文档";
        } else if ([fileName isEqualToString:@"Makefile"] || [fileName isEqualToString:@"control"]) {
            cell.imageView.image = [UIImage systemImageNamed:@"gear"];
            cell.detailTextLabel.text = @"构建文件";
        } else {
            cell.imageView.image = [UIImage systemImageNamed:@"doc"];
            cell.detailTextLabel.text = @"文件";
        }
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *fileName = self.filesArray[indexPath.row];
    NSString *filePath = [self.currentPath stringByAppendingPathComponent:fileName];
    
    BOOL isDirectory;
    [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDirectory];
    
    if (isDirectory) {
        // 进入子目录
        self.currentPath = filePath;
        [self refreshFileList];

        // 添加动画效果
        [UIView transitionWithView:self.tableView
                          duration:0.25
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            [self.tableView reloadData];
        } completion:nil];
    } else {
        // 打开文件编辑器
        [self openCodeEditorWithFilePath:filePath];
    }
}

- (void)openCodeEditorWithFilePath:(NSString *)filePath {
    CodeEditorViewController *editorVC = [[CodeEditorViewController alloc] init];
    editorVC.filePath = filePath;
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:editorVC];
    navController.modalPresentationStyle = UIModalPresentationFullScreen;
    
    [self presentViewController:navController animated:YES completion:nil];
}

// 支持滑动删除
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSString *fileName = self.filesArray[indexPath.row];
        NSString *filePath = [self.currentPath stringByAppendingPathComponent:fileName];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认删除"
                                                                       message:[NSString stringWithFormat:@"确定要删除 %@ 吗？", fileName]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            NSError *error;
            BOOL success = [[PluginFileManager sharedManager] deleteFileAtPath:filePath error:&error];
            if (success) {
                [self refreshFileList];
            } else {
                UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"删除失败"
                                                                                   message:error.localizedDescription
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                [errorAlert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:errorAlert animated:YES completion:nil];
            }
        }]];
        
        [self presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark - 分享功能

- (BOOL)isCurrentPathAProjectDirectory {
    NSString *projectsRoot = [[TheosProjectManager sharedManager] getProjectsRootPath];

    // 检查当前路径是否包含项目文件
    NSArray *files = [[PluginFileManager sharedManager] listFilesInDirectory:self.currentPath];
    for (NSString *file in files) {
        if ([file hasSuffix:@".xm"] || [file isEqualToString:@"Makefile"] || [file isEqualToString:@"control"]) {
            return YES;
        }
    }

    // 检查是否在项目子目录中
    if (![self.currentPath isEqualToString:projectsRoot]) {
        NSString *parentPath = self.currentPath;
        while (![parentPath isEqualToString:projectsRoot] && parentPath.length > projectsRoot.length) {
            NSArray *parentFiles = [[PluginFileManager sharedManager] listFilesInDirectory:parentPath];
            for (NSString *file in parentFiles) {
                if ([file hasSuffix:@".xm"] || [file isEqualToString:@"Makefile"] || [file isEqualToString:@"control"]) {
                    return YES;
                }
            }
            parentPath = [parentPath stringByDeletingLastPathComponent];
        }
    }

    return NO;
}

- (void)shareCurrentProject {
    // 找到项目根目录
    NSString *projectPath = [self findProjectRootPath];
    if (!projectPath) {
        [self showAlertWithTitle:@"分享失败" message:@"无法找到项目根目录"];
        return;
    }

    NSString *projectName = [projectPath lastPathComponent];

    // 显示加载提示
    UIAlertController *loadingAlert = [UIAlertController alertControllerWithTitle:@"正在压缩项目"
                                                                          message:@"请稍候..."
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:loadingAlert animated:YES completion:nil];

    // 异步压缩项目
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *zipPath = [self createZipForProject:projectPath withName:projectName];

        dispatch_async(dispatch_get_main_queue(), ^{
            [loadingAlert dismissViewControllerAnimated:YES completion:^{
                if (zipPath) {
                    [self presentShareSheetWithFilePath:zipPath];
                } else {
                    [self showAlertWithTitle:@"压缩失败" message:@"无法创建项目压缩包"];
                }
            }];
        });
    });
}

- (NSString *)findProjectRootPath {
    NSString *projectsRoot = [[TheosProjectManager sharedManager] getProjectsRootPath];
    NSString *currentPath = self.currentPath;

    // 如果当前就在项目根目录
    if ([self isProjectDirectory:currentPath]) {
        return currentPath;
    }

    // 向上查找项目根目录
    while (![currentPath isEqualToString:projectsRoot] && currentPath.length > projectsRoot.length) {
        if ([self isProjectDirectory:currentPath]) {
            return currentPath;
        }
        currentPath = [currentPath stringByDeletingLastPathComponent];
    }

    return nil;
}

- (BOOL)isProjectDirectory:(NSString *)path {
    NSArray *files = [[PluginFileManager sharedManager] listFilesInDirectory:path];
    BOOL hasXmFile = NO;
    BOOL hasMakefile = NO;
    BOOL hasControl = NO;

    for (NSString *file in files) {
        if ([file hasSuffix:@".xm"]) hasXmFile = YES;
        if ([file isEqualToString:@"Makefile"]) hasMakefile = YES;
        if ([file isEqualToString:@"control"]) hasControl = YES;
    }

    return hasXmFile && hasMakefile && hasControl;
}

- (NSString *)createZipForProject:(NSString *)projectPath withName:(NSString *)projectName {
    NSString *tempDir = NSTemporaryDirectory();
    NSString *zipFileName = [NSString stringWithFormat:@"%@_%@.zip", projectName, [self currentTimestamp]];
    NSString *zipPath = [tempDir stringByAppendingPathComponent:zipFileName];

    // 使用NSFileManager创建压缩包
    BOOL success = [self createZipArchiveAtPath:zipPath fromDirectory:projectPath];

    if (success && [[NSFileManager defaultManager] fileExistsAtPath:zipPath]) {
        return zipPath;
    }

    return nil;
}

- (BOOL)createZipArchiveAtPath:(NSString *)zipPath fromDirectory:(NSString *)sourceDir {
    // 使用 SSZipArchive 创建压缩包
    return [SSZipArchive createZipFileAtPath:zipPath withContentsOfDirectory:sourceDir];
}



- (NSString *)currentTimestamp {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMdd_HHmmss";
    return [formatter stringFromDate:[NSDate date]];
}

- (void)presentShareSheetWithFilePath:(NSString *)filePath {
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    NSArray *activityItems = @[fileURL];

    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];

    // iPad适配
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = self.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 0, 0);
    }

    // 分享完成后删除临时文件
    activityVC.completionWithItemsHandler = ^(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        });
    };

    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
