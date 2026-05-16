#import "SettingsViewController.h"
#import "VMTool.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

// 添加AboutTableViewDataSource类的完整声明
@interface AboutTableViewDataSource : NSObject <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) NSArray *features;
- (instancetype)initWithFeatures:(NSArray *)features;
@end

@implementation AboutTableViewDataSource

- (instancetype)initWithFeatures:(NSArray *)features {
    self = [super init];
    if (self) {
        _features = features;
    }
    return self;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.features.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AboutFeatureCell" forIndexPath:indexPath];
    
    if (indexPath.row < self.features.count) {
        NSDictionary *feature = self.features[indexPath.row];
        
        cell.textLabel.text = feature[@"title"];
        if (@available(iOS 13.0, *)) {
            cell.imageView.image = [UIImage systemImageNamed:feature[@"icon"]];
            cell.imageView.tintColor = [UIColor systemBlueColor];
        }
        
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    // 处理功能项的点击事件
    // 这里可以添加点击后的操作
}

@end

@interface SettingsViewController () {
    uint64_t _currentLowerLimit;
    uint64_t _currentUpperLimit;
    int _currentNearRangeValue;
    NSInteger _currentLimitCount;
    
    // 新增浮点数误差范围属性
    CGFloat _currentFloatErrorRange;
    
    // 新增有符号/无符号状态
    BOOL _isFloatSignedMode;
    
    // 新增模糊字符状态
    BOOL _isFuzzyStringEnabled;



    // 循环锁定相关
    NSInteger _duration;
    NSInteger _duration1;
}

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISwitch *floatSignModeSwitch;
@property (nonatomic, strong) UISwitch *fuzzyStringSwitch;  // 新增模糊字符开关


// 美化界面相关方法声明
- (void)setupGradientBackgroundForView:(UIView *)view;
- (void)updateGradientFrame:(NSNotification *)notification;
- (void)setupModernAppIcon:(UIImageView *)iconView;
- (UIView *)createModernFeatureCard:(NSDictionary *)feature;
- (UIView *)createAuthorizationStatusCard;

@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 配置视图
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // 设置标题
    [self setupTitleLabel];
    
    // 设置表格
    [self setupTableView];
    
    // 加载当前设置
    [self loadCurrentSettings];
}

- (void)setupTitleLabel {
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"设置";
    self.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.titleLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.titleLabel.heightAnchor constraintEqualToConstant:30]
    ]];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    
    // 禁用默认分割线
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = [UIColor clearColor];
    
    // 显式设置 delegate 和 dataSource
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 调整 TableView 布局，减少顶部间距
    [self.view addSubview:self.tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:5],  // 将间距改为 0
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
    
    // 配置表格样式
    if (@available(iOS 13.0, *)) {
        self.tableView.backgroundColor = [UIColor systemBackgroundColor];
        self.tableView.layer.cornerRadius = 10;
        self.tableView.clipsToBounds = YES;
    } else {
        self.tableView.backgroundColor = [UIColor whiteColor];
        self.tableView.layer.cornerRadius = 10;
        self.tableView.clipsToBounds = YES;
    }
}

