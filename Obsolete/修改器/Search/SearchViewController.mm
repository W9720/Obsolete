#import "SearchViewController.h"
#import <UIKit/UIKit.h>
#import "ProcessManager.h"
#import "VMTool.h"
#import "MemModel.h"
#import "MemoryBrowserViewController.h"
#import "PointerScanViewController.h"
#import "RXMemSearchEngine.h"
#import "BitSlicerStringSearcher.h"
#import "PointerScanManager.h"

// 自定义搜索结果单元格
@interface SearchResultCell : UITableViewCell

@property (nonatomic, strong) UILabel *addressLabel;
@property (nonatomic, strong) UILabel *valueLabel;
@property (nonatomic, strong) UIButton *infoButton; // 添加叹号按钮
@property (nonatomic, strong) UIImageView *checkboxImageView; // 添加复选框图像视图
@property (nonatomic, strong) NSLayoutConstraint *addressLeadingConstraint; // 地址标签前导约束
@property (nonatomic, strong) NSLayoutConstraint *valueLeadingConstraint; // 值标签前导约束

- (void)setupWithAddress:(NSString *)address value:(NSString *)value permissions:(NSString *)permissions moduleName:(NSString *)moduleName index:(NSInteger)index;
- (void)setSelectionModeActive:(BOOL)active selected:(BOOL)selected;

@end

@implementation SearchResultCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // 创建复选框图像视图
        self.checkboxImageView = [[UIImageView alloc] init];
        self.checkboxImageView.translatesAutoresizingMaskIntoConstraints = NO;
        self.checkboxImageView.contentMode = UIViewContentModeScaleAspectFit;
        if (@available(iOS 13.0, *)) {
            self.checkboxImageView.image = [UIImage systemImageNamed:@"square"];
            self.checkboxImageView.tintColor = [UIColor systemBlueColor];
        } else {
            // 对于iOS 13以下版本，可以使用自定义图像或其他方式
            self.checkboxImageView.backgroundColor = [UIColor clearColor];
            self.checkboxImageView.layer.borderWidth = 1.0;
            self.checkboxImageView.layer.borderColor = [UIColor colorWithRed:0 green:0.5 blue:1.0 alpha:1.0].CGColor;
            self.checkboxImageView.layer.cornerRadius = 3.0;
        }
        self.checkboxImageView.hidden = YES; // 默认隐藏
        [self.contentView addSubview:self.checkboxImageView];
        
        // 创建地址标签
        self.addressLabel = [[UILabel alloc] init];
        self.addressLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        self.addressLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:self.addressLabel];
        


        // 创建值标签
        self.valueLabel = [[UILabel alloc] init];
        self.valueLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        self.valueLabel.textColor = [UIColor labelColor];
        self.valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:self.valueLabel];
        
        // 创建叹号按钮
        if (@available(iOS 13.0, *)) {
            // iOS 13及以上使用系统的圆形信息按钮
            self.infoButton = [UIButton buttonWithType:UIButtonTypeDetailDisclosure]; // 使用详情按钮样式
        } else {
            // 老版本iOS创建自定义的圆形叹号按钮
            self.infoButton = [UIButton buttonWithType:UIButtonTypeCustom];
            [self.infoButton setTitle:@"!" forState:UIControlStateNormal];
            self.infoButton.backgroundColor = [UIColor colorWithRed:0 green:0.5 blue:1.0 alpha:1.0];
            self.infoButton.layer.cornerRadius = 11;
            self.infoButton.layer.masksToBounds = YES;
            [self.infoButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            self.infoButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        }
        
        self.infoButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:self.infoButton];
        
        // 创建约束变量，用于动态调整
        self.addressLeadingConstraint = [self.addressLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:15];
        self.valueLeadingConstraint = [self.valueLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:15];
        
        // 设置约束
        [NSLayoutConstraint activateConstraints:@[
            // 复选框约束
            [self.checkboxImageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:15],
            [self.checkboxImageView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [self.checkboxImageView.widthAnchor constraintEqualToConstant:22],
            [self.checkboxImageView.heightAnchor constraintEqualToConstant:22],
            
            // 信息按钮约束
            [self.infoButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [self.infoButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-15],
            [self.infoButton.widthAnchor constraintEqualToConstant:22],
            [self.infoButton.heightAnchor constraintEqualToConstant:22]
        ]];
        
        // 激活默认约束
        self.addressLeadingConstraint.active = YES;
        self.valueLeadingConstraint.active = YES;
        
        // 添加地址和值标签的其他约束
        [NSLayoutConstraint activateConstraints:@[
            // 地址标签约束
            [self.addressLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6],
            [self.addressLabel.trailingAnchor constraintEqualToAnchor:self.infoButton.leadingAnchor constant:-10],

            // 值标签约束
            [self.valueLabel.topAnchor constraintEqualToAnchor:self.addressLabel.bottomAnchor constant:2],
            [self.valueLabel.trailingAnchor constraintEqualToAnchor:self.infoButton.leadingAnchor constant:-10],
            [self.valueLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6],
        ]];
    }
    return self;
}

- (void)setupWithAddress:(NSString *)address value:(NSString *)value permissions:(NSString *)permissions moduleName:(NSString *)moduleName index:(NSInteger)index {
    self.addressLabel.text = [NSString stringWithFormat:@"%ld. 地址: %@", (long)index, address];

    // 将模块信息添加到值标签中，与权限信息并排显示
    NSString *moduleText = @"";
    if (moduleName && moduleName.length > 0) {
        moduleText = [NSString stringWithFormat:@" 📦 %@", moduleName];
    } else {
        moduleText = @" 📦 未知模块";
    }
    
    // 修改值和权限显示逻辑，避免长字符串遮挡权限信息
    // 限制显示的字符串长度，最多显示25个字符，超过则截断并添加省略号
    NSString *displayValue = value;
    if (value.length > 25) {
        displayValue = [[value substringToIndex:22] stringByAppendingString:@"..."];
    }
    
    // 使用NSAttributedString来设置不同部分的文本样式
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:@"值: "];
    
    // 值部分使用深绿色，区分于地址
    NSAttributedString *valueAttr = [[NSAttributedString alloc] initWithString:displayValue
                                                                   attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12 weight:UIFontWeightMedium],
                                                                               NSForegroundColorAttributeName:[UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0]}];
    [attributedText appendAttributedString:valueAttr];
    
    // 添加足够的空格作为分隔
    [attributedText appendAttributedString:[[NSAttributedString alloc] initWithString:@"   "]];
    
    // 权限部分根据权限类型使用不同颜色
    UIColor *permissionColor;
    if ([permissions containsString:@"[RW"]) {
        // 可读可写 - 使用绿色
        permissionColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.2 alpha:1.0];
    } else if ([permissions containsString:@"[R-"]) {
        // 只读 - 使用橙色警告色
        permissionColor = [UIColor colorWithRed:0.8 green:0.4 blue:0.0 alpha:1.0];
    } else if ([permissions containsString:@"[R"]) {
        // 其他可读权限 - 使用蓝色
        permissionColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:1.0];
    } else {
        // 无权限或未知 - 使用灰色
        permissionColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.6 alpha:1.0];
    }

    NSAttributedString *permissionsAttr = [[NSAttributedString alloc] initWithString:permissions
                                                                        attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12 weight:UIFontWeightMedium],
                                                                                    NSForegroundColorAttributeName:permissionColor}];
    [attributedText appendAttributedString:permissionsAttr];

    // 添加模块信息
    NSAttributedString *moduleAttr = [[NSAttributedString alloc] initWithString:moduleText
                                                                    attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:11 weight:UIFontWeightRegular],
                                                                                NSForegroundColorAttributeName:[UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0]}];
    [attributedText appendAttributedString:moduleAttr];

    self.valueLabel.attributedText = attributedText;
    
    // 存储地址信息作为按钮的tag（将地址字符串转换为整数）
    self.infoButton.accessibilityIdentifier = address;
}

- (void)setSelectionModeActive:(BOOL)active selected:(BOOL)selected {
    // 先移除旧约束
    [NSLayoutConstraint deactivateConstraints:@[self.addressLeadingConstraint, self.valueLeadingConstraint]];
    
    if (active) {
        // 显示复选框
        self.checkboxImageView.hidden = NO;
        
        // 更新复选框状态
        if (@available(iOS 13.0, *)) {
            self.checkboxImageView.image = selected ? [UIImage systemImageNamed:@"checkmark.square.fill"] : [UIImage systemImageNamed:@"square"];
        } else {
            // 对于iOS 13以下版本，可以使用自定义图像或其他方式表示选中状态
            self.checkboxImageView.backgroundColor = selected ? [UIColor colorWithRed:0 green:0.5 blue:1.0 alpha:1.0] : [UIColor clearColor];
        }
        
        // 调整标签位置，为复选框腾出空间
        self.addressLeadingConstraint = [self.addressLabel.leadingAnchor constraintEqualToAnchor:self.checkboxImageView.trailingAnchor constant:10];
        self.valueLeadingConstraint = [self.valueLabel.leadingAnchor constraintEqualToAnchor:self.checkboxImageView.trailingAnchor constant:10];
    } else {
        // 隐藏复选框
        self.checkboxImageView.hidden = YES;

        // 恢复标签位置
        self.addressLeadingConstraint = [self.addressLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:15];
        self.valueLeadingConstraint = [self.valueLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:15];
    }

    // 激活新约束
    [NSLayoutConstraint activateConstraints:@[self.addressLeadingConstraint, self.valueLeadingConstraint]];
    
    // 强制布局更新
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

@end

@interface SearchViewController ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIStackView *buttonStackView;
@property (nonatomic, strong) UISwitch *searchSwitch;
@property (nonatomic, strong) UIButton *settingsButton;
@property (nonatomic, strong) UILabel *searchResultLabel;
@property (nonatomic, strong) UITableView *resultsTableView;
@property (nonatomic, strong) NSArray *allSearchResults; // 所有搜索结果
@property (nonatomic, strong) NSMutableArray *displayResults; // 当前显示的搜索结果
@property (nonatomic, assign) NSInteger batchSize; // 每次加载的数量
@property (nonatomic, assign) BOOL isLoadingMore; // 是否正在加载更多
@property (nonatomic, assign) VMMemValueType currentValueType;
@property (nonatomic, assign) BOOL isNearbySearch;
@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGesture; // 长按手势
@property (nonatomic, assign) BOOL isSelectionModeActive; // 是否处于选择模式
@property (nonatomic, strong) NSMutableArray *selectedItems; // 选中的项目
@property (nonatomic, strong) NSMutableSet *deletedAddresses; // 已删除的地址集合
@property (nonatomic, strong) UIRefreshControl *refreshControl; // 下拉刷新控件
@property (nonatomic, assign) BOOL isShowingSettingsMenu; // 是否正在显示设置菜单

// 搜索设置状态
@property (nonatomic, assign) BOOL isTraditionalSearch; // YES=传统搜索, NO=高效搜索
@property (nonatomic, assign) BOOL isFastMode; // YES=快速模式, NO=完整模式

// 模块信息缓存
@property (nonatomic, strong) NSArray<ModuleInfo *> *cachedModules; // 缓存的模块列表
@property (nonatomic, strong) NSDate *modulesCacheTime; // 模块缓存时间

@end

@implementation SearchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // 初始化属性
    self.batchSize = 20; // 每次加载20条
    self.displayResults = [NSMutableArray array];
    self.allSearchResults = @[];
    self.selectedItems = [NSMutableArray array];
    self.deletedAddresses = [NSMutableSet set]; // 初始化已删除地址集合
    self.isSelectionModeActive = NO;

    // 初始化搜索设置（从用户偏好读取，如果没有则使用默认值）
    [self loadSearchSettings];
    
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"未选择进程";
    self.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.titleLabel.textColor = [UIColor labelColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.titleLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.titleLabel.heightAnchor constraintEqualToConstant:30]
    ]];
    
    // 创建按钮
    [self setupButtonStackView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(processSelectedNotification:)
                                                 name:@"ProcessSelectedNotification"
                                               object:nil];
    
    // 添加搜索结果更新通知监听
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(searchResultUpdateNotification:)
                                                 name:@"SearchResultUpdateNotification"
                                               object:nil];

    // 添加内存修改失败通知监听
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(memoryModifyFailedNotification:)
                                                 name:@"MemoryModifyFailedNotification"
                                               object:nil];
    
    // 添加长按手势识别器
    self.longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    self.longPressGesture.minimumPressDuration = 0.8; // 设置长按时间为0.8秒
    [self.resultsTableView addGestureRecognizer:self.longPressGesture];
}

- (void)setupButtonStackView {
    NSArray *buttonTitles = @[@"全改", @"选择", @"数值", @"模糊", @"清除"];
    
    // 创建按钮堆栈视图
    self.buttonStackView = [[UIStackView alloc] init];
    self.buttonStackView.axis = UILayoutConstraintAxisHorizontal;
    self.buttonStackView.distribution = UIStackViewDistributionFillEqually;
    self.buttonStackView.spacing = 8;
    self.buttonStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.buttonStackView];
    
    // 创建按钮
    for (NSString *title in buttonTitles) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setTitle:title forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        button.backgroundColor = [UIColor secondarySystemBackgroundColor];
        button.layer.cornerRadius = 10;
        button.clipsToBounds = YES;
        
        // 设置最小宽度约束
        NSLayoutConstraint *widthConstraint = [button.widthAnchor constraintGreaterThanOrEqualToConstant:70];
        widthConstraint.priority = UILayoutPriorityDefaultHigh;
        widthConstraint.active = YES;
        
        [button addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.buttonStackView addArrangedSubview:button];
    }
    
    // 创建开关
    self.searchSwitch = [[UISwitch alloc] init];
    self.searchSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [self.searchSwitch addTarget:self action:@selector(searchSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.searchSwitch];
    
    // 创建设置按钮
    self.settingsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.settingsButton setImage:[UIImage systemImageNamed:@"ellipsis.circle"] forState:UIControlStateNormal];
    self.settingsButton.tintColor = [UIColor systemBlueColor];
    self.settingsButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.settingsButton addTarget:self action:@selector(showSearchSettingsMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.settingsButton];

    // 创建搜索结果标签
    self.searchResultLabel = [[UILabel alloc] init];
    self.searchResultLabel.text = @"搜索结果：0";
    self.searchResultLabel.textAlignment = NSTextAlignmentCenter;
    self.searchResultLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    self.searchResultLabel.textColor = [UIColor secondaryLabelColor];
    self.searchResultLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.searchResultLabel];
    
    // 创建结果表格视图
    self.resultsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.resultsTableView.delegate = self;
    self.resultsTableView.dataSource = self;
    self.resultsTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.resultsTableView.rowHeight = 50.0;
    [self.view addSubview:self.resultsTableView];
    
    // 注册单元格
    [self.resultsTableView registerClass:[SearchResultCell class] forCellReuseIdentifier:@"SearchResultCell"];

    // 设置下拉刷新
    [self setupRefreshControl];

    // 添加约束
    [NSLayoutConstraint activateConstraints:@[
        [self.buttonStackView.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:10],
        [self.buttonStackView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.buttonStackView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-75], // 修改这里，确保在横屏模式下有足够的空间
        [self.buttonStackView.heightAnchor constraintEqualToConstant:36],

        [self.searchSwitch.centerYAnchor constraintEqualToAnchor:self.buttonStackView.centerYAnchor],
        [self.searchSwitch.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.searchSwitch.widthAnchor constraintEqualToConstant:51],
        [self.searchSwitch.heightAnchor constraintEqualToConstant:31],

        // 设置按钮位于标题行的右上角
        [self.settingsButton.centerYAnchor constraintEqualToAnchor:self.titleLabel.centerYAnchor],
        [self.settingsButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.settingsButton.widthAnchor constraintEqualToConstant:30],
        [self.settingsButton.heightAnchor constraintEqualToConstant:30],
        
        [self.searchResultLabel.topAnchor constraintEqualToAnchor:self.buttonStackView.bottomAnchor constant:10],
        [self.searchResultLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.searchResultLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.searchResultLabel.heightAnchor constraintEqualToConstant:30],
        
        [self.resultsTableView.topAnchor constraintEqualToAnchor:self.searchResultLabel.bottomAnchor constant:10],
        [self.resultsTableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.resultsTableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.resultsTableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
}

// 设置下拉刷新控件
- (void)setupRefreshControl {
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = [UIColor systemBlueColor];

    // 设置刷新文本
    NSAttributedString *refreshText = [[NSAttributedString alloc] initWithString:@"下拉刷新搜索数据"
                                                                      attributes:@{NSForegroundColorAttributeName: [UIColor systemBlueColor],
                                                                                  NSFontAttributeName: [UIFont systemFontOfSize:14]}];
    self.refreshControl.attributedTitle = refreshText;

    // 添加刷新事件
    [self.refreshControl addTarget:self action:@selector(refreshSearchResults) forControlEvents:UIControlEventValueChanged];

    // 将刷新控件添加到表格视图
    [self.resultsTableView addSubview:self.refreshControl];
}

- (void)buttonTapped:(UIButton *)sender {
    NSString *title = [sender titleForState:UIControlStateNormal];
    
    if ([title isEqualToString:@"全改"]) {
        // 全改逻辑
        [self showModifyAllValuesAlert];
    } else if ([title isEqualToString:@"选择"]) {
        // 进入选择模式
        [self enterSelectionMode];
    } else if ([title isEqualToString:@"修改"]) {
        // 检查是否有选中的内存地址
        if (self.selectedItems.count > 0) {
            // 有选中的地址，显示选择操作菜单
            [self showModifyOrClearSelectionMenu];
        } else {
            // 没有选中的地址，退出选择模式
            [self exitSelectionMode];
        }
    } else if ([title isEqualToString:@"删除"]) {
        // 删除选中的项目
        [self deleteSelectedItems];
    } else if ([title isEqualToString:@"对半"]) {
        // 对半选择
        [self selectHalfItems];
    } else if ([title isEqualToString:@"自选"]) {
        // 显示自定义选择数量输入框
        [self showCustomSelectionCountAlert];
    } else if ([title isEqualToString:@"数值"] || [title isEqualToString:@"临近"]) {
        // 根据当前模式调用相应的搜索方法
        [self handleValueSearch];
    } else if ([title isEqualToString:@"模糊"]) {
        // 模糊搜索逻辑
        [self showFuzzySearchOptions];
    } else if ([title isEqualToString:@"清除"]) {
        // 直接执行清除全部操作
        [self clearAllSearchResults];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 获取当前选中的进程
    NSString *selectedProcessName = [ProcessManager sharedManager].selectedProcessName;
    NSString *selectedProcessPID = [ProcessManager sharedManager].selectedProcessPID;
    
    // 如果有选中的进程，更新标签
    if (selectedProcessName && selectedProcessPID) {
        self.titleLabel.text = [NSString stringWithFormat:@"当前进程：%@ (PID: %@)", selectedProcessName, selectedProcessPID];
    }
    
    // 确保导航栏隐藏
    self.navigationController.navigationBar.hidden = YES;
}

- (void)processSelectedNotification:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSString *processName = userInfo[@"processName"];
    NSInteger pid = [userInfo[@"pid"] integerValue];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // 更新标题
        self.titleLabel.text = [NSString stringWithFormat:@"当前进程：%@ (PID: %ld)", processName, (long)pid];

        // 重置搜索
        [[VMTool share] reset];

        // 清除模块缓存（进程变化时需要重新获取模块信息）
        [self clearModuleCache];

        // 重置搜索结果
        [self resetSearchResults];
    });
}

- (void)searchResultUpdateNotification:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSNumber *resultCount = userInfo[@"resultCount"];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateSearchResultCount:[resultCount integerValue]];
    });
}

