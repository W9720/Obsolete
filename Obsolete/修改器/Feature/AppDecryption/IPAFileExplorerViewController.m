//
//  IPAFileExplorerViewController.m
//  Obsolete
//
//  Created by Assistant on 2024/01/16.
//

#import "IPAFileExplorerViewController.h"
#import "MachOAnalysisPopupView.h"
#import <mach-o/loader.h>
#import <mach-o/fat.h>
#import <objc/runtime.h>

@interface FileItem : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *path;
@property (nonatomic, assign) BOOL isDirectory;
@property (nonatomic, assign) long long fileSize;
@property (nonatomic, strong) NSDate *modificationDate;
@end

@implementation FileItem
@end

// NSData 扩展，基于 optool 的实现
@interface NSData (Reading)
@property (nonatomic, assign) NSUInteger currentOffset;
- (uint32_t)intAtOffset:(NSUInteger)offset;
@end

@implementation NSData (Reading)

static char OFFSET;
- (NSUInteger)currentOffset {
    NSNumber *value = objc_getAssociatedObject(self, &OFFSET);
    return value.unsignedIntegerValue;
}

- (void)setCurrentOffset:(NSUInteger)offset {
    objc_setAssociatedObject(self, &OFFSET, [NSNumber numberWithUnsignedInteger:offset], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (uint32_t)intAtOffset:(NSUInteger)offset {
    if (offset + sizeof(uint32_t) > self.length) {
        return 0;
    }
    uint32_t result;
    [self getBytes:&result range:NSMakeRange(offset, sizeof(result))];
    return result;
}

@end

@interface IPAFileExplorerViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) NSString *rootPath;
@property (nonatomic, strong) NSString *currentPath;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<FileItem *> *fileItems;
@property (nonatomic, strong) UILabel *pathLabel;
@end

@implementation IPAFileExplorerViewController

- (instancetype)initWithRootPath:(NSString *)rootPath fileName:(NSString *)fileName {
    self = [super init];
    if (self) {
        _rootPath = rootPath;
        _currentPath = rootPath;
        _fileName = fileName;
        _fileItems = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupUI];
    [self loadCurrentDirectory];
}

- (void)setupUI {
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = self.fileName;
    
    // 导航栏按钮
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(closeExplorer)];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"返回上级"
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(goBack)];
    
    // 路径标签
    self.pathLabel = [[UILabel alloc] init];
    self.pathLabel.font = [UIFont systemFontOfSize:12];
    self.pathLabel.textColor = [UIColor secondaryLabelColor];
    self.pathLabel.numberOfLines = 0;
    self.pathLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.pathLabel];
    
    // 表格视图
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];
    
    // 约束
    [NSLayoutConstraint activateConstraints:@[
        [self.pathLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.pathLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.pathLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        
        [self.tableView.topAnchor constraintEqualToAnchor:self.pathLabel.bottomAnchor constant:8],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)loadCurrentDirectory {
    [self.fileItems removeAllObjects];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:self.currentPath error:&error];
    
    if (error) {
        NSLog(@"Error reading directory: %@", error.localizedDescription);
        return;
    }
    
    for (NSString *itemName in contents) {
        NSString *itemPath = [self.currentPath stringByAppendingPathComponent:itemName];
        
        FileItem *item = [[FileItem alloc] init];
        item.name = itemName;
        item.path = itemPath;
        
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:itemPath error:nil];
        item.isDirectory = [attributes[NSFileType] isEqualToString:NSFileTypeDirectory];
        item.fileSize = [attributes[NSFileSize] longLongValue];
        item.modificationDate = attributes[NSFileModificationDate];
        
        [self.fileItems addObject:item];
    }
    
    // 排序：目录在前，文件在后，按名称排序
    [self.fileItems sortUsingComparator:^NSComparisonResult(FileItem *obj1, FileItem *obj2) {
        if (obj1.isDirectory && !obj2.isDirectory) {
            return NSOrderedAscending;
        } else if (!obj1.isDirectory && obj2.isDirectory) {
            return NSOrderedDescending;
        } else {
            return [obj1.name localizedCaseInsensitiveCompare:obj2.name];
        }
    }];
    
    [self updatePathLabel];
    [self.tableView reloadData];
}