- (void)loadCurrentSettings {
    VMTool *vmTool = [VMTool share];
    _currentLowerLimit = [vmTool addrLowValue];
    _currentUpperLimit = [vmTool addrUppValue];
    _currentNearRangeValue = [vmTool rangeValue];
    _currentLimitCount = [vmTool limitCount];
    
    // 初始化浮点数误差范围，默认值为 0.0
    _currentFloatErrorRange = [vmTool floatErrorRange];
    
    // 从 NSUserDefaults 读取符号模式状态，默认为有符号模式（YES）
    _isFloatSignedMode = [[NSUserDefaults standardUserDefaults] objectForKey:@"FloatSignMode"] == nil ? 
        YES : [[NSUserDefaults standardUserDefaults] boolForKey:@"FloatSignMode"];
    
    // 从 NSUserDefaults 读取模糊字符状态，默认关闭（NO）
    _isFuzzyStringEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"FuzzyStringMode"];



    // 初始化循环锁定相关变量
    _duration = [vmTool duration];
    if (_duration == 0) {
        _duration = 100; // 使用默认值100毫秒
    }
    
    _duration1 = [vmTool duration1];
    if (_duration1 == 0) {
        _duration1 = 20; // 使用默认值20毫秒
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // 检查是否是关于页面的表格视图
    if (tableView.tag == 1001) {
        return 1;  // 关于页面只有一个分区
    }
    
    return 5;  // 搜索范围 + 临近范围 + 浮点数误差范围 + 循环锁定 + 使用说明
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // 检查是否是关于页面的表格视图
    if (tableView.tag == 1001) {
        // 不再从这里处理关于页面的表格视图，因为我们使用了自定义数据源
        return 0;
    }
    
    // 原有的表格视图行数逻辑
    switch (section) {
        case SettingsSectionTypeSearchRange:
            return 2;  // 下限和上限
        case SettingsSectionTypeNearRange:
            return 2;  // 临近范围、限制数量
        case SettingsSectionTypeFloatErrorRange:
            return 3;  // 浮点数误差范围 + 有符号/无符号模式 + 模糊字符 (删除整数误差范围)
        case SettingsSectionTypeLoopLock:
            return 2;  // 循环脚本 + 数据锁定
        case SettingsSectionTypeHelp:
            return 3;  // 使用协议 + 加群反馈 + 关于应用
        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // 检查是否是关于页面的表格视图
    if (tableView.tag == 1001) {
        // 不再从这里处理关于页面的表格视图，因为我们使用了自定义数据源
        return [[UITableViewCell alloc] init];
    }
    
    // 原有的单元格配置逻辑
    static NSString *cellIdentifier = @"SettingsCell";
    static NSString *switchCellIdentifier = @"SwitchCell";
    
    UITableViewCell *cell;
    
    switch (indexPath.section) {
        case SettingsSectionTypeSearchRange: {
            cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
            
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
            }
            
            switch (indexPath.row) {
                case SettingsRowTypeSearchLowerLimit: {
                    cell.textLabel.text = @"搜索下限";
                    cell.imageView.image = [UIImage systemImageNamed:@"arrow.down.circle"];
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"0x%llX", _currentLowerLimit];
                    break;
                }
                case SettingsRowTypeSearchUpperLimit: {
                    cell.textLabel.text = @"搜索上限";
                    cell.imageView.image = [UIImage systemImageNamed:@"arrow.up.circle"];
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"0x%llX", _currentUpperLimit];
                    break;
                }
            }
            break;
        }
        case SettingsSectionTypeNearRange: {
            cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
            
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
            }
            
            switch (indexPath.row) {
                case SettingsRowTypeNearRangeValue: {
                    cell.textLabel.text = @"临近范围";
                    cell.imageView.image = [UIImage systemImageNamed:@"scope"];
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"0x%X", _currentNearRangeValue];
                    break;
                }
                case SettingsRowTypeLimitCount: {
                    cell.textLabel.text = @"结果限制";
                    cell.imageView.image = [UIImage systemImageNamed:@"number"];

                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)_currentLimitCount];
                    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
                    break;
                }

            }
            break;
        }
        case SettingsSectionTypeFloatErrorRange: {
            switch (indexPath.row) {
                case SettingsRowTypeFloatErrorRange: {
                    cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
                    
                    if (cell == nil) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
                    }
                    
                    cell.textLabel.text = @"浮点误差";
                    cell.imageView.image = [UIImage systemImageNamed:@"slider.horizontal.3"];
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f", _currentFloatErrorRange];
                    break;
                }
                case SettingsRowTypeFloatSignMode: {
                    cell = [tableView dequeueReusableCellWithIdentifier:switchCellIdentifier];
                    
                    if (cell == nil) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:switchCellIdentifier];
                    }
                    
                    // 设置文本和图标
                    cell.textLabel.text = @"符号模式";
                    cell.imageView.image = [UIImage systemImageNamed:@"signpost.right"];
                    
                    if (self.floatSignModeSwitch == nil) {
                        self.floatSignModeSwitch = [[UISwitch alloc] init];
                        [self.floatSignModeSwitch addTarget:self action:@selector(floatSignModeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                    }
                    
                    // 设置开关状态，默认为有符号模式
                    self.floatSignModeSwitch.on = _isFloatSignedMode;
                    cell.accessoryView = self.floatSignModeSwitch;
                    
                    break;
                }
                case SettingsRowTypeFuzzyString: {
                    cell = [tableView dequeueReusableCellWithIdentifier:switchCellIdentifier];
                    
                    if (cell == nil) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:switchCellIdentifier];
                    }
                    
                    // 设置文本和图标
                    cell.textLabel.text = @"模糊字符";
                    cell.imageView.image = [UIImage systemImageNamed:@"character"];
                    
                    if (self.fuzzyStringSwitch == nil) {
                        self.fuzzyStringSwitch = [[UISwitch alloc] init];
                        [self.fuzzyStringSwitch addTarget:self action:@selector(fuzzyStringSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                    }
                    
                    // 设置开关状态，默认为关闭
                    self.fuzzyStringSwitch.on = _isFuzzyStringEnabled;
                    cell.accessoryView = self.fuzzyStringSwitch;
                    
                    break;
                }
            }
            break;
        }
        case SettingsSectionTypeLoopLock: {
            cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
            
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
            }
            
            switch (indexPath.row) {
                case SettingsRowTypeLoopScript: {
                    cell.textLabel.text = @"循环脚本";
                    cell.imageView.image = [UIImage systemImageNamed:@"repeat.circle"];
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.2f秒", (float)_duration/1000.0];
                    break;
                }
                case SettingsRowTypeDataLock: {
                    cell.textLabel.text = @"数据锁定";
                    cell.imageView.image = [UIImage systemImageNamed:@"lock.circle"];
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.2f秒", (float)_duration1/1000.0];
                    break;
                }
            }
            break;
        }
        case SettingsSectionTypeHelp: {
            cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
            
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
            }
            
            switch (indexPath.row) {
                case SettingsRowTypeUserAgreement: {
                    cell.textLabel.text = @"使用协议";
                    cell.imageView.image = [UIImage systemImageNamed:@"doc.text"];
                    cell.detailTextLabel.text = @""; // 清除详细文本
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    break;
                }
                case SettingsRowTypeFeedbackGroup: {
                    cell.textLabel.text = @"加群反馈";
                    cell.imageView.image = [UIImage systemImageNamed:@"bubble.left.and.bubble.right"];
                    cell.detailTextLabel.text = @""; // 清除详细文本
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    break;
                }
                case SettingsRowTypeAboutApp: {
                    cell.textLabel.text = @"关于应用";
                    cell.imageView.image = [UIImage systemImageNamed:@"info.circle"];
                    cell.detailTextLabel.text = @""; // 清除详细文本
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    break;
                }
            }
            break;
        }
    }
    
    // 适配深色和浅色模式的颜色
    if (@available(iOS 13.0, *)) {
        cell.textLabel.textColor = [UIColor labelColor];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        cell.backgroundColor = [UIColor secondarySystemBackgroundColor];
    } else {
        cell.textLabel.textColor = [UIColor blackColor];
        cell.detailTextLabel.textColor = [UIColor darkGrayColor];
        cell.backgroundColor = [UIColor whiteColor];
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 40.0;  // 增加 cell 高度到 60 点
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    // 获取当前分区的总行数
    NSInteger numberOfRows = [self tableView:tableView numberOfRowsInSection:indexPath.section];
    
    // 设置默认圆角为0（中间的cell不应该有圆角）
    cell.layer.cornerRadius = 0;
    cell.layer.masksToBounds = YES;
    
    // 清除之前可能设置的maskedCorners
    cell.layer.maskedCorners = 0;
    
    // 只为第一个和最后一个cell设置圆角
    if (numberOfRows == 1) {
        // 如果只有一行，则全部圆角
        cell.layer.cornerRadius = 8;
        cell.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | 
                                   kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    } else if (indexPath.row == 0) {
        // 第一行只添加顶部圆角
        cell.layer.cornerRadius = 8;
        cell.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    } else if (indexPath.row == numberOfRows - 1) {
        // 最后一行只添加底部圆角
        cell.layer.cornerRadius = 8;
        cell.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    }
    
    // 移除所有可能存在的分割线
    for (UIView *subview in cell.contentView.subviews) {
        if (subview.frame.size.height <= 0.5 && 
            [subview isKindOfClass:[UIView class]]) {
            [subview removeFromSuperview];
        }
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case SettingsSectionTypeSearchRange:
            return @"搜索范围";
        case SettingsSectionTypeNearRange:
            return @"临近范围";
        case SettingsSectionTypeFloatErrorRange:
            return @"浮点误差";
        case SettingsSectionTypeLoopLock:
            return @"循环锁定";
        case SettingsSectionTypeHelp:
            return @"使用说明";
        default:
            return @"";
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 40.0;  // 增加 section header 高度到 40 点
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 10.0;  // 添加一个小的 footer 高度，增加 section 之间的间距
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *headerView = [[UIView alloc] init];
    headerView.backgroundColor = [UIColor clearColor];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    titleLabel.textColor = [UIColor secondaryLabelColor];
    
    switch (section) {
        case SettingsSectionTypeSearchRange:
            titleLabel.text = @"搜索范围";
            break;
        case SettingsSectionTypeNearRange:
            titleLabel.text = @"临近范围";
            break;
        case SettingsSectionTypeFloatErrorRange:
            titleLabel.text = @"浮点误差";
            break;
        case SettingsSectionTypeLoopLock:
            titleLabel.text = @"循环锁定";
            break;
        case SettingsSectionTypeHelp:
            titleLabel.text = @"使用说明";
            break;
    }
    
    [headerView addSubview:titleLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor constant:20],
        [titleLabel.centerYAnchor constraintEqualToAnchor:headerView.centerYAnchor],
        [titleLabel.heightAnchor constraintEqualToConstant:20]
    ]];
    
    return headerView;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    UIView *footerView = [[UIView alloc] init];
    footerView.backgroundColor = [UIColor clearColor];
    return footerView;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // 对于开关类型的cell，直接返回，不弹出弹窗
    if ((indexPath.section == SettingsSectionTypeFloatErrorRange &&
         indexPath.row == SettingsRowTypeFloatSignMode) ||
        (indexPath.section == SettingsSectionTypeFloatErrorRange &&
         indexPath.row == SettingsRowTypeFuzzyString)) {
        return;
    }
    
    // 处理使用说明部分的点击事件
    if (indexPath.section == SettingsSectionTypeHelp) {
        switch (indexPath.row) {
            case SettingsRowTypeUserAgreement:
                [self showUserAgreement];
                return;
            case SettingsRowTypeFeedbackGroup:
                [self showFeedbackGroup];
                return;
            case SettingsRowTypeAboutApp:
                [self showAboutApp];
                return;
        }
    }
    
    NSString *title, *message, *placeholder;
    switch (indexPath.section) {
        case SettingsSectionTypeSearchRange: {
            switch (indexPath.row) {
                case SettingsRowTypeSearchLowerLimit: {
                    title = @"下限范围";
                    message = [NSString stringWithFormat:@"当前下限：0x%llX\n请输入新的搜索下限地址", _currentLowerLimit];
                    placeholder = @"输入十六进制地址（如 0x1000000000）";
                    break;
                }
                case SettingsRowTypeSearchUpperLimit: {
                    title = @"上限范围";
                    message = [NSString stringWithFormat:@"当前上限：0x%llX\n请输入新的搜索上限地址", _currentUpperLimit];
                    placeholder = @"输入十六进制地址（如 0x160000000）";
                    break;
                }
            }
            break;
        }
        case SettingsSectionTypeNearRange: {
            switch (indexPath.row) {
                case SettingsRowTypeNearRangeValue: {
                    title = @"临近范围";
                    message = [NSString stringWithFormat:@"当前临近范围：0x%X\n请输入新的临近搜索范围", _currentNearRangeValue];
                    placeholder = @"输入十六进制值（如 0x40）";
                    break;
                }
                case SettingsRowTypeLimitCount: {
                    title = @"结果限制";
                    message = [NSString stringWithFormat:@"当前限制：%ld\n请输入新的搜索结果数量限制", (long)_currentLimitCount];
                    placeholder = @"输入数字（如 10000）";
                    break;
                }
            }
            break;
        }
        case SettingsSectionTypeFloatErrorRange: {
            switch (indexPath.row) {
                case SettingsRowTypeFloatErrorRange: {
                    title = @"浮点误差";
                    message = [NSString stringWithFormat:@"当前浮点误差：%.1f\n请输入新的浮点误差范围", _currentFloatErrorRange];
                    placeholder = @"输入浮点数（如 0.0）";
                    break;
                }
                case SettingsRowTypeFloatSignMode: {
                    // 这里不需要处理，因为已经在方法开头返回
                    return;
                }
                case SettingsRowTypeFuzzyString: {
                    // 这里不需要处理，因为已经在方法开头返回
                    return;
                }
            }
            break;
        }
        case SettingsSectionTypeLoopLock: {
            switch (indexPath.row) {
                case SettingsRowTypeLoopScript: {
                    title = @"循环脚本";
                    message = [NSString stringWithFormat:@"当前循环间隔：%.2f秒\n请输入新的循环脚本间隔", (float)_duration/1000.0];
                    placeholder = @"输入秒数（如 0.1）";
                    break;
                }
                case SettingsRowTypeDataLock: {
                    title = @"数据锁定";
                    message = [NSString stringWithFormat:@"当前锁定间隔：%.2f秒\n请输入新的数据锁定间隔", (float)_duration1/1000.0];
                    placeholder = @"输入秒数（如 0.02）";
                    break;
                }
            }
            break;
        }
        default:
            return;
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title 
                                                                           message:message 
                                                                    preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = placeholder;
        textField.keyboardType = indexPath.section == SettingsSectionTypeSearchRange ? 
            UIKeyboardTypeASCIICapable : 
            (indexPath.section == SettingsSectionTypeFloatErrorRange || 
             (indexPath.section == SettingsSectionTypeLoopLock)) ? 
            UIKeyboardTypeDecimalPad : UIKeyboardTypeNumberPad;
    }];
    
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确定" 
                                                            style:UIAlertActionStyleDefault 
                                                          handler:^(UIAlertAction * _Nonnull action) {
        UITextField *textField = alertController.textFields.firstObject;
        NSString *inputValue = textField.text;
        
        VMTool *vmTool = [VMTool share];
        
        switch (indexPath.section) {
            case SettingsSectionTypeSearchRange: {
                uint64_t newValue = 0;
                NSScanner *scanner = [NSScanner scannerWithString:inputValue];
                
                if ([inputValue hasPrefix:@"0x"] || [inputValue hasPrefix:@"0X"]) {
                    [scanner scanHexLongLong:&newValue];
                } else {
                    newValue = (uint64_t)strtoull([inputValue UTF8String], NULL, 16);
                }
                
                switch (indexPath.row) {
                    case SettingsRowTypeSearchLowerLimit: {
                        [vmTool setAddrRange:[NSString stringWithFormat:@"0x%llX", newValue]];
                        self->_currentLowerLimit = newValue;
                        break;
                    }
                    case SettingsRowTypeSearchUpperLimit: {
                        [vmTool setAddrRangeUpp:[NSString stringWithFormat:@"0x%llX", newValue]];
                        self->_currentUpperLimit = newValue;
                        break;
                    }
                }
                break;
            }
            case SettingsSectionTypeNearRange: {
                switch (indexPath.row) {
                    case SettingsRowTypeNearRangeValue: {
                        int newValue = (int)strtol([inputValue UTF8String], NULL, 16);
                        [vmTool setRange:[NSString stringWithFormat:@"0x%X", newValue]];
                        self->_currentNearRangeValue = newValue;
                        break;
                    }
                    case SettingsRowTypeLimitCount: {
                        NSInteger newValue = [inputValue integerValue];

                        NSInteger maxSafeLimit = 10000000; // 1000万条安全上限

                        if (newValue > maxSafeLimit) {
                            NSString *warningMessage = [NSString stringWithFormat:@"设置的结果限制过大 (%ld)，可能导致内存溢出。\n\n已自动调整为安全上限：%ld", (long)newValue, (long)maxSafeLimit];

                            UIAlertController *warningAlert = [UIAlertController alertControllerWithTitle:@"结果限制调整"
                                                                                                  message:warningMessage
                                                                                           preferredStyle:UIAlertControllerStyleAlert];

                            UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
                            [warningAlert addAction:okAction];

                            [self presentViewController:warningAlert animated:YES completion:nil];

                            newValue = maxSafeLimit;
                        }

                        [vmTool setLimitCount:[NSString stringWithFormat:@"%ld", (long)newValue]];
                        self->_currentLimitCount = newValue;
                        break;
                    }
                }
                break;
            }
            case SettingsSectionTypeFloatErrorRange: {
                switch (indexPath.row) {
                    case SettingsRowTypeFloatErrorRange: {
                        CGFloat newValue = [inputValue floatValue];
                        [vmTool setFloatErrorRange:[NSString stringWithFormat:@"%.1f", newValue]];
                        self->_currentFloatErrorRange = newValue;
                        break;
                    }
                }
                break;
            }
            case SettingsSectionTypeLoopLock: {
                switch (indexPath.row) {
                    case SettingsRowTypeLoopScript: {
                        CGFloat newValue = [inputValue floatValue];
                        [vmTool setDuration:[NSString stringWithFormat:@"%ld", (long)(newValue*1000)]];
                        self->_duration = (NSInteger)(newValue*1000);
                        break;
                    }
                    case SettingsRowTypeDataLock: {
                        CGFloat newValue = [inputValue floatValue];
                        [vmTool setDuration1:[NSString stringWithFormat:@"%ld", (long)(newValue*1000)]];
                        self->_duration1 = (NSInteger)(newValue*1000);
                        break;
                    }
                }
                break;
            }
        }
        
        [tableView reloadData];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" 
                                                           style:UIAlertActionStyleCancel 
                                                         handler:nil];
    
    [alertController addAction:confirmAction];
    [alertController addAction:cancelAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

// 添加开关状态改变的方法
- (void)floatSignModeSwitchChanged:(UISwitch *)sender {
    // 保存符号模式状态到 NSUserDefaults
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:@"FloatSignMode"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 更新本地状态
    _isFloatSignedMode = sender.isOn;
    
    // 发送通知，通知搜索界面更新
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FloatSignModeChangedNotification" 
                                                        object:nil 
                                                      userInfo:@{@"isSignedMode": @(sender.isOn)}];
}