- (void)memoryModifyFailedNotification:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSString *reason = userInfo[@"reason"];
    NSString *address = userInfo[@"address"];

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([reason isEqualToString:@"readonly"]) {
            NSString *message = [NSString stringWithFormat:@"地址 %@ 为只读内存区域，无法修改。\n\n只读区域通常包含：\n• 程序代码段\n• 常量数据\n• 系统保护区域", address];
            [self showAlertWithTitle:@"无法修改只读内存" message:message];
        } else {
            NSString *message = [NSString stringWithFormat:@"修改地址 %@ 失败，可能原因：\n• 内存访问权限不足\n• 地址无效\n• 进程保护机制", address];
            [self showAlertWithTitle:@"修改失败" message:message];
        }
    });
}

- (void)searchResultWarningNotification:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSNumber *count = userInfo[@"count"];
    NSString *type = userInfo[@"type"];

    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *title = @"搜索结果较多";
        NSString *message;

        if ([type isEqualToString:@"large_result"]) {
            message = [NSString stringWithFormat:@"搜索到 %@ 条结果，数量较多可能影响性能。\n\n建议：\n• 使用更精确的搜索条件\n• 缩小搜索范围\n• 分批处理结果\n\n所有结果都会显示，但加载可能较慢。", count];
        } else if ([type isEqualToString:@"unknown_large_result"]) {
            message = [NSString stringWithFormat:@"未知值搜索到 %@ 条结果，数量非常多。\n\n建议：\n• 选择更具体的数据类型\n• 使用比较搜索缩小范围\n• 考虑重新开始搜索\n\n所有结果都会显示，但可能需要较长时间加载。", count];
        }

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"继续"
                                                           style:UIAlertActionStyleDefault
                                                         handler:nil];
        [alert addAction:okAction];

        [self presentViewController:alert animated:YES completion:nil];
    });
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateSearchResultCount:(NSInteger)count {
    self.searchResultLabel.text = [NSString stringWithFormat:@"搜索结果：%ld", (long)count];
}

// 刷新搜索结果
- (void)refreshSearchResults {
    // 检查是否有搜索结果可以刷新
    if (self.allSearchResults.count == 0) {
        // 没有搜索结果，延迟结束刷新并显示提示
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.refreshControl endRefreshing];

            // 恢复刷新控件文本
            NSAttributedString *normalText = [[NSAttributedString alloc] initWithString:@"下拉刷新搜索数据"
                                                                             attributes:@{NSForegroundColorAttributeName: [UIColor systemBlueColor],
                                                                                         NSFontAttributeName: [UIFont systemFontOfSize:14]}];
            self.refreshControl.attributedTitle = normalText;

            // 显示Toast提示
            [self showToastMessage:@"没有搜索结果可以刷新，请先进行搜索"];
        });
        return;
    }

    // 更新刷新控件文本
    NSAttributedString *refreshingText = [[NSAttributedString alloc] initWithString:@"正在刷新搜索数据..."
                                                                         attributes:@{NSForegroundColorAttributeName: [UIColor systemBlueColor],
                                                                                     NSFontAttributeName: [UIFont systemFontOfSize:14]}];
    self.refreshControl.attributedTitle = refreshingText;

    // 根据搜索模式选择不同的刷新方法
    if (self.isTraditionalSearch) {
        // 传统搜索模式：使用VMTool的refresh方法
        [[VMTool share] refreshWithCallback:^(NSInteger count, NSArray *array) {
            // 过滤掉已删除的地址
            NSArray *filteredArray = array;
            if (self.deletedAddresses.count > 0) {
                NSMutableArray *filteredResults = [NSMutableArray array];
                for (MemModel *item in array) {
                    if (![self.deletedAddresses containsObject:item.address]) {
                        [filteredResults addObject:item];
                    }
                }
                filteredArray = [NSArray arrayWithArray:filteredResults];
            }

            // 更新搜索结果
            self.allSearchResults = filteredArray;

            // 清空并重新加载显示结果
            [self.displayResults removeAllObjects];
            [self loadMoreResults];

            dispatch_async(dispatch_get_main_queue(), ^{
                // 刷新表格
                [self.resultsTableView reloadData];

                // 更新搜索结果计数
                [self updateSearchResultCount:self.allSearchResults.count];

                // 结束刷新动画
                [self.refreshControl endRefreshing];

                // 恢复刷新控件文本
                NSAttributedString *normalText = [[NSAttributedString alloc] initWithString:@"下拉刷新搜索数据"
                                                                                 attributes:@{NSForegroundColorAttributeName: [UIColor systemBlueColor],
                                                                                             NSFontAttributeName: [UIFont systemFontOfSize:14]}];
                self.refreshControl.attributedTitle = normalText;

                // 显示刷新完成提示
                NSString *message = [NSString stringWithFormat:@"已刷新，当前 %ld 条结果", (long)self.allSearchResults.count];
                [self showToastMessage:message];
            });
        }];
    } else {
        // 高效搜索模式：使用refreshEfficientSearchResults方法
        [self refreshEfficientSearchResults];

        // 延迟结束刷新动画并显示提示
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // 结束刷新动画
            [self.refreshControl endRefreshing];

            // 恢复刷新控件文本
            NSAttributedString *normalText = [[NSAttributedString alloc] initWithString:@"下拉刷新搜索数据"
                                                                             attributes:@{NSForegroundColorAttributeName: [UIColor systemBlueColor],
                                                                                         NSFontAttributeName: [UIFont systemFontOfSize:14]}];
            self.refreshControl.attributedTitle = normalText;

            // 显示刷新完成提示
            NSString *message = [NSString stringWithFormat:@"已刷新，当前 %ld 条结果", (long)self.allSearchResults.count];
            [self showToastMessage:message];
        });
    }
}

// 显示Toast提示消息
- (void)showToastMessage:(NSString *)message {
    UILabel *toastLabel = [[UILabel alloc] init];
    toastLabel.text = message;
    toastLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7];
    toastLabel.textColor = [UIColor whiteColor];
    toastLabel.textAlignment = NSTextAlignmentCenter;
    toastLabel.font = [UIFont systemFontOfSize:14];
    toastLabel.layer.cornerRadius = 8;
    toastLabel.clipsToBounds = YES;
    toastLabel.numberOfLines = 0; // 支持多行

    // 计算文本大小
    CGSize maxSize = CGSizeMake(self.view.bounds.size.width - 40, CGFLOAT_MAX);
    CGSize textSize = [message boundingRectWithSize:maxSize
                                            options:NSStringDrawingUsesLineFragmentOrigin
                                         attributes:@{NSFontAttributeName: toastLabel.font}
                                            context:nil].size;

    // 设置Toast位置和大小
    CGFloat toastWidth = textSize.width + 20;
    CGFloat toastHeight = textSize.height + 16;
    toastLabel.frame = CGRectMake((self.view.bounds.size.width - toastWidth) / 2,
                                 self.view.bounds.size.height - 150,
                                 toastWidth,
                                 toastHeight);

    [self.view addSubview:toastLabel];

    // 2秒后自动消失
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.3 animations:^{
            toastLabel.alpha = 0;
        } completion:^(BOOL finished) {
            [toastLabel removeFromSuperview];
        }];
    });
}

- (void)handleValueSearch {
    // 检查是否选择了进程
    NSString *pidString = [ProcessManager sharedManager].selectedProcessPID;
    
    if (!pidString) {
        [self showAlertWithTitle:@"错误" message:@"请先选择进程"];
        return;
    }
    
    // 创建搜索弹窗
    [self showCustomSearchMemoryView];
}

- (void)showCustomSearchMemoryView {
    // 定义容器尺寸 - 根据屏幕方向调整
    CGFloat containerWidth = MIN(self.view.bounds.size.width - 40, 300);
    CGFloat containerHeight = 180;
    
    // 创建背景遮罩
    UIView *backgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
    backgroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    backgroundView.alpha = 0;
    backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; // 自动调整大小
    
    // 创建容器视图
    UIView *containerView = [[UIView alloc] initWithFrame:CGRectMake(
        (self.view.bounds.size.width - containerWidth) / 2,
        (self.view.bounds.size.height - containerHeight) / 2 - 40,
        containerWidth,
        containerHeight
    )];
    containerView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin; // 自动调整位置
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        containerView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        containerView.layer.borderWidth = 0.5;
        containerView.layer.borderColor = [UIColor systemGrayColor].CGColor;
    } else {
        containerView.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.96 alpha:1.0];
        containerView.layer.borderWidth = 0.5;
        containerView.layer.borderColor = [UIColor colorWithWhite:0.85 alpha:1.0].CGColor;
    }
    
    containerView.layer.cornerRadius = 15;
    containerView.layer.shadowColor = [UIColor blackColor].CGColor;
    containerView.layer.shadowOffset = CGSizeMake(0, 4);
    containerView.layer.shadowOpacity = 0.1;
    containerView.layer.shadowRadius = 10;
    containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 5, containerWidth - 40, 30)];
    titleLabel.text = self.isNearbySearch ? @"临近搜索" : @"数值搜索";
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        titleLabel.textColor = [UIColor labelColor];
    } else {
        titleLabel.textColor = [UIColor darkTextColor];
    }
    
    // 类型分段控件
    UISegmentedControl *typeSegmentControl = [[UISegmentedControl alloc]
                                              initWithItems:@[@"F32", @"F64", @"I8", @"I16", @"I32", @"I64", @"Str"]];
    typeSegmentControl.frame = CGRectMake(20, 45, containerWidth - 40, 30);
    typeSegmentControl.selectedSegmentIndex = 4; // 默认选择I32类型（索引为4）
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        typeSegmentControl.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        typeSegmentControl.selectedSegmentTintColor = [UIColor systemBlueColor];
    }
    
    // 输入框
    UITextField *valueTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 85, containerWidth - 40, 35)];
    valueTextField.borderStyle = UITextBorderStyleRoundedRect;
    valueTextField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    
    // 根据选择的类型设置 placeholder
    NSArray *placeholders = @[
        @"请输入单浮点数值",
        @"请输入双浮点数值",
        @"请输入8位整数",
        @"请输入16位整数",
        @"请输入32位整数",
        @"请输入64位整数",
        @"请输入字符串"
    ];
    valueTextField.placeholder = placeholders[4]; // 默认显示I32类型的placeholder
    
    // 添加类型选择变化的监听
    [typeSegmentControl addTarget:self action:@selector(typeSegmentControlChanged:) forControlEvents:UIControlEventValueChanged];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        valueTextField.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        valueTextField.textColor = [UIColor labelColor];
        valueTextField.attributedPlaceholder = [[NSAttributedString alloc]
            initWithString:placeholders[4] // 默认显示I32类型的placeholder
            attributes:@{NSForegroundColorAttributeName: [UIColor secondaryLabelColor]}];
    } else {
        valueTextField.backgroundColor = [UIColor colorWithWhite:0.98 alpha:1];
        valueTextField.textColor = [UIColor darkTextColor];
    }
    
    // 搜索按钮
    UIButton *searchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    searchButton.frame = CGRectMake(containerWidth / 2 + 10, 130, (containerWidth - 60) / 2, 35);
    [searchButton setTitle:@"搜索" forState:UIControlStateNormal];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        searchButton.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.2 green:0.22 blue:0.25 alpha:1.0];
            } else {
                return [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0];
            }
        }];
        [searchButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        searchButton.backgroundColor = [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0];
        [searchButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    
    searchButton.layer.cornerRadius = 8;
    
    // 取消按钮
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.frame = CGRectMake(20, 130, (containerWidth - 60) / 2, 35);
    [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        cancelButton.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.18 green:0.18 blue:0.2 alpha:1.0];
            } else {
                return [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
            }
        }];
        [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        cancelButton.backgroundColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
        [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    
    cancelButton.layer.cornerRadius = 8;
    
    // 添加视图
    [containerView addSubview:titleLabel];
    [containerView addSubview:typeSegmentControl];
    [containerView addSubview:valueTextField];
    [containerView addSubview:searchButton];
    [containerView addSubview:cancelButton];
    
    [backgroundView addSubview:containerView];
    [self.view addSubview:backgroundView];
    
    // 设置标签用于区分搜索弹窗的按钮
    cancelButton.tag = 1001; // 搜索弹窗的取消按钮标签
    
    // 搜索按钮点击事件
    [searchButton addTarget:self action:@selector(searchButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 取消按钮点击事件
    [cancelButton addTarget:self action:@selector(cancelButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 存储引用
    objc_setAssociatedObject(self, "backgroundView", backgroundView, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(self, "containerView", containerView, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(self, "valueTextField", valueTextField, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(self, "typeSegmentControl", typeSegmentControl, OBJC_ASSOCIATION_ASSIGN);
    
    // 动画显示
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 1;
        containerView.transform = CGAffineTransformIdentity;
    }];
}

- (void)typeSegmentControlChanged:(UISegmentedControl *)sender {
    UITextField *valueTextField = objc_getAssociatedObject(self, "valueTextField");
    
    // 根据选择的类型设置 placeholder
    NSArray *placeholders = @[
        @"请输入单浮点数值",
        @"请输入双浮点数值）",
        @"请输入8位整数",
        @"请输入16位整数",
        @"请输入32位整数",
        @"请输入64位整数",
        @"请输入字符串"
    ];
    
    valueTextField.placeholder = placeholders[sender.selectedSegmentIndex];
    
    // 适配深色和浅色模式的 placeholder 颜色
    if (@available(iOS 13.0, *)) {
        valueTextField.attributedPlaceholder = [[NSAttributedString alloc]
            initWithString:placeholders[sender.selectedSegmentIndex]
            attributes:@{NSForegroundColorAttributeName: [UIColor secondaryLabelColor]}];
    }
    
    // 如果选择了字符串类型，更改键盘类型为默认
    if (sender.selectedSegmentIndex == 6) { // 字符串类型
        valueTextField.keyboardType = UIKeyboardTypeDefault;
    } else {
        // 其他数值类型使用数字键盘
        valueTextField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    }
}

- (void)searchButtonTapped:(UIButton *)sender {
    UIView *containerView = objc_getAssociatedObject(self, "containerView");
    UIView *backgroundView = objc_getAssociatedObject(self, "backgroundView");
    UITextField *valueTextField = objc_getAssociatedObject(self, "valueTextField");
    UISegmentedControl *typeSegmentControl = objc_getAssociatedObject(self, "typeSegmentControl");
    
    NSString *searchValue = [valueTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // 检查是否选择了进程
    NSString *pidString = [ProcessManager sharedManager].selectedProcessPID;
    if (!pidString) {
        [self showAlertWithTitle:@"错误" message:@"请先选择进程"];
        return;
    }
    
    // 检查搜索值是否为空
    if (searchValue.length == 0) {
        [self showAlertWithTitle:@"提示" message:@"请输入搜索值"];
        return;
    }
    
    // 获取选中的类型
    NSArray *types = @[@"F32", @"F64", @"I8", @"I16", @"I32", @"I64", @"Str"];
    NSString *selectedType = types[typeSegmentControl.selectedSegmentIndex];
    
    // 获取对应的VMMemValueType枚举值
    NSDictionary *keyValues = @{
        @"F32": @(VMMemValueTypeFloat),
        @"F64": @(VMMemValueTypeDouble),
        @"I8": @(VMMemValueTypeSignedByte),
        @"I16": @(VMMemValueTypeSignedShort),
        @"I32": @(VMMemValueTypeSignedInt),
        @"I64": @(VMMemValueTypeSignedLong),
        @"Str": @(VMMemValueTypeStr)
    };
    
    // 获取当前符号模式
    BOOL isSignedMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"FloatSignMode"];
    
    // 如果FloatSignMode未设置，默认为有符号模式
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"FloatSignMode"]) {
        isSignedMode = YES;
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"FloatSignMode"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    // 根据符号模式选择类型
    VMMemValueType selectedTypeValue;
    if (isSignedMode) {
        // 有符号模式
        selectedTypeValue = (VMMemValueType)[keyValues[selectedType] integerValue];
    } else {
        // 无符号模式，映射到对应的无符号类型
        // 字符串类型没有有符号/无符号的区别
        if ([selectedType isEqualToString:@"Str"]) {
            selectedTypeValue = VMMemValueTypeStr;
        } else {
        NSDictionary *unsignedMapping = @{
            @"I8": @(VMMemValueTypeUnsignedByte),
            @"I16": @(VMMemValueTypeUnsignedShort),
            @"I32": @(VMMemValueTypeUnsignedInt),
            @"I64": @(VMMemValueTypeUnsignedLong),
            @"F32": @(VMMemValueTypeFloat),  // 浮点数没有无符号版本
                @"F64": @(VMMemValueTypeDouble)
        };
        selectedTypeValue = (VMMemValueType)[unsignedMapping[selectedType] integerValue];
        }
    }
    
    // 验证输入值的合法性
    BOOL isValidInput = [self validateInput:searchValue forType:selectedType];
    if (!isValidInput) {
        NSString *errorMessage;
        if (!isSignedMode) {
            errorMessage = @"无符号模式下不允许输入负数";
        } else {
            errorMessage = [NSString stringWithFormat:@"请输入正确的%@类型值", selectedType];
        }
        [self showAlertWithTitle:@"错误" message:errorMessage];
        return;
    }
    
    // 设置当前进程
    [[VMTool share] setPid:[pidString intValue] name:[ProcessManager sharedManager].selectedProcessName];
    
    // 根据当前模式选择不同的搜索方法
    if (self.isNearbySearch) {
        // 直接使用VMTool中设置的临近范围值
        // VMTool初始化时默认值为0x20，用户设置的值会覆盖默认值
        int searchRange = [[VMTool share] rangeValue];
        
        // 使用nearMemSearch方法进行临近搜索
        [[VMTool share] nearMemSearch:searchValue
                                 type:selectedTypeValue
                                range:searchRange
                             callback:^(NSInteger count, NSArray *array) {
            // 确保在主线程上执行UI更新
            if ([NSThread isMainThread]) {
                // 保存当前搜索的数据类型
                self.currentValueType = selectedTypeValue;

                // 使用统一方法更新搜索结果
                [self updateSearchResultsWithArray:array count:count];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 保存当前搜索的数据类型
                    self.currentValueType = selectedTypeValue;

                    // 使用统一方法更新搜索结果
                    [self updateSearchResultsWithArray:array count:count];
                });
            }
        }];
    } else {
        // 如果是字符串类型，使用精确搜索或模糊搜索
        if (selectedTypeValue == VMMemValueTypeStr) {
            // 检查是否开启了模糊字符设置
            BOOL isFuzzyStringEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"FuzzyStringMode"];
            
            // 根据模糊字符设置选择比较方式
            VMMemComparison comparisonType = isFuzzyStringEnabled ? VMMemComparisonLE : VMMemComparisonEQ;
            
            // 直接执行字符串搜索，不再显示提示弹窗
            [self performStringSearchWithValue:searchValue type:selectedTypeValue comparison:comparisonType];
            
            // 关闭搜索框
            [UIView animateWithDuration:0.3 animations:^{
                UIView *backgroundView = objc_getAssociatedObject(self, "backgroundView");
                UIView *containerView = objc_getAssociatedObject(self, "containerView");
                
                backgroundView.alpha = 0;
                containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
            } completion:^(BOOL finished) {
                UIView *backgroundView = objc_getAssociatedObject(self, "backgroundView");
                [backgroundView removeFromSuperview];
            }];
            return;
        }
        
        // 检查是否是浮点数类型
        BOOL isFloatType = [selectedType isEqualToString:@"F32"] || [selectedType isEqualToString:@"F64"];
        
        // 获取浮点误差范围
        CGFloat errorRange = [[VMTool share] floatErrorRange];
        
        // 如果是浮点数类型且设置了误差范围
        if (isFloatType && errorRange > 0.0) {
            // 执行浮点数范围搜索
            [self performFloatRangeSearchWithValue:searchValue type:selectedTypeValue errorRange:errorRange];
        } else {
            // 根据搜索模式选择搜索引擎
            [self performSearchWithValue:searchValue
                                    type:selectedTypeValue
                              comparison:VMMemComparisonEQ];
        }
    }
    
    // 隐藏弹窗
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 0;
        containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    } completion:^(BOOL finished) {
        [backgroundView removeFromSuperview];
    }];
}

