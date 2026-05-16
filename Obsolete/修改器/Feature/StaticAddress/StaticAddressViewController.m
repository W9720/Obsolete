//
//  StaticAddressViewController.m
//  Obsolete
//
//  Created by Assistant on 2025/08/05.
//  静态地址计算器 - 计算IDA/Hopper中的静态地址
//

#import "StaticAddressViewController.h"
#import "ProcessManager.h"
#import "../PointerScan/PointerScanManager.h"

@interface StaticAddressViewController () <UITableViewDataSource, UITableViewDelegate>

// UI 组件
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;

// 进程信息
@property (nonatomic, strong) UILabel *processLabel;
@property (nonatomic, strong) UIButton *refreshButton;

// 模块选择 - 改为表格视图样式
@property (nonatomic, strong) UILabel *moduleLabel;
@property (nonatomic, strong) UITableView *moduleTableView;
@property (nonatomic, strong) UIView *moduleContainerView;
@property (nonatomic, strong) NSArray<ModuleInfo *> *modules;
@property (nonatomic, assign) NSInteger selectedModuleIndex;

// 地址输入
@property (nonatomic, strong) UILabel *dynamicAddressLabel;
@property (nonatomic, strong) UITextField *dynamicAddressField;

// 计算结果
@property (nonatomic, strong) UILabel *resultLabel;
@property (nonatomic, strong) UITextView *resultTextView;

// 计算按钮
@property (nonatomic, strong) UIButton *calculateButton;
@property (nonatomic, strong) UIButton *resultCopyButton;

// 扩展功能
@property (nonatomic, strong) UISegmentedControl *outputFormatControl;
@property (nonatomic, strong) UISwitch *showDetailSwitch;
@property (nonatomic, strong) UILabel *showDetailLabel;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *calculationHistory;

@end

@implementation StaticAddressViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // 初始化历史记录和选择状态
    self.calculationHistory = [[NSMutableArray alloc] init];
    self.selectedModuleIndex = -1; // 初始化为未选择状态

    [self setupUI];
    [self loadModules];
    [self updateProcessInfo];

    // 监听进程选择变化
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(processSelectionChanged:)
                                                 name:@"ProcessManagerSelectedProcessChangedNotification"
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // 确保导航栏显示
    self.navigationController.navigationBar.hidden = NO;
    // 确保标题显示
    self.title = @"静态地址";
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // 再次确保导航栏和标题显示（防止被其他视图控制器影响）
    self.navigationController.navigationBar.hidden = NO;
    self.title = @"静态地址";
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UI Setup

- (void)setupUI {
    self.title = @"静态地址";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    // 直接使用主视图，不需要滚动视图
    self.contentView = self.view;

    [self setupProcessSection];
    [self setupModuleSection];
    [self setupAddressSection];
    [self setupOptionsSection];
    [self setupResultSection];
    [self setupButtons];
    [self setupConstraints];
}

- (void)setupProcessSection {
    // 进程信息标签
    self.processLabel = [[UILabel alloc] init];
    self.processLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.processLabel.text = @"当前进程: 未选择";
    self.processLabel.font = [UIFont systemFontOfSize:16]; // 恢复正常字体
    self.processLabel.textColor = [UIColor labelColor];
    self.processLabel.numberOfLines = 0; // 允许多行显示
    self.processLabel.lineBreakMode = NSLineBreakByWordWrapping; // 按单词换行

    // 移除自动调整字体大小，改为固定字体大小和顶部对齐
    self.processLabel.adjustsFontSizeToFitWidth = NO; // 禁用自动调整字体大小

    // 设置文本垂直对齐方式为顶部对齐，防止文字被裁剪
    self.processLabel.textAlignment = NSTextAlignmentLeft;
    self.processLabel.baselineAdjustment = UIBaselineAdjustmentAlignBaselines;

    [self.contentView addSubview:self.processLabel];

    // 刷新按钮
    self.refreshButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.refreshButton setTitle:@"刷新" forState:UIControlStateNormal];
    self.refreshButton.titleLabel.font = [UIFont systemFontOfSize:16]; // 恢复正常字体
    [self.refreshButton addTarget:self action:@selector(refreshModules) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.refreshButton];
}

