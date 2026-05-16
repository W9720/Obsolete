//
//  UnityAppSelectionViewController.m
//  Obsolete
//
//  Created by Assistant on 2024/8/16.
//  Unity应用选择界面
//

#import "UnityAppSelectionViewController.h"
#import "PidModel.h"
#import "NSTask.h"

@implementation UnityAppInfo
@end

// 添加私有API声明
@interface UIImage (Private)
+ (instancetype)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier
                                                  format:(int)format
                                                   scale:(CGFloat)scale;
@end

@interface UnityAppSelectionViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) NSMutableArray<PidModel *> *runningProcesses;
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;
@property (nonatomic, strong) NSMutableDictionary *appInfoCache;

@end

@implementation UnityAppSelectionViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"选择Unity应用";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    [self setupNavigationBar];
    [self setupUI];
    [self setupConstraints];
    [self fetchRunningProcesses];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = NO;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self fetchRunningProcesses];
}

- (void)setupNavigationBar {
    self.navigationController.navigationBar.hidden = NO;
    
    // 取消按钮
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                  target:self
                                                                                  action:@selector(cancelButtonTapped)];
    self.navigationItem.leftBarButtonItem = cancelButton;
}

- (void)setupUI {
    // 状态标签
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"正在加载运行中的应用...";
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont systemFontOfSize:16];
    self.statusLabel.textColor = [UIColor secondaryLabelColor];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusLabel];
    
    // 表格视图
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    if (@available(iOS 13.0, *)) {
        self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    } else {
        self.tableView.backgroundColor = [UIColor systemBackgroundColor];
    }
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];
    
    // 下拉刷新
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshApps:) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = self.refreshControl;
    
    // 加载指示器
    if (@available(iOS 13.0, *)) {
        self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    } else {
        if (@available(iOS 13.0, *)) {
        self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    } else {
        self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    }
    }
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.loadingIndicator];
    
    self.runningProcesses = [NSMutableArray array];
    self.appInfoCache = [NSMutableDictionary dictionary];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // 状态标签
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        
        // 表格视图
        [self.tableView.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:20],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        // 加载指示器
        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

#pragma mark - Actions

- (void)cancelButtonTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)refreshApps:(UIRefreshControl *)sender {
    [self fetchRunningProcesses];
}

#pragma mark - Data Loading

- (void)fetchRunningProcesses {
    [self.loadingIndicator startAnimating];

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
                    [self.refreshControl endRefreshing];
                    [self.loadingIndicator stopAnimating];
                });
                return;
            }

            NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (!output || output.length == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.refreshControl endRefreshing];
                    [self.loadingIndicator stopAnimating];
                });
                return;
            }

            NSArray *processGroups = [self modelArray:output];
            NSMutableArray *userProcesses = [processGroups.firstObject mutableCopy];

            if (!userProcesses || userProcesses.count == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.refreshControl endRefreshing];
                    [self.loadingIndicator stopAnimating];
                });
                return;
            }

            // 显示所有运行的应用进程
            NSMutableArray *allProcesses = [userProcesses mutableCopy];

            [allProcesses sortUsingComparator:^NSComparisonResult(PidModel *obj1, PidModel *obj2) {
                return [@(obj2.pidValue) compare:@(obj1.pidValue)];
            }];

            dispatch_async(dispatch_get_main_queue(), ^{
                self.runningProcesses = allProcesses;
                [self.tableView reloadData];
                [self.refreshControl endRefreshing];
                [self.loadingIndicator stopAnimating];

                if (allProcesses.count > 0) {
                    self.statusLabel.text = [NSString stringWithFormat:@"找到 %lu 个运行中的应用", (unsigned long)allProcesses.count];
                } else {
                    self.statusLabel.text = @"未找到运行中的应用";
                }
            });
        } @catch (NSException *exception) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.refreshControl endRefreshing];
                [self.loadingIndicator stopAnimating];
                self.statusLabel.text = @"获取应用列表失败";
            });
        }
    });
}

- (void)buildAppInfoCache {
    @try {
        NSMutableDictionary *cache = [NSMutableDictionary dictionary];

        // 使用运行时调用LSApplicationWorkspace
        Class LSApplicationWorkspaceClass = NSClassFromString(@"LSApplicationWorkspace");
        if (!LSApplicationWorkspaceClass) {
            self.appInfoCache = [NSMutableDictionary dictionary];
            return;
        }

        SEL defaultWorkspaceSelector = NSSelectorFromString(@"defaultWorkspace");
        id workspace = [LSApplicationWorkspaceClass performSelector:defaultWorkspaceSelector];
        if (!workspace) {
            self.appInfoCache = [NSMutableDictionary dictionary];
            return;
        }

        SEL allApplicationsSelector = NSSelectorFromString(@"allApplications");
        NSArray *allApps = [workspace performSelector:allApplicationsSelector];
        if (!allApps) {
            self.appInfoCache = [NSMutableDictionary dictionary];
            return;
        }

        for (id proxy in allApps) {
            @try {
                SEL applicationIdentifierSelector = NSSelectorFromString(@"applicationIdentifier");
                SEL localizedNameSelector = NSSelectorFromString(@"localizedName");
                SEL bundleURLSelector = NSSelectorFromString(@"bundleURL");

                NSString *bundleIdentifier = [proxy performSelector:applicationIdentifierSelector];
                NSString *localizedName = [proxy performSelector:localizedNameSelector];
                NSURL *bundleURL = [proxy performSelector:bundleURLSelector];

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

        self.appInfoCache = [cache mutableCopy];
    } @catch (NSException *exception) {
        self.appInfoCache = [NSMutableDictionary dictionary];
    }
}

- (NSArray *)modelArray:(NSString *)input {
    NSArray *arr = [input componentsSeparatedByString:@"\n"];

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
    // 完全复制应用解密的图标加载逻辑
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
    // 刷新特定模型对应的cell
    NSInteger index = [self.runningProcesses indexOfObject:model];
    if (index != NSNotFound) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        });
    }
}