// 执行浮点数范围搜索
- (void)performFloatRangeSearchWithValue:(NSString *)searchValue type:(VMMemValueType)valueType errorRange:(CGFloat)errorRange {
    // 解析搜索值为浮点数
    float searchFloat = [searchValue floatValue];
    
    // 计算误差范围内的最小值和最大值
    float minValue = searchFloat - errorRange;
    float maxValue = searchFloat + errorRange;
    
    // 将最小值转为字符串，用于搜索
    NSString *minValueString = [NSString stringWithFormat:@"%.2f", minValue];
    
    // 首先搜索大于等于最小值的结果
    [[VMTool share] searchValue:minValueString
                           type:valueType
                     comparison:VMMemComparisonGE
                       callback:^(NSInteger geCount, NSArray *geResults) {
        
        // 如果找到了结果，再搜索小于等于最大值的结果
        if (geCount > 0) {
            // 将最大值转为字符串，用于搜索
            NSString *maxValueString = [NSString stringWithFormat:@"%.2f", maxValue];
            
            // 注意：这里的逻辑是，我们先找到了>=最小值的结果，
            // 现在在这些结果中找到<=最大值的结果，这样就是范围内的所有值
            [[VMTool share] searchValue:maxValueString
                                   type:valueType
                             comparison:VMMemComparisonLE
                               callback:^(NSInteger finalCount, NSArray *finalResults) {
                
                // 保存当前搜索的数据类型
                self.currentValueType = valueType;
                
                // 保存最终搜索结果
                self.allSearchResults = finalResults;
                
                // 清空当前显示结果
                [self.displayResults removeAllObjects];
                
                // 加载第一批数据
                [self loadMoreResults];
                
                // 发送通知更新UI
                [[NSNotificationCenter defaultCenter]
                 postNotificationName:@"SearchResultUpdateNotification"
                 object:nil
                 userInfo:@{@"resultCount": @(finalCount)}];
            }];
        } else {
            // 如果没有找到大于等于最小值的结果，直接返回空结果
            // 保存当前搜索的数据类型
            self.currentValueType = valueType;
            
            // 没有结果
            self.allSearchResults = @[];
            
            // 清空当前显示结果
            [self.displayResults removeAllObjects];
            
            // 刷新表格
            [self.resultsTableView reloadData];
            
            // 发送通知更新UI
            [[NSNotificationCenter defaultCenter]
             postNotificationName:@"SearchResultUpdateNotification"
             object:nil
             userInfo:@{@"resultCount": @(0)}];
        }
    }];
}

- (void)cancelButtonTapped:(UIButton *)sender {
    // 根据按钮标签区分是哪个弹窗的取消按钮
    if (sender.tag == 1001) {
        // 搜索弹窗的取消按钮
        UIView *backgroundView = objc_getAssociatedObject(self, "backgroundView");
        UIView *containerView = objc_getAssociatedObject(self, "containerView");
    
        // 隐藏搜索弹窗
        [UIView animateWithDuration:0.3 animations:^{
            backgroundView.alpha = 0;
            containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
        } completion:^(BOOL finished) {
            [backgroundView removeFromSuperview];
        }];
    } else if (sender.tag == 1002) {
        // 修改值弹窗的取消按钮
        [self closeModifyValueAlert];
    } else if (sender.tag == 1003) {
        // 全改弹窗的取消按钮
        [self closeModifyAllAlert];
    } else {
        // 如果没有标签，尝试判断是哪个弹窗
        UIView *modifyBackgroundView = objc_getAssociatedObject(self, "modifyBackgroundView");
        UIView *searchBackgroundView = objc_getAssociatedObject(self, "backgroundView");
        UIView *modifyAllBackgroundView = objc_getAssociatedObject(self, "modifyAllBackgroundView");
        
        // 先检查sender是否在修改值弹窗内
        if (modifyBackgroundView && [self isView:sender inHierarchyOfView:modifyBackgroundView]) {
            [self closeModifyValueAlert];
            return;
        }
        
        // 检查sender是否在全改弹窗内
        if (modifyAllBackgroundView && [self isView:sender inHierarchyOfView:modifyAllBackgroundView]) {
            [self closeModifyAllAlert];
            return;
        }
        
        // 检查sender是否在搜索弹窗内
        if (searchBackgroundView && [self isView:sender inHierarchyOfView:searchBackgroundView]) {
            [UIView animateWithDuration:0.3 animations:^{
                searchBackgroundView.alpha = 0;
                UIView *containerView = objc_getAssociatedObject(self, "containerView");
                containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
            } completion:^(BOOL finished) {
                [searchBackgroundView removeFromSuperview];
            }];
        }
    }
}

// 辅助方法：检查一个视图是否在另一个视图的层级内
- (BOOL)isView:(UIView *)view inHierarchyOfView:(UIView *)containerView {
    UIView *parentView = view;
    while (parentView != nil) {
        if (parentView == containerView) {
            return YES;
        }
        parentView = parentView.superview;
    }
    return NO;
}

- (BOOL)validateInput:(NSString *)input forType:(NSString *)type {
    // 如果是字符串类型，所有输入都是有效的
    if ([type isEqualToString:@"Str"]) {
        return YES;
    }
    
    // 其他类型按照原有逻辑验证
    BOOL isSignedMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"FloatSignMode"];
    
    // 检查是否是浮点数类型
    BOOL isFloatType = [type isEqualToString:@"F32"] || [type isEqualToString:@"F64"];
    
    // 检查是否是整数类型
    BOOL isIntegerType = [type isEqualToString:@"I8"] || [type isEqualToString:@"I16"] ||
                         [type isEqualToString:@"I32"] || [type isEqualToString:@"I64"];
    
    // 无符号模式下不允许负数
    if (!isSignedMode && [input hasPrefix:@"-"]) {
        return NO;
    }
    
    NSCharacterSet *nonDigitSet;
    if (isFloatType) {
        // 浮点数可以包含 ., -, e, E, +
        nonDigitSet = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789.eE+-"] invertedSet];
    } else if (isIntegerType) {
        // 整数只能包含 - 和数字
        nonDigitSet = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789-"] invertedSet];
        } else {
        // 未知类型，使用默认验证
        return YES;
    }
    
    // 检查是否包含非法字符
    NSRange range = [input rangeOfCharacterFromSet:nonDigitSet];
    return range.location == NSNotFound;
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                           style:UIAlertActionStyleDefault
                                                         handler:nil];
        
        [alert addAction:okAction];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger count = self.displayResults.count;
    NSLog(@"[调试] numberOfRowsInSection 返回: %ld, allSearchResults.count: %ld", (long)count, (long)self.allSearchResults.count);

    // 🚨 紧急修复：如果displayResults为空但allSearchResults有数据，立即加载
    if (count == 0 && self.allSearchResults.count > 0) {
        NSLog(@"[紧急修复] displayResults为空但有搜索结果，立即加载数据");
        NSInteger loadCount = MIN(self.batchSize, self.allSearchResults.count);
        NSArray *firstBatch = [self.allSearchResults subarrayWithRange:NSMakeRange(0, loadCount)];
        [self.displayResults addObjectsFromArray:firstBatch];
        count = self.displayResults.count;
        NSLog(@"[紧急修复] 加载完成，新的count: %ld", (long)count);

        // 异步刷新表格
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.resultsTableView reloadData];
        });
    }

    return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"[调试] cellForRowAtIndexPath - row: %ld, displayResults.count: %ld", (long)indexPath.row, (long)self.displayResults.count);

    static NSString *cellIdentifier = @"SearchResultCell";

    SearchResultCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[SearchResultCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        NSLog(@"[调试] 创建新的SearchResultCell");
    }

    // 安全检查：确保索引有效
    if (indexPath.row >= self.displayResults.count) {
        NSLog(@"[错误] 索引超出范围: row=%ld, count=%ld", (long)indexPath.row, (long)self.displayResults.count);
        return cell;
    }

    // 获取当前行的数据 - MemModel类型
    MemModel *resultItem = self.displayResults[indexPath.row];
    NSLog(@"[调试] 获取到MemModel - 地址: %@, 值: %@", resultItem.address, resultItem.value);
    
    // 获取内存权限信息
    NSString *permissions = [resultItem permissionString];
    if (!permissions || [permissions isEqualToString:@"[---]"]) {
        permissions = @"[权限未知]";
    }

    // 获取模块信息
    NSString *moduleName = [self findModuleNameForAddress:resultItem.address];

    // 配置单元格
    [cell setupWithAddress:resultItem.address value:resultItem.value permissions:permissions moduleName:moduleName index:(indexPath.row + 1)];
    NSLog(@"[调试] 配置单元格完成 - 地址: %@, 值: %@, 权限: %@, 模块: %@", resultItem.address, resultItem.value, permissions, moduleName);
    
    // 设置信息按钮的点击事件
    [cell.infoButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents]; // 清除旧的目标
    [cell.infoButton addTarget:self action:@selector(infoButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    cell.infoButton.tag = indexPath.row; // 使用行索引作为标签
    
    // 在选择模式下设置选中状态
    if (self.isSelectionModeActive) {
        // 检查当前项是否被选中
        BOOL isSelected = [self.selectedItems containsObject:resultItem.address];
        [cell setSelectionModeActive:YES selected:isSelected]; // 修改这里，确保传入YES
    } else {
        // 非选择模式下，清除选中状态
        [cell setSelectionModeActive:NO selected:NO];
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0; // 保持原来的单元格高度
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // 获取选中的数据
    MemModel *selectedItem = self.displayResults[indexPath.row];
    
    if (self.isSelectionModeActive) {
        // 选择模式下，切换选中状态
        NSString *address = selectedItem.address;
        
        if ([self.selectedItems containsObject:address]) {
            // 如果已经选中，则取消选中
            [self.selectedItems removeObject:address];
        } else {
            // 如果未选中，则选中
            [self.selectedItems addObject:address];
        }
        
        // 刷新单元格显示
        [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        
        // 更新选中计数
        [self updateSelectionCountLabel];
    } else {
        // 非选择模式下，显示修改值弹窗
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self showModifyValueAlertForAddress:selectedItem.address currentValue:selectedItem.value];
    }
}

// 显示修改值的弹窗
- (void)showModifyValueAlertForAddress:(NSString *)address currentValue:(NSString *)currentValue {
    // 定义固定尺寸
    CGFloat containerWidth = 300;
    CGFloat containerHeight = 190;
    
    // 创建背景遮罩
    UIView *backgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
    backgroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    backgroundView.alpha = 0;
    
    // 创建容器视图
    UIView *containerView = [[UIView alloc] initWithFrame:CGRectMake(
        (self.view.bounds.size.width - containerWidth) / 2,
        (self.view.bounds.size.height - containerHeight) / 2 - 40,
        containerWidth,
        containerHeight
    )];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        containerView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        containerView.layer.borderWidth = 0.5;
        containerView.layer.borderColor = [UIColor systemGrayColor].CGColor;
    } else {
        containerView.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.96 alpha:1.0];
        containerView.layer.borderWidth = 0.5;
        containerView.layer.borderColor = [UIColor colorWithWhite:0.85 alpha:1.0].CGColor;
    }
    
    containerView.layer.cornerRadius = 15;
    containerView.layer.shadowColor = [UIColor blackColor].CGColor;
    containerView.layer.shadowOffset = CGSizeMake(0, 4);
    containerView.layer.shadowOpacity = 0.1;
    containerView.layer.shadowRadius = 10;
    containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 5, containerWidth - 40, 30)];
    titleLabel.text = @"修改值";
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        titleLabel.textColor = [UIColor labelColor];
    } else {
        titleLabel.textColor = [UIColor darkTextColor];
    }
    
    // 地址和当前值信息标签
    UILabel *addressLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 35, containerWidth - 40, 20)];
    addressLabel.text = [NSString stringWithFormat:@"地址: %@", address];
    addressLabel.font = [UIFont systemFontOfSize:14];
    addressLabel.textAlignment = NSTextAlignmentCenter;
    
    // 类型分段控件
    NSArray *allKeys = [[VMTool share] allKeys];
    UISegmentedControl *typeSegment = [[UISegmentedControl alloc] initWithItems:allKeys];
    typeSegment.frame = CGRectMake(20, 60, containerWidth - 40, 30);
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        typeSegment.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        typeSegment.selectedSegmentTintColor = [UIColor systemBlueColor];
    }
    
    // 根据当前值类型自动选择对应的分段
    NSDictionary *keyValues = [[VMTool share] keyValues];
    NSInteger defaultSelectedIndex = 0; // 默认选择第一个
    
    // 查找当前类型对应的索引
    for (NSInteger i = 0; i < allKeys.count; i++) {
        NSString *key = allKeys[i];
        if ([keyValues[key] integerValue] == self.currentValueType) {
            defaultSelectedIndex = i;
            break;
        }
    }
    
    typeSegment.selectedSegmentIndex = defaultSelectedIndex;
    
    // 输入框
    UITextField *valueTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 100, containerWidth - 40, 35)];
    valueTextField.placeholder = @"请输入新值";
    valueTextField.text = currentValue;
    valueTextField.borderStyle = UITextBorderStyleRoundedRect;
    valueTextField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    valueTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        valueTextField.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        valueTextField.textColor = [UIColor labelColor];
        valueTextField.attributedPlaceholder = [[NSAttributedString alloc]
            initWithString:@"请输入新值"
            attributes:@{NSForegroundColorAttributeName: [UIColor secondaryLabelColor]}];
    } else {
        valueTextField.backgroundColor = [UIColor colorWithWhite:0.98 alpha:1];
        valueTextField.textColor = [UIColor darkTextColor];
    }
    
    // 确认按钮
    UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
    confirmButton.frame = CGRectMake(containerWidth / 2 + 10, 145, (containerWidth - 60) / 2, 35);
    [confirmButton setTitle:@"确定" forState:UIControlStateNormal];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        confirmButton.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.2 green:0.22 blue:0.25 alpha:1.0];
            } else {
                return [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0];
            }
        }];
        [confirmButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        confirmButton.backgroundColor = [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0];
        [confirmButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    
    confirmButton.layer.cornerRadius = 8;
    
    // 取消按钮
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.frame = CGRectMake(20, 145, (containerWidth - 60) / 2, 35);
    [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        cancelButton.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.18 green:0.18 blue:0.2 alpha:1.0];
            } else {
                return [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
            }
        }];
        [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        cancelButton.backgroundColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
        [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    
    cancelButton.layer.cornerRadius = 8;
    
    // 添加视图
    [containerView addSubview:titleLabel];
    [containerView addSubview:addressLabel];
    [containerView addSubview:typeSegment];
    [containerView addSubview:valueTextField];
    [containerView addSubview:confirmButton];
    [containerView addSubview:cancelButton];
    
    [backgroundView addSubview:containerView];
    [self.view addSubview:backgroundView];
    
    // 设置标签用于区分修改值弹窗的按钮
    cancelButton.tag = 1002; // 修改值弹窗的取消按钮标签
    
    // 确认按钮点击事件
    [confirmButton addTarget:self action:@selector(confirmButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 取消按钮点击事件
    [cancelButton addTarget:self action:@selector(cancelButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    // 类型分段控件值改变事件
    [typeSegment addTarget:self action:@selector(modifyTypeSegmentChanged:) forControlEvents:UIControlEventValueChanged];

    // 存储引用以便在按钮回调中访问
    objc_setAssociatedObject(self, "modifyBackgroundView", backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "modifyContainerView", containerView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "modifyValueTextField", valueTextField, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "modifyTypeSegment", typeSegment, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "modifyAddress", address, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 动画显示
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 1;
        containerView.transform = CGAffineTransformIdentity;
    }];
}

// 确认按钮点击事件处理
- (void)confirmButtonTapped:(UIButton *)sender {
    UITextField *valueTextField = objc_getAssociatedObject(self, "modifyValueTextField");
    UISegmentedControl *typeSegment = objc_getAssociatedObject(self, "modifyTypeSegment");
    NSString *address = objc_getAssociatedObject(self, "modifyAddress");
    
    NSString *newValue = valueTextField.text;
    NSInteger selectedTypeIndex = typeSegment.selectedSegmentIndex;
    
    // 检查输入是否为空字符串
        if (newValue.length > 0) {
        // 根据选择的类型获取对应的VMMemValueType
        NSArray *allKeys = [[VMTool share] allKeys];
        NSString *selectedType = allKeys[selectedTypeIndex];
        VMMemValueType modifyType = (VMMemValueType)[[[VMTool share] keyValues][selectedType] integerValue];

        // 根据搜索模式选择修改方法
        if (self.isTraditionalSearch) {
            // 传统搜索模式：使用VMTool修改内存值
            [[VMTool share] modifyValue:newValue address:address type:modifyType];
        } else {
            // 高效搜索模式：使用RXMemSearchEngine修改内存值
            RXValueType rxValueType = [self convertVMValueTypeToRXValueType:modifyType];
            RXMemSearchEngine *rxEngine = [RXMemSearchEngine sharedEngine];
            BOOL success = [rxEngine writeValue:newValue toAddress:address type:rxValueType];

            if (!success) {
                NSLog(@"❌ 高效搜索模式：内存值修改失败");
                // 如果RX引擎修改失败，可以考虑回退到VMTool
                [[VMTool share] modifyValue:newValue address:address type:modifyType];
            }
        }

        [self refreshAfterModifyWithAddress:address];
    }
    
    // 关闭弹窗
    [self closeModifyValueAlert];
}

// 关闭修改值弹窗
- (void)closeModifyValueAlert {
    UIView *backgroundView = objc_getAssociatedObject(self, "modifyBackgroundView");
    UIView *containerView = objc_getAssociatedObject(self, "modifyContainerView");

    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 0;
        containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    } completion:^(BOOL finished) {
        [backgroundView removeFromSuperview];

        // 清除关联对象，防止内存泄漏
        objc_setAssociatedObject(self, "modifyBackgroundView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "modifyContainerView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "modifyValueTextField", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "modifyTypeSegment", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "modifyAddress", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }];
}

// 修改值弹窗中类型分段控件值改变事件处理
- (void)modifyTypeSegmentChanged:(UISegmentedControl *)sender {
    UITextField *valueTextField = objc_getAssociatedObject(self, "modifyValueTextField");
    NSString *address = objc_getAssociatedObject(self, "modifyAddress");

    if (!valueTextField || !address) {
        return;
    }

    // 获取选中的类型
    NSArray *allKeys = [[VMTool share] allKeys];
    if (sender.selectedSegmentIndex >= 0 && sender.selectedSegmentIndex < allKeys.count) {
        NSString *selectedType = allKeys[sender.selectedSegmentIndex];

        // 根据选中的类型重新读取内存值
        NSString *currentValue = [self readMemoryValueAtAddress:address withType:selectedType];

        // 更新输入框的值
        valueTextField.text = currentValue;
    }
}

// 根据指定类型读取指定地址的内存值
- (NSString *)readMemoryValueAtAddress:(NSString *)address withType:(NSString *)typeKey {
    if (!address || !typeKey) {
        return @"0";
    }

    // 根据类型键获取对应的VMMemValueType
    VMMemValueType valueType = VMMemValueTypeSignedInt; // 默认值

    if ([typeKey isEqualToString:@"F32"]) {
        valueType = VMMemValueTypeFloat;
    } else if ([typeKey isEqualToString:@"F64"]) {
        valueType = VMMemValueTypeDouble;
    } else if ([typeKey isEqualToString:@"I8"]) {
        valueType = VMMemValueTypeSignedByte;
    } else if ([typeKey isEqualToString:@"I16"]) {
        valueType = VMMemValueTypeSignedShort;
    } else if ([typeKey isEqualToString:@"I32"]) {
        valueType = VMMemValueTypeSignedInt;
    } else if ([typeKey isEqualToString:@"I64"]) {
        valueType = VMMemValueTypeSignedLong;
    } else if ([typeKey isEqualToString:@"Str"]) {
        valueType = VMMemValueTypeStr;
    }

    // 使用VMTool读取内存值
    NSString *result = [[VMTool share] getValueFromAddress:address valueType:valueType];

    return result ?: @"0";
}

// 根据当前搜索类型读取指定地址的内存值
- (NSString *)readMemoryValueAtAddress:(NSString *)address withCurrentType:(VMMemValueType)valueType {
    if (!address) {
        return @"0";
    }

    // 使用VMTool读取内存值
    NSString *result = [[VMTool share] getValueFromAddress:address valueType:valueType];

    return result ?: @"0";
}

// 修改值后刷新搜索结果
- (void)refreshAfterModifyWithAddress:(NSString *)address {
    if (self.isTraditionalSearch) {
        // 传统搜索模式：使用VMTool的refresh方法
        [[VMTool share] refreshWithCallback:^(NSInteger count, NSArray *array) {
            // 过滤掉已删除的地址
            if (self.deletedAddresses.count > 0) {
                NSMutableArray *filteredResults = [NSMutableArray array];

                for (MemModel *item in array) {
                    if (![self.deletedAddresses containsObject:item.address]) {
                        [filteredResults addObject:item];
                    }
                }

                self.allSearchResults = [NSArray arrayWithArray:filteredResults];
            } else {
                self.allSearchResults = array;
            }

            // 清空并重新加载显示结果
            [self.displayResults removeAllObjects];
            [self loadMoreResults];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.resultsTableView reloadData];

                // 更新搜索结果计数
                [self updateSearchResultCount:self.allSearchResults.count];
            });
        }];
    } else {
        // 高效搜索模式：直接更新内存中的搜索结果，不清零搜索状态
        [self refreshEfficientSearchResults];
    }
}