- (void)setupModuleSection {
    // 模块选择标签
    self.moduleLabel = [[UILabel alloc] init];
    self.moduleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.moduleLabel.text = @"选择模块:";
    self.moduleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.moduleLabel.textColor = [UIColor labelColor];
    [self.contentView addSubview:self.moduleLabel];

    // 创建模块容器视图
    self.moduleContainerView = [[UIView alloc] init];
    self.moduleContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.moduleContainerView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.moduleContainerView.layer.cornerRadius = 12.0;
    self.moduleContainerView.layer.borderWidth = 1.0;
    self.moduleContainerView.layer.borderColor = [UIColor systemGray4Color].CGColor;
    [self.contentView addSubview:self.moduleContainerView];

    // 创建表格视图 - 现代化卡片样式
    self.moduleTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.moduleTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.moduleTableView.dataSource = self;
    self.moduleTableView.delegate = self;
    self.moduleTableView.backgroundColor = [UIColor clearColor];
    self.moduleTableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.moduleTableView.separatorColor = [UIColor systemGray5Color];
    self.moduleTableView.layer.cornerRadius = 10.0;
    self.moduleTableView.clipsToBounds = YES;
    self.moduleTableView.showsVerticalScrollIndicator = YES;
    self.moduleTableView.rowHeight = 50.0;

    // 注册cell
    [self.moduleTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ModuleCell"];

    [self.moduleContainerView addSubview:self.moduleTableView];
}

- (void)setupAddressSection {
    // 动态地址输入标签
    self.dynamicAddressLabel = [[UILabel alloc] init];
    self.dynamicAddressLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.dynamicAddressLabel.text = @"动态地址:";
    self.dynamicAddressLabel.font = [UIFont boldSystemFontOfSize:16]; // 恢复正常字体
    self.dynamicAddressLabel.textColor = [UIColor labelColor];
    [self.contentView addSubview:self.dynamicAddressLabel];

    // 动态地址输入框
    self.dynamicAddressField = [[UITextField alloc] init];
    self.dynamicAddressField.translatesAutoresizingMaskIntoConstraints = NO;
    self.dynamicAddressField.borderStyle = UITextBorderStyleRoundedRect;
    self.dynamicAddressField.placeholder = @"输入动态地址 (如: 0x1A2B3C4D)"; // 恢复详细占位符
    self.dynamicAddressField.font = [UIFont systemFontOfSize:16]; // 恢复正常字体
    self.dynamicAddressField.keyboardType = UIKeyboardTypeDefault;
    self.dynamicAddressField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.dynamicAddressField.autocorrectionType = UITextAutocorrectionTypeNo;
    [self.contentView addSubview:self.dynamicAddressField];
}

- (void)setupOptionsSection {
    // 显示详细信息开关标签
    self.showDetailLabel = [[UILabel alloc] init];
    self.showDetailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.showDetailLabel.text = @"显示详细信息:";
    self.showDetailLabel.font = [UIFont boldSystemFontOfSize:16]; // 恢复正常字体
    self.showDetailLabel.textColor = [UIColor labelColor];
    [self.contentView addSubview:self.showDetailLabel];

    // 显示详细信息开关 - 正常大小
    self.showDetailSwitch = [[UISwitch alloc] init];
    self.showDetailSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.showDetailSwitch.on = YES; // 默认开启显示详细信息
    [self.contentView addSubview:self.showDetailSwitch];

    // 输出格式选择 - 使用完整标题
    NSArray *formatTitles = @[@"标准格式", @"IDA格式", @"Hopper格式", @"Ghidra格式"];
    self.outputFormatControl = [[UISegmentedControl alloc] initWithItems:formatTitles];
    self.outputFormatControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.outputFormatControl.selectedSegmentIndex = 0; // 默认选择标准格式
    [self.outputFormatControl setTitleTextAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:14]} forState:UIControlStateNormal]; // 适中字体
    [self.contentView addSubview:self.outputFormatControl];
}