#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.runningProcesses.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 70; // 合适的行高
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"UnityAppCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        // 设置cell的背景为透明，这样我们可以在contentView上添加圆角背景
        cell.backgroundColor = [UIColor clearColor];

        // 创建一个容器视图来实现间距效果
        UIView *containerView = [[UIView alloc] init];
        containerView.tag = 999;
        containerView.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:containerView];

        // 设置容器视图的约束，留出上下间距
        [NSLayoutConstraint activateConstraints:@[
            [containerView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
            [containerView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
            [containerView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:4],
            [containerView.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-4]
        ]];

        // 适配深色和浅色模式的容器视图布局
        if (@available(iOS 13.0, *)) {
            containerView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        } else {
            containerView.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
        }
        containerView.layer.cornerRadius = 12;
        containerView.layer.masksToBounds = YES;

        // 创建应用图标
        UIImageView *iconView = [[UIImageView alloc] init];
        iconView.tag = 1000;
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        iconView.layer.cornerRadius = 8;
        iconView.layer.masksToBounds = YES;
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [containerView addSubview:iconView];

        // 创建应用名称标签
        UILabel *nameLabel = [[UILabel alloc] init];
        nameLabel.tag = 1001;
        nameLabel.font = [UIFont boldSystemFontOfSize:16];
        if (@available(iOS 13.0, *)) {
            nameLabel.textColor = [UIColor labelColor];
        } else {
            nameLabel.textColor = [UIColor whiteColor];
        }
        nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [containerView addSubview:nameLabel];

        // 创建PID标签
        UILabel *pidLabel = [[UILabel alloc] init];
        pidLabel.tag = 1002;
        pidLabel.font = [UIFont systemFontOfSize:14];
        if (@available(iOS 13.0, *)) {
            pidLabel.textColor = [UIColor secondaryLabelColor];
        } else {
            pidLabel.textColor = [UIColor lightGrayColor];
        }
        pidLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [containerView addSubview:pidLabel];

        // 设置约束，相对于容器视图
        [NSLayoutConstraint activateConstraints:@[
            [iconView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:12],
            [iconView.centerYAnchor constraintEqualToAnchor:containerView.centerYAnchor],
            [iconView.widthAnchor constraintEqualToConstant:40],
            [iconView.heightAnchor constraintEqualToConstant:40],

            [nameLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:12],
            [nameLabel.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:12],
            [nameLabel.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-12],

            [pidLabel.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor],
            [pidLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:2],
            [pidLabel.trailingAnchor constraintEqualToAnchor:nameLabel.trailingAnchor],
            [pidLabel.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor constant:-12]
        ]];
    }

    PidModel *process = self.runningProcesses[indexPath.row];

    // 获取容器视图和其中的组件
    UIView *containerView = [cell.contentView viewWithTag:999];
    UIImageView *iconView = [containerView viewWithTag:1000];
    UILabel *nameLabel = [containerView viewWithTag:1001];
    UILabel *pidLabel = [containerView viewWithTag:1002];

    // 设置内容
    nameLabel.text = process.name;
    pidLabel.text = [NSString stringWithFormat:@"PID: %@", process.pid];

    // 设置图标
    if (process.appIcon) {
        iconView.image = process.appIcon;
    } else {
        if (@available(iOS 13.0, *)) {
            iconView.image = [UIImage systemImageNamed:@"app.fill"];
            iconView.tintColor = [UIColor systemBlueColor];
        } else {
            iconView.backgroundColor = [UIColor systemBlueColor];
        }
    }

    // 设置选中状态
    if ([indexPath isEqual:self.selectedIndexPath]) {
        containerView.backgroundColor = [UIColor systemBlueColor];
        nameLabel.textColor = [UIColor whiteColor];
        pidLabel.textColor = [UIColor whiteColor];
    } else {
        if (@available(iOS 13.0, *)) {
            containerView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
            nameLabel.textColor = [UIColor labelColor];
            pidLabel.textColor = [UIColor secondaryLabelColor];
        } else {
            containerView.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
            nameLabel.textColor = [UIColor whiteColor];
            pidLabel.textColor = [UIColor lightGrayColor];
        }
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    // 更新选中状态
    NSIndexPath *previousSelection = self.selectedIndexPath;
    self.selectedIndexPath = indexPath;

    // 刷新相关行
    NSMutableArray *indexPathsToReload = [NSMutableArray array];
    if (previousSelection) {
        [indexPathsToReload addObject:previousSelection];
    }
    [indexPathsToReload addObject:indexPath];
    [tableView reloadRowsAtIndexPaths:indexPathsToReload withRowAnimation:UITableViewRowAnimationNone];

    // 创建UnityAppInfo并回调
    PidModel *selectedProcess = self.runningProcesses[indexPath.row];
    UnityAppInfo *appInfo = [[UnityAppInfo alloc] init];
    appInfo.bundleId = selectedProcess.bundleIdentifier;
    appInfo.displayName = selectedProcess.name;
    appInfo.isRunning = YES;
    appInfo.processId = (pid_t)selectedProcess.pidValue;

    if ([self.delegate respondsToSelector:@selector(didSelectUnityApp:)]) {
        [self.delegate didSelectUnityApp:appInfo];
    }

    // 延迟关闭界面
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self dismissViewControllerAnimated:YES completion:nil];
    });
}

@end