// 高效搜索模式下刷新搜索结果（不清零搜索状态）
- (void)refreshEfficientSearchResults {
    if (self.allSearchResults.count == 0) {
        return;
    }

    NSLog(@"⚡ 高效搜索模式：刷新内存值，保持搜索状态");

    // 在后台线程重新读取所有地址的内存值
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *updatedResults = [NSMutableArray array];

        for (MemModel *item in self.allSearchResults) {
            // 跳过已删除的地址
            if ([self.deletedAddresses containsObject:item.address]) {
                continue;
            }

            // 重新读取内存值（读取操作不影响搜索引擎状态，可以继续使用VMTool）
            NSString *updatedValue = [self readMemoryValueAtAddress:item.address withCurrentType:self.currentValueType];

            if (updatedValue) {
                // 创建新的MemModel对象，保持地址不变，更新值
                MemModel *updatedItem = [[MemModel alloc] init];
                updatedItem.address = item.address;
                updatedItem.value = updatedValue;
                updatedItem.type = item.type;

                // 保持原有的权限信息
                updatedItem.protection = item.protection;

                // 如果原有权限信息为空，尝试重新获取
                if (updatedItem.protection == 0) {
                    // 转换地址为vm_address_t
                    vm_address_t addr = strtoull([item.address UTF8String], NULL, 16);
                    RXMemSearchEngine *rxEngine = [RXMemSearchEngine sharedEngine];
                    int protection = [rxEngine getMemoryProtectionForAddress:addr];
                    updatedItem.protection = protection;
                }

                [updatedResults addObject:updatedItem];
            }
        }

        // 在主线程更新UI
        dispatch_async(dispatch_get_main_queue(), ^{
            // 更新搜索结果
            self.allSearchResults = [NSArray arrayWithArray:updatedResults];

            // 清空并重新加载显示结果
            [self.displayResults removeAllObjects];
            [self loadMoreResults];

            // 刷新表格
            [self.resultsTableView reloadData];

            // 更新搜索结果计数
            [self updateSearchResultCount:self.allSearchResults.count];

            NSLog(@"⚡ 高效搜索结果已刷新，保持 %lu 条结果", (unsigned long)self.allSearchResults.count);
        });
    });
}

// 加载更多搜索结果
- (void)loadMoreResults {
    NSLog(@"[调试] loadMoreResults 开始 - isLoadingMore: %d", self.isLoadingMore);

    // 防止重复加载
    if (self.isLoadingMore) {
        NSLog(@"[调试] 正在加载中，跳过");
        return;
    }

    // 安全检查：确保数据源存在
    if (!self.displayResults) {
        NSLog(@"[错误] 显示数据源未初始化，停止加载");
        return;
    }

    self.isLoadingMore = YES;

    // 计算下一批数据的范围
    NSInteger currentCount = self.displayResults.count;
    NSInteger totalCount = self.totalResultCount > 0 ? self.totalResultCount : self.allSearchResults.count;

    NSLog(@"[调试] 当前显示数量: %ld, 总数量: %ld, 批次大小: %ld",
          (long)currentCount, (long)totalCount, (long)self.batchSize);

    // 已经加载完所有数据
    if (currentCount >= totalCount) {
        NSLog(@"[调试] 已加载完所有数据");
        self.isLoadingMore = NO;
        return;
    }

    // 计算本次要加载的数量
    NSInteger remainingCount = totalCount - currentCount;
    NSInteger loadCount = MIN(self.batchSize, remainingCount);

    NSLog(@"[调试] 剩余数量: %ld, 本次加载数量: %ld", (long)remainingCount, (long)loadCount);

    // 安全检查：确保范围有效
    if (currentCount >= totalCount || loadCount <= 0) {
        NSLog(@"[调试] 范围无效，停止加载");
        self.isLoadingMore = NO;
        return;
    }
    
    // 根据搜索模式和数据类型选择不同的加载方式
    if (!self.isTraditionalSearch && self.totalResultCount > currentCount) {
        // 检查当前搜索类型
        if (self.currentValueType == VMMemValueTypeStr) {
            // 字符串搜索：BitSlicerStringSearcher一次性返回所有结果，使用传统方式加载
            NSLog(@"[调试] 字符串搜索使用传统方式加载更多结果");

            // 安全检查：确保allSearchResults存在
            if (!self.allSearchResults || self.allSearchResults.count == 0) {
                NSLog(@"[错误] allSearchResults为空，停止加载");
                self.isLoadingMore = NO;
                return;
            }

            // 从allSearchResults中获取下一批数据
            NSRange loadRange = NSMakeRange(currentCount, loadCount);
            if (NSMaxRange(loadRange) > self.allSearchResults.count) {
                loadRange.length = self.allSearchResults.count - currentCount;
            }

            NSArray *nextBatch = [self.allSearchResults subarrayWithRange:loadRange];
            NSLog(@"[调试] 字符串搜索获取到下一批数据: %ld 条", (long)nextBatch.count);

            // 添加到显示数组
            [self.displayResults addObjectsFromArray:nextBatch];
            NSLog(@"[调试] 添加后displayResults数量: %ld", (long)self.displayResults.count);

            // 增量更新表格
            if (currentCount > 0) {
                NSLog(@"[调试] 执行增量更新");
                [self insertRowsForNewResults:nextBatch startingAtIndex:currentCount];
            } else {
                NSLog(@"[调试] 初始加载，不执行增量更新");
            }
        } else {
            // 数值搜索：使用RX引擎的增量加载方式
            NSLog(@"[调试] 数值搜索使用RX引擎增量加载更多结果");

            RXMemSearchEngine *rxEngine = [RXMemSearchEngine sharedEngine];
            // 安全检查：确保RX引擎存在且有搜索结果
            if (!rxEngine || !rxEngine.lastSearchResult) {
                NSLog(@"[错误] RX引擎或搜索结果为空，停止加载");
                self.isLoadingMore = NO;
                return;
            }

            NSArray *nextBatch = [rxEngine loadMoreResultsFromOffset:(uint32_t)currentCount count:(uint32_t)loadCount];

            if (nextBatch && nextBatch.count > 0) {
                NSLog(@"[调试] RX引擎获取到下一批数据: %lu 条", (unsigned long)nextBatch.count);

                // 添加到显示数组
                [self.displayResults addObjectsFromArray:nextBatch];
                NSLog(@"[调试] 添加后displayResults数量: %ld", (long)self.displayResults.count);

                // 增量更新表格
                if (currentCount > 0) {
                    NSLog(@"[调试] 执行增量更新");
                    [self insertRowsForNewResults:nextBatch startingAtIndex:currentCount];
                } else {
                    NSLog(@"[调试] 初始加载，不执行增量更新");
                }
            } else {
                NSLog(@"[警告] RX引擎未返回有效数据");
            }
        }
    } else {
        // 传统方式：从已有结果中加载
        NSLog(@"[调试] 使用传统方式加载更多结果");
        
        // 获取下一批数据
        NSRange loadRange = NSMakeRange(currentCount, loadCount);
        NSLog(@"[调试] 加载范围: location=%ld, length=%ld", (long)loadRange.location, (long)loadRange.length);
        
        // 再次检查范围是否超出数组边界
        if (NSMaxRange(loadRange) > self.allSearchResults.count) {
            NSLog(@"[错误] 范围超出数组边界: NSMaxRange=%ld, totalCount=%ld", 
                  (long)NSMaxRange(loadRange), (long)self.allSearchResults.count);
            self.isLoadingMore = NO;
            return;
        }
        
        NSArray *nextBatch = [self.allSearchResults subarrayWithRange:loadRange];
        NSLog(@"[调试] 获取到下一批数据: %ld 条", (long)nextBatch.count);
        
        // 添加到显示数组
        [self.displayResults addObjectsFromArray:nextBatch];
        NSLog(@"[调试] 添加后displayResults数量: %ld", (long)self.displayResults.count);
        
        // 只有在非初始加载时才使用增量更新
        if (currentCount > 0) {
            NSLog(@"[调试] 执行增量更新");
            // 使用增量更新而不是完全重新加载表格
            [self insertRowsForNewResults:nextBatch startingAtIndex:currentCount];
        } else {
            NSLog(@"[调试] 初始加载，不执行增量更新");
        }
    }

    self.isLoadingMore = NO;
    NSLog(@"[调试] loadMoreResults 完成");
}

// 新增方法：增量插入新行
- (void)insertRowsForNewResults:(NSArray *)newResults startingAtIndex:(NSInteger)startIndex {
    if (!newResults || newResults.count == 0) {
        return;
    }

    // 安全检查：确保表格视图存在
    if (!self.resultsTableView) {
        NSLog(@"[错误] 表格视图未初始化");
        return;
    }

    // 创建要插入的索引路径
    NSMutableArray *indexPaths = [[NSMutableArray alloc] initWithCapacity:newResults.count];
    for (NSInteger i = 0; i < newResults.count; i++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:startIndex + i inSection:0];
        [indexPaths addObject:indexPath];
    }

    // 使用try-catch包装表格更新，防止闪退
    @try {
        [self.resultsTableView beginUpdates];
        [self.resultsTableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
        [self.resultsTableView endUpdates];
    } @catch (NSException *exception) {
        NSLog(@"[错误] 表格插入行时发生异常: %@", exception.reason);
        // 发生异常时，使用完全重新加载作为备选方案
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.resultsTableView reloadData];
        });
    }
}

// 新增方法：统一处理搜索结果更新（优化版本）
- (void)updateSearchResultsWithArray:(NSArray *)array count:(NSInteger)count {
    // 性能监控：记录UI更新开始时间
    NSTimeInterval uiUpdateStartTime = [[NSDate date] timeIntervalSince1970];
    NSLog(@"[UI性能监控] 开始更新搜索结果UI - 结果数: %ld, 数组实际长度: %ld", (long)count, (long)array.count);

    // 安全检查：防止空指针导致闪退
    if (!array) {
        NSLog(@"[错误] 搜索结果数组为空，停止更新");
        array = @[];
        count = 0;
    }

    // 🚨 内存保护：检查结果数量是否过大
    const NSInteger MAX_SAFE_RESULTS = 10000000; // 1000万条结果作为安全上限
    if (array.count > MAX_SAFE_RESULTS) {
        NSLog(@"[内存保护] 搜索结果过多 (%ld 条)，为防止内存溢出，将限制为 %ld 条", (long)array.count, (long)MAX_SAFE_RESULTS);

        // 截取前面的安全数量
        array = [array subarrayWithRange:NSMakeRange(0, MAX_SAFE_RESULTS)];
        count = MAX_SAFE_RESULTS;

        // 在主线程显示警告
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *message = [NSString stringWithFormat:@"搜索结果过多，为防止内存溢出已限制显示前 %ld 条结果。\n\n建议：\n1. 缩小搜索范围\n2. 使用更精确的搜索条件\n3. 降低结果限制设置", (long)MAX_SAFE_RESULTS];
            [self showAlertWithTitle:@"内存保护提醒" message:message];
        });
    }

    // 调试日志：检查数组内容
    if (array.count > 0) {
        NSLog(@"[调试] 搜索结果数组第一个元素类型: %@", NSStringFromClass([array.firstObject class]));
        if ([array.firstObject isKindOfClass:[MemModel class]]) {
            MemModel *firstItem = array.firstObject;
            NSLog(@"[调试] 第一个MemModel - 地址: %@, 值: %@", firstItem.address, firstItem.value);
        }
    } else {
        NSLog(@"[警告] 搜索结果数组为空，但count为: %ld", (long)count);
    }

    // 优化：所有数据和UI更新都在主队列中进行，确保一致性
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            NSLog(@"[警告] SearchViewController已被释放，跳过UI更新");
            return;
        }

        // 保存所有搜索结果
        strongSelf.allSearchResults = array;
        NSLog(@"[调试] 保存搜索结果 - allSearchResults.count: %ld", (long)strongSelf.allSearchResults.count);
        
        // 设置总结果数量，用于增量加载
        strongSelf.totalResultCount = count;
        NSLog(@"[调试] 设置总结果数量 - totalResultCount: %ld", (long)strongSelf.totalResultCount);

        // 清空当前显示结果
        [strongSelf.displayResults removeAllObjects];
        NSLog(@"[调试] 清空displayResults后 - displayResults.count: %ld", (long)strongSelf.displayResults.count);

        // 🔧 修复：确保有数据时直接加载第一批
        if (strongSelf.allSearchResults.count > 0) {
            NSInteger loadCount = MIN(strongSelf.batchSize, strongSelf.allSearchResults.count);
            NSArray *firstBatch = [strongSelf.allSearchResults subarrayWithRange:NSMakeRange(0, loadCount)];
            [strongSelf.displayResults addObjectsFromArray:firstBatch];
            NSLog(@"[修复] 直接加载第一批数据: %ld 条", (long)firstBatch.count);
        }

        NSLog(@"[调试] 修复后displayResults.count: %ld", (long)strongSelf.displayResults.count);

        // 🚨 关键修复：确保表格视图在数据准备完成后才刷新
        if (strongSelf.displayResults.count > 0) {
            NSLog(@"[关键修复] 有数据，立即刷新表格");
            [strongSelf.resultsTableView reloadData];

            // 🔥 最终修复：多重保险刷新
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSLog(@"[最终修复] 0.05秒后确认刷新，displayResults.count: %ld", (long)strongSelf.displayResults.count);
                if (strongSelf.displayResults.count > 0) {
                    // 🔍 调试表格视图状态
                    NSLog(@"[调试] 表格视图状态检查:");
                    NSLog(@"  - frame: %@", NSStringFromCGRect(strongSelf.resultsTableView.frame));
                    NSLog(@"  - hidden: %d", strongSelf.resultsTableView.hidden);
                    NSLog(@"  - alpha: %.2f", strongSelf.resultsTableView.alpha);
                    NSLog(@"  - superview: %@", strongSelf.resultsTableView.superview);
                    NSLog(@"  - numberOfSections: %ld", (long)[strongSelf.resultsTableView numberOfSections]);
                    NSLog(@"  - numberOfRows: %ld", (long)[strongSelf.resultsTableView numberOfRowsInSection:0]);

                    // 🔍 调试视图层级
                    NSLog(@"[调试] 主视图子视图数量: %ld", (long)strongSelf.view.subviews.count);
                    for (NSInteger i = 0; i < strongSelf.view.subviews.count; i++) {
                        UIView *subview = strongSelf.view.subviews[i];
                        NSLog(@"  - 子视图[%ld]: %@ frame:%@", (long)i, NSStringFromClass([subview class]), NSStringFromCGRect(subview.frame));
                    }

                    // 确保表格视图可见
                    strongSelf.resultsTableView.hidden = NO;
                    strongSelf.resultsTableView.alpha = 1.0;

                    [strongSelf.resultsTableView reloadData];

                    // 强制滚动到顶部，确保显示
                    if (strongSelf.displayResults.count > 0) {
                        [strongSelf.resultsTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                                                           atScrollPosition:UITableViewScrollPositionTop
                                                                   animated:NO];
                    }

                    // 🚨 最后的手段：强制重新布局
                    [strongSelf.view setNeedsLayout];
                    [strongSelf.view layoutIfNeeded];
                    [strongSelf.resultsTableView setNeedsLayout];
                    [strongSelf.resultsTableView layoutIfNeeded];
                }
            });
        } else {
            NSLog(@"[警告] displayResults为空，不刷新表格");
        }

        // 更新搜索结果计数
        [strongSelf updateSearchResultCount:count];

        NSTimeInterval uiUpdateEndTime = [[NSDate date] timeIntervalSince1970];
        NSLog(@"[UI性能监控] 搜索结果UI更新完成 - 耗时: %.3f秒", uiUpdateEndTime - uiUpdateStartTime);
    });

    // 发送通知更新UI（不需要等待主队列）
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"SearchResultUpdateNotification"
     object:nil
     userInfo:@{@"resultCount": @(count)}];
}





// 清除全部搜索结果
- (void)clearAllSearchResults {
    // 使用try-catch包装，防止清除过程中的异常导致闪退
    @try {
        NSLog(@"[清除] 开始清除全部搜索结果");
        
        // 如果使用高效搜索引擎，需要重置RX搜索引擎
        if (!self.isTraditionalSearch) {
            RXMemSearchEngine *rxEngine = [RXMemSearchEngine sharedEngine];
            if (rxEngine) {
                [rxEngine reset];
                NSLog(@"[清除] 已重置RX搜索引擎");
            }
        }
        
        // 重置VMTool
        [[VMTool share] reset];
        NSLog(@"[清除] 已重置VMTool");

        // 重置搜索结果
        [self resetSearchResults];
        NSLog(@"[清除] 已重置搜索结果");

        // 如果在选择模式，退出选择模式
        if (self.isSelectionModeActive) {
            [self exitSelectionMode];
            NSLog(@"[清除] 已退出选择模式");
        }
        
        NSLog(@"[清除] 清除全部搜索结果完成");
    } @catch (NSException *exception) {
        NSLog(@"[错误] 清除搜索结果时发生异常: %@", exception.reason);
        
        // 确保基本状态被重置
        self.allSearchResults = @[];
        [self.displayResults removeAllObjects];
        self.totalResultCount = 0;
        self.isLoadingMore = NO;
        [self.resultsTableView reloadData];
        [self updateSearchResultCount:0];
    }
}

// 重置搜索结果
- (void)resetSearchResults {
    self.allSearchResults = @[];
    [self.displayResults removeAllObjects];
    [self.deletedAddresses removeAllObjects]; // 清空已删除地址集合
    self.totalResultCount = 0; // 重置总结果计数
    self.isLoadingMore = NO; // 重置加载状态
    [self.resultsTableView reloadData];
    [self updateSearchResultCount:0];
}