- (void)setupResultSection {
    // 结果标签
    self.resultLabel = [[UILabel alloc] init];
    self.resultLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.resultLabel.text = @"计算结果:";
    self.resultLabel.font = [UIFont boldSystemFontOfSize:16]; // 恢复正常字体
    self.resultLabel.textColor = [UIColor labelColor];
    [self.contentView addSubview:self.resultLabel];

    // 结果显示区域 - 恢复正常大小
    self.resultTextView = [[UITextView alloc] init];
    self.resultTextView.translatesAutoresizingMaskIntoConstraints = NO;
    self.resultTextView.layer.borderColor = [UIColor systemGrayColor].CGColor;
    self.resultTextView.layer.borderWidth = 1.0;
    self.resultTextView.layer.cornerRadius = 8.0; // 恢复正常圆角
    self.resultTextView.font = [UIFont fontWithName:@"Menlo" size:14]; // 恢复正常字体
    self.resultTextView.editable = NO;
    self.resultTextView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.resultTextView.text = @"请选择模块并输入动态地址后点击计算";
    self.resultTextView.textContainerInset = UIEdgeInsetsMake(12, 12, 12, 12); // 恢复正常内边距
    [self.contentView addSubview:self.resultTextView];
}

- (void)setupButtons {
    // 计算按钮
    self.calculateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.calculateButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.calculateButton setTitle:@"计算静态地址" forState:UIControlStateNormal]; // 恢复完整文字
    self.calculateButton.backgroundColor = [UIColor systemBlueColor];
    [self.calculateButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.calculateButton.layer.cornerRadius = 8.0; // 恢复正常圆角
    self.calculateButton.titleLabel.font = [UIFont boldSystemFontOfSize:16]; // 恢复正常字体
    [self.calculateButton addTarget:self action:@selector(calculateStaticAddress) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.calculateButton];

    // 复制按钮
    self.resultCopyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.resultCopyButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.resultCopyButton setTitle:@"复制结果" forState:UIControlStateNormal]; // 恢复完整文字
    self.resultCopyButton.backgroundColor = [UIColor systemGreenColor];
    [self.resultCopyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.resultCopyButton.layer.cornerRadius = 8.0; // 恢复正常圆角
    self.resultCopyButton.titleLabel.font = [UIFont boldSystemFontOfSize:16]; // 恢复正常字体
    [self.resultCopyButton addTarget:self action:@selector(copyResult) forControlEvents:UIControlEventTouchUpInside];
    self.resultCopyButton.enabled = NO;
    [self.contentView addSubview:self.resultCopyButton];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[

        // Process Section - 确保进程标签完整显示，文字从顶部开始
        [self.processLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [self.processLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.processLabel.trailingAnchor constraintEqualToAnchor:self.refreshButton.leadingAnchor constant:-10],
        [self.processLabel.heightAnchor constraintEqualToConstant:50], // 固定高度，确保文字完整显示

        // 刷新按钮与进程标签顶部对齐，而不是居中对齐
        [self.refreshButton.topAnchor constraintEqualToAnchor:self.processLabel.topAnchor],
        [self.refreshButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.refreshButton.widthAnchor constraintEqualToConstant:60],
        [self.refreshButton.heightAnchor constraintEqualToConstant:44],

        // Module Section - 紧凑间距
        [self.moduleLabel.topAnchor constraintEqualToAnchor:self.processLabel.bottomAnchor constant:15],
        [self.moduleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.moduleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],

        // 模块容器视图约束
        [self.moduleContainerView.topAnchor constraintEqualToAnchor:self.moduleLabel.bottomAnchor constant:8],
        [self.moduleContainerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.moduleContainerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.moduleContainerView.heightAnchor constraintEqualToConstant:150],

        // 表格视图约束
        [self.moduleTableView.topAnchor constraintEqualToAnchor:self.moduleContainerView.topAnchor constant:8],
        [self.moduleTableView.leadingAnchor constraintEqualToAnchor:self.moduleContainerView.leadingAnchor constant:8],
        [self.moduleTableView.trailingAnchor constraintEqualToAnchor:self.moduleContainerView.trailingAnchor constant:-8],
        [self.moduleTableView.bottomAnchor constraintEqualToAnchor:self.moduleContainerView.bottomAnchor constant:-8],

        // Address Section - 紧凑间距
        [self.dynamicAddressLabel.topAnchor constraintEqualToAnchor:self.moduleContainerView.bottomAnchor constant:15],
        [self.dynamicAddressLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.dynamicAddressLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],

        [self.dynamicAddressField.topAnchor constraintEqualToAnchor:self.dynamicAddressLabel.bottomAnchor constant:10],
        [self.dynamicAddressField.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.dynamicAddressField.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.dynamicAddressField.heightAnchor constraintEqualToConstant:44], // 恢复正常高度

        // Options Section - 适中间距
        [self.showDetailLabel.topAnchor constraintEqualToAnchor:self.dynamicAddressField.bottomAnchor constant:25],
        [self.showDetailLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],

        [self.showDetailSwitch.centerYAnchor constraintEqualToAnchor:self.showDetailLabel.centerYAnchor],
        [self.showDetailSwitch.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],

        [self.outputFormatControl.topAnchor constraintEqualToAnchor:self.showDetailLabel.bottomAnchor constant:15],
        [self.outputFormatControl.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.outputFormatControl.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.outputFormatControl.heightAnchor constraintEqualToConstant:32], // 恢复正常高度

        // Result Section - 适中间距
        [self.resultLabel.topAnchor constraintEqualToAnchor:self.outputFormatControl.bottomAnchor constant:25],
        [self.resultLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.resultLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],

        [self.resultTextView.topAnchor constraintEqualToAnchor:self.resultLabel.bottomAnchor constant:10],
        [self.resultTextView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.resultTextView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.resultTextView.heightAnchor constraintEqualToConstant:150], // 增加高度以更好利用空间

        // Buttons - 垂直排列，更好利用空间
        [self.calculateButton.topAnchor constraintEqualToAnchor:self.resultTextView.bottomAnchor constant:20],
        [self.calculateButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.calculateButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.calculateButton.heightAnchor constraintEqualToConstant:50], // 恢复正常高度

        [self.resultCopyButton.topAnchor constraintEqualToAnchor:self.calculateButton.bottomAnchor constant:15],
        [self.resultCopyButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.resultCopyButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.resultCopyButton.heightAnchor constraintEqualToConstant:50], // 恢复正常高度
        [self.resultCopyButton.bottomAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20]
    ]];
}

