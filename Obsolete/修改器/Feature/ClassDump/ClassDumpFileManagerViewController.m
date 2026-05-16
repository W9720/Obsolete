//
//  ClassDumpFileManagerViewController.m
//  Modifier
//
//  Created by AI Assistant on 2024/8/13.
//

#import "ClassDumpFileManagerViewController.h"
#import "ClassDumpFileContentViewController.h"

@interface ClassDumpFileManagerViewController () <UITableViewDelegate, UITableViewDataSource, ClassDumpFileContentViewControllerDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSString *dumpPath;
@property (nonatomic, strong) NSMutableArray *dumpFiles;
@property (nonatomic, strong) UIBarButtonItem *editButton;
@property (nonatomic, strong) UIBarButtonItem *deleteAllButton;

@end

@implementation ClassDumpFileManagerViewController

- (instancetype)initWithDumpPath:(NSString *)dumpPath {
    self = [super init];
    if (self) {
        _dumpPath = dumpPath;
        _dumpFiles = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"文件管理";

    // 设置导航栏
    [self setupNavigationBar];

    // 设置表格
    [self setupTableView];

    // 加载文件列表
    [self loadDumpFiles];
}

#pragma mark - Setup Methods

- (void)setupNavigationBar {
    // 编辑按钮
    self.editButton = [[UIBarButtonItem alloc] initWithTitle:@"编辑"
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(toggleEditMode)];

    // 全部删除按钮
    self.deleteAllButton = [[UIBarButtonItem alloc] initWithTitle:@"全部删除"
                                                            style:UIBarButtonItemStylePlain
                                                           target:self
                                                           action:@selector(deleteAllFiles)];
    self.deleteAllButton.tintColor = [UIColor systemRedColor];

    self.navigationItem.rightBarButtonItems = @[self.editButton, self.deleteAllButton];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
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

#pragma mark - File Management

- (void)loadDumpFiles {
    [self.dumpFiles removeAllObjects];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSArray *files = [fileManager contentsOfDirectoryAtPath:self.dumpPath error:&error];

    if (error) {
        NSLog(@"读取dump目录失败: %@", error.localizedDescription);
        return;
    }

    for (NSString *fileName in files) {
        if (![fileName hasPrefix:@"."]) { // 忽略隐藏文件
            NSString *filePath = [self.dumpPath stringByAppendingPathComponent:fileName];
            NSDictionary *attributes = [fileManager attributesOfItemAtPath:filePath error:nil];

            NSMutableDictionary *fileInfo = [NSMutableDictionary dictionary];
            fileInfo[@"name"] = fileName;
            fileInfo[@"path"] = filePath;
            fileInfo[@"size"] = attributes[NSFileSize];
            fileInfo[@"date"] = attributes[NSFileModificationDate];
            fileInfo[@"isDirectory"] = attributes[NSFileType] == NSFileTypeDirectory ? @YES : @NO;

            [self.dumpFiles addObject:fileInfo];
        }
    }

    // 按修改时间排序
    [self.dumpFiles sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        NSDate *date1 = obj1[@"date"];
        NSDate *date2 = obj2[@"date"];
        return [date2 compare:date1]; // 最新的在前面
    }];

    [self.tableView reloadData];

    // 更新按钮状态
    self.deleteAllButton.enabled = self.dumpFiles.count > 0;
}

#pragma mark - Actions

- (void)toggleEditMode {
    BOOL isEditing = !self.tableView.editing;
    [self.tableView setEditing:isEditing animated:YES];

    self.editButton.title = isEditing ? @"完成" : @"编辑";
    self.deleteAllButton.enabled = !isEditing && self.dumpFiles.count > 0;
}

- (void)deleteAllFiles {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认删除"
                                                                   message:@"确定要删除所有dump文件吗？此操作不可恢复。"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"删除"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self performDeleteAllFiles];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [alert addAction:deleteAction];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performDeleteAllFiles {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;

    for (NSDictionary *fileInfo in self.dumpFiles) {
        NSString *filePath = fileInfo[@"path"];
        [fileManager removeItemAtPath:filePath error:&error];
        if (error) {
            NSLog(@"删除文件失败: %@", error.localizedDescription);
        }
    }

    [self loadDumpFiles];

    UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"完成"
                                                                          message:@"所有文件已删除"
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    [successAlert addAction:okAction];
    [self presentViewController:successAlert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dumpFiles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"FileManagerCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }

    NSDictionary *fileInfo = self.dumpFiles[indexPath.row];
    NSString *fileName = fileInfo[@"name"];
    NSNumber *fileSize = fileInfo[@"size"];
    NSDate *modDate = fileInfo[@"date"];
    BOOL isDirectory = [fileInfo[@"isDirectory"] boolValue];

    cell.textLabel.text = fileName;

    // 格式化文件大小和日期
    NSString *sizeString = [self formatFileSize:[fileSize longLongValue]];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterShortStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    NSString *dateString = [dateFormatter stringFromDate:modDate];

    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@", sizeString, dateString];

    // 设置图标
    if (isDirectory) {
        cell.imageView.image = [UIImage systemImageNamed:@"folder"];
    } else if ([fileName.pathExtension isEqualToString:@"h"]) {
        cell.imageView.image = [UIImage systemImageNamed:@"doc.text"];
    } else if ([fileName.pathExtension isEqualToString:@"xm"]) {
        cell.imageView.image = [UIImage systemImageNamed:@"hammer"];
        cell.imageView.tintColor = [UIColor systemOrangeColor];
    } else {
        cell.imageView.image = [UIImage systemImageNamed:@"doc"];
    }

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSDictionary *fileInfo = self.dumpFiles[indexPath.row];
        NSString *filePath = fileInfo[@"path"];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error;
        [fileManager removeItemAtPath:filePath error:&error];

        if (error) {
            NSLog(@"删除文件失败: %@", error.localizedDescription);
            return;
        }

        [self.dumpFiles removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];

        // 更新按钮状态
        self.deleteAllButton.enabled = self.dumpFiles.count > 0;
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (tableView.editing) {
        return; // 编辑模式下不响应点击
    }

    NSDictionary *fileInfo = self.dumpFiles[indexPath.row];
    NSString *filePath = fileInfo[@"path"];
    BOOL isDirectory = [fileInfo[@"isDirectory"] boolValue];

    if (isDirectory) {
        // 如果是目录，创建新的文件管理器
        ClassDumpFileManagerViewController *subManagerVC = [[ClassDumpFileManagerViewController alloc] initWithDumpPath:filePath];
        [self.navigationController pushViewController:subManagerVC animated:YES];
    } else {
        // 如果是文件，显示文件内容
        [self showFileContent:filePath];
    }
}

#pragma mark - Helper Methods

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

- (void)showFileContent:(NSString *)filePath {
    // 创建文件内容查看器
    ClassDumpFileContentViewController *contentVC = [[ClassDumpFileContentViewController alloc] initWithFilePath:filePath];
    contentVC.delegate = self;
    [self.navigationController pushViewController:contentVC animated:YES];
}

#pragma mark - ClassDumpFileContentViewControllerDelegate

- (void)fileContentViewController:(ClassDumpFileContentViewController *)controller didGenerateHookFile:(NSString *)hookFilePath {
    // Hook文件生成后刷新文件列表
    [self loadDumpFiles];
}

@end