- (void)searchSwitchChanged:(UISwitch *)sender {
    self.isNearbySearch = sender.isOn;
    
    // 更新"数值"按钮的标题
    UIButton *valueButton = self.buttonStackView.arrangedSubviews[2]; // 数值按钮是第三个按钮
    if (self.isNearbySearch) {
        [valueButton setTitle:@"临近" forState:UIControlStateNormal];
    } else {
        [valueButton setTitle:@"数值" forState:UIControlStateNormal];
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // 当用户滚动到接近底部时，加载更多数据
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentHeight = scrollView.contentSize.height;
    CGFloat screenHeight = scrollView.frame.size.height;
    
    // 当滚动到距离底部100像素时，触发加载更多
    if (offsetY > contentHeight - screenHeight - 100) {
        // 检查是否正在加载、是否还有更多数据可加载
        if (!self.isLoadingMore && 
            self.displayResults.count < self.totalResultCount) {
            
            NSLog(@"[滚动加载] 触发加载更多数据 - 当前显示: %lu, 总数: %lu", 
                  (unsigned long)self.displayResults.count, 
                  (unsigned long)self.totalResultCount);
            
            [self loadMoreResults];
        }
    }

}

// 执行字符串搜索
- (void)performStringSearchWithValue:(NSString *)searchValue type:(VMMemValueType)valueType comparison:(VMMemComparison)comparison {
    if (self.isTraditionalSearch) {
        // 使用传统搜索
        [[VMTool share] searchValue:searchValue
                               type:valueType
                         comparison:comparison
                           callback:^(NSInteger count, NSArray *array) {
            // 保存当前搜索的数据类型
            self.currentValueType = valueType;

            // 使用统一方法更新搜索结果
            [self updateSearchResultsWithArray:array count:count];
        }];
    } else {
        // 使用高效搜索（BitSlicerStringSearcher）
        NSLog(@"⚡ 使用BitSlicer字符串搜索引擎搜索字符串: %@", searchValue);

        // 确保BitSlicer搜索引擎已连接到当前进程
        BitSlicerStringSearcher *stringSearcher = [BitSlicerStringSearcher sharedInstance];
        NSString *pidString = [ProcessManager sharedManager].selectedProcessPID;
        if (pidString) {
            pid_t pid = [pidString intValue];
            if ([stringSearcher currentPid] != pid) {
                BOOL attached = [stringSearcher attachToProcess:pid];
                if (!attached) {
                    NSLog(@"❌ BitSlicer字符串搜索引擎连接进程失败: %d", pid);
                    // 回退到传统搜索
                    [[VMTool share] searchValue:searchValue
                                           type:valueType
                                     comparison:comparison
                                       callback:^(NSInteger count, NSArray *array) {
                        self.currentValueType = valueType;
                        [self updateSearchResultsWithArray:array count:count];
                    }];
                    return;
                }
            }
        }

        // 执行BitSlicer字符串搜索
        [self performBitSlicerStringSearchWithValue:searchValue stringSearcher:stringSearcher];
    }
}

// 显示带回调的提示框
- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message completion:(void (^)(void))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
            if (completion) {
                completion();
            }
        }];
        
        [alert addAction:okAction];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

// 处理信息按钮点击事件
- (void)infoButtonTapped:(UIButton *)sender {
    // 获取按钮关联的地址
    NSString *address = sender.accessibilityIdentifier;
    if (!address) {
        // 尝试通过tag获取索引
        NSInteger index = sender.tag;
        if (index < self.displayResults.count) {
            MemModel *item = self.displayResults[index];
            address = item.address;
        } else {
            return;
        }
    }
    
    // 查找对应的内存模型
    MemModel *selectedItem = nil;
    for (MemModel *item in self.displayResults) {
        if ([item.address isEqualToString:address]) {
            selectedItem = item;
            break;
        }
    }
    
    if (!selectedItem && sender.tag < self.displayResults.count) {
        selectedItem = self.displayResults[sender.tag];
    }
    
    if (selectedItem) {
        // 显示选择菜单
        [self showAddressActionMenuForItem:selectedItem];
    } else {
        [self showAlertWithTitle:@"错误" message:@"无法获取内存地址信息"];
    }
}

// 显示地址操作菜单
- (void)showAddressActionMenuForItem:(MemModel *)item {
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"选择操作"
                                                                         message:[NSString stringWithFormat:@"地址: %@", item.address]
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];

    // 内存浏览器选项
    UIAlertAction *memoryBrowserAction = [UIAlertAction actionWithTitle:@"内存浏览器"
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * _Nonnull action) {
        [self openMemoryBrowserForItem:item];
    }];
    [actionSheet addAction:memoryBrowserAction];

    // 指针扫描选项
    UIAlertAction *pointerScanAction = [UIAlertAction actionWithTitle:@"指针扫描"
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * _Nonnull action) {
        [self openPointerScanForItem:item];
    }];
    [actionSheet addAction:pointerScanAction];

    // 取消选项
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [actionSheet addAction:cancelAction];

    // 对于iPad，需要设置popover的源
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        actionSheet.popoverPresentationController.sourceView = self.view;
        actionSheet.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
    }

    [self presentViewController:actionSheet animated:YES completion:nil];
}

// 打开内存浏览器
- (void)openMemoryBrowserForItem:(MemModel *)item {
    MemoryBrowserViewController *memoryVC = [[MemoryBrowserViewController alloc] initWithAddress:item.address valueType:item.type];

    // 确保导航栏可见
    self.navigationController.navigationBar.hidden = NO;

    // 使用导航控制器推入新界面
    [self.navigationController pushViewController:memoryVC animated:YES];
}

// 打开指针扫描
- (void)openPointerScanForItem:(MemModel *)item {
    PointerScanViewController *pointerScanVC = [[PointerScanViewController alloc] initWithTargetAddress:item.address];

    // 确保导航栏可见
    self.navigationController.navigationBar.hidden = NO;

    // 使用导航控制器推入新界面
    [self.navigationController pushViewController:pointerScanVC animated:YES];
}

#pragma mark - 长按手势处理

// 处理长按手势
- (void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        CGPoint touchPoint = [gestureRecognizer locationInView:self.resultsTableView];
        NSIndexPath *indexPath = [self.resultsTableView indexPathForRowAtPoint:touchPoint];
        
        if (indexPath) {
            // 获取选中的数据
            MemModel *selectedItem = self.displayResults[indexPath.row];
            // 显示保存记录弹窗
            [self showSaveRecordAlertForItem:selectedItem];
        }
    }
}

// 显示保存记录弹窗
- (void)showSaveRecordAlertForItem:(MemModel *)item {
    // 定义固定尺寸
    CGFloat containerWidth = 300;
    CGFloat containerHeight = 180;
    
    // 创建背景遮罩
    UIView *backgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
    backgroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    backgroundView.alpha = 0;
    
    // 创建容器视图
    UIView *containerView = [[UIView alloc] initWithFrame:CGRectMake(
        (self.view.bounds.size.width - containerWidth) / 2,
        (self.view.bounds.size.height - containerHeight) / 2 - 40,
        containerWidth,
        containerHeight
    )];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        containerView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    } else {
        containerView.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.96 alpha:1.0];
    }
    
    containerView.layer.cornerRadius = 15;
    containerView.layer.shadowColor = [UIColor blackColor].CGColor;
    containerView.layer.shadowOffset = CGSizeMake(0, 4);
    containerView.layer.shadowOpacity = 0.1;
    containerView.layer.shadowRadius = 10;
    containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 15, containerWidth - 40, 30)];
    titleLabel.text = @"保存到记录";
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    
    // 地址和值信息
    UILabel *infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 45, containerWidth - 40, 30)];
    infoLabel.text = [NSString stringWithFormat:@"地址: %@ 值: %@", item.address, item.value];
    infoLabel.font = [UIFont systemFontOfSize:14];
    infoLabel.textAlignment = NSTextAlignmentCenter;
    infoLabel.numberOfLines = 0;
    
    // 名称输入框
    UITextField *nameTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 85, containerWidth - 40, 35)];
    nameTextField.placeholder = @"请输入记录名称";
    nameTextField.borderStyle = UITextBorderStyleRoundedRect;
    nameTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    
    // 保存按钮
    UIButton *saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    saveButton.frame = CGRectMake(containerWidth / 2 + 10, 130, (containerWidth - 60) / 2, 35);
    [saveButton setTitle:@"保存" forState:UIControlStateNormal];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        saveButton.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.2 green:0.22 blue:0.25 alpha:1.0];
            } else {
                return [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0];
            }
        }];
        [saveButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        saveButton.backgroundColor = [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0];
        [saveButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    
    saveButton.layer.cornerRadius = 8;
    
    // 取消按钮
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.frame = CGRectMake(20, 130, (containerWidth - 60) / 2, 35);
    [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        cancelButton.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.18 green:0.18 blue:0.2 alpha:1.0];
            } else {
                return [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
            }
        }];
        [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        cancelButton.backgroundColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
        [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    
    cancelButton.layer.cornerRadius = 8;
    
    // 添加视图
    [containerView addSubview:titleLabel];
    [containerView addSubview:infoLabel];
    [containerView addSubview:nameTextField];
    [containerView addSubview:saveButton];
    [containerView addSubview:cancelButton];
    
    [backgroundView addSubview:containerView];
    [self.view addSubview:backgroundView];
    
    // 存储引用以便在按钮回调中访问
    objc_setAssociatedObject(self, "saveRecordBackgroundView", backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "saveRecordContainerView", containerView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "saveRecordNameTextField", nameTextField, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "saveRecordItem", item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 保存按钮点击事件
    [saveButton addTarget:self action:@selector(saveRecordButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 取消按钮点击事件
    [cancelButton addTarget:self action:@selector(cancelSaveRecordButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 动画显示
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 1;
        containerView.transform = CGAffineTransformIdentity;
    }];
}

// 保存记录按钮点击事件
- (void)saveRecordButtonTapped:(UIButton *)sender {
    UITextField *nameTextField = objc_getAssociatedObject(self, "saveRecordNameTextField");
    MemModel *item = objc_getAssociatedObject(self, "saveRecordItem");
    
    NSString *recordName = nameTextField.text;
    if (recordName.length == 0) {
        recordName = @"未命名记录";
    }
    
    // 创建记录数据
    NSMutableDictionary *recordData = [NSMutableDictionary dictionary];
    [recordData setObject:recordName forKey:@"recordName"];
    [recordData setObject:item.address forKey:@"address"];
    [recordData setObject:item.value forKey:@"value"];
    [recordData setObject:@(item.type) forKey:@"valueType"];
    [recordData setObject:[ProcessManager sharedManager].selectedProcessName ?: @"未知进程" forKey:@"processName"];
    [recordData setObject:[NSDate date] forKey:@"timestamp"];
    
    // 发送通知到记录界面
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AddRecordNotification" object:nil userInfo:recordData];
    
    // 直接关闭弹窗，不显示保存成功提示
    [self closeSaveRecordAlert];
}

// 取消保存记录按钮点击事件
- (void)cancelSaveRecordButtonTapped:(UIButton *)sender {
    [self closeSaveRecordAlert];
}

// 关闭保存记录弹窗
- (void)closeSaveRecordAlert {
    UIView *backgroundView = objc_getAssociatedObject(self, "saveRecordBackgroundView");
    UIView *containerView = objc_getAssociatedObject(self, "saveRecordContainerView");
    
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 0;
        containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    } completion:^(BOOL finished) {
        [backgroundView removeFromSuperview];
        
        // 清除关联对象，防止内存泄漏
        objc_setAssociatedObject(self, "saveRecordBackgroundView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "saveRecordContainerView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "saveRecordNameTextField", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "saveRecordItem", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }];
}

// 显示全改弹窗
- (void)showModifyAllValuesAlert {
    // 检查是否有搜索结果
    if (self.allSearchResults.count == 0) {
        [self showAlertWithTitle:@"提示" message:@"没有可修改的搜索结果"];
        return;
    }
    
    // 定义固定尺寸
    CGFloat containerWidth = 300;
    CGFloat containerHeight = 190;
    
    // 创建背景遮罩
    UIView *backgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
    backgroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    backgroundView.alpha = 0;
    
    // 创建容器视图
    UIView *containerView = [[UIView alloc] initWithFrame:CGRectMake(
        (self.view.bounds.size.width - containerWidth) / 2,
        (self.view.bounds.size.height - containerHeight) / 2 - 40,
        containerWidth,
        containerHeight
    )];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        containerView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        containerView.layer.borderWidth = 0.5;
        containerView.layer.borderColor = [UIColor systemGrayColor].CGColor;
    } else {
        containerView.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.96 alpha:1.0];
        containerView.layer.borderWidth = 0.5;
        containerView.layer.borderColor = [UIColor colorWithWhite:0.85 alpha:1.0].CGColor;
    }
    
    containerView.layer.cornerRadius = 15;
    containerView.layer.shadowColor = [UIColor blackColor].CGColor;
    containerView.layer.shadowOffset = CGSizeMake(0, 4);
    containerView.layer.shadowOpacity = 0.1;
    containerView.layer.shadowRadius = 10;
    containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 5, containerWidth - 40, 30)];
    titleLabel.text = @"批量修改值";
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        titleLabel.textColor = [UIColor labelColor];
    } else {
        titleLabel.textColor = [UIColor darkTextColor];
    }
    
    // 提示信息
    UILabel *infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 35, containerWidth - 40, 20)];
    infoLabel.text = [NSString stringWithFormat:@"将修改全部 %lu 条搜索结果", (unsigned long)self.allSearchResults.count];
    infoLabel.font = [UIFont systemFontOfSize:14];
    infoLabel.textAlignment = NSTextAlignmentCenter;
    
    // 类型分段控件
    NSArray *allKeys = [[VMTool share] allKeys];
    UISegmentedControl *typeSegment = [[UISegmentedControl alloc] initWithItems:allKeys];
    typeSegment.frame = CGRectMake(20, 60, containerWidth - 40, 30);
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        typeSegment.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        typeSegment.selectedSegmentTintColor = [UIColor systemBlueColor];
    }
    
    // 根据当前值类型自动选择对应的分段
    NSDictionary *keyValues = [[VMTool share] keyValues];
    NSInteger defaultSelectedIndex = 0; // 默认选择第一个
    
    // 查找当前类型对应的索引
    for (NSInteger i = 0; i < allKeys.count; i++) {
        NSString *key = allKeys[i];
        if ([keyValues[key] integerValue] == self.currentValueType) {
            defaultSelectedIndex = i;
            break;
        }
    }
    
    typeSegment.selectedSegmentIndex = defaultSelectedIndex;
    
    // 输入框
    UITextField *valueTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 100, containerWidth - 40, 35)];
    valueTextField.placeholder = @"请输入新值";
    valueTextField.borderStyle = UITextBorderStyleRoundedRect;
    valueTextField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    valueTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        valueTextField.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        valueTextField.textColor = [UIColor labelColor];
        valueTextField.attributedPlaceholder = [[NSAttributedString alloc]
            initWithString:@"请输入新值"
            attributes:@{NSForegroundColorAttributeName: [UIColor secondaryLabelColor]}];
    } else {
        valueTextField.backgroundColor = [UIColor colorWithWhite:0.98 alpha:1];
        valueTextField.textColor = [UIColor darkTextColor];
    }
    
    // 确认按钮
    UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
    confirmButton.frame = CGRectMake(containerWidth / 2 + 10, 145, (containerWidth - 60) / 2, 35);
    [confirmButton setTitle:@"确定" forState:UIControlStateNormal];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        confirmButton.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.2 green:0.22 blue:0.25 alpha:1.0];
            } else {
                return [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0];
            }
        }];
        [confirmButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        confirmButton.backgroundColor = [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0];
        [confirmButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    
    confirmButton.layer.cornerRadius = 8;
    
    // 取消按钮
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.frame = CGRectMake(20, 145, (containerWidth - 60) / 2, 35);
    [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        cancelButton.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.18 green:0.18 blue:0.2 alpha:1.0];
            } else {
                return [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
            }
        }];
        [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        cancelButton.backgroundColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
        [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    
    cancelButton.layer.cornerRadius = 8;
    
    // 添加视图
    [containerView addSubview:titleLabel];
    [containerView addSubview:infoLabel];
    [containerView addSubview:typeSegment];
    [containerView addSubview:valueTextField];
    [containerView addSubview:confirmButton];
    [containerView addSubview:cancelButton];
    
    [backgroundView addSubview:containerView];
    [self.view addSubview:backgroundView];
    
    // 设置标签用于区分弹窗的按钮
    cancelButton.tag = 1003; // 全改弹窗的取消按钮标签
    
    // 确认按钮点击事件
    [confirmButton addTarget:self action:@selector(confirmModifyAllButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 取消按钮点击事件
    [cancelButton addTarget:self action:@selector(cancelModifyAllButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 存储引用以便在按钮回调中访问
    objc_setAssociatedObject(self, "modifyAllBackgroundView", backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "modifyAllContainerView", containerView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "modifyAllValueTextField", valueTextField, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "modifyAllTypeSegment", typeSegment, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 动画显示
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 1;
        containerView.transform = CGAffineTransformIdentity;
    }];
}

// 确认全改按钮点击事件
- (void)confirmModifyAllButtonTapped:(UIButton *)sender {
    UITextField *valueTextField = objc_getAssociatedObject(self, "modifyAllValueTextField");
    UISegmentedControl *typeSegment = objc_getAssociatedObject(self, "modifyAllTypeSegment");
    
    NSString *newValue = valueTextField.text;
    NSInteger selectedTypeIndex = typeSegment.selectedSegmentIndex;
    
    // 检查输入是否为空字符串
    if (newValue.length > 0) {
        // 根据选择的类型获取对应的VMMemValueType
        NSArray *allKeys = [[VMTool share] allKeys];
        NSString *selectedType = allKeys[selectedTypeIndex];
        VMMemValueType modifyType = (VMMemValueType)[[[VMTool share] keyValues][selectedType] integerValue];
        
        // 显示进度提示
        UIAlertController *progressAlert = [UIAlertController alertControllerWithTitle:@"正在修改"
                                                                              message:@"请稍候..."
                                                                       preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:progressAlert animated:YES completion:nil];
        
        // 在后台线程执行批量修改，避免阻塞UI
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // 修改所有搜索结果的值
            for (MemModel *item in self.allSearchResults) {
                [[VMTool share] modifyValue:newValue address:item.address type:modifyType];
            }
            
            // 修改完成后刷新搜索结果
            dispatch_async(dispatch_get_main_queue(), ^{
                // 关闭进度提示
                [progressAlert dismissViewControllerAnimated:YES completion:^{
                    // 刷新搜索结果
                    [self refreshAfterModifyWithAddress:nil];
                }];
            });
        });
    }
    
    // 关闭弹窗
    [self closeModifyAllAlert];
}

// 取消全改按钮点击事件
- (void)cancelModifyAllButtonTapped:(UIButton *)sender {
    [self closeModifyAllAlert];
}

// 关闭全改弹窗
- (void)closeModifyAllAlert {
    UIView *backgroundView = objc_getAssociatedObject(self, "modifyAllBackgroundView");
    UIView *containerView = objc_getAssociatedObject(self, "modifyAllContainerView");
    
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 0;
        containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    } completion:^(BOOL finished) {
        [backgroundView removeFromSuperview];
        
        // 清除关联对象，防止内存泄漏
        objc_setAssociatedObject(self, "modifyAllBackgroundView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "modifyAllContainerView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "modifyAllValueTextField", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "modifyAllTypeSegment", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }];
}

// 进入选择模式
- (void)enterSelectionMode {
    self.isSelectionModeActive = YES;
    [self.selectedItems removeAllObjects];
    
    // 更新按钮标题
    for (UIButton *button in self.buttonStackView.arrangedSubviews) {
        NSString *currentTitle = [button titleForState:UIControlStateNormal];
        
        if ([currentTitle isEqualToString:@"全改"]) {
            [button setTitle:@"删除" forState:UIControlStateNormal];
        } else if ([currentTitle isEqualToString:@"选择"]) {
            [button setTitle:@"修改" forState:UIControlStateNormal];
        } else if ([currentTitle isEqualToString:@"数值"] || [currentTitle isEqualToString:@"临近"]) {
            [button setTitle:@"对半" forState:UIControlStateNormal];
        } else if ([currentTitle isEqualToString:@"模糊"]) {
            [button setTitle:@"自选" forState:UIControlStateNormal];
        }
    }
    
    // 刷新表格以显示选择状态
    [self.resultsTableView reloadData];
    
    // 更新结果标签显示选中数量
    [self updateSelectionCountLabel];
}

// 退出选择模式
- (void)exitSelectionMode {
    self.isSelectionModeActive = NO;
    [self.selectedItems removeAllObjects];
    
    // 恢复按钮标题
    for (UIButton *button in self.buttonStackView.arrangedSubviews) {
        NSString *currentTitle = [button titleForState:UIControlStateNormal];
        
        if ([currentTitle isEqualToString:@"删除"]) {
            [button setTitle:@"全改" forState:UIControlStateNormal];
        } else if ([currentTitle isEqualToString:@"修改"]) {
            [button setTitle:@"选择" forState:UIControlStateNormal];
        } else if ([currentTitle isEqualToString:@"对半"]) {
            // 根据当前搜索模式设置正确的标题
            [button setTitle:self.isNearbySearch ? @"临近" : @"数值" forState:UIControlStateNormal];
        } else if ([currentTitle isEqualToString:@"自选"]) {
            [button setTitle:@"模糊" forState:UIControlStateNormal];
        }
    }
    
    // 刷新表格以隐藏选择状态
    [self.resultsTableView reloadData];
    
    // 恢复结果标签显示
    [self updateSearchResultCount:self.allSearchResults.count];
}

// 更新选择计数标签
- (void)updateSelectionCountLabel {
    self.searchResultLabel.text = [NSString stringWithFormat:@"已选择：%lu / %lu", (unsigned long)self.selectedItems.count, (unsigned long)self.allSearchResults.count];
}

// 删除选中的项目
- (void)deleteSelectedItems {
    if (self.selectedItems.count == 0) {
        [self showAlertWithTitle:@"提示" message:@"请先选择要删除的项目"];
        return;
    }
    
    // 将选中的地址添加到已删除地址集合中
    [self.deletedAddresses addObjectsFromArray:self.selectedItems];
    
    // 创建一个临时数组来存储要保留的结果
    NSMutableArray *remainingResults = [NSMutableArray array];
    
    // 遍历所有搜索结果
    for (MemModel *item in self.allSearchResults) {
        // 检查当前项是否在选中列表中
        if (![self.selectedItems containsObject:item.address]) {
            [remainingResults addObject:item];
        }
    }
    
    // 更新搜索结果
    self.allSearchResults = [NSArray arrayWithArray:remainingResults];
    [self.displayResults removeAllObjects];
    [self loadMoreResults];
    
    // 退出选择模式
    [self exitSelectionMode];
    
    // 更新UI
    [self.resultsTableView reloadData];
    [self updateSearchResultCount:self.allSearchResults.count];
}

// 对半选择
- (void)selectHalfItems {
    if (!self.isSelectionModeActive || self.allSearchResults.count == 0) {
        return;
    }

    // 清空当前选择
    [self.selectedItems removeAllObjects];

    // 计算要选择的项目数量（基于全部搜索结果的一半）
    NSInteger halfCount = self.allSearchResults.count / 2;

    // 确保加载足够的结果以供选择
    while (self.displayResults.count < halfCount && self.displayResults.count < self.allSearchResults.count) {
        [self loadMoreResults];
    }

    // 选择前半部分
    for (NSInteger i = 0; i < halfCount && i < self.displayResults.count; i++) {
        MemModel *item = self.displayResults[i];
        [self.selectedItems addObject:item.address];
    }

    // 刷新表格以显示选择状态
    [self.resultsTableView reloadData];

    // 更新结果标签显示选中数量
    [self updateSelectionCountLabel];
}

// 显示自定义选择数量输入框
- (void)showCustomSelectionCountAlert {
    if (!self.isSelectionModeActive || self.displayResults.count == 0) {
        return;
    }
    
    // 定义固定尺寸
    CGFloat containerWidth = 300;
    CGFloat containerHeight = 180;
    
    // 创建背景遮罩
    UIView *backgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
    backgroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    backgroundView.alpha = 0;
    
    // 创建容器视图
    UIView *containerView = [[UIView alloc] initWithFrame:CGRectMake(
        (self.view.bounds.size.width - containerWidth) / 2,
        (self.view.bounds.size.height - containerHeight) / 2 - 40,
        containerWidth,
        containerHeight
    )];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        containerView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        containerView.layer.borderWidth = 0.5;
        containerView.layer.borderColor = [UIColor systemGrayColor].CGColor;
    } else {
        containerView.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.96 alpha:1.0];
        containerView.layer.borderWidth = 0.5;
        containerView.layer.borderColor = [UIColor colorWithWhite:0.85 alpha:1.0].CGColor;
    }
    
    containerView.layer.cornerRadius = 15;
    containerView.layer.shadowColor = [UIColor blackColor].CGColor;
    containerView.layer.shadowOffset = CGSizeMake(0, 4);
    containerView.layer.shadowOpacity = 0.1;
    containerView.layer.shadowRadius = 10;
    containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 15, containerWidth - 40, 30)];
    titleLabel.text = @"自定义选择数量";
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        titleLabel.textColor = [UIColor labelColor];
    } else {
        titleLabel.textColor = [UIColor darkTextColor];
    }
    
    // 提示信息
    UILabel *infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 50, containerWidth - 40, 20)];
    infoLabel.text = [NSString stringWithFormat:@"当前共有 %lu 条结果", (unsigned long)self.allSearchResults.count];
    infoLabel.font = [UIFont systemFontOfSize:14];
    infoLabel.textAlignment = NSTextAlignmentCenter;
    
    // 输入框
    UITextField *countTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 80, containerWidth - 40, 35)];
    countTextField.placeholder = @"请输入要选择的数量";
    countTextField.borderStyle = UITextBorderStyleRoundedRect;
    countTextField.keyboardType = UIKeyboardTypeNumberPad;
    countTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    countTextField.textAlignment = NSTextAlignmentCenter;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        countTextField.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        countTextField.textColor = [UIColor labelColor];
        countTextField.attributedPlaceholder = [[NSAttributedString alloc]
            initWithString:@"请输入要选择的数量"
            attributes:@{NSForegroundColorAttributeName: [UIColor secondaryLabelColor]}];
    } else {
        countTextField.backgroundColor = [UIColor colorWithWhite:0.98 alpha:1];
        countTextField.textColor = [UIColor darkTextColor];
    }
    
    // 确认按钮
    UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
    confirmButton.frame = CGRectMake(containerWidth / 2 + 10, 130, (containerWidth - 60) / 2, 35);
    [confirmButton setTitle:@"确定" forState:UIControlStateNormal];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        confirmButton.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.2 green:0.22 blue:0.25 alpha:1.0];
            } else {
                return [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0];
            }
        }];
        [confirmButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        confirmButton.backgroundColor = [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0];
        [confirmButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    
    confirmButton.layer.cornerRadius = 8;
    
    // 取消按钮
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.frame = CGRectMake(20, 130, (containerWidth - 60) / 2, 35);
    [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        cancelButton.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.18 green:0.18 blue:0.2 alpha:1.0];
            } else {
                return [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
            }
        }];
        [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        cancelButton.backgroundColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
        [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    
    cancelButton.layer.cornerRadius = 8;
    
    // 添加视图
    [containerView addSubview:titleLabel];
    [containerView addSubview:infoLabel];
    [containerView addSubview:countTextField];
    [containerView addSubview:confirmButton];
    [containerView addSubview:cancelButton];
    
    [backgroundView addSubview:containerView];
    [self.view addSubview:backgroundView];
    
    // 确认按钮点击事件
    [confirmButton addTarget:self action:@selector(confirmCustomSelectionCountButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 取消按钮点击事件
    [cancelButton addTarget:self action:@selector(cancelCustomSelectionCountButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 存储引用以便在按钮回调中访问
    objc_setAssociatedObject(self, "customSelectionBackgroundView", backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "customSelectionContainerView", containerView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "customSelectionCountTextField", countTextField, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 动画显示
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 1;
        containerView.transform = CGAffineTransformIdentity;
    }];
    
    // 自动弹出键盘
    [countTextField becomeFirstResponder];
}

// 确认自定义选择数量按钮点击事件
- (void)confirmCustomSelectionCountButtonTapped:(UIButton *)sender {
    UITextField *countTextField = objc_getAssociatedObject(self, "customSelectionCountTextField");
    NSString *countString = countTextField.text;
    
    // 检查输入是否为空
    if (countString.length > 0) {
        NSInteger count = [countString integerValue];
        
        // 确保输入的数量有效
        if (count > 0) {
            // 限制最大选择数量为当前显示结果的数量
            count = MIN(count, self.allSearchResults.count);
            
            // 清空当前选择
            [self.selectedItems removeAllObjects];
            
            // 确保加载足够的结果以供选择
            while (self.displayResults.count < count && self.displayResults.count < self.allSearchResults.count) {
                [self loadMoreResults];
            }
            
            // 选择指定数量的项目
            for (NSInteger i = 0; i < count && i < self.displayResults.count; i++) {
                MemModel *item = self.displayResults[i];
                [self.selectedItems addObject:item.address];
            }
            
            // 刷新表格以显示选择状态
            [self.resultsTableView reloadData];
            
            // 更新结果标签显示选中数量
            [self updateSelectionCountLabel];
        }
    }
    
    // 关闭弹窗
    [self closeCustomSelectionCountAlert];
}

// 取消自定义选择数量按钮点击事件
- (void)cancelCustomSelectionCountButtonTapped:(UIButton *)sender {
    [self closeCustomSelectionCountAlert];
}

// 关闭自定义选择数量弹窗
- (void)closeCustomSelectionCountAlert {
    UIView *backgroundView = objc_getAssociatedObject(self, "customSelectionBackgroundView");
    UIView *containerView = objc_getAssociatedObject(self, "customSelectionContainerView");
    
    // 隐藏键盘
    UITextField *countTextField = objc_getAssociatedObject(self, "customSelectionCountTextField");
    [countTextField resignFirstResponder];
    
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 0;
        containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    } completion:^(BOOL finished) {
        [backgroundView removeFromSuperview];
        
        // 清除关联对象，防止内存泄漏
        objc_setAssociatedObject(self, "customSelectionBackgroundView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "customSelectionContainerView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "customSelectionCountTextField", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }];
}

// 显示自定义选择弹窗
- (void)showCustomSelectionAlert {
    if (!self.isSelectionModeActive) {
        return;
    }
    
    // 创建弹窗
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"自定义选择"
                                                                             message:@"请选择操作方式"
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    // 添加"全选"选项
    UIAlertAction *selectAllAction = [UIAlertAction actionWithTitle:@"全选"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * _Nonnull action) {
        [self selectAllItems];
    }];
    [alertController addAction:selectAllAction];
    
    // 添加"反选"选项
    UIAlertAction *invertSelectionAction = [UIAlertAction actionWithTitle:@"反选"
                                                                    style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction * _Nonnull action) {
        [self invertSelection];
    }];
    [alertController addAction:invertSelectionAction];
    
    // 添加"自定义数量"选项
    UIAlertAction *customCountAction = [UIAlertAction actionWithTitle:@"自定义数量"
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * _Nonnull action) {
        [self showCustomSelectionCountAlert];
    }];
    [alertController addAction:customCountAction];
    
    // 添加"清除选择"选项
    UIAlertAction *clearSelectionAction = [UIAlertAction actionWithTitle:@"清除选择"
                                                                   style:UIAlertActionStyleDefault
                                                                 handler:^(UIAlertAction * _Nonnull action) {
        [self clearSelection];
    }];
    [alertController addAction:clearSelectionAction];
    
    // 添加取消按钮
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alertController addAction:cancelAction];
    
    // 显示弹窗
    [self presentViewController:alertController animated:YES completion:nil];
}