#pragma mark - Data Loading

- (void)updateProcessInfo {
    ProcessManager *processManager = [ProcessManager sharedManager];
    if (processManager.selectedProcessPID && processManager.selectedProcessName) {
        self.processLabel.text = [NSString stringWithFormat:@"当前进程: %@ (PID: %@)", 
                                 processManager.selectedProcessName, processManager.selectedProcessPID];
    } else {
        self.processLabel.text = @"当前进程: 未选择";
    }
}

- (void)loadModules {
    ProcessManager *processManager = [ProcessManager sharedManager];
    if (!processManager.selectedProcessPID) {
        self.modules = @[];
        [self.moduleTableView reloadData];
        self.selectedModuleIndex = -1;
        return;
    }
    
    PointerScanManager *pointerManager = [PointerScanManager sharedManager];
    
    // 附加到进程
    NSError *error = nil;
    pid_t pid = [processManager.selectedProcessPID intValue];
    if (![pointerManager attachToProcess:pid error:&error]) {
        NSLog(@"[StaticAddress] 附加进程失败: %@", error.localizedDescription);
        self.modules = @[];
        [self.moduleTableView reloadData];
        self.selectedModuleIndex = -1;
        return;
    }

    // 获取模块列表
    NSArray<ModuleInfo *> *modules = [pointerManager getModuleList:&error forceRefresh:YES];
    if (error) {
        NSLog(@"[StaticAddress] 获取模块列表失败: %@", error.localizedDescription);
        self.modules = @[];
    } else {
        self.modules = modules ?: @[];
    }

    [self.moduleTableView reloadData];
    self.selectedModuleIndex = -1; // 重置选择状态
}

#pragma mark - Actions