// 新增模糊字符开关响应方法
- (void)fuzzyStringSwitchChanged:(UISwitch *)sender {
    _isFuzzyStringEnabled = sender.isOn;
    [[NSUserDefaults standardUserDefaults] setBool:_isFuzzyStringEnabled forKey:@"FuzzyStringMode"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}



- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    // 对于开关类型的cell，返回NO禁止高亮
    if ((indexPath.section == SettingsSectionTypeFloatErrorRange &&
        indexPath.row == SettingsRowTypeFloatSignMode) ||
        (indexPath.section == SettingsSectionTypeFloatErrorRange &&
        indexPath.row == SettingsRowTypeFuzzyString)) {
        return NO;
    }
    return YES;
}

// 同时保留之前的 willSelectRowAtIndexPath 方法
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // 如果是开关类型的cell，返回nil禁止选中
    if ((indexPath.section == SettingsSectionTypeFloatErrorRange &&
        indexPath.row == SettingsRowTypeFloatSignMode) ||
        (indexPath.section == SettingsSectionTypeFloatErrorRange &&
        indexPath.row == SettingsRowTypeFuzzyString)) {
        return nil;
    }
    return indexPath;
}

// 添加使用说明相关方法
- (void)showUserAgreement {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"使用协议" 
                                                                           message:@"本应用仅供学习和研究iOS开发技术，请勿用于非法用途。使用本应用即表示您同意遵守相关法律法规，并对使用后果自负。\n24小时内进行删除，任何法律责任与我无关。" 
                                                                    preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"我同意" 
                                                      style:UIAlertActionStyleDefault 
                                                    handler:nil];
    [alertController addAction:okAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)showFeedbackGroup {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"加群反馈" 
                                                                           message:@"如有问题或建议，欢迎加群反馈"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *joinQQAction = [UIAlertAction actionWithTitle:@"加入QQ群" 
                                                        style:UIAlertActionStyleDefault 
                                                      handler:^(UIAlertAction * _Nonnull action) {
        // 尝试打开QQ群链接
        NSString *qqGroupURL = @"https://qm.qq.com/q/hejecSB8yI";
        NSURL *qqURL = [NSURL URLWithString:qqGroupURL];
        
        if ([[UIApplication sharedApplication] canOpenURL:qqURL]) {
            [[UIApplication sharedApplication] openURL:qqURL options:@{} completionHandler:nil];
        } else {
            // 如果无法打开QQ应用，则复制群号到剪贴板
            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
            pasteboard.string = @"922961660";
            
            // 显示复制成功提示
            UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"未安装QQ" 
                                                                             message:@"QQ群号已复制到剪贴板" 
                                                                      preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" 
                                                          style:UIAlertActionStyleDefault 
                                                        handler:nil];
            [successAlert addAction:okAction];
            [self presentViewController:successAlert animated:YES completion:nil];
        }
    }];
    
    UIAlertAction *joinTGAction = [UIAlertAction actionWithTitle:@"加入Telegram群" 
                                                         style:UIAlertActionStyleDefault 
                                                       handler:^(UIAlertAction * _Nonnull action) {
        // 尝试打开Telegram群链接
        NSString *tgGroupURL = @"https://t.me/Obsolete_88";
        NSURL *tgURL = [NSURL URLWithString:tgGroupURL];
        
        if ([[UIApplication sharedApplication] canOpenURL:tgURL]) {
            [[UIApplication sharedApplication] openURL:tgURL options:@{} completionHandler:nil];
        } else {
            // 如果无法打开Telegram应用，则复制链接到剪贴板
            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
            pasteboard.string = tgGroupURL;
            
            // 显示复制成功提示
            UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"未安装Telegram" 
                                                                             message:@"Telegram群链接已复制到剪贴板" 
                                                                      preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" 
                                                          style:UIAlertActionStyleDefault 
                                                        handler:nil];
            [successAlert addAction:okAction];
            [self presentViewController:successAlert animated:YES completion:nil];
        }
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" 
                                                          style:UIAlertActionStyleCancel 
                                                        handler:nil];
    
    [alertController addAction:joinQQAction];
    [alertController addAction:joinTGAction];
    [alertController addAction:cancelAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)showAboutApp {
    // 创建关于应用的视图控制器
    UIViewController *aboutViewController = [[UIViewController alloc] init];
    aboutViewController.title = @"关于应用";

    // 设置现代化渐变背景
    [self setupGradientBackgroundForView:aboutViewController.view];

    // 创建滚动视图以容纳内容
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;

    // 确保滚动视图不会阻止子视图的点击事件
    scrollView.userInteractionEnabled = YES;
    scrollView.delaysContentTouches = NO;
    scrollView.canCancelContentTouches = NO;

    [aboutViewController.view addSubview:scrollView];

    // 设置滚动视图约束
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:aboutViewController.view.safeAreaLayoutGuide.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:aboutViewController.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:aboutViewController.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:aboutViewController.view.safeAreaLayoutGuide.bottomAnchor]
    ]];

    // 创建内容容器视图
    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    contentView.userInteractionEnabled = YES; // 确保内容视图启用用户交互
    [scrollView addSubview:contentView];

    // 设置内容视图约束
    [NSLayoutConstraint activateConstraints:@[
        [contentView.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor]
    ]];
    
    // 创建应用图标容器（带阴影效果）
    UIView *iconContainer = [[UIView alloc] init];
    iconContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:iconContainer];

    // 添加现代化应用图标
    UIImageView *appIconView = [[UIImageView alloc] init];
    appIconView.translatesAutoresizingMaskIntoConstraints = NO;
    appIconView.layer.cornerRadius = 25;
    appIconView.layer.masksToBounds = YES;

    // 添加阴影效果
    iconContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    iconContainer.layer.shadowOffset = CGSizeMake(0, 8);
    iconContainer.layer.shadowRadius = 20;
    iconContainer.layer.shadowOpacity = 0.15;

    // 创建现代化图标
    [self setupModernAppIcon:appIconView];

    [iconContainer addSubview:appIconView];

    // 设置图标容器约束
    [NSLayoutConstraint activateConstraints:@[
        [iconContainer.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:20],
        [iconContainer.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [iconContainer.widthAnchor constraintEqualToConstant:80],
        [iconContainer.heightAnchor constraintEqualToConstant:80]
    ]];

    // 设置应用图标约束
    [NSLayoutConstraint activateConstraints:@[
        [appIconView.centerXAnchor constraintEqualToAnchor:iconContainer.centerXAnchor],
        [appIconView.centerYAnchor constraintEqualToAnchor:iconContainer.centerYAnchor],
        [appIconView.widthAnchor constraintEqualToConstant:80],
        [appIconView.heightAnchor constraintEqualToConstant:80]
    ]];
    
    // 添加现代化应用名称标签
    UILabel *appNameLabel = [[UILabel alloc] init];
    appNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    appNameLabel.text = @"Obsolete";
    appNameLabel.font = [UIFont systemFontOfSize:32 weight:UIFontWeightBold];
    appNameLabel.textAlignment = NSTextAlignmentCenter;

    // 添加渐变文字效果
    if (@available(iOS 13.0, *)) {
        appNameLabel.textColor = [UIColor labelColor];
    } else {
        appNameLabel.textColor = [UIColor blackColor];
    }

    [contentView addSubview:appNameLabel];

    // 设置应用名称标签约束
    [NSLayoutConstraint activateConstraints:@[
        [appNameLabel.topAnchor constraintEqualToAnchor:iconContainer.bottomAnchor constant:15],
        [appNameLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [appNameLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [appNameLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor]
    ]];

    // 添加副标题
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.text = @"iOS Memory Modifier";
    subtitleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    if (@available(iOS 13.0, *)) {
        subtitleLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        subtitleLabel.textColor = [UIColor darkGrayColor];
    }

    [contentView addSubview:subtitleLabel];

    // 添加版本标签
    NSString *appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"2.3";

    UILabel *versionLabel = [[UILabel alloc] init];
    versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    versionLabel.text = [NSString stringWithFormat:@"Version %@", appVersion];
    versionLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    versionLabel.textAlignment = NSTextAlignmentCenter;
    if (@available(iOS 13.0, *)) {
        versionLabel.textColor = [UIColor tertiaryLabelColor];
    } else {
        versionLabel.textColor = [UIColor lightGrayColor];
    }

    [contentView addSubview:versionLabel];

    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        [subtitleLabel.topAnchor constraintEqualToAnchor:appNameLabel.bottomAnchor constant:8],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [subtitleLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],

        [versionLabel.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:8],
        [versionLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [versionLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [versionLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor]
    ]];
    
    // 创建现代化功能卡片容器
    UIView *featuresContainer = [[UIView alloc] init];
    featuresContainer.translatesAutoresizingMaskIntoConstraints = NO;
    featuresContainer.userInteractionEnabled = YES; // 确保功能卡片容器启用用户交互
    [contentView addSubview:featuresContainer];

    // 创建授权状态卡片
    UIView *authCard = [self createAuthorizationStatusCard];
    [featuresContainer addSubview:authCard];

    [NSLayoutConstraint activateConstraints:@[
        [authCard.leadingAnchor constraintEqualToAnchor:featuresContainer.leadingAnchor constant:20],
        [authCard.trailingAnchor constraintEqualToAnchor:featuresContainer.trailingAnchor constant:-20],
        [authCard.topAnchor constraintEqualToAnchor:featuresContainer.topAnchor],
        [authCard.heightAnchor constraintEqualToConstant:80]
    ]];

    // 创建功能卡片
    NSArray *features = @[
        @{@"title": @"功能介绍", @"subtitle": @"iOS内存搜索与修改工具", @"icon": @"doc.text.fill", @"color": @"systemBlue"},
        @{@"title": @"购买地址", @"subtitle": @"获取完整版本和技术支持", @"icon": @"cart.fill", @"color": @"systemOrange"}
    ];

    UIView *previousCard = authCard;
    for (int i = 0; i < features.count; i++) {
        NSDictionary *feature = features[i];
        UIView *featureCard = [self createModernFeatureCard:feature];
        [featuresContainer addSubview:featureCard];

        [NSLayoutConstraint activateConstraints:@[
            [featureCard.leadingAnchor constraintEqualToAnchor:featuresContainer.leadingAnchor constant:20],
            [featureCard.trailingAnchor constraintEqualToAnchor:featuresContainer.trailingAnchor constant:-20],
            [featureCard.heightAnchor constraintEqualToConstant:70]
        ]];

        [featureCard.topAnchor constraintEqualToAnchor:previousCard.bottomAnchor constant:12].active = YES;

        if (i == features.count - 1) {
            [featureCard.bottomAnchor constraintEqualToAnchor:featuresContainer.bottomAnchor].active = YES;
        }

        previousCard = featureCard;
    }

    // 设置功能容器约束
    [NSLayoutConstraint activateConstraints:@[
        [featuresContainer.topAnchor constraintEqualToAnchor:versionLabel.bottomAnchor constant:20],
        [featuresContainer.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [featuresContainer.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor]
    ]];

    // 添加功能说明区域
    UIView *descriptionContainer = [[UIView alloc] init];
    descriptionContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:descriptionContainer];

    // 创建更新内容标题
    UILabel *descriptionTitle = [[UILabel alloc] init];
    descriptionTitle.translatesAutoresizingMaskIntoConstraints = NO;
    descriptionTitle.text = @"🎉 v2.3 重大更新";
    descriptionTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    if (@available(iOS 13.0, *)) {
        descriptionTitle.textColor = [UIColor labelColor];
    } else {
        descriptionTitle.textColor = [UIColor blackColor];
    }
    [descriptionContainer addSubview:descriptionTitle];

    // 创建更新内容
    UILabel *descriptionContent = [[UILabel alloc] init];
    descriptionContent.translatesAutoresizingMaskIntoConstraints = NO;
    descriptionContent.text = @"🔧 全新插件制作器功能\n📚 30个专业代码模板\n🎨 12种创意弹窗模板\n⚡ 一键编译部署系统";
    descriptionContent.font = [UIFont systemFontOfSize:14];
    descriptionContent.numberOfLines = 0;
    descriptionContent.lineBreakMode = NSLineBreakByWordWrapping;
    if (@available(iOS 13.0, *)) {
        descriptionContent.textColor = [UIColor secondaryLabelColor];
    } else {
        descriptionContent.textColor = [UIColor darkGrayColor];
    }
    [descriptionContainer addSubview:descriptionContent];

    // 设置功能说明约束
    [NSLayoutConstraint activateConstraints:@[
        [descriptionContainer.topAnchor constraintEqualToAnchor:featuresContainer.bottomAnchor constant:15],
        [descriptionContainer.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [descriptionContainer.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],

        [descriptionTitle.topAnchor constraintEqualToAnchor:descriptionContainer.topAnchor],
        [descriptionTitle.leadingAnchor constraintEqualToAnchor:descriptionContainer.leadingAnchor],
        [descriptionTitle.trailingAnchor constraintEqualToAnchor:descriptionContainer.trailingAnchor],

        [descriptionContent.topAnchor constraintEqualToAnchor:descriptionTitle.bottomAnchor constant:8],
        [descriptionContent.leadingAnchor constraintEqualToAnchor:descriptionContainer.leadingAnchor],
        [descriptionContent.trailingAnchor constraintEqualToAnchor:descriptionContainer.trailingAnchor],
        [descriptionContent.bottomAnchor constraintEqualToAnchor:descriptionContainer.bottomAnchor]
    ]];

    // 添加现代化版权信息区域
    UIView *footerContainer = [[UIView alloc] init];
    footerContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:footerContainer];

    // 添加分割线
    UIView *separatorLine = [[UIView alloc] init];
    separatorLine.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        separatorLine.backgroundColor = [UIColor separatorColor];
    } else {
        separatorLine.backgroundColor = [UIColor lightGrayColor];
    }
    [footerContainer addSubview:separatorLine];

    // 添加版权信息标签
    UILabel *copyrightLabel = [[UILabel alloc] init];
    copyrightLabel.translatesAutoresizingMaskIntoConstraints = NO;
    copyrightLabel.text = @"Copyright © 2025 Obsolete Team";
    copyrightLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    copyrightLabel.textAlignment = NSTextAlignmentCenter;
    if (@available(iOS 13.0, *)) {
        copyrightLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        copyrightLabel.textColor = [UIColor darkGrayColor];
    }
    [footerContainer addSubview:copyrightLabel];

    // 添加技术信息标签
    UILabel *techLabel = [[UILabel alloc] init];
    techLabel.translatesAutoresizingMaskIntoConstraints = NO;
    techLabel.text = @"Made with ❤️ for iOS Research";
    techLabel.font = [UIFont systemFontOfSize:12];
    techLabel.textAlignment = NSTextAlignmentCenter;
    if (@available(iOS 13.0, *)) {
        techLabel.textColor = [UIColor tertiaryLabelColor];
    } else {
        techLabel.textColor = [UIColor lightGrayColor];
    }
    [footerContainer addSubview:techLabel];

    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        [footerContainer.topAnchor constraintEqualToAnchor:descriptionContainer.bottomAnchor constant:20],
        [footerContainer.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [footerContainer.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [footerContainer.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-20],

        [separatorLine.topAnchor constraintEqualToAnchor:footerContainer.topAnchor],
        [separatorLine.centerXAnchor constraintEqualToAnchor:footerContainer.centerXAnchor],
        [separatorLine.widthAnchor constraintEqualToConstant:60],
        [separatorLine.heightAnchor constraintEqualToConstant:2],

        [copyrightLabel.topAnchor constraintEqualToAnchor:separatorLine.bottomAnchor constant:12],
        [copyrightLabel.leadingAnchor constraintEqualToAnchor:footerContainer.leadingAnchor constant:20],
        [copyrightLabel.trailingAnchor constraintEqualToAnchor:footerContainer.trailingAnchor constant:-20],

        [techLabel.topAnchor constraintEqualToAnchor:copyrightLabel.bottomAnchor constant:6],
        [techLabel.leadingAnchor constraintEqualToAnchor:footerContainer.leadingAnchor constant:20],
        [techLabel.trailingAnchor constraintEqualToAnchor:footerContainer.trailingAnchor constant:-20],
        [techLabel.bottomAnchor constraintEqualToAnchor:footerContainer.bottomAnchor]
    ]];
    
    // 创建导航控制器并推入关于视图控制器
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:aboutViewController];
    
    // 添加关闭按钮
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
                                                                                target:self 
                                                                                action:@selector(dismissAboutView:)];
    aboutViewController.navigationItem.rightBarButtonItem = closeButton;
    
    // 模态显示导航控制器
    [self presentViewController:navController animated:YES completion:nil];
}

