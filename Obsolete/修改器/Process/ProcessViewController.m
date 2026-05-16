#import "ProcessViewController.h"
#import <UIKit/UIKit.h>
#import "NSTask.h"
#import "ProcessManager.h"
#import "PidModel.h"

// 添加私有API声明
@interface UIImage (Private)
+ (instancetype)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier
                                                  format:(int)format
                                                   scale:(CGFloat)scale;
@end







@interface ProcessViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *processTableView;
@property (nonatomic, strong) NSArray *runningProcesses;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;
@property (nonatomic, strong) NSDictionary *appInfoCache; // 缓存应用信息

@end

@implementation ProcessViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];



    [self setupNavigationBar];
    [self setupHeaderView];
    [self setupTableView];
    [self setupLoadingIndicator];
    [self fetchRunningProcesses];

    // 确保表格内容不被底部标签栏遮挡
    [self adjustTableViewContentInsets];
    
    // 注册应用进入前台的通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)dealloc {
    // 移除通知观察者
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// 应用从后台回到前台时调用
- (void)appWillEnterForeground {
    // 应用回到前台时刷新进程列表
    [self fetchRunningProcesses];
}

// 添加viewDidAppear方法，确保每次视图出现时都刷新进程列表
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // 每次视图出现时刷新进程列表
    [self fetchRunningProcesses];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    // 每次布局更新时调整内容内边距
    [self adjustTableViewContentInsets];
}

- (void)adjustTableViewContentInsets {
    // 获取标签栏高度
    CGFloat tabBarHeight = self.tabBarController.tabBar.frame.size.height;
    
    // 设置表格视图的内容内边距，确保底部有足够空间
    self.processTableView.contentInset = UIEdgeInsetsMake(0, 0, tabBarHeight, 0);
    self.processTableView.scrollIndicatorInsets = self.processTableView.contentInset;
}

- (void)setupNavigationBar {
    self.navigationController.navigationBar.prefersLargeTitles = YES;

    // 添加刷新按钮
    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                   target:self
                                                                                   action:@selector(fetchRunningProcesses)];
    refreshButton.tintColor = [UIColor systemBlueColor];
    self.navigationItem.rightBarButtonItem = refreshButton;
}

- (void)setupHeaderView {
    // 创建头部容器视图
    self.headerView = [[UIView alloc] init];
    self.headerView.backgroundColor = [UIColor systemBackgroundColor];
    self.headerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.headerView];

    // 标题标签
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"进程";
    self.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = [UIColor labelColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.headerView addSubview:self.titleLabel];

    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        // 头部视图约束
        [self.headerView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.headerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.headerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.headerView.heightAnchor constraintEqualToConstant:60],

        // 标题标签约束
        [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
        [self.titleLabel.centerXAnchor constraintEqualToAnchor:self.headerView.centerXAnchor],
        [self.titleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.headerView.leadingAnchor constant:20],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.headerView.trailingAnchor constant:-20]
    ]];
}

- (void)setupTableView {
    self.processTableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.processTableView.delegate = self;
    self.processTableView.dataSource = self;
    self.processTableView.rowHeight = 80; // 增加行高以适应新设计
    self.processTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.processTableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.processTableView.showsVerticalScrollIndicator = YES;
    self.processTableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:self.processTableView];

    // 添加下拉刷新
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = [UIColor systemBlueColor];
    [self.refreshControl addTarget:self action:@selector(fetchRunningProcesses) forControlEvents:UIControlEventValueChanged];
    self.processTableView.refreshControl = self.refreshControl;

    // 自动布局约束
    self.processTableView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.processTableView.topAnchor constraintEqualToAnchor:self.headerView.bottomAnchor],
        [self.processTableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.processTableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.processTableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
}

- (void)setupLoadingIndicator {
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.color = [UIColor systemBlueColor];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.loadingIndicator];

    [NSLayoutConstraint activateConstraints:@[
        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
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
                    [self.refreshControl endRefreshing];
                    [self.loadingIndicator stopAnimating];
                });
                return;
            }

            NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (!string || string.length == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.refreshControl endRefreshing];
                    [self.loadingIndicator stopAnimating];
                });
                return;
            }

            NSArray *processGroups = [self modelArray:string];
            NSMutableArray *userProcesses = [processGroups.firstObject mutableCopy];

            if (!userProcesses || userProcesses.count == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.refreshControl endRefreshing];
                    [self.loadingIndicator stopAnimating];
                });
                return;
            }

            [userProcesses sortUsingComparator:^NSComparisonResult(PidModel *obj1, PidModel *obj2) {
                return [@(obj2.pidValue) compare:@(obj1.pidValue)];
            }];

            NSString *selectedPID = [ProcessManager sharedManager].selectedProcessPID;
            dispatch_async(dispatch_get_main_queue(), ^{
                self.runningProcesses = [userProcesses copy];
                [self.processTableView reloadData];
                [self.refreshControl endRefreshing];
                [self.loadingIndicator stopAnimating];

                if (selectedPID) {
                    [self restoreSelectedProcess:selectedPID];
                }
            });
        } @catch (NSException *exception) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.refreshControl endRefreshing];
                [self.loadingIndicator stopAnimating];
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