// 全选
- (void)selectAllItems {
    [self.selectedItems removeAllObjects];
    
    // 选择所有显示的项目
    for (MemModel *item in self.displayResults) {
        [self.selectedItems addObject:item.address];
    }
    
    // 刷新表格以显示选择状态
    [self.resultsTableView reloadData];
    
    // 更新结果标签显示选中数量
    [self updateSelectionCountLabel];
}

// 反选
- (void)invertSelection {
    NSMutableArray *newSelection = [NSMutableArray array];
    
    // 遍历所有显示的项目
    for (MemModel *item in self.displayResults) {
        // 如果当前项不在选中列表中，则添加到新的选择列表
        if (![self.selectedItems containsObject:item.address]) {
            [newSelection addObject:item.address];
        }
    }
    
    // 更新选中列表
    [self.selectedItems removeAllObjects];
    [self.selectedItems addObjectsFromArray:newSelection];
    
    // 刷新表格以显示选择状态
    [self.resultsTableView reloadData];
    
    // 更新结果标签显示选中数量
    [self updateSelectionCountLabel];
}

// 清除选择
- (void)clearSelection {
    [self.selectedItems removeAllObjects];

    // 刷新表格以显示选择状态
    [self.resultsTableView reloadData];

    // 更新结果标签显示选中数量
    [self updateSelectionCountLabel];
}

// 显示修改或清除选择的菜单
- (void)showModifyOrClearSelectionMenu {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"选择操作"
                                                                             message:[NSString stringWithFormat:@"已选择 %lu 个项目", (unsigned long)self.selectedItems.count]
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    // 修改选中项
    UIAlertAction *modifyAction = [UIAlertAction actionWithTitle:@"修改选中项"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self showModifySelectedItemsAlert];
    }];
    [alertController addAction:modifyAction];

    // 清除所有选择
    UIAlertAction *clearAction = [UIAlertAction actionWithTitle:@"清除所有选择"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * _Nonnull action) {
        [self clearSelection];
    }];
    [alertController addAction:clearAction];

    // 取消
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alertController addAction:cancelAction];

    [self presentViewController:alertController animated:YES completion:nil];
}