// 关闭关于视图的方法
- (void)dismissAboutView:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}



#pragma mark - 美化界面辅助方法

// 设置渐变背景
- (void)setupGradientBackgroundForView:(UIView *)view {
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.frame = view.bounds;

    if (@available(iOS 13.0, *)) {
        gradientLayer.colors = @[
            (id)[UIColor systemBackgroundColor].CGColor,
            (id)[UIColor secondarySystemBackgroundColor].CGColor
        ];
    } else {
        gradientLayer.colors = @[
            (id)[UIColor colorWithRed:0.98 green:0.98 blue:1.0 alpha:1.0].CGColor,
            (id)[UIColor colorWithRed:0.95 green:0.95 blue:0.97 alpha:1.0].CGColor
        ];
    }

    gradientLayer.startPoint = CGPointMake(0.0, 0.0);
    gradientLayer.endPoint = CGPointMake(1.0, 1.0);

    [view.layer insertSublayer:gradientLayer atIndex:0];

    // 监听界面旋转，更新渐变层大小
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateGradientFrame:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
}

// 更新渐变层大小
- (void)updateGradientFrame:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (CALayer *layer in self.view.layer.sublayers) {
            if ([layer isKindOfClass:[CAGradientLayer class]]) {
                layer.frame = self.view.bounds;
            }
        }
    });
}

