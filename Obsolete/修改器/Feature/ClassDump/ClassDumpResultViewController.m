//
//  ClassDumpResultViewController.m
//  Modifier
//
//  Created by AI Assistant on 2024/8/13.
//

#import "ClassDumpResultViewController.h"
#import "ClassDumpFileContentViewController.h"

@interface ClassDumpResultViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSString *dumpPath;
@property (nonatomic, strong) NSMutableArray *dumpFiles;

@end

@implementation ClassDumpResultViewController

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
    self.title = @"Dump结果";

    // 设置导航栏
    [self setupNavigationBar];

    // 设置表格
    [self setupTableView];

    // 加载文件列表
    [self loadDumpFiles];
}

#pragma mark - Setup Methods

- (void)setupNavigationBar {
    // 添加刷新按钮
    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                   target:self
                                                                                   action:@selector(refreshFiles)];
    self.navigationItem.rightBarButtonItem = refreshButton;
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
}

- (void)refreshFiles {
    [self loadDumpFiles];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dumpFiles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"DumpFileCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
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
    } else {
        cell.imageView.image = [UIImage systemImageNamed:@"doc"];
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *fileInfo = self.dumpFiles[indexPath.row];
    NSString *filePath = fileInfo[@"path"];
    BOOL isDirectory = [fileInfo[@"isDirectory"] boolValue];

    if (isDirectory) {
        // 如果是目录，创建新的结果查看器
        ClassDumpResultViewController *subResultVC = [[ClassDumpResultViewController alloc] initWithDumpPath:filePath];
        [self.navigationController pushViewController:subResultVC animated:YES];
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
    [self.navigationController pushViewController:contentVC animated:YES];
}

@end