// 添加新方法，用于恢复选中的进程
- (void)restoreSelectedProcess:(NSString *)selectedPID {
    // 重置选中状态
    self.selectedIndexPath = nil;

    // 查找选中的进程在当前列表中的位置
    for (NSInteger i = 0; i < self.runningProcesses.count; i++) {
        PidModel *process = self.runningProcesses[i];
        if ([process.pid isEqualToString:selectedPID]) {
            // 找到匹配的进程，设置选中状态
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
            self.selectedIndexPath = indexPath;

            // 更新UI显示
            UITableViewCell *cell = [self.processTableView cellForRowAtIndexPath:indexPath];
            if (cell) {
                [self updateCellSelectionState:cell isSelected:YES];
            } else {
                // 如果cell不可见，滚动到可见位置
                [self.processTableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
                // 延迟更新UI，确保cell已经被加载
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    UITableViewCell *cell = [self.processTableView cellForRowAtIndexPath:indexPath];
                    if (cell) {
                        [self updateCellSelectionState:cell isSelected:YES];
                    }
                });
            }
            break;
        }
    }
}

// 添加viewWillAppear方法，确保每次视图出现时都能正确显示选中状态
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 获取当前选中的进程ID
    NSString *selectedPID = [ProcessManager sharedManager].selectedProcessPID;
    if (selectedPID) {
        [self restoreSelectedProcess:selectedPID];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    PidModel *selectedProcess = self.runningProcesses[indexPath.row];
    
    // 如果点击的是已选中的进程，则不做处理
    if (self.selectedIndexPath && self.selectedIndexPath.row == indexPath.row) {
        return;
    }
    
    // 取消之前的选中
    if (self.selectedIndexPath) {
        UITableViewCell *previousCell = [tableView cellForRowAtIndexPath:self.selectedIndexPath];
        [self updateCellSelectionState:previousCell isSelected:NO];
    }
    
    // 设置新的选中
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    [self updateCellSelectionState:cell isSelected:YES];
    self.selectedIndexPath = indexPath;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择进程" 
                                                                   message:[NSString stringWithFormat:@"是否选择进程：%@\nPID：%@", 
                                                                            selectedProcess.name, 
                                                                            selectedProcess.pid] 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确定" 
                                                            style:UIAlertActionStyleDefault 
                                                          handler:^(UIAlertAction * _Nonnull action) {
        // 使用ProcessManager管理进程选择
        [[ProcessManager sharedManager] selectProcessWithPID:selectedProcess.pid 
                                                  processName:selectedProcess.name];
        
        // 发送通知到搜索界面
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ProcessSelectedNotification" 
                                                            object:nil 
                                                          userInfo:@{
                                                              @"processName": selectedProcess.name,
                                                              @"pid": selectedProcess.pid
                                                          }];
        
        NSLog(@"选中的进程：%@, PID：%@", selectedProcess.name, selectedProcess.pid);
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" 
                                                           style:UIAlertActionStyleCancel 
                                                         handler:^(UIAlertAction * _Nonnull action) {
        // 如果取消，则取消选中
        [self updateCellSelectionState:cell isSelected:NO];
        self.selectedIndexPath = nil;
    }];
    
    [alert addAction:confirmAction];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
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
    if (!model.bundleIdentifier) {
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *icon = [UIImage _applicationIconImageForBundleIdentifier:model.bundleIdentifier
                                                                   format:0
                                                                    scale:[UIScreen mainScreen].scale];

        dispatch_async(dispatch_get_main_queue(), ^{
            model.appIcon = icon;
            [self refreshCellForModel:model];
        });
    });
}

// 刷新特定model对应的cell
- (void)refreshCellForModel:(PidModel *)model {
    NSInteger index = [self.runningProcesses indexOfObject:model];
    if (index != NSNotFound) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
        UITableViewCell *cell = [self.processTableView cellForRowAtIndexPath:indexPath];
        if (cell) {
            // 找到图标视图并更新
            UIImageView *iconView = [cell.contentView viewWithTag:1000];
            if (iconView && model.appIcon) {
                iconView.image = model.appIcon;
            }
        }
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.runningProcesses.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"ProcessCell";
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

        // 进程名称标签约束
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
    if (self.selectedIndexPath && self.selectedIndexPath.row == indexPath.row) {
        [self updateCellSelectionState:cell isSelected:YES];
    }
    
    return cell;
}

@end