// 设置现代化应用图标
- (void)setupModernAppIcon:(UIImageView *)iconView {
    // 创建渐变背景
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.frame = CGRectMake(0, 0, 100, 100);
    gradientLayer.cornerRadius = 25;

    // 设置现代化渐变色
    gradientLayer.colors = @[
        (id)[UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.1 green:0.4 blue:0.8 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.05 green:0.2 blue:0.6 alpha:1.0].CGColor
    ];

    gradientLayer.startPoint = CGPointMake(0.0, 0.0);
    gradientLayer.endPoint = CGPointMake(1.0, 1.0);

    // 创建图标符号
    UIImage *symbolImage;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:40 weight:UIImageSymbolWeightBold];
        symbolImage = [UIImage systemImageNamed:@"memorychip.fill" withConfiguration:config];
        if (!symbolImage) {
            symbolImage = [UIImage systemImageNamed:@"cpu.fill" withConfiguration:config];
        }
    }

    // 设置图标
    [iconView.layer insertSublayer:gradientLayer atIndex:0];
    iconView.image = symbolImage;
    iconView.tintColor = [UIColor whiteColor];
    iconView.contentMode = UIViewContentModeCenter;
}

// 创建授权状态卡片
- (UIView *)createAuthorizationStatusCard {
    UIView *cardView = [[UIView alloc] init];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;

    // 设置卡片样式
    cardView.layer.cornerRadius = 16;
    cardView.layer.masksToBounds = NO;
    cardView.layer.shadowColor = [UIColor blackColor].CGColor;
    cardView.layer.shadowOffset = CGSizeMake(0, 2);
    cardView.layer.shadowRadius = 8;
    cardView.layer.shadowOpacity = 0.1;

    // 根据授权状态设置背景色
    BOOL isAuthorized = NO; // 这里后期需要实际检查授权状态
    if (isAuthorized) {
        if (@available(iOS 13.0, *)) {
            cardView.backgroundColor = [UIColor systemGreenColor];
        } else {
            cardView.backgroundColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:1.0];
        }
    } else {
        if (@available(iOS 13.0, *)) {
            cardView.backgroundColor = [UIColor systemOrangeColor];
        } else {
            cardView.backgroundColor = [UIColor colorWithRed:1.0 green:0.6 blue:0.0 alpha:1.0];
        }
    }

    // 添加图标
    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightBold];
        if (isAuthorized) {
            iconView.image = [UIImage systemImageNamed:@"checkmark.shield.fill" withConfiguration:config];
        } else {
            iconView.image = [UIImage systemImageNamed:@"exclamationmark.shield.fill" withConfiguration:config];
        }
    }
    iconView.tintColor = [UIColor whiteColor];
    [cardView addSubview:iconView];

    // 添加状态标题
    UILabel *statusLabel = [[UILabel alloc] init];
    statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    statusLabel.text = isAuthorized ? @"已授权" : @"未授权";
    statusLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    statusLabel.textColor = [UIColor whiteColor];
    [cardView addSubview:statusLabel];

    // 添加状态描述
    UILabel *descLabel = [[UILabel alloc] init];
    descLabel.translatesAutoresizingMaskIntoConstraints = NO;
    descLabel.text = isAuthorized ? @"应用已通过验证，可正常使用所有功能" : @"需要验证授权后才能使用完整功能";
    descLabel.font = [UIFont systemFontOfSize:13];
    descLabel.textColor = [UIColor whiteColor];
    descLabel.alpha = 0.9;
    [cardView addSubview:descLabel];

    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        [iconView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:16],
        [iconView.centerYAnchor constraintEqualToAnchor:cardView.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:32],
        [iconView.heightAnchor constraintEqualToConstant:32],

        [statusLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:12],
        [statusLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-16],
        [statusLabel.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:16],

        [descLabel.leadingAnchor constraintEqualToAnchor:statusLabel.leadingAnchor],
        [descLabel.trailingAnchor constraintEqualToAnchor:statusLabel.trailingAnchor],
        [descLabel.topAnchor constraintEqualToAnchor:statusLabel.bottomAnchor constant:4],
        [descLabel.bottomAnchor constraintLessThanOrEqualToAnchor:cardView.bottomAnchor constant:-16]
    ]];

    return cardView;
}