// 添加新方法：显示修改选中项目的弹窗
- (void)showModifySelectedItemsAlert {
    // 定义固定尺寸
    CGFloat containerWidth = 300;
    CGFloat containerHeight = 190;
    
    // 创建背景遮罩
    UIView *backgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
    backgroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    backgroundView.alpha = 0;
    
    // 创建容器视图
    UIView *containerView = [[UIView alloc] initWithFrame:CGRectMake(
        (self.view.bounds.size.width - containerWidth) / 2,
        (self.view.bounds.size.height - containerHeight) / 2 - 40,
        containerWidth,
        containerHeight
    )];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        containerView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        containerView.layer.borderWidth = 0.5;
        containerView.layer.borderColor = [UIColor systemGrayColor].CGColor;
    } else {
        containerView.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.96 alpha:1.0];
        containerView.layer.borderWidth = 0.5;
        containerView.layer.borderColor = [UIColor colorWithWhite:0.85 alpha:1.0].CGColor;
    }
    
    containerView.layer.cornerRadius = 15;
    containerView.layer.shadowColor = [UIColor blackColor].CGColor;
    containerView.layer.shadowOffset = CGSizeMake(0, 4);
    containerView.layer.shadowOpacity = 0.1;
    containerView.layer.shadowRadius = 10;
    containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 5, containerWidth - 40, 30)];
    titleLabel.text = @"批量修改选中项";
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        titleLabel.textColor = [UIColor labelColor];
    } else {
        titleLabel.textColor = [UIColor darkTextColor];
    }
    
    // 提示信息
    UILabel *infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 35, containerWidth - 40, 20)];
    infoLabel.text = [NSString stringWithFormat:@"将修改选中的 %lu 个地址", (unsigned long)self.selectedItems.count];
    infoLabel.font = [UIFont systemFontOfSize:14];
    infoLabel.textAlignment = NSTextAlignmentCenter;
    
    // 类型分段控件
    NSArray *allKeys = [[VMTool share] allKeys];
    UISegmentedControl *typeSegment = [[UISegmentedControl alloc] initWithItems:allKeys];
    typeSegment.frame = CGRectMake(20, 60, containerWidth - 40, 30);
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        typeSegment.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        typeSegment.selectedSegmentTintColor = [UIColor systemBlueColor];
    }
    
    // 根据当前值类型自动选择对应的分段
    NSDictionary *keyValues = [[VMTool share] keyValues];
    NSInteger defaultSelectedIndex = 0; // 默认选择第一个
    
    // 查找当前类型对应的索引
    for (NSInteger i = 0; i < allKeys.count; i++) {
        NSString *key = allKeys[i];
        if ([keyValues[key] integerValue] == self.currentValueType) {
            defaultSelectedIndex = i;
            break;
        }
    }
    
    typeSegment.selectedSegmentIndex = defaultSelectedIndex;
    
    // 输入框
    UITextField *valueTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 100, containerWidth - 40, 35)];
    valueTextField.placeholder = @"请输入新值";
    valueTextField.borderStyle = UITextBorderStyleRoundedRect;
    valueTextField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    valueTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        valueTextField.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        valueTextField.textColor = [UIColor labelColor];
        valueTextField.attributedPlaceholder = [[NSAttributedString alloc]
            initWithString:@"请输入新值"
            attributes:@{NSForegroundColorAttributeName: [UIColor secondaryLabelColor]}];
    } else {
        valueTextField.backgroundColor = [UIColor colorWithWhite:0.98 alpha:1];
        valueTextField.textColor = [UIColor darkTextColor];
    }
    
    // 确认按钮
    UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
    confirmButton.frame = CGRectMake(containerWidth / 2 + 10, 145, (containerWidth - 60) / 2, 35);
    [confirmButton setTitle:@"确定" forState:UIControlStateNormal];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        confirmButton.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.2 green:0.22 blue:0.25 alpha:1.0];
            } else {
                return [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0];
            }
        }];
        [confirmButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        confirmButton.backgroundColor = [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0];
        [confirmButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    
    confirmButton.layer.cornerRadius = 8;
    
    // 取消按钮
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.frame = CGRectMake(20, 145, (containerWidth - 60) / 2, 35);
    [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        cancelButton.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.18 green:0.18 blue:0.2 alpha:1.0];
            } else {
                return [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
            }
        }];
        [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        cancelButton.backgroundColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
        [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    
    cancelButton.layer.cornerRadius = 8;
    
    // 添加视图
    [containerView addSubview:titleLabel];
    [containerView addSubview:infoLabel];
    [containerView addSubview:typeSegment];
    [containerView addSubview:valueTextField];
    [containerView addSubview:confirmButton];
    [containerView addSubview:cancelButton];
    
    [backgroundView addSubview:containerView];
    [self.view addSubview:backgroundView];
    
    // 设置标签用于区分弹窗的按钮
    cancelButton.tag = 1004; // 修改选中项弹窗的取消按钮标签
    
    // 确认按钮点击事件
    [confirmButton addTarget:self action:@selector(confirmModifySelectedButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 取消按钮点击事件
    [cancelButton addTarget:self action:@selector(cancelModifySelectedButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 存储引用以便在按钮回调中访问
    objc_setAssociatedObject(self, "modifySelectedBackgroundView", backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "modifySelectedContainerView", containerView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "modifySelectedValueTextField", valueTextField, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "modifySelectedTypeSegment", typeSegment, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 动画显示
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 1;
        containerView.transform = CGAffineTransformIdentity;
    }];
}

// 确认修改选中项按钮点击事件
- (void)confirmModifySelectedButtonTapped:(UIButton *)sender {
    UITextField *valueTextField = objc_getAssociatedObject(self, "modifySelectedValueTextField");
    UISegmentedControl *typeSegment = objc_getAssociatedObject(self, "modifySelectedTypeSegment");
    
    NSString *newValue = valueTextField.text;
    NSInteger selectedTypeIndex = typeSegment.selectedSegmentIndex;
    
    // 检查输入是否为空字符串
    if (newValue.length > 0) {
        // 根据选择的类型获取对应的VMMemValueType
        NSArray *allKeys = [[VMTool share] allKeys];
        NSString *selectedType = allKeys[selectedTypeIndex];
        VMMemValueType modifyType = (VMMemValueType)[[[VMTool share] keyValues][selectedType] integerValue];
        
        // 显示进度提示
        UIAlertController *progressAlert = [UIAlertController alertControllerWithTitle:@"正在修改"
                                                                              message:@"请稍候..."
                                                                       preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:progressAlert animated:YES completion:nil];
        
        // 在后台线程执行批量修改，避免阻塞UI
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // 修改所有选中的地址的值
            for (NSString *address in self.selectedItems) {
                // 根据搜索模式选择修改方法
                if (self.isTraditionalSearch) {
                    // 传统搜索模式：使用VMTool修改内存值
                    [[VMTool share] modifyValue:newValue address:address type:modifyType];
                } else {
                    // 高效搜索模式：使用RXMemSearchEngine修改内存值
                    RXValueType rxValueType = [self convertVMValueTypeToRXValueType:modifyType];
                    RXMemSearchEngine *rxEngine = [RXMemSearchEngine sharedEngine];
                    BOOL success = [rxEngine writeValue:newValue toAddress:address type:rxValueType];

                    if (!success) {
                        NSLog(@"❌ 高效搜索模式：地址 %@ 内存值修改失败", address);
                        // 如果RX引擎修改失败，可以考虑回退到VMTool
                        [[VMTool share] modifyValue:newValue address:address type:modifyType];
                    }
                }
            }

            // 修改完成后刷新搜索结果
            dispatch_async(dispatch_get_main_queue(), ^{
                // 关闭进度提示
                [progressAlert dismissViewControllerAnimated:YES completion:^{
                    // 刷新搜索结果
                    [self refreshAfterModifyWithAddress:nil];

                    // 退出选择模式
                    [self exitSelectionMode];
                }];
            });
        });
    }
    
    // 关闭弹窗
    [self closeModifySelectedAlert];
}

// 取消修改选中项按钮点击事件
- (void)cancelModifySelectedButtonTapped:(UIButton *)sender {
    [self closeModifySelectedAlert];
}

// 关闭修改选中项弹窗
- (void)closeModifySelectedAlert {
    UIView *backgroundView = objc_getAssociatedObject(self, "modifySelectedBackgroundView");
    UIView *containerView = objc_getAssociatedObject(self, "modifySelectedContainerView");
    
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 0;
        containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    } completion:^(BOOL finished) {
        [backgroundView removeFromSuperview];
        
        // 清除关联对象，防止内存泄漏
        objc_setAssociatedObject(self, "modifySelectedBackgroundView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "modifySelectedContainerView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "modifySelectedValueTextField", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "modifySelectedTypeSegment", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }];
}

- (void)showFuzzySearchOptions {
    // 检查是否有搜索结果，如果有则显示比较选项，否则显示首次搜索弹窗
    if (self.allSearchResults.count > 0) {
        // 已有搜索结果，显示比较选项弹窗
        [self showFuzzyCompareOptions];
        return;
    }
    
    // 检查是否选择了进程
    NSString *pidString = [ProcessManager sharedManager].selectedProcessPID;
    if (!pidString) {
        [self showAlertWithTitle:@"错误" message:@"请先选择进程"];
        return;
    }
    
    // 定义固定尺寸
    CGFloat containerWidth = 300;
    CGFloat containerHeight = 150; // 比普通搜索弹窗矮一些，因为没有输入框
    
    // 创建背景遮罩
    UIView *backgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
    backgroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    backgroundView.alpha = 0;
    
    // 创建容器视图
    UIView *containerView = [[UIView alloc] initWithFrame:CGRectMake(
        (self.view.bounds.size.width - containerWidth) / 2,
        (self.view.bounds.size.height - containerHeight) / 2 - 40,
        containerWidth,
        containerHeight
    )];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        containerView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        containerView.layer.borderWidth = 0.5;
        containerView.layer.borderColor = [UIColor systemGrayColor].CGColor;
    } else {
        containerView.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.96 alpha:1.0];
        containerView.layer.borderWidth = 0.5;
        containerView.layer.borderColor = [UIColor colorWithWhite:0.85 alpha:1.0].CGColor;
    }
    
    containerView.layer.cornerRadius = 15;
    containerView.layer.shadowColor = [UIColor blackColor].CGColor;
    containerView.layer.shadowOffset = CGSizeMake(0, 4);
    containerView.layer.shadowOpacity = 0.1;
    containerView.layer.shadowRadius = 10;
    containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 15, containerWidth - 40, 30)];
    titleLabel.text = @"未知值搜索";
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        titleLabel.textColor = [UIColor labelColor];
    } else {
        titleLabel.textColor = [UIColor darkTextColor];
    }
    
    // 类型分段控件
    UISegmentedControl *typeSegmentControl = [[UISegmentedControl alloc]
                                             initWithItems:@[@"F32", @"F64", @"I8", @"I16", @"I32", @"I64"]];
    typeSegmentControl.frame = CGRectMake(20, 55, containerWidth - 40, 30);
    typeSegmentControl.selectedSegmentIndex = 0; // 默认选择F32
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        typeSegmentControl.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        typeSegmentControl.selectedSegmentTintColor = [UIColor systemBlueColor];
    }
    
    // 搜索按钮
    UIButton *searchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    searchButton.frame = CGRectMake(containerWidth / 2 + 10, 100, (containerWidth - 60) / 2, 35);
    [searchButton setTitle:@"搜索" forState:UIControlStateNormal];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        searchButton.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.2 green:0.22 blue:0.25 alpha:1.0];
            } else {
                return [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0];
            }
        }];
        [searchButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        searchButton.backgroundColor = [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0];
        [searchButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    
    searchButton.layer.cornerRadius = 8;
    
    // 取消按钮
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.frame = CGRectMake(20, 100, (containerWidth - 60) / 2, 35);
    [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        cancelButton.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.18 green:0.18 blue:0.2 alpha:1.0];
            } else {
                return [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
            }
        }];
        [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        cancelButton.backgroundColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
        [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    
    cancelButton.layer.cornerRadius = 8;
    
    // 添加视图
    [containerView addSubview:titleLabel];
    [containerView addSubview:typeSegmentControl];
    [containerView addSubview:searchButton];
    [containerView addSubview:cancelButton];
    
    [backgroundView addSubview:containerView];
    [self.view addSubview:backgroundView];
    
    // 搜索按钮点击事件
    [searchButton addTarget:self action:@selector(firstFuzzySearchButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 取消按钮点击事件
    [cancelButton addTarget:self action:@selector(cancelFuzzySearchButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 存储引用
    objc_setAssociatedObject(self, "fuzzyBackgroundView", backgroundView, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(self, "fuzzyContainerView", containerView, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(self, "fuzzyTypeSegmentControl", typeSegmentControl, OBJC_ASSOCIATION_ASSIGN);
    
    // 动画显示
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 1;
        containerView.transform = CGAffineTransformIdentity;
    }];
}

- (void)cancelFuzzySearchButtonTapped:(UIButton *)sender {
    UIView *backgroundView = objc_getAssociatedObject(self, "fuzzyBackgroundView");
    UIView *containerView = objc_getAssociatedObject(self, "fuzzyContainerView");
    
    // 隐藏弹窗
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 0;
        containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    } completion:^(BOOL finished) {
        [backgroundView removeFromSuperview];
    }];
}

- (void)firstFuzzySearchButtonTapped:(UIButton *)sender {
    // 获取类型选择控件
    UISegmentedControl *typeSegmentControl = objc_getAssociatedObject(self, "fuzzyTypeSegmentControl");
    
    // 获取选中的类型
    NSArray *types = @[@"F32", @"F64", @"I8", @"I16", @"I32", @"I64"];
    NSString *selectedType = types[typeSegmentControl.selectedSegmentIndex];
    
    // 获取对应的VMMemValueType枚举值
    NSDictionary *keyValues = @{
        @"F32": @(VMMemValueTypeFloat),
        @"F64": @(VMMemValueTypeDouble),
        @"I8": @(VMMemValueTypeSignedByte),
        @"I16": @(VMMemValueTypeSignedShort),
        @"I32": @(VMMemValueTypeSignedInt),
        @"I64": @(VMMemValueTypeSignedLong)
    };
    
    // 获取当前符号模式
    BOOL isSignedMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"FloatSignMode"];
    
    // 如果FloatSignMode未设置，默认为有符号模式
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"FloatSignMode"]) {
        isSignedMode = YES;
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"FloatSignMode"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    // 根据符号模式选择类型
    VMMemValueType selectedTypeValue;
    if (isSignedMode) {
        // 有符号模式
        selectedTypeValue = (VMMemValueType)[keyValues[selectedType] integerValue];
    } else {
        // 无符号模式，映射到对应的无符号类型
        NSDictionary *unsignedMapping = @{
            @"I8": @(VMMemValueTypeUnsignedByte),
            @"I16": @(VMMemValueTypeUnsignedShort),
            @"I32": @(VMMemValueTypeUnsignedInt),
            @"I64": @(VMMemValueTypeUnsignedLong),
            @"F32": @(VMMemValueTypeFloat),  // 浮点数没有无符号版本
            @"F64": @(VMMemValueTypeDouble)
        };
        selectedTypeValue = (VMMemValueType)[unsignedMapping[selectedType] integerValue];
    }
    
    // 设置当前进程
    NSString *pidString = [ProcessManager sharedManager].selectedProcessPID;
    [[VMTool share] setPid:[pidString intValue] name:[ProcessManager sharedManager].selectedProcessName];
    
    // 根据搜索模式执行未知值搜索
    if (self.isTraditionalSearch) {
        // 使用传统搜索
        [[VMTool share] searchValue:@""
                              type:selectedTypeValue
                        comparison:VMMemComparisonUnknown
                          callback:^(NSInteger count, NSArray *array) {
            // 保存当前搜索的数据类型
            self.currentValueType = selectedTypeValue;

            // 使用统一的搜索结果更新方法
            [self updateSearchResultsWithArray:array count:count];
        }];
    } else {
        // 使用高效搜索（RX引擎）
        NSLog(@"⚡ 使用高效搜索引擎进行首次模糊搜索");

        // 确保RX搜索引擎已连接到当前进程
        RXMemSearchEngine *rxEngine = [RXMemSearchEngine sharedEngine];
        NSString *pidString = [ProcessManager sharedManager].selectedProcessPID;
        if (pidString) {
            pid_t pid = [pidString intValue];
            if ([rxEngine targetPid] != pid) {
                BOOL attached = [rxEngine attachToProcess:pid];
                if (!attached) {
                    NSLog(@"❌ RX搜索引擎连接进程失败: %d", pid);
                    // 回退到传统搜索
                    [[VMTool share] searchValue:@""
                                          type:selectedTypeValue
                                    comparison:VMMemComparisonUnknown
                                      callback:^(NSInteger count, NSArray *array) {
                        self.currentValueType = selectedTypeValue;
                        [self updateSearchResultsWithArray:array count:count];
                    }];
                    return;
                }
            }
        }

        // 转换类型
        RXValueType rxValueType = [self convertVMValueTypeToRXValueType:selectedTypeValue];

        // 根据快速/完整模式设置搜索范围
        [self configureEfficientSearchMode];

        // 执行RX首次模糊搜索
        [rxEngine firstFuzzySearchWithType:rxValueType
                                  callback:^(RXSearchResult *result, NSArray<MemModel *> *results) {
            // 保存当前搜索的数据类型
            self.currentValueType = selectedTypeValue;
            
            // 保存总结果数量，用于后续增量加载
            self.totalResultCount = result.matchedCount;
            
            // 使用统一的搜索结果更新方法
            [self updateSearchResultsWithArray:results count:result.matchedCount];

            NSLog(@"⚡ RX首次模糊搜索完成: 找到 %lu 个结果，初始加载 %lu 条，耗时 %lu ms",
                  (unsigned long)result.matchedCount, 
                  (unsigned long)results.count,
                  (unsigned long)result.timeUsed);
        }];
    }
    
    // 关闭弹窗
    UIView *backgroundView = objc_getAssociatedObject(self, "fuzzyBackgroundView");
    UIView *containerView = objc_getAssociatedObject(self, "fuzzyContainerView");
    
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 0;
        containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    } completion:^(BOOL finished) {
        [backgroundView removeFromSuperview];
    }];
}

// 添加缺失的模糊比较搜索按钮点击方法
- (void)fuzzyCompareSearchButtonTapped:(UIButton *)sender {
    // 显示模糊比较选项
    [self showFuzzyCompareOptions];
}

- (void)showFuzzyCompareOptions {
    // 检查是否有搜索结果
    if (self.allSearchResults.count == 0) {
        [self showAlertWithTitle:@"错误" message:@"请先进行未知值搜索"];
        return;
    }
    
    // 创建弹窗
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"比较搜索"
                                                                             message:@"请选择比较方式"
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    // 添加"值改变"选项
    UIAlertAction *changedAction = [UIAlertAction actionWithTitle:@"值已改变"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self fuzzyCompareSearchWithType:VMMemComparisonChanged];
    }];
    [alertController addAction:changedAction];
    
    // 添加"值未改变"选项
    UIAlertAction *unchangedAction = [UIAlertAction actionWithTitle:@"值未改变"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
        [self fuzzyCompareSearchWithType:VMMemComparisonUnchanged];
    }];
    [alertController addAction:unchangedAction];
    
    // 添加"值增加"选项
    UIAlertAction *increasedAction = [UIAlertAction actionWithTitle:@"值增加"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
        [self fuzzyCompareSearchWithType:VMMemComparisonIncreased];
    }];
    [alertController addAction:increasedAction];
    
    // 添加"值减少"选项
    UIAlertAction *decreasedAction = [UIAlertAction actionWithTitle:@"值减少"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
        [self fuzzyCompareSearchWithType:VMMemComparisonDecreased];
    }];
    [alertController addAction:decreasedAction];
    
    // 添加取消按钮
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alertController addAction:cancelAction];
    
    // 显示弹窗
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)fuzzyCompareSearchWithType:(VMMemComparison)comparisonType {
    if (self.isTraditionalSearch) {
        // 使用传统搜索
        [[VMTool share] fuzzyCompareSearch:comparisonType
                                      type:self.currentValueType
                                  callback:^(NSInteger count, NSArray *array) {
            // 保存所有搜索结果
            self.allSearchResults = array;

            // 清空当前显示结果
            [self.displayResults removeAllObjects];

            // 加载第一批数据
            [self loadMoreResults];

            // 发送通知更新UI
            [[NSNotificationCenter defaultCenter]
             postNotificationName:@"SearchResultUpdateNotification"
             object:nil
             userInfo:@{@"resultCount": @(count)}];
        }];
    } else {
        // 使用高效搜索（RX引擎）
        NSLog(@"⚡ 使用高效搜索引擎进行模糊比较搜索");

        // 确保RX搜索引擎已连接到当前进程
        RXMemSearchEngine *rxEngine = [RXMemSearchEngine sharedEngine];
        NSString *pidString = [ProcessManager sharedManager].selectedProcessPID;
        if (pidString) {
            pid_t pid = [pidString intValue];
            if ([rxEngine targetPid] != pid) {
                BOOL attached = [rxEngine attachToProcess:pid];
                if (!attached) {
                    NSLog(@"❌ RX搜索引擎连接进程失败: %d", pid);
                    // 回退到传统搜索
                    [[VMTool share] fuzzyCompareSearch:comparisonType
                                                  type:self.currentValueType
                                              callback:^(NSInteger count, NSArray *array) {
                        self.allSearchResults = array;
                        [self.displayResults removeAllObjects];
                        [self loadMoreResults];
                        [[NSNotificationCenter defaultCenter]
                         postNotificationName:@"SearchResultUpdateNotification"
                         object:nil
                         userInfo:@{@"resultCount": @(count)}];
                    }];
                    return;
                }
            }
        }

        // 转换比较类型
        RXCompareType rxCompareType = [self convertVMComparisonToRXCompareType:comparisonType];

        // 根据快速/完整模式设置搜索范围
        [self configureEfficientSearchMode];

        // 执行RX模糊搜索
        [rxEngine fuzzySearchWithComparison:rxCompareType
                                   callback:^(RXSearchResult *result, NSArray<MemModel *> *results) {
            // 保存所有搜索结果
            self.allSearchResults = results;
            
            // 保存总结果数量，用于后续增量加载
            self.totalResultCount = result.matchedCount;

            // 清空当前显示结果
            [self.displayResults removeAllObjects];

            // 加载第一批数据
            [self loadMoreResults];

            // 确保在主线程更新UI
            dispatch_async(dispatch_get_main_queue(), ^{
                // 刷新表格视图
                [self.resultsTableView reloadData];
                
                // 更新搜索结果计数
                [self updateSearchResultCount:result.matchedCount];
                
                // 发送通知更新UI
                [[NSNotificationCenter defaultCenter]
                 postNotificationName:@"SearchResultUpdateNotification"
                 object:nil
                 userInfo:@{@"resultCount": @(result.matchedCount)}];
            });

            NSLog(@"⚡ RX模糊比较搜索完成: 找到 %lu 个结果，初始加载 %lu 条，耗时 %lu ms",
                  (unsigned long)result.matchedCount, 
                  (unsigned long)results.count,
                  (unsigned long)result.timeUsed);
        }];
    }
}

#pragma mark - 搜索设置菜单