- (void)refreshModules {
    [self loadModules];
    
    // 显示刷新提示
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" 
                                                                   message:@"模块列表已刷新" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)calculateStaticAddress {
    // 检查是否选择了进程
    if (!self.modules || self.modules.count == 0) {
        [self showAlert:@"错误" message:@"请先选择进程并刷新模块列表"];
        return;
    }
    
    // 检查是否选择了模块
    if (self.selectedModuleIndex < 0 || self.selectedModuleIndex >= self.modules.count) {
        [self showAlert:@"错误" message:@"请选择一个有效的模块"];
        return;
    }
    
    // 检查是否输入了地址
    NSString *addressText = [self.dynamicAddressField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (addressText.length == 0) {
        [self showAlert:@"错误" message:@"请输入动态内存地址"];
        return;
    }
    
    // 解析动态地址
    uint64_t dynamicAddress = [self parseHexAddress:addressText];
    if (dynamicAddress == 0) {
        [self showAlert:@"错误" message:@"无效的地址格式，请使用十六进制格式 (如: 0x1A2B3C4D)"];
        return;
    }
    
    // 获取选中的模块
    ModuleInfo *selectedModule = self.modules[self.selectedModuleIndex];
    uint64_t moduleBaseAddress = selectedModule.startAddress;
    
    // 计算静态地址
    if (dynamicAddress < moduleBaseAddress) {
        [self showAlert:@"错误" message:@"动态地址小于模块基址，可能不属于该模块"];
        return;
    }
    
    uint64_t staticAddress = dynamicAddress - moduleBaseAddress;
    uint64_t moduleEndAddress = selectedModule.endAddress;
    uint64_t moduleSize = moduleEndAddress - moduleBaseAddress;
    uint64_t offsetFromStart = staticAddress;
    uint64_t offsetFromEnd = moduleSize - staticAddress;

    // 保存到历史记录
    NSDictionary *historyItem = @{
        @"timestamp": [NSDate date],
        @"moduleName": selectedModule.name,
        @"dynamicAddress": @(dynamicAddress),
        @"staticAddress": @(staticAddress),
        @"moduleBase": @(moduleBaseAddress)
    };
    [self.calculationHistory insertObject:historyItem atIndex:0];
    if (self.calculationHistory.count > 10) {
        [self.calculationHistory removeLastObject]; // 只保留最近10条记录
    }

    // 生成结果
    NSMutableString *result = [self generateResultString:selectedModule
                                          dynamicAddress:dynamicAddress
                                           staticAddress:staticAddress
                                         moduleBaseAddress:moduleBaseAddress
                                         moduleEndAddress:moduleEndAddress
                                          offsetFromStart:offsetFromStart
                                            offsetFromEnd:offsetFromEnd
                                              moduleSize:moduleSize];
    
    self.resultTextView.text = result;
    self.resultCopyButton.enabled = YES;
    
    NSLog(@"[StaticAddress] 计算完成 - 模块:%@ 动态:0x%llX 静态:0x%llX", 
          selectedModule.name, dynamicAddress, staticAddress);
}

- (void)copyResult {
    if (self.resultTextView.text.length > 0) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = self.resultTextView.text;
        
        [self showAlert:@"成功" message:@"计算结果已复制到剪贴板"];
    }
}

#pragma mark - Notifications

- (void)processSelectionChanged:(NSNotification *)notification {
    [self updateProcessInfo];
    [self loadModules];
    
    // 清空结果
    self.resultTextView.text = @"请选择模块并输入动态地址后点击计算";
    self.resultCopyButton.enabled = NO;
    self.selectedModuleIndex = -1; // 重置选择状态
    [self.moduleTableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.modules.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ModuleCell" forIndexPath:indexPath];

    if (indexPath.row < self.modules.count) {
        ModuleInfo *module = self.modules[indexPath.row];

        // 设置主标题
        cell.textLabel.text = module.name;
        cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        cell.textLabel.textColor = [UIColor labelColor];

        // 设置副标题（基址）
        cell.detailTextLabel.text = [NSString stringWithFormat:@"基址: 0x%lX", (unsigned long)module.startAddress];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];

        // 设置选中状态
        if (indexPath.row == self.selectedModuleIndex) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            // 使用兼容的颜色设置方式
            if (@available(iOS 13.0, *)) {
                cell.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.1];
            } else {
                cell.backgroundColor = [[UIColor blueColor] colorWithAlphaComponent:0.1];
            }
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.backgroundColor = [UIColor clearColor];
        }

        // 设置cell样式
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    // 更新选择状态
    self.selectedModuleIndex = indexPath.row;
    [tableView reloadData];

    // 显示选择反馈
    if (indexPath.row < self.modules.count) {
        ModuleInfo *module = self.modules[indexPath.row];
        NSLog(@"[StaticAddress] 选择模块: %@ (0x%lX)", module.name, (unsigned long)module.startAddress);
    }
}

#pragma mark - Helper Methods