// 创建现代化功能卡片
- (UIView *)createModernFeatureCard:(NSDictionary *)feature {
    UIView *cardView = [[UIView alloc] init];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;

    // 设置卡片样式
    cardView.layer.cornerRadius = 16;
    cardView.layer.masksToBounds = NO;
    cardView.layer.shadowColor = [UIColor blackColor].CGColor;
    cardView.layer.shadowOffset = CGSizeMake(0, 2);
    cardView.layer.shadowRadius = 8;
    cardView.layer.shadowOpacity = 0.1;

    if (@available(iOS 13.0, *)) {
        cardView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    } else {
        cardView.backgroundColor = [UIColor whiteColor];
    }

    // 添加图标
    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightMedium];
        iconView.image = [UIImage systemImageNamed:feature[@"icon"] withConfiguration:config];

        // 设置图标颜色
        NSString *colorName = feature[@"color"];
        if ([colorName isEqualToString:@"systemBlue"]) {
            iconView.tintColor = [UIColor systemBlueColor];
        } else if ([colorName isEqualToString:@"systemGreen"]) {
            iconView.tintColor = [UIColor systemGreenColor];
        } else if ([colorName isEqualToString:@"systemOrange"]) {
            iconView.tintColor = [UIColor systemOrangeColor];
        } else if ([colorName isEqualToString:@"systemPurple"]) {
            iconView.tintColor = [UIColor systemPurpleColor];
        } else if ([colorName isEqualToString:@"systemRed"]) {
            iconView.tintColor = [UIColor systemRedColor];
        }
    }
    [cardView addSubview:iconView];

    // 添加标题
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = feature[@"title"];
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    if (@available(iOS 13.0, *)) {
        titleLabel.textColor = [UIColor labelColor];
    } else {
        titleLabel.textColor = [UIColor blackColor];
    }
    [cardView addSubview:titleLabel];

    // 添加副标题
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.text = feature[@"subtitle"];
    subtitleLabel.font = [UIFont systemFontOfSize:13];
    if (@available(iOS 13.0, *)) {
        subtitleLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        subtitleLabel.textColor = [UIColor darkGrayColor];
    }
    [cardView addSubview:subtitleLabel];

    // 移除箭头，因为不再需要点击功能

    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        [iconView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:16],
        [iconView.centerYAnchor constraintEqualToAnchor:cardView.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:32],
        [iconView.heightAnchor constraintEqualToConstant:32],

        [titleLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:16],
        [titleLabel.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:16],
        [titleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-16],

        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:cardView.bottomAnchor constant:-16]
    ]];

    // 设置为纯信息展示卡片，无点击功能
    cardView.userInteractionEnabled = NO;

    return cardView;
}

@end