// 显示搜索设置菜单
- (void)showSearchSettingsMenu {
    // 防止重复显示
    if (self.isShowingSettingsMenu) {
        return;
    }
    self.isShowingSettingsMenu = YES;

    // 创建设置菜单视图
    UIView *menuView = [[UIView alloc] init];
    menuView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    menuView.layer.cornerRadius = 16;
    menuView.layer.shadowColor = [UIColor blackColor].CGColor;
    menuView.layer.shadowOffset = CGSizeMake(0, 4);
    menuView.layer.shadowOpacity = 0.15;
    menuView.layer.shadowRadius = 8;
    menuView.translatesAutoresizingMaskIntoConstraints = NO;

    // 创建背景遮罩
    UIView *backgroundView = [[UIView alloc] init];
    backgroundView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
    backgroundView.translatesAutoresizingMaskIntoConstraints = NO;

    // 添加点击手势关闭菜单
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissSearchSettingsMenu)];
    [backgroundView addGestureRecognizer:tapGesture];

    [self.view addSubview:backgroundView];
    [self.view addSubview:menuView];

    // 创建菜单按钮
    NSMutableArray *buttons = [NSMutableArray array];

    // 传统搜索按钮
    UIButton *traditionalBtn = [self createSearchMenuButton:@"🔍 传统搜索"
                                                     action:@selector(selectTraditionalSearch)
                                                   selected:self.isTraditionalSearch];
    [buttons addObject:traditionalBtn];

    // 高效搜索按钮
    UIButton *efficientBtn = [self createSearchMenuButton:@"⚡ 高效搜索"
                                                   action:@selector(selectEfficientSearch)
                                                 selected:!self.isTraditionalSearch];
    [buttons addObject:efficientBtn];

    // 快速模式按钮
    UIButton *fastBtn = [self createSearchMenuButton:@"🚀 快速模式"
                                               action:@selector(selectFastMode)
                                             selected:self.isFastMode];
    [buttons addObject:fastBtn];

    // 完整模式按钮
    UIButton *completeBtn = [self createSearchMenuButton:@"📋 完整模式"
                                                  action:@selector(selectCompleteMode)
                                                selected:!self.isFastMode];
    [buttons addObject:completeBtn];

    // 添加按钮到菜单
    for (int i = 0; i < buttons.count; i++) {
        [menuView addSubview:buttons[i]];
    }

    // 设置约束
    [self setupSearchMenuConstraints:backgroundView menuView:menuView buttons:buttons];

    // 动画显示
    menuView.alpha = 0;
    menuView.transform = CGAffineTransformMakeScale(0.8, 0.8);
    backgroundView.alpha = 0;

    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
        menuView.alpha = 1;
        menuView.transform = CGAffineTransformIdentity;
        backgroundView.alpha = 1;
    } completion:nil];

    // 保存引用以便关闭
    objc_setAssociatedObject(self, "searchSettingsMenuView", menuView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "searchSettingsBackgroundView", backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// 创建搜索菜单按钮
- (UIButton *)createSearchMenuButton:(NSString *)title action:(SEL)action selected:(BOOL)selected {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];

    // 根据选中状态设置不同的样式
    if (selected) {
        button.backgroundColor = [UIColor systemBlueColor];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        button.backgroundColor = [UIColor secondarySystemBackgroundColor];
        [button setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    }

    button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.8;
    button.layer.cornerRadius = 10;
    button.layer.borderWidth = selected ? 0 : 1;
    button.layer.borderColor = [UIColor systemGrayColor].CGColor;
    button.translatesAutoresizingMaskIntoConstraints = NO;

    // 添加点击事件
    [button addTarget:self action:@selector(searchMenuButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    // 保存原始action
    objc_setAssociatedObject(button, "originalAction", NSStringFromSelector(action), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    return button;
}

// 搜索菜单按钮点击处理
- (void)searchMenuButtonTapped:(UIButton *)sender {
    // 先关闭菜单
    [self dismissSearchSettingsMenu];

    // 延迟执行原始操作
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *actionString = objc_getAssociatedObject(sender, "originalAction");
        if (actionString) {
            SEL action = NSSelectorFromString(actionString);
            if ([self respondsToSelector:action]) {
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [self performSelector:action];
                #pragma clang diagnostic pop
            }
        }
    });
}

// 设置搜索菜单约束
- (void)setupSearchMenuConstraints:(UIView *)backgroundView menuView:(UIView *)menuView buttons:(NSArray<UIButton *> *)buttons {
    // 背景视图约束
    [backgroundView.topAnchor constraintEqualToAnchor:self.view.topAnchor].active = YES;
    [backgroundView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
    [backgroundView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;
    [backgroundView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = YES;

    // 菜单视图约束
    [menuView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
    [menuView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor].active = YES;
    [menuView.widthAnchor constraintEqualToConstant:320].active = YES;

    // 按钮约束 - 两行布局
    CGFloat buttonHeight = 45;
    CGFloat horizontalSpacing = 10;
    CGFloat verticalSpacing = 12;
    CGFloat margin = 20;

    // 计算每行按钮数量
    NSInteger buttonsPerRow = 2;

    for (int i = 0; i < buttons.count; i++) {
        UIButton *button = buttons[i];

        NSInteger row = i / buttonsPerRow;
        NSInteger col = i % buttonsPerRow;

        [button.heightAnchor constraintEqualToConstant:buttonHeight].active = YES;

        // 垂直位置
        if (row == 0) {
            [button.topAnchor constraintEqualToAnchor:menuView.topAnchor constant:margin].active = YES;
        } else {
            UIButton *buttonAbove = buttons[i - buttonsPerRow];
            [button.topAnchor constraintEqualToAnchor:buttonAbove.bottomAnchor constant:verticalSpacing].active = YES;
        }

        // 水平位置
        if (col == 0) {
            // 左侧按钮
            [button.leadingAnchor constraintEqualToAnchor:menuView.leadingAnchor constant:margin].active = YES;
            [button.trailingAnchor constraintEqualToAnchor:menuView.centerXAnchor constant:-horizontalSpacing/2].active = YES;
        } else {
            // 右侧按钮
            [button.leadingAnchor constraintEqualToAnchor:menuView.centerXAnchor constant:horizontalSpacing/2].active = YES;
            [button.trailingAnchor constraintEqualToAnchor:menuView.trailingAnchor constant:-margin].active = YES;
        }

        // 最后一行的最后一个按钮设置底部约束
        if (i == buttons.count - 1) {
            [button.bottomAnchor constraintEqualToAnchor:menuView.bottomAnchor constant:-margin].active = YES;
        }
    }
}

// 关闭搜索设置菜单
- (void)dismissSearchSettingsMenu {
    UIView *menuView = objc_getAssociatedObject(self, "searchSettingsMenuView");
    UIView *backgroundView = objc_getAssociatedObject(self, "searchSettingsBackgroundView");

    if (menuView && backgroundView) {
        [UIView animateWithDuration:0.2 animations:^{
            menuView.alpha = 0;
            menuView.transform = CGAffineTransformMakeScale(0.8, 0.8);
            backgroundView.alpha = 0;
        } completion:^(BOOL finished) {
            [menuView removeFromSuperview];
            [backgroundView removeFromSuperview];
            self.isShowingSettingsMenu = NO;
        }];
    }
}

// 搜索设置选项方法
- (void)selectTraditionalSearch {
    if (!self.isTraditionalSearch) {
        self.isTraditionalSearch = YES;
        NSLog(@"切换到传统搜索");
        [self saveSearchSettings];
        // TODO: 实现传统搜索逻辑
    }
}

- (void)selectEfficientSearch {
    if (self.isTraditionalSearch) {
        self.isTraditionalSearch = NO;
        NSLog(@"切换到高效搜索");
        [self saveSearchSettings];
        // TODO: 实现高效搜索逻辑
    }
}

- (void)selectFastMode {
    if (!self.isFastMode) {
        self.isFastMode = YES;
        NSLog(@"切换到快速模式");
        [self saveSearchSettings];
        // TODO: 实现快速模式逻辑
    }
}

- (void)selectCompleteMode {
    if (self.isFastMode) {
        self.isFastMode = NO;
        NSLog(@"切换到完整模式");
        [self saveSearchSettings];
        // TODO: 实现完整模式逻辑
    }
}

#pragma mark - 搜索设置持久化

// 加载搜索设置
- (void)loadSearchSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // 检查是否是第一次启动
    if ([defaults objectForKey:@"SearchSettings_IsTraditionalSearch"] == nil) {
        // 第一次启动，使用默认值
        self.isTraditionalSearch = YES; // 默认传统搜索
        self.isFastMode = YES; // 默认快速模式
        [self saveSearchSettings]; // 保存默认设置
    } else {
        // 从用户偏好读取设置
        self.isTraditionalSearch = [defaults boolForKey:@"SearchSettings_IsTraditionalSearch"];
        self.isFastMode = [defaults boolForKey:@"SearchSettings_IsFastMode"];
    }

    NSLog(@"加载搜索设置: 传统搜索=%@, 快速模式=%@",
          self.isTraditionalSearch ? @"是" : @"否",
          self.isFastMode ? @"是" : @"否");
}

// 保存搜索设置
- (void)saveSearchSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:self.isTraditionalSearch forKey:@"SearchSettings_IsTraditionalSearch"];
    [defaults setBool:self.isFastMode forKey:@"SearchSettings_IsFastMode"];
    [defaults synchronize];

    NSLog(@"保存搜索设置: 传统搜索=%@, 快速模式=%@",
          self.isTraditionalSearch ? @"是" : @"否",
          self.isFastMode ? @"是" : @"否");
}

#pragma mark - 搜索引擎选择

// 根据搜索模式执行搜索
- (void)performSearchWithValue:(NSString *)searchValue
                          type:(VMMemValueType)valueType
                    comparison:(VMMemComparison)comparison {

    if (self.isTraditionalSearch) {
        // 使用传统搜索（VMTool）
        [self performTraditionalSearchWithValue:searchValue type:valueType comparison:comparison];
    } else {
        // 使用高效搜索（RXMemSearchEngine）
        [self performEfficientSearchWithValue:searchValue type:valueType comparison:comparison];
    }
}

// 传统搜索实现
- (void)performTraditionalSearchWithValue:(NSString *)searchValue
                                     type:(VMMemValueType)valueType
                               comparison:(VMMemComparison)comparison {

    NSLog(@"🔍 使用传统搜索引擎搜索值: %@", searchValue);

    [[VMTool share] searchValue:searchValue
                           type:valueType
                     comparison:comparison
                       callback:^(NSInteger count, NSArray *array) {
        // 保存当前搜索的数据类型
        self.currentValueType = valueType;

        // 使用统一方法更新搜索结果
        [self updateSearchResultsWithArray:array count:count];
    }];
}

// 高效搜索实现
- (void)performEfficientSearchWithValue:(NSString *)searchValue
                                   type:(VMMemValueType)valueType
                             comparison:(VMMemComparison)comparison {

    NSLog(@"⚡ 使用高效搜索引擎搜索值: %@", searchValue);

    // 转换类型
    RXValueType rxValueType = [self convertVMValueTypeToRXValueType:valueType];
    RXCompareType rxCompareType = [self convertVMComparisonToRXCompareType:comparison];

    // 确保RX搜索引擎已连接到当前进程
    RXMemSearchEngine *rxEngine = [RXMemSearchEngine sharedEngine];
    NSString *pidString = [ProcessManager sharedManager].selectedProcessPID;
    if (pidString) {
        pid_t pid = [pidString intValue];
        if ([rxEngine targetPid] != pid) {
            BOOL attached = [rxEngine attachToProcess:pid];
            if (!attached) {
                NSLog(@"❌ RX搜索引擎连接进程失败: %d", pid);
                // 回退到传统搜索
                [self performTraditionalSearchWithValue:searchValue type:valueType comparison:comparison];
                return;
            }
        }
    }

    // 根据快速/完整模式设置搜索范围
    [self configureEfficientSearchMode];

    // 执行RX搜索
    [rxEngine searchValue:searchValue
                     type:rxValueType
               comparison:rxCompareType
                 callback:^(RXSearchResult *result, NSArray<MemModel *> *results) {

        // 保存当前搜索的数据类型
        self.currentValueType = valueType;

        // 使用统一方法更新搜索结果
        [self updateSearchResultsWithArray:results count:result.matchedCount];

        NSLog(@"⚡ RX搜索完成: 找到 %lu 个结果，耗时 %lu ms",
              (unsigned long)result.matchedCount, (unsigned long)result.timeUsed);
    }];
}

// BitSlicer字符串搜索
- (void)performBitSlicerStringSearchWithValue:(NSString *)searchValue
                               stringSearcher:(BitSlicerStringSearcher *)stringSearcher {

    // 获取搜索参数设置
    BOOL caseInsensitive = [[NSUserDefaults standardUserDefaults] boolForKey:@"CaseInsensitiveSearch"];
    BOOL utf16Mode = [[NSUserDefaults standardUserDefaults] boolForKey:@"UTF16StringSearch"];

    // 根据快速/完整模式设置内存搜索范围
    BOOL includeReadOnly = !self.isFastMode; // 完整模式包含只读区域，快速模式不包含
    [[NSUserDefaults standardUserDefaults] setBool:includeReadOnly forKey:@"IncludeReadOnlySearch"];

    NSLog(@"⚡ BitSlicer字符串搜索参数: 大小写不敏感=%@, UTF16=%@, 包含只读=%@",
          caseInsensitive ? @"是" : @"否",
          utf16Mode ? @"是" : @"否",
          includeReadOnly ? @"是" : @"否");

    [stringSearcher searchString:searchValue
                  caseInsensitive:caseInsensitive
                           utf16:utf16Mode
                        callback:^(NSInteger count, NSArray<MemModel *> *results, NSTimeInterval timeUsed) {
        // 保存当前搜索的数据类型
        self.currentValueType = VMMemValueTypeStr;

        // 使用统一方法更新搜索结果
        [self updateSearchResultsWithArray:results count:count];

        NSLog(@"⚡ BitSlicer字符串搜索完成: 找到 %ld 个结果，耗时 %.3f 秒",
              (long)count, timeUsed);
    }];
}

// 配置高效搜索模式
- (void)configureEfficientSearchMode {
    // 根据快速/完整模式设置内存搜索范围
    BOOL includeReadOnly = !self.isFastMode; // 完整模式包含只读区域，快速模式不包含

    // 设置NSUserDefaults，供BitSlicerStringSearcher使用
    [[NSUserDefaults standardUserDefaults] setBool:includeReadOnly forKey:@"IncludeReadOnlySearch"];

    // 设置RXMemSearchEngine的搜索范围
    RXMemSearchEngine *rxEngine = [RXMemSearchEngine sharedEngine];
    [rxEngine setIncludeReadOnlyMemory:includeReadOnly];

    NSLog(@"⚡ 配置高效搜索模式: %@ (包含只读区域: %@)",
          self.isFastMode ? @"快速模式" : @"完整模式",
          includeReadOnly ? @"是" : @"否");
}

#pragma mark - 搜索引擎类型转换

// 将VMMemValueType转换为RXValueType
- (RXValueType)convertVMValueTypeToRXValueType:(VMMemValueType)vmType {
    switch (vmType) {
        case VMMemValueTypeSignedByte:
            return RXValueTypeInt8;
        case VMMemValueTypeSignedShort:
            return RXValueTypeInt16;
        case VMMemValueTypeSignedInt:
            return RXValueTypeInt32;
        case VMMemValueTypeSignedLong:
            return RXValueTypeInt64;
        case VMMemValueTypeUnsignedByte:
            return RXValueTypeUInt8;
        case VMMemValueTypeUnsignedShort:
            return RXValueTypeUInt16;
        case VMMemValueTypeUnsignedInt:
            return RXValueTypeUInt32;
        case VMMemValueTypeUnsignedLong:
            return RXValueTypeUInt64;
        case VMMemValueTypeFloat:
            return RXValueTypeFloat;
        case VMMemValueTypeDouble:
            return RXValueTypeDouble;
        case VMMemValueTypeStr:
            return RXValueTypeString;
        default:
            return RXValueTypeInt32; // 默认值
    }
}

// 将VMMemComparison转换为RXCompareType
- (RXCompareType)convertVMComparisonToRXCompareType:(VMMemComparison)vmComparison {
    switch (vmComparison) {
        case VMMemComparisonEQ:
            return RXCompareTypeEqual;
        case VMMemComparisonGT:
            return RXCompareTypeGreater;
        case VMMemComparisonLT:
            return RXCompareTypeLess;
        case VMMemComparisonGE:
            return RXCompareTypeGreaterEqual;
        case VMMemComparisonLE:
            return RXCompareTypeLessEqual;
        case VMMemComparisonChanged:
            return RXCompareTypeChanged;
        case VMMemComparisonUnchanged:
            return RXCompareTypeUnchanged;
        case VMMemComparisonIncreased:
            return RXCompareTypeIncreased;
        case VMMemComparisonDecreased:
            return RXCompareTypeDecreased;
        default:
            return RXCompareTypeEqual; // 默认值
    }
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

// 屏幕旋转时调用
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    // 在旋转动画完成后更新UI
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        // 旋转过程中的动画
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        // 旋转完成后调用处理方法
        [self handleScreenRotation];
    }];
}

// 处理屏幕旋转
- (void)handleScreenRotation {
    // 刷新表格视图
    [self.resultsTableView reloadData];
    
    // 重新布局按钮栈视图
    [self.buttonStackView setNeedsLayout];
    [self.buttonStackView layoutIfNeeded];
    
    // 更新弹窗位置（如果有弹窗显示）
    if (self.isShowingSettingsMenu) {
        [self dismissSearchSettingsMenu];
        [self showSearchSettingsMenu];
    }
    
    // 重新布局数值搜索弹窗（如果正在显示）
    UIView *searchContainerView = objc_getAssociatedObject(self, "containerView");
    UIView *searchBackgroundView = objc_getAssociatedObject(self, "backgroundView");
    if (searchContainerView && searchBackgroundView) {
        // 更新背景视图的大小
        searchBackgroundView.frame = self.view.bounds;
        
        // 更新容器视图的位置
        CGFloat containerWidth = MIN(self.view.bounds.size.width - 40, 300);
        CGFloat containerHeight = searchContainerView.frame.size.height;
        searchContainerView.frame = CGRectMake(
            (self.view.bounds.size.width - containerWidth) / 2,
            (self.view.bounds.size.height - containerHeight) / 2 - 40,
            containerWidth,
            containerHeight
        );
        
        // 更新内部控件的布局
        [self updateSearchViewControlsLayout:searchContainerView];
    }
    
    // 强制更新所有视图布局
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    
    // 确保表格视图内容可见
    if (self.displayResults.count > 0) {
        [self.resultsTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] 
                                     atScrollPosition:UITableViewScrollPositionTop 
                                             animated:NO];
    }
}

// 更新数值搜索弹窗内部控件的布局
- (void)updateSearchViewControlsLayout:(UIView *)containerView {
    // 获取容器视图的宽度
    CGFloat containerWidth = containerView.frame.size.width;
    
    // 更新标题标签
    UILabel *titleLabel = [containerView.subviews filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings) {
        return [obj isKindOfClass:[UILabel class]] && ((UILabel *)obj).frame.origin.y < 30;
    }]].firstObject;
    
    if (titleLabel) {
        titleLabel.frame = CGRectMake(20, 5, containerWidth - 40, 30);
    }
    
    // 更新类型分段控件
    UISegmentedControl *typeSegmentControl = objc_getAssociatedObject(self, "typeSegmentControl");
    if (typeSegmentControl) {
        typeSegmentControl.frame = CGRectMake(20, 45, containerWidth - 40, 30);
    }
    
    // 更新输入框
    UITextField *valueTextField = objc_getAssociatedObject(self, "valueTextField");
    if (valueTextField) {
        valueTextField.frame = CGRectMake(20, 85, containerWidth - 40, 35);
    }
    
    // 更新按钮
    UIButton *searchButton = nil;
    UIButton *cancelButton = nil;
    
    for (UIView *subview in containerView.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            if (button.tag == 1001) { // 取消按钮
                cancelButton = button;
            } else { // 搜索按钮
                searchButton = button;
            }
        }
    }
    
    if (cancelButton && searchButton) {
        cancelButton.frame = CGRectMake(20, 130, (containerWidth - 60) / 2, 35);
        searchButton.frame = CGRectMake(containerWidth / 2 + 10, 130, (containerWidth - 60) / 2, 35);
    }
}

#pragma mark - 模块信息相关方法

// 获取缓存的模块列表
- (NSArray<ModuleInfo *> *)getCachedModules {
    // 检查缓存是否过期（5分钟过期）
    if (self.cachedModules && self.modulesCacheTime) {
        NSTimeInterval cacheAge = [[NSDate date] timeIntervalSinceDate:self.modulesCacheTime];
        if (cacheAge < 300) { // 5分钟内有效
            return self.cachedModules;
        }
    }

    // 获取新的模块列表
    PointerScanManager *pointerManager = [PointerScanManager sharedManager];
    ProcessManager *processManager = [ProcessManager sharedManager];

    if (!processManager.selectedProcessPID) {
        return nil;
    }

    NSError *error = nil;
    pid_t pid = [processManager.selectedProcessPID intValue];

    // 确保已附加到进程
    if (![pointerManager attachToProcess:pid error:&error]) {
        NSLog(@"[SearchViewController] 附加进程失败: %@", error.localizedDescription);
        return nil;
    }

    // 获取模块列表
    NSArray<ModuleInfo *> *modules = [pointerManager getModuleList:&error forceRefresh:YES];
    if (error) {
        NSLog(@"[SearchViewController] 获取模块列表失败: %@", error.localizedDescription);
        return nil;
    }

    // 更新缓存
    self.cachedModules = modules;
    self.modulesCacheTime = [NSDate date];

    return modules;
}

// 根据地址查找所属模块
- (NSString *)findModuleNameForAddress:(NSString *)addressString {
    if (!addressString || addressString.length == 0) {
        return nil;
    }

    // 解析地址
    uint64_t address = 0;
    NSScanner *scanner = [NSScanner scannerWithString:addressString];
    if (![scanner scanHexLongLong:&address]) {
        return nil;
    }

    // 获取模块列表
    NSArray<ModuleInfo *> *modules = [self getCachedModules];
    if (!modules) {
        return nil;
    }

    // 查找地址所属的模块
    for (ModuleInfo *module in modules) {
        if (address >= module.startAddress && address < module.endAddress) {
            return module.name;
        }
    }

    return nil;
}

// 清除模块缓存
- (void)clearModuleCache {
    self.cachedModules = nil;
    self.modulesCacheTime = nil;
}

@end