- (void)updatePathLabel {
    NSString *relativePath = [self.currentPath stringByReplacingOccurrencesOfString:self.rootPath withString:@""];
    if (relativePath.length == 0) {
        relativePath = @"/";
    }
    self.pathLabel.text = [NSString stringWithFormat:@"当前路径: %@", relativePath];
}

- (void)closeExplorer {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)goBack {
    if ([self.currentPath isEqualToString:self.rootPath]) {
        return; // 已经在根目录
    }
    
    self.currentPath = [self.currentPath stringByDeletingLastPathComponent];
    [self loadCurrentDirectory];
    
    // 更新返回按钮状态
    self.navigationItem.rightBarButtonItem.enabled = ![self.currentPath isEqualToString:self.rootPath];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.fileItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"FileCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    FileItem *item = self.fileItems[indexPath.row];
    
    cell.textLabel.text = item.name;
    
    if (item.isDirectory) {
        cell.imageView.image = [UIImage systemImageNamed:@"folder.fill"];
        cell.detailTextLabel.text = @"文件夹";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.imageView.tintColor = [UIColor systemBlueColor];
    } else {
        // 检查是否为可执行文件或dylib
        if ([self isExecutableOrDylib:item.path]) {
            NSString *extension = [[item.path pathExtension] lowercaseString];
            if ([extension isEqualToString:@"dylib"]) {
                cell.imageView.image = [UIImage systemImageNamed:@"gear.circle.fill"];
                cell.imageView.tintColor = [UIColor systemOrangeColor];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"动态库 • %@", [self formatFileSize:item.fileSize]];
            } else {
                cell.imageView.image = [UIImage systemImageNamed:@"terminal.fill"];
                cell.imageView.tintColor = [UIColor systemGreenColor];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"可执行文件 • %@", [self formatFileSize:item.fileSize]];
            }
        } else {
            cell.imageView.image = [UIImage systemImageNamed:@"doc.fill"];
            cell.imageView.tintColor = [UIColor systemGrayColor];
            cell.detailTextLabel.text = [self formatFileSize:item.fileSize];
        }
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    FileItem *item = self.fileItems[indexPath.row];
    
    if (item.isDirectory) {
        // 进入子目录
        self.currentPath = item.path;
        [self loadCurrentDirectory];
        self.navigationItem.rightBarButtonItem.enabled = YES;
    } else {
        // 检查是否为可执行文件或dylib
        if ([self isExecutableOrDylib:item.path]) {
            [self showMachOAnalysis:item];
        } else {
            // 显示普通文件信息
            [self showFileInfo:item];
        }
    }
}

- (void)showFileInfo:(FileItem *)item {
    NSString *message = [NSString stringWithFormat:@"文件大小: %@\n修改时间: %@\n路径: %@",
                        [self formatFileSize:item.fileSize],
                        [self formatDate:item.modificationDate],
                        item.path];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:item.name
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    [alert addAction:okAction];
    
    [self presentViewController:alert animated:YES completion:nil];
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

- (NSString *)formatDate:(NSDate *)date {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    return [formatter stringFromDate:date];
}

- (BOOL)isExecutableOrDylib:(NSString *)filePath {
    NSFileManager *fileManager = [NSFileManager defaultManager];

    // 检查文件是否存在
    if (![fileManager fileExistsAtPath:filePath]) {
        return NO;
    }

    // 读取文件头
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    if (!fileHandle) {
        return NO;
    }

    NSData *headerData = [fileHandle readDataOfLength:sizeof(uint32_t)];
    [fileHandle closeFile];

    if (headerData.length < sizeof(uint32_t)) {
        return NO;
    }

    uint32_t magic = *(uint32_t *)headerData.bytes;

    // 检查Mach-O魔数
    BOOL isMachO = (magic == MH_MAGIC || magic == MH_MAGIC_64 ||
                    magic == MH_CIGAM || magic == MH_CIGAM_64 ||
                    magic == FAT_MAGIC || magic == FAT_CIGAM ||
                    magic == FAT_MAGIC_64 || magic == FAT_CIGAM_64);

    if (!isMachO) {
        return NO;
    }

    // 检查文件扩展名
    NSString *extension = [[filePath pathExtension] lowercaseString];
    if ([extension isEqualToString:@"dylib"] || [extension length] == 0) {
        return YES;
    }

    return NO;
}

#pragma mark - Mach-O Analysis (基于 optool 实现)

- (void)showMachOAnalysis:(FileItem *)item {
    // 显示分析进度
    UIAlertController *progressAlert = [UIAlertController alertControllerWithTitle:@"分析中"
                                                                           message:@"正在分析Mach-O文件..."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:progressAlert animated:YES completion:nil];

    // 在后台线程分析文件
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *dependencies = [self analyzeMachODependenciesOptoolStyle:item.path];

        dispatch_async(dispatch_get_main_queue(), ^{
            [progressAlert dismissViewControllerAnimated:YES completion:^{
                [self showDependenciesResult:item dependencies:dependencies];
            }];
        });
    });
}