- (uint64_t)parseHexAddress:(NSString *)addressString {
    // 移除空格和换行符
    addressString = [addressString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // 支持多种格式
    if ([addressString hasPrefix:@"0x"] || [addressString hasPrefix:@"0X"]) {
        addressString = [addressString substringFromIndex:2];
    }
    
    // 转换为大写
    addressString = [addressString uppercaseString];
    
    // 验证是否为有效的十六进制字符串
    NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"];
    NSCharacterSet *inputSet = [NSCharacterSet characterSetWithCharactersInString:addressString];
    if (![hexSet isSupersetOfSet:inputSet]) {
        return 0;
    }
    
    // 转换为数值
    NSScanner *scanner = [NSScanner scannerWithString:addressString];
    uint64_t result = 0;
    if ([scanner scanHexLongLong:&result]) {
        return result;
    }
    
    return 0;
}

- (NSMutableString *)generateResultString:(ModuleInfo *)module
                           dynamicAddress:(uint64_t)dynamicAddress
                            staticAddress:(uint64_t)staticAddress
                          moduleBaseAddress:(uint64_t)moduleBaseAddress
                          moduleEndAddress:(uint64_t)moduleEndAddress
                           offsetFromStart:(uint64_t)offsetFromStart
                             offsetFromEnd:(uint64_t)offsetFromEnd
                               moduleSize:(uint64_t)moduleSize {

    NSMutableString *result = [NSMutableString string];
    NSInteger selectedFormat = self.outputFormatControl.selectedSegmentIndex;
    BOOL showDetail = self.showDetailSwitch.isOn;

    if (showDetail) {
        // 详细信息 - 紧凑格式
        [result appendFormat:@"📍 %@ (0x%lX)\n", module.name, (unsigned long)moduleBaseAddress];
        [result appendFormat:@"动态: 0x%lX → 静态: 0x%lX\n", (unsigned long)dynamicAddress, (unsigned long)staticAddress];

        double positionPercent = ((double)offsetFromStart / (double)moduleSize) * 100.0;
        [result appendFormat:@"位置: %.1f%% 大小: %luB\n\n", positionPercent, (unsigned long)moduleSize];
    } else {
        // 简洁信息
        [result appendFormat:@"📍 %@\n", module.name];
        [result appendFormat:@"静态地址: 0x%lX\n\n", (unsigned long)staticAddress];
    }

    // 根据选择的格式输出 - 紧凑格式
    switch (selectedFormat) {
        case 0: // 标准格式
            [result appendFormat:@"🎯 0x%lX (%lu)\n", (unsigned long)staticAddress, (unsigned long)staticAddress];
            break;

        case 1: // IDA格式
            [result appendFormat:@"🎯 IDA: Alt+G → 0x%lX\n", (unsigned long)staticAddress];
            if (showDetail) {
                [result appendFormat:@"Python: idc.jump_to_address(0x%lX)\n", (unsigned long)staticAddress];
            }
            break;

        case 2: // Hopper格式
            [result appendFormat:@"🎯 Hopper: Cmd+G → 0x%lX\n", (unsigned long)staticAddress];
            break;

        case 3: // Ghidra格式
            [result appendFormat:@"🎯 Ghidra: G → 0x%08lx\n", (unsigned long)staticAddress];
            if (showDetail) {
                [result appendFormat:@"Python: goTo(toAddr(0x%lx))\n", (unsigned long)staticAddress];
            }
            break;
    }

    if (showDetail) {
        // 添加计算公式说明 - 紧凑格式
        [result appendFormat:@"\n📝 0x%lX = 0x%lX - 0x%lX\n",
         (unsigned long)staticAddress, (unsigned long)dynamicAddress, (unsigned long)moduleBaseAddress];

        // 添加历史记录 - 只显示最近2条
        if (self.calculationHistory.count > 1) {
            [result appendFormat:@"📚 历史: "];
            for (int i = 1; i < MIN(3, self.calculationHistory.count); i++) {
                NSDictionary *item = self.calculationHistory[i];
                NSString *moduleName = item[@"moduleName"];
                uint64_t historyStatic = [item[@"staticAddress"] unsignedLongLongValue];
                [result appendFormat:@"%@:0x%lX ", moduleName, (unsigned long)historyStatic];
            }
            [result appendFormat:@"\n"];
        }

        // 简化提示信息
        [result appendFormat:@"💡 ASLR影响基址，静态地址固定"];
    }

    return result;
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