- (NSArray *)analyzeMachODependenciesOptoolStyle:(NSString *)filePath {
    NSMutableArray *dependencies = [NSMutableArray array];

    @try {
        NSMutableData *binary = [NSMutableData dataWithContentsOfFile:filePath];
        if (!binary || binary.length < sizeof(struct mach_header)) {
            return dependencies;
        }

        // 设置初始偏移
        binary.currentOffset = 0;

        // 读取魔数
        uint32_t magic = [binary intAtOffset:0];
        if (magic != MH_MAGIC && magic != MH_MAGIC_64) {
            return dependencies;
        }

        BOOL is64bit = (magic == MH_MAGIC_64);

        // 跳过 header
        binary.currentOffset = is64bit ? sizeof(struct mach_header_64) : sizeof(struct mach_header);

        // 读取 header 信息
        struct mach_header *header = (struct mach_header *)binary.bytes;
        uint32_t ncmds = header->ncmds;

        // 遍历 load commands
        for (uint32_t i = 0; i < ncmds && binary.currentOffset < binary.length; i++) {
            if (binary.currentOffset + sizeof(struct load_command) > binary.length) {
                break;
            }

            uint32_t cmd = [binary intAtOffset:binary.currentOffset];
            uint32_t cmdsize = [binary intAtOffset:binary.currentOffset + 4];

            if (cmdsize < sizeof(struct load_command) ||
                binary.currentOffset + cmdsize > binary.length) {
                break;
            }

            switch (cmd) {
                case LC_LOAD_DYLIB:
                case LC_LOAD_WEAK_DYLIB: {
                    if (cmdsize >= sizeof(struct dylib_command)) {
                        struct dylib_command *dylibCmd = (struct dylib_command *)(binary.bytes + binary.currentOffset);

                        NSUInteger nameOffset = binary.currentOffset + dylibCmd->dylib.name.offset;
                        NSUInteger nameLength = cmdsize - dylibCmd->dylib.name.offset;

                        if (nameOffset < binary.length && nameOffset + nameLength <= binary.length) {
                            NSData *nameData = [binary subdataWithRange:NSMakeRange(nameOffset, nameLength)];
                            char *nameBytes = (char *)nameData.bytes;

                            // 确保字符串以 null 结尾
                            NSString *dylibName = nil;
                            for (NSUInteger j = 0; j < nameLength; j++) {
                                if (nameBytes[j] == '\0') {
                                    dylibName = [NSString stringWithUTF8String:nameBytes];
                                    break;
                                }
                            }

                            if (dylibName && dylibName.length > 0) {
                                NSString *type = (cmd == LC_LOAD_WEAK_DYLIB) ? @"LC_LOAD_WEAK_DYLIB" : @"LC_LOAD_DYLIB";

                                [dependencies addObject:@{
                                    @"name": dylibName,
                                    @"type": type,
                                    @"version": [NSString stringWithFormat:@"%u.%u.%u",
                                               dylibCmd->dylib.current_version >> 16,
                                               (dylibCmd->dylib.current_version >> 8) & 0xff,
                                               dylibCmd->dylib.current_version & 0xff]
                                }];
                            }
                        }
                    }
                    break;
                }
                default:
                    break;
            }

            binary.currentOffset += cmdsize;
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Error analyzing Mach-O file %@: %@", filePath, exception);
    }

    return [dependencies copy];
}

- (void)showDependenciesResult:(FileItem *)item dependencies:(NSArray *)dependencies {
    // 使用自定义弹窗显示结果
    [MachOAnalysisPopupView showWithFileName:item.name
                                    fileSize:item.fileSize
                                dependencies:dependencies
                              fromController:self];
}

@end
