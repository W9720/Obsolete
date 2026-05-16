//
//  PointerScanViewController.mm
//  指针扫描视图控制器 - 重写版本
//

#import "PointerScanViewController.h"
#import "PointerScanManager.h"
#import "ProcessManager.h"
#import "VMTool.h"
#import "PointerFileEditorViewController.h"
#import <objc/runtime.h>

// 添加 extern "C" 包装来正确链接 Rust 生成的 C 函数
extern "C" {
#import "libptrs.h"
}

// 简化的指针链结果
@interface PointerChainResult : NSObject
@property (nonatomic, strong) NSString *originalChain;    // 原始指针链字符串
@property (nonatomic, strong) NSString *displayText;      // 显示文本
@property (nonatomic, strong) NSString *moduleName;       // 模块名
@property (nonatomic, assign) uintptr_t baseAddress;      // 基址
@property (nonatomic, strong) NSArray<NSNumber *> *offsets; // 偏移数组
@property (nonatomic, assign) BOOL isValid;               // 是否有效
@end

@implementation PointerChainResult

- (NSString *)description {
    return [NSString stringWithFormat:@"PointerChain: %@ -> %@", self.moduleName, self.displayText];
}

@end

@interface PointerScanViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate, UIDocumentPickerDelegate, PointerFileEditorDelegate>

// 数据
@property (nonatomic, strong) NSArray<ModuleInfo *> *modules;
@property (nonatomic, strong) NSArray<ModuleInfo *> *selectedModules;
@property (nonatomic, strong) NSArray<PointerChainResult *> *scanResults;
@property (nonatomic, assign) BOOL isScanning;

// 预设目标地址
@property (nonatomic, strong) NSString *presetTargetAddress;

// 进程状态跟踪
@property (nonatomic, assign) pid_t lastProcessPID;

// UI 组件
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;

// 抽屉式设置面板
@property (nonatomic, strong) UIView *drawerView;
@property (nonatomic, strong) UIButton *drawerToggleButton;
@property (nonatomic, strong) UIView *drawerContentView;
@property (nonatomic, assign) BOOL isDrawerExpanded;
@property (nonatomic, strong) NSLayoutConstraint *drawerHeightConstraint;

@property (nonatomic, strong) UITextField *addressField;
@property (nonatomic, strong) UITextField *depthField;
@property (nonatomic, strong) UITextField *rangeField;
@property (nonatomic, strong) UITextField *maxResultsField;
@property (nonatomic, strong) UIButton *moduleSelectButton;
@property (nonatomic, strong) UIButton *scanButton;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UITableView *resultsTableView;

// 设置选项
@property (nonatomic, assign) BOOL filterNegativeOffsets;  // 是否过滤偏移
@property (nonatomic, assign) BOOL enableFileMapping;      // 是否启用文件指针映射
@property (nonatomic, assign) BOOL isImportingPointers;    // 是否正在导入指针
@property (nonatomic, assign) BOOL isShowingSettingsMenu; // 是否正在显示设置菜单

// 过滤选项
@property (nonatomic, assign) BOOL enableValueFilter;     // 是否启用数值过滤
@property (nonatomic, assign) BOOL enableAddressFilter;   // 是否启用地址过滤
@property (nonatomic, strong) NSString *filterValue;      // 过滤数值
@property (nonatomic, assign) VMMemValueType filterValueType; // 过滤数值类型
@property (nonatomic, strong) NSString *filterAddress;    // 过滤地址
@property (nonatomic, strong) NSArray<PointerChainResult *> *filteredResults; // 过滤后的结果

// 文件管理
@property (nonatomic, strong) NSString *scanDataDirectory; // 扫描数据目录

// 方法声明
- (void)updateModuleButtonTitle;
- (void)addToolbarToTextField:(UITextField *)textField;
- (void)dismissKeyboard;
- (void)updateStatusDisplay;
- (BOOL)ensureScannerInitialized;
- (void)checkAndRefreshProcessState;

@end

// 创建模块选择表格视图控制器
@interface ModuleSelectionTableViewController : UITableViewController
@property (nonatomic, strong) NSArray<ModuleInfo *> *modules;
@property (nonatomic, weak) PointerScanViewController *parentController;
@property (nonatomic, weak) UIAlertController *alertController;
@end

@implementation ModuleSelectionTableViewController

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.modules.count + 1; // +1 for "全部模块"
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"ModuleCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.textLabel.font = [UIFont systemFontOfSize:14];
    }

    if (indexPath.row == 0) {
        cell.textLabel.text = @"全部模块";
    } else {
        ModuleInfo *module = self.modules[indexPath.row - 1];
        cell.textLabel.text = module.name;
    }

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 35.0; // 紧凑的行高
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.row == 0) {
        // 选择全部模块
        self.parentController.selectedModules = self.modules;
    } else {
        // 选择单个模块
        ModuleInfo *selectedModule = self.modules[indexPath.row - 1];
        self.parentController.selectedModules = @[selectedModule];
    }

    [self.parentController updateModuleButtonTitle];
    [self.alertController dismissViewControllerAnimated:YES completion:nil];
}

@end

@implementation PointerScanViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        // 初始化
    }
    return self;
}

- (instancetype)initWithTargetAddress:(NSString *)targetAddress {
    self = [super init];
    if (self) {
        // 保存预设的目标地址
        self.presetTargetAddress = targetAddress;
    }
    return self;
}



- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"指针扫描";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    // 添加右上角设置按钮
    [self setupNavigationBarButtons];

    // 修复右滑返回问题
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    self.navigationController.interactivePopGestureRecognizer.delegate = nil;

    // 初始化设置选项 - 从 UserDefaults 读取保存的设置
    self.filterNegativeOffsets = [[NSUserDefaults standardUserDefaults] boolForKey:@"PointerScan_FilterNegativeOffsets"];
    self.enableFileMapping = [[NSUserDefaults standardUserDefaults] boolForKey:@"PointerScan_EnableFileMapping"];

    // 初始化过滤选项
    self.enableValueFilter = NO;
    self.enableAddressFilter = NO;
    self.filterValueType = VMMemValueTypeSignedInt; // 默认为32位整数

    // 初始化状态
    self.isImportingPointers = NO;

    // 初始化扫描数据目录
    [self setupScanDataDirectory];

    [self setupUI];
    [self initializeScanner];

    // 如果有预设的目标地址，设置到输入框
    if (self.presetTargetAddress && self.addressField) {
        self.addressField.text = self.presetTargetAddress;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = NO;

    // 检查进程是否发生变化，如果变化则重新初始化
    [self checkAndRefreshProcessState];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.navigationController.navigationBar.hidden = NO;
}

- (void)setupUI {
    @try {
        // 创建主容器视图
        self.scrollView = [[UIScrollView alloc] init];
        self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
        self.scrollView.scrollEnabled = NO; // 禁用滚动
        [self.view addSubview:self.scrollView];

        self.contentView = [[UIView alloc] init];
        self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.scrollView addSubview:self.contentView];

        // 创建抽屉式设置面板
        [self createDrawerView];

        // 创建进度视图
        [self createProgressView];

        // 创建结果表格
        [self createResultsTable];

        // 设置约束
        [self setupConstraints];

    } @catch (NSException *exception) {
        // 静默处理异常
    }
}

- (void)createDrawerView {
    // 创建抽屉容器
    self.drawerView = [[UIView alloc] init];
    self.drawerView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.drawerView.layer.cornerRadius = 12;
    self.drawerView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.drawerView.layer.shadowOffset = CGSizeMake(0, 2);
    self.drawerView.layer.shadowOpacity = 0.1;
    self.drawerView.layer.shadowRadius = 4;
    self.drawerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.drawerView];

    // 创建抽屉切换按钮
    self.drawerToggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.drawerToggleButton setTitle:@"⚙️ 扫描设置" forState:UIControlStateNormal];
    self.drawerToggleButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.drawerToggleButton setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    self.drawerToggleButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.drawerToggleButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    self.drawerToggleButton.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    self.drawerToggleButton.backgroundColor = [UIColor clearColor];
    [self.drawerToggleButton addTarget:self action:@selector(toggleDrawer) forControlEvents:UIControlEventTouchUpInside];
    self.drawerToggleButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.drawerView addSubview:self.drawerToggleButton];

    // 创建抽屉内容视图
    self.drawerContentView = [[UIView alloc] init];
    self.drawerContentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.drawerContentView.clipsToBounds = YES;
    [self.drawerView addSubview:self.drawerContentView];

    // 创建输入字段和按钮
    [self createInputFields];
    [self createButtons];

    // 初始状态为收起
    self.isDrawerExpanded = NO;
}

- (void)createInputFields {
    // 目标地址输入框
    self.addressField = [[UITextField alloc] init];
    self.addressField.placeholder = @"目标地址 (0x...)";
    self.addressField.borderStyle = UITextBorderStyleRoundedRect;
    self.addressField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.addressField.textAlignment = NSTextAlignmentCenter;
    self.addressField.delegate = self;
    self.addressField.returnKeyType = UIReturnKeyDone;
    self.addressField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.drawerContentView addSubview:self.addressField];

    // 扫描层数输入框
    self.depthField = [[UITextField alloc] init];
    self.depthField.placeholder = @"扫描层数 (默认3)";
    self.depthField.text = @"3";
    self.depthField.borderStyle = UITextBorderStyleRoundedRect;
    self.depthField.keyboardType = UIKeyboardTypeNumberPad;
    self.depthField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.depthField.textAlignment = NSTextAlignmentCenter;
    self.depthField.delegate = self;
    self.depthField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.drawerContentView addSubview:self.depthField];
    [self addToolbarToTextField:self.depthField];

    // 扫描范围输入框
    self.rangeField = [[UITextField alloc] init];
    self.rangeField.placeholder = @"扫描范围";
    self.rangeField.text = @"1000";  // 优化后的默认扫描范围
    self.rangeField.borderStyle = UITextBorderStyleRoundedRect;
    self.rangeField.keyboardType = UIKeyboardTypeNumberPad;
    self.rangeField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.rangeField.textAlignment = NSTextAlignmentCenter;
    self.rangeField.delegate = self;
    self.rangeField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.drawerContentView addSubview:self.rangeField];
    [self addToolbarToTextField:self.rangeField];

    // 最大结果数输入框
    self.maxResultsField = [[UITextField alloc] init];
    self.maxResultsField.placeholder = @"最大结果数 (默认1000)";
    self.maxResultsField.text = @"1000";
    self.maxResultsField.borderStyle = UITextBorderStyleRoundedRect;
    self.maxResultsField.keyboardType = UIKeyboardTypeNumberPad;
    self.maxResultsField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.maxResultsField.textAlignment = NSTextAlignmentCenter;
    self.maxResultsField.delegate = self;
    self.maxResultsField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.drawerContentView addSubview:self.maxResultsField];
    [self addToolbarToTextField:self.maxResultsField];
}

- (void)createButtons {
    // 模块选择按钮
    self.moduleSelectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.moduleSelectButton setTitle:@"选择模块" forState:UIControlStateNormal];
    self.moduleSelectButton.backgroundColor = [UIColor systemGrayColor];
    [self.moduleSelectButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.moduleSelectButton.layer.cornerRadius = 8;
    [self.moduleSelectButton addTarget:self action:@selector(selectModules) forControlEvents:UIControlEventTouchUpInside];
    self.moduleSelectButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.drawerContentView addSubview:self.moduleSelectButton];

    // 扫描按钮
    self.scanButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.scanButton setTitle:@"🔍 开始扫描" forState:UIControlStateNormal];
    self.scanButton.backgroundColor = [UIColor systemBlueColor];
    [self.scanButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.scanButton.layer.cornerRadius = 8;
    self.scanButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.scanButton addTarget:self action:@selector(scanButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    self.scanButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.drawerContentView addSubview:self.scanButton];
}

- (void)toggleDrawer {
    self.isDrawerExpanded = !self.isDrawerExpanded;

    // 更新按钮标题
    NSString *title = self.isDrawerExpanded ? @"⚙️ 收起设置" : @"⚙️ 扫描设置";
    [self.drawerToggleButton setTitle:title forState:UIControlStateNormal];

    // 动画更新高度约束 - 恢复原来的高度，确保下方内容可见
    CGFloat targetHeight = self.isDrawerExpanded ? 220 : 50; // 展开时220pt，收起时50pt
    self.drawerHeightConstraint.constant = targetHeight;

    [UIView animateWithDuration:0.3
                          delay:0
         usingSpringWithDamping:0.8
          initialSpringVelocity:0.5
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        [self.view layoutIfNeeded];

        // 同时调整内容视图的透明度
        self.drawerContentView.alpha = self.isDrawerExpanded ? 1.0 : 0.0;

        // 确保进度条和状态标签始终可见
        self.progressView.hidden = NO;
        self.statusLabel.hidden = NO;

    } completion:^(BOOL finished) {
        // 动画完成后强制刷新表格布局
        [self.resultsTableView setNeedsLayout];
        [self.resultsTableView layoutIfNeeded];

        // 如果有数据，重新加载表格确保显示正确
        if (self.scanResults.count > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.resultsTableView reloadData];
            });
        }

        // 确保状态信息在抽屉切换后仍然可见
        [self updateStatusDisplay];

    }];
}

- (void)createProgressView {
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.hidden = YES;
    self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.progressView];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"准备就绪";
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.textColor = [UIColor secondaryLabelColor];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.statusLabel];
}

- (void)createResultsTable {
    self.resultsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.resultsTableView.dataSource = self;
    self.resultsTableView.delegate = self;
    self.resultsTableView.translatesAutoresizingMaskIntoConstraints = NO;

    // 设置表格样式 - 优化后的样式
    self.resultsTableView.backgroundColor = [UIColor systemBackgroundColor];
    self.resultsTableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine; // 恢复分隔线
    self.resultsTableView.separatorColor = [UIColor separatorColor];
    self.resultsTableView.rowHeight = UITableViewAutomaticDimension;

    // 设置内容插入边距，防止遮挡顶部的扫描数量显示，减少底部空白
    self.resultsTableView.contentInset = UIEdgeInsetsMake(10, 0, 20, 0);
    self.resultsTableView.scrollIndicatorInsets = self.resultsTableView.contentInset;

    // 添加长按手势识别器
    UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressOnResultsTable:)];
    longPressGesture.minimumPressDuration = 0.5; // 长按0.5秒触发
    [self.resultsTableView addGestureRecognizer:longPressGesture];





    [self.contentView addSubview:self.resultsTableView];

}

- (void)setupConstraints {
    @try {

        // 滚动视图约束
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor].active = YES;
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = YES;

        // 内容视图约束
        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor].active = YES;
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor].active = YES;
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor].active = YES;
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor].active = YES;
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor].active = YES;

        // 设置内容视图高度等于屏幕高度，不超出屏幕
        CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
        [self.contentView.heightAnchor constraintEqualToConstant:screenHeight].active = YES;

        [self setupDrawerConstraints];
        [self setupProgressConstraints];
        [self setupResultsTableConstraints];


    } @catch (NSException *exception) {
    }
}

- (void)setupDrawerConstraints {
    CGFloat margin = 15;  // 减小边距
    CGFloat spacing = 6;   // 进一步减小间距
    CGFloat fieldHeight = 36; // 减小字段高度

    // 抽屉视图约束 - 减小顶部间距
    [self.drawerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10].active = YES;
    [self.drawerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:margin].active = YES;
    [self.drawerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-margin].active = YES;

    // 抽屉高度约束（可变）
    self.drawerHeightConstraint = [self.drawerView.heightAnchor constraintEqualToConstant:50];
    self.drawerHeightConstraint.active = YES;

    // 抽屉切换按钮约束 - 更好的居中和间距
    [self.drawerToggleButton.topAnchor constraintEqualToAnchor:self.drawerView.topAnchor constant:8].active = YES;
    [self.drawerToggleButton.leadingAnchor constraintEqualToAnchor:self.drawerView.leadingAnchor constant:15].active = YES;
    [self.drawerToggleButton.trailingAnchor constraintEqualToAnchor:self.drawerView.trailingAnchor constant:-15].active = YES;
    [self.drawerToggleButton.heightAnchor constraintEqualToConstant:34].active = YES;

    // 抽屉内容视图约束
    [self.drawerContentView.topAnchor constraintEqualToAnchor:self.drawerToggleButton.bottomAnchor constant:10].active = YES;
    [self.drawerContentView.leadingAnchor constraintEqualToAnchor:self.drawerView.leadingAnchor constant:8].active = YES;
    [self.drawerContentView.trailingAnchor constraintEqualToAnchor:self.drawerView.trailingAnchor constant:-8].active = YES;
    [self.drawerContentView.bottomAnchor constraintEqualToAnchor:self.drawerView.bottomAnchor constant:-5].active = YES;

    // 初始状态设置内容视图透明度为0
    self.drawerContentView.alpha = 0.0;

    // 输入字段约束
    [self.addressField.topAnchor constraintEqualToAnchor:self.drawerContentView.topAnchor].active = YES;
    [self.addressField.leadingAnchor constraintEqualToAnchor:self.drawerContentView.leadingAnchor].active = YES;
    [self.addressField.trailingAnchor constraintEqualToAnchor:self.drawerContentView.trailingAnchor].active = YES;
    [self.addressField.heightAnchor constraintEqualToConstant:fieldHeight].active = YES;

    [self.depthField.topAnchor constraintEqualToAnchor:self.addressField.bottomAnchor constant:spacing].active = YES;
    [self.depthField.leadingAnchor constraintEqualToAnchor:self.drawerContentView.leadingAnchor].active = YES;
    [self.depthField.heightAnchor constraintEqualToConstant:fieldHeight].active = YES;
    [self.depthField.widthAnchor constraintEqualToConstant:150].active = YES;

    [self.rangeField.topAnchor constraintEqualToAnchor:self.depthField.topAnchor].active = YES;
    [self.rangeField.trailingAnchor constraintEqualToAnchor:self.drawerContentView.trailingAnchor].active = YES;
    [self.rangeField.heightAnchor constraintEqualToConstant:fieldHeight].active = YES;
    [self.rangeField.widthAnchor constraintEqualToConstant:150].active = YES;

    [self.maxResultsField.topAnchor constraintEqualToAnchor:self.depthField.bottomAnchor constant:spacing].active = YES;
    [self.maxResultsField.leadingAnchor constraintEqualToAnchor:self.drawerContentView.leadingAnchor].active = YES;
    [self.maxResultsField.trailingAnchor constraintEqualToAnchor:self.drawerContentView.trailingAnchor].active = YES;
    [self.maxResultsField.heightAnchor constraintEqualToConstant:fieldHeight].active = YES;

    // 按钮约束 - 使用灵活宽度，确保按钮完整显示
    [self.moduleSelectButton.topAnchor constraintEqualToAnchor:self.maxResultsField.bottomAnchor constant:spacing].active = YES;
    [self.moduleSelectButton.leadingAnchor constraintEqualToAnchor:self.drawerContentView.leadingAnchor].active = YES;
    [self.moduleSelectButton.heightAnchor constraintEqualToConstant:fieldHeight].active = YES;

    [self.scanButton.topAnchor constraintEqualToAnchor:self.moduleSelectButton.topAnchor].active = YES;
    [self.scanButton.trailingAnchor constraintEqualToAnchor:self.drawerContentView.trailingAnchor].active = YES;
    [self.scanButton.heightAnchor constraintEqualToConstant:fieldHeight].active = YES;

    // 设置按钮之间的间距，让它们平分可用宽度
    [self.scanButton.leadingAnchor constraintEqualToAnchor:self.moduleSelectButton.trailingAnchor constant:8].active = YES;
    [self.moduleSelectButton.widthAnchor constraintEqualToAnchor:self.scanButton.widthAnchor].active = YES;

    // 设置按钮最小宽度，确保文字能完整显示
    [self.moduleSelectButton.widthAnchor constraintGreaterThanOrEqualToConstant:80].active = YES;
    [self.scanButton.widthAnchor constraintGreaterThanOrEqualToConstant:100].active = YES;
}

- (void)setupProgressConstraints {
    CGFloat margin = 15;  // 减小边距

    // 进度视图约束 - 恢复原来的相对于抽屉底部的约束
    [self.progressView.topAnchor constraintEqualToAnchor:self.drawerView.bottomAnchor constant:8].active = YES;
    [self.progressView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:margin].active = YES;
    [self.progressView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-margin].active = YES;

    [self.statusLabel.topAnchor constraintEqualToAnchor:self.progressView.bottomAnchor constant:6].active = YES;
    [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:margin].active = YES;
    [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-margin].active = YES;
}

- (void)setupResultsTableConstraints {
    CGFloat margin = 15;  // 减小边距

    // 结果表格约束 - 让表格占用更多空间
    [self.resultsTableView.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:8].active = YES;
    [self.resultsTableView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:margin].active = YES;
    [self.resultsTableView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-margin].active = YES;

    // 计算表格合适的高度，让它占用更多空间
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    CGFloat usedHeight = 200; // 导航栏、状态栏、抽屉（收起时）、进度条、状态标签、底部安全区域等占用的空间
    CGFloat availableHeight = screenHeight - usedHeight;
    CGFloat tableHeight = availableHeight * 0.85; // 占可用空间的85%，让表格更大

    // 设置表格固定高度约束
    NSLayoutConstraint *heightConstraint = [self.resultsTableView.heightAnchor constraintEqualToConstant:tableHeight];
    heightConstraint.active = YES;
    heightConstraint.priority = UILayoutPriorityRequired;

    // 设置表格底部约束，使用中等优先级
    NSLayoutConstraint *bottomConstraint = [self.resultsTableView.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-margin];
    bottomConstraint.priority = UILayoutPriorityDefaultHigh;
    bottomConstraint.active = YES;

}

#pragma mark - 初始化和扫描

- (void)initializeScanner {
    @try {
        // 检查是否已选择进程
        ProcessManager *processManager = [ProcessManager sharedManager];
        if (!processManager || !processManager.selectedProcessPID) {
            self.statusLabel.text = @"请先选择进程";
            self.scanButton.enabled = NO;
            return;
        }

        // 初始化扫描器
        NSError *error = nil;
        PointerScanManager *scanner = [PointerScanManager sharedManager];

        if (![scanner initializeWithError:&error]) {
            self.statusLabel.text = [NSString stringWithFormat:@"初始化失败: %@", error.localizedDescription];
            self.scanButton.enabled = NO;
            return;
        }

        // 附加到进程
        pid_t pid = [processManager selectedPid];
        if (![scanner attachToProcess:pid error:&error]) {
            self.statusLabel.text = [NSString stringWithFormat:@"附加进程失败: %@", error.localizedDescription];
            self.scanButton.enabled = NO;
            return;
        }

        // 获取模块列表
        self.modules = [scanner getModuleList:&error];
        if (!self.modules) {
            self.statusLabel.text = [NSString stringWithFormat:@"获取模块失败: %@", error.localizedDescription];
            self.scanButton.enabled = NO;
            return;
        }

        self.statusLabel.text = [NSString stringWithFormat:@"已连接到进程，找到 %lu 个模块", (unsigned long)self.modules.count];
        self.scanButton.enabled = YES;

        // 默认选择全部模块
        self.selectedModules = self.modules;
        [self updateModuleButtonTitle];

        // 记录当前进程PID
        self.lastProcessPID = pid;

    } @catch (NSException *exception) {
        self.statusLabel.text = [NSString stringWithFormat:@"初始化失败: %@", exception.reason];
        self.scanButton.enabled = NO;
    }
}

- (void)updateModuleButtonTitle {
    if (self.selectedModules.count == 0) {
        [self.moduleSelectButton setTitle:@"选择模块" forState:UIControlStateNormal];
    } else if (self.selectedModules.count == self.modules.count) {
        [self.moduleSelectButton setTitle:@"全部模块" forState:UIControlStateNormal];
    } else if (self.selectedModules.count == 1) {
        ModuleInfo *module = self.selectedModules.firstObject;
        [self.moduleSelectButton setTitle:module.name forState:UIControlStateNormal];
    } else {
        NSString *title = [NSString stringWithFormat:@"已选择 %lu 个模块", (unsigned long)self.selectedModules.count];
        [self.moduleSelectButton setTitle:title forState:UIControlStateNormal];
    }
}

#pragma mark - 导航栏设置

// 设置导航栏按钮
- (void)setupNavigationBarButtons {
    // 创建设置按钮
    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"]
                                                                        style:UIBarButtonItemStylePlain
                                                                       target:self
                                                                       action:@selector(showSettingsMenu)];

    self.navigationItem.rightBarButtonItem = settingsButton;
}

// 显示设置菜单
- (void)showSettingsMenu {
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
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissSettingsMenu)];
    [backgroundView addGestureRecognizer:tapGesture];

    [self.view addSubview:backgroundView];
    [self.view addSubview:menuView];

    // 创建菜单按钮
    NSMutableArray *buttons = [NSMutableArray array];

    // 导入指针按钮
    UIButton *importBtn = [self createMenuButton:@"📥 导入指针" action:@selector(importPointerChains)];
    [buttons addObject:importBtn];

    // 过滤指针按钮
    UIButton *filterBtn = [self createMenuButton:@"📁 过滤指针" action:@selector(filterPointerChains)];
    [buttons addObject:filterBtn];

    // 过滤偏移按钮
    NSString *offsetTitle = self.filterNegativeOffsets ? @"✓ 过滤偏移" : @"⚪ 过滤偏移";
    UIButton *offsetBtn = [self createMenuButton:offsetTitle action:@selector(toggleNegativeOffsetFilter)];
    [buttons addObject:offsetBtn];
    
    // 文件指针映射按钮
    NSString *fileMappingTitle = self.enableFileMapping ? @"✓ 文件映射" : @"⚪ 文件映射";
    UIButton *fileMappingBtn = [self createMenuButton:fileMappingTitle action:@selector(toggleFileMapping)];
    [buttons addObject:fileMappingBtn];

    // 数值过滤按钮
    UIButton *valueFilterBtn = [self createMenuButton:@"🔢 数值过滤" action:@selector(toggleValueFilter)];
    [buttons addObject:valueFilterBtn];

    // 地址过滤按钮
    UIButton *addressFilterBtn = [self createMenuButton:@"📍 地址过滤" action:@selector(toggleAddressFilter)];
    [buttons addObject:addressFilterBtn];

    // 清除过滤按钮（仅在有过滤时显示）
    if (self.enableValueFilter || self.enableAddressFilter) {
        UIButton *clearFilterBtn = [self createMenuButton:@"🔄 清除过滤" action:@selector(clearFilters)];
        [buttons addObject:clearFilterBtn];
        
        // 添加保存过滤结果按钮
        if (self.filteredResults && self.filteredResults.count > 0) {
            UIButton *saveFilteredBtn = [self createMenuButton:@"💾 保存过滤" action:@selector(saveFilteredResults)];
            [buttons addObject:saveFilteredBtn];
        }
    }

    // 指针盒子按钮（管理已保存的指针文件）
    UIButton *pointerBoxBtn = [self createMenuButton:@"📦 指针盒子" action:@selector(showPointerBox)];
    [buttons addObject:pointerBoxBtn];

    // 清除指针按钮
    UIButton *clearBtn = [self createMenuButton:@"🗑️ 清除指针" action:@selector(clearPointerChains)];
    clearBtn.backgroundColor = [UIColor systemRedColor];
    [buttons addObject:clearBtn];

    // 添加按钮到菜单
    for (int i = 0; i < buttons.count; i++) {
        [menuView addSubview:buttons[i]];
    }

    // 设置约束
    [self setupMenuConstraints:backgroundView menuView:menuView buttons:buttons];

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
    objc_setAssociatedObject(self, "settingsMenuView", menuView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "settingsBackgroundView", backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// 创建菜单按钮
- (UIButton *)createMenuButton:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.backgroundColor = [UIColor systemBlueColor];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.8;
    button.layer.cornerRadius = 10;
    button.translatesAutoresizingMaskIntoConstraints = NO;

    // 添加点击事件
    [button addTarget:self action:@selector(menuButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    // 保存原始action
    objc_setAssociatedObject(button, "originalAction", NSStringFromSelector(action), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    return button;
}

// 菜单按钮点击处理
- (void)menuButtonTapped:(UIButton *)sender {
    // 先关闭菜单
    [self dismissSettingsMenu];

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

// 设置菜单约束
- (void)setupMenuConstraints:(UIView *)backgroundView menuView:(UIView *)menuView buttons:(NSArray<UIButton *> *)buttons {
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
    NSInteger totalRows = (buttons.count + buttonsPerRow - 1) / buttonsPerRow;

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
            if (buttonsPerRow == 2) {
                [button.trailingAnchor constraintEqualToAnchor:menuView.centerXAnchor constant:-horizontalSpacing/2].active = YES;
            }
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

// 关闭设置菜单
- (void)dismissSettingsMenu {
    UIView *menuView = objc_getAssociatedObject(self, "settingsMenuView");
    UIView *backgroundView = objc_getAssociatedObject(self, "settingsBackgroundView");

    if (menuView && backgroundView) {
        [UIView animateWithDuration:0.2 animations:^{
            menuView.alpha = 0;
            menuView.transform = CGAffineTransformMakeScale(0.8, 0.8);
            backgroundView.alpha = 0;
        } completion:^(BOOL finished) {
            [menuView removeFromSuperview];
            [backgroundView removeFromSuperview];
            objc_setAssociatedObject(self, "settingsMenuView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(self, "settingsBackgroundView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

            // 重置标志，允许再次显示菜单
            self.isShowingSettingsMenu = NO;
        }];
    } else {
        // 如果没有找到菜单视图，也要重置标志
        self.isShowingSettingsMenu = NO;
    }
}

// 切换偏移过滤设置
- (void)toggleNegativeOffsetFilter {
    self.filterNegativeOffsets = !self.filterNegativeOffsets;

    // 保存设置到 UserDefaults
    [[NSUserDefaults standardUserDefaults] setBool:self.filterNegativeOffsets forKey:@"PointerScan_FilterNegativeOffsets"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSString *message = self.filterNegativeOffsets ?
        @"已开启偏移过滤，扫描结果将不显示包含负偏移的指针链" :
        @"已关闭偏移过滤，扫描结果将显示所有指针链";

    [self showToastMessage:message];
}

// 切换文件指针映射设置
- (void)toggleFileMapping {
    self.enableFileMapping = !self.enableFileMapping;
    
    // 保存设置到 UserDefaults
    [[NSUserDefaults standardUserDefaults] setBool:self.enableFileMapping forKey:@"PointerScan_EnableFileMapping"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSString *message = self.enableFileMapping ?
        @"已开启文件指针映射，扫描结果将更全面但首次扫描较慢" :
        @"已关闭文件指针映射，扫描速度更快但结果可能不全面";
    
    [self showToastMessage:message];
}

// 数值过滤
- (void)toggleValueFilter {
    [self dismissSettingsMenu];

    // 直接显示数值过滤设置界面
    [self showValueFilterSettings];
}

// 地址过滤
- (void)toggleAddressFilter {
    [self dismissSettingsMenu];

    // 直接显示地址过滤设置界面
    [self showAddressFilterSettings];
}

// 清除所有过滤器
- (void)clearFilters {
    [self dismissSettingsMenu];

    // 重置过滤状态
    self.enableValueFilter = NO;
    self.enableAddressFilter = NO;
    self.filterValue = nil;
    self.filterAddress = nil;
    self.filteredResults = nil;

    // 刷新显示
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.resultsTableView reloadData];
        [self updateResultsLabel];
    });

    [self showToastMessage:@"已清除所有过滤器"];
}

#pragma mark - 扫描数据目录设置

// 设置扫描数据目录
- (void)setupScanDataDirectory {
    // 获取Documents目录
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];

    // 创建扫描指针目录
    self.scanDataDirectory = [documentsDirectory stringByAppendingPathComponent:@"扫描指针"];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    if (![fileManager fileExistsAtPath:self.scanDataDirectory]) {
        NSError *error;
        [fileManager createDirectoryAtPath:self.scanDataDirectory
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:&error];
        if (error) {
            NSLog(@"创建扫描数据目录失败: %@", error.localizedDescription);
        }
    }
}

// 自动保存扫描结果
- (void)autoSaveScanResults {
    if (!self.scanResults || self.scanResults.count == 0) {
        return;
    }

    // 在后台线程保存
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            NSString *content = [self generatePointerChainsShareContent];
            if (content && content.length > 0) {
                // 生成文件名（包含时间戳和指针数量）
                NSString *fileName = [NSString stringWithFormat:@"扫描结果_%@_%lu条.txt",
                                    [self getCurrentTimestamp], (unsigned long)self.scanResults.count];
                NSString *filePath = [self.scanDataDirectory stringByAppendingPathComponent:fileName];

                // 写入文件
                NSError *writeError;
                BOOL success = [content writeToFile:filePath
                                         atomically:YES
                                           encoding:NSUTF8StringEncoding
                                              error:&writeError];

                if (success) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showToastMessage:[NSString stringWithFormat:@"扫描结果已自动保存: %@", fileName]];
                    });
                } else {
                    NSLog(@"自动保存扫描结果失败: %@", writeError.localizedDescription);
                }
            }
        } @catch (NSException *exception) {
            NSLog(@"自动保存扫描结果异常: %@", exception.reason);
        }
    });
}

#pragma mark - 设置菜单操作

// 导入指针链
- (void)importPointerChains {
    // 检查并刷新进程状态
    [self checkAndRefreshProcessState];

    // 确保扫描器已初始化
    if (![self ensureScannerInitialized]) {
        [self showAlert:@"错误" message:@"扫描器未初始化，请先选择进程"];
        return;
    }

    // 设置导入标志
    self.isImportingPointers = YES;

    // 显示文件选择器，支持文本文件
    UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc]
                                                     initWithDocumentTypes:@[@"public.text", @"public.plain-text", @"public.utf8-plain-text", @"public.data"]
                                                     inMode:UIDocumentPickerModeOpen];

    documentPicker.delegate = self;
    documentPicker.modalPresentationStyle = UIModalPresentationFormSheet;
    documentPicker.allowsMultipleSelection = NO;

    [self presentViewController:documentPicker animated:YES completion:nil];
}

// 清除指针链
- (void)clearPointerChains {
    // 检查是否有指针链可以清除
    if (!self.scanResults || self.scanResults.count == 0) {
        UIAlertController *infoAlert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                           message:@"当前没有指针链可以清除"
                                                                    preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                           style:UIAlertActionStyleDefault
                                                         handler:nil];

        [infoAlert addAction:okAction];
        [self presentViewController:infoAlert animated:YES completion:nil];
        return;
    }

    // 有指针链时显示确认对话框
    NSString *message = [NSString stringWithFormat:@"确定要清除所有 %lu 条指针链吗？此操作不可撤销。", (unsigned long)self.scanResults.count];
    UIAlertController *confirmAlert = [UIAlertController alertControllerWithTitle:@"确认清除"
                                                                          message:message
                                                                   preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确定"
                                                            style:UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction * _Nonnull action) {
        // 清除扫描结果和过滤结果
        self.scanResults = [NSMutableArray array];
        self.filteredResults = nil;

        // 重置过滤状态
        self.enableValueFilter = NO;
        self.enableAddressFilter = NO;

        // 刷新表格
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.resultsTableView reloadData];
            [self updateStatusDisplay];
        });

        // 显示清除成功提示
        [self showToastMessage:@"指针链已清除"];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [confirmAlert addAction:confirmAction];
    [confirmAlert addAction:cancelAction];

    [self presentViewController:confirmAlert animated:YES completion:nil];
}

// 过滤指针链
- (void)filterPointerChains {
    // 设置过滤标志
    self.isImportingPointers = NO;

    // 显示文件选择器，兼容 iOS 13.0+
    UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc]
                                                     initWithDocumentTypes:@[@"public.text", @"public.plain-text", @"public.utf8-plain-text"]
                                                     inMode:UIDocumentPickerModeOpen];

    documentPicker.delegate = self;
    documentPicker.modalPresentationStyle = UIModalPresentationFormSheet;

    [self presentViewController:documentPicker animated:YES completion:nil];
}

// 显示指针盒子
- (void)showPointerBox {
    // 获取已保存的指针文件列表
    NSArray<NSDictionary *> *savedFiles = [self getSavedPointerFiles];

    if (savedFiles.count == 0) {
        [self showToastMessage:@"暂无已保存的指针文件"];
        return;
    }

    // 创建指针盒子界面
    [self presentPointerBoxWithFiles:savedFiles];
}

// 获取已保存的指针文件列表
- (NSArray<NSDictionary *> *)getSavedPointerFiles {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSArray *files = [fileManager contentsOfDirectoryAtPath:self.scanDataDirectory error:&error];

    if (error || !files) {
        return @[];
    }

    NSMutableArray *fileInfos = [NSMutableArray array];

    for (NSString *fileName in files) {
        if ([fileName hasSuffix:@".txt"]) {
            NSString *fullPath = [self.scanDataDirectory stringByAppendingPathComponent:fileName];
            NSDictionary *attributes = [fileManager attributesOfItemAtPath:fullPath error:nil];

            if (attributes) {
                [fileInfos addObject:@{
                    @"name": fileName,
                    @"path": fullPath,
                    @"date": attributes[NSFileModificationDate],
                    @"size": attributes[NSFileSize]
                }];
            }
        }
    }

    // 按修改时间排序，最新的在前面
    [fileInfos sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        return [obj2[@"date"] compare:obj1[@"date"]];
    }];

    return [fileInfos copy];
}

// 显示指针盒子界面
- (void)presentPointerBoxWithFiles:(NSArray<NSDictionary *> *)files {
    UIAlertController *boxAlert = [UIAlertController alertControllerWithTitle:@"📦 指针盒子"
                                                                      message:[NSString stringWithFormat:@"共有 %lu 个已保存的指针文件", (unsigned long)files.count]
                                                               preferredStyle:UIAlertControllerStyleActionSheet];

    // 为每个文件添加选项
    for (NSDictionary *fileInfo in files) {
        NSString *fileName = fileInfo[@"name"];
        NSDate *date = fileInfo[@"date"];
        NSNumber *size = fileInfo[@"size"];

        // 格式化文件信息
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"MM-dd HH:mm";
        NSString *dateString = [formatter stringFromDate:date];

        NSString *sizeString = [self formatFileSize:size.longLongValue];
        NSString *displayName = [NSString stringWithFormat:@"%@ (%@ %@)",
                               [fileName stringByDeletingPathExtension], dateString, sizeString];

        UIAlertAction *fileAction = [UIAlertAction actionWithTitle:displayName
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
            [self showFileOptionsForFile:fileInfo];
        }];

        [boxAlert addAction:fileAction];
    }

    // 添加取消按钮
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [boxAlert addAction:cancelAction];

    // 为iPad设置弹出位置
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        boxAlert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    }

    [self presentViewController:boxAlert animated:YES completion:nil];
}

// 显示文件操作选项
- (void)showFileOptionsForFile:(NSDictionary *)fileInfo {
    NSString *fileName = fileInfo[@"name"];
    NSString *filePath = fileInfo[@"path"];

    UIAlertController *optionsAlert = [UIAlertController alertControllerWithTitle:fileName
                                                                          message:@"选择操作"
                                                                   preferredStyle:UIAlertControllerStyleActionSheet];

    // 加载指针链
    UIAlertAction *loadAction = [UIAlertAction actionWithTitle:@"📂 加载指针链"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
        [self loadPointerFileAtPath:filePath];
    }];
    [optionsAlert addAction:loadAction];

    // 编辑文件
    UIAlertAction *editAction = [UIAlertAction actionWithTitle:@"✏️ 编辑文件"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
        [self editFileAtPath:filePath];
    }];
    [optionsAlert addAction:editAction];

    // 分享文件
    UIAlertAction *shareAction = [UIAlertAction actionWithTitle:@"📤 分享文件"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * _Nonnull action) {
        [self shareFileAtPath:filePath];
    }];
    [optionsAlert addAction:shareAction];

    // 重命名文件
    UIAlertAction *renameAction = [UIAlertAction actionWithTitle:@"✏️ 重命名"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self renameFileAtPath:filePath currentName:fileName];
    }];
    [optionsAlert addAction:renameAction];

    // 删除文件
    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"🗑️ 删除文件"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self deleteFileAtPath:filePath fileName:fileName];
    }];
    [optionsAlert addAction:deleteAction];

    // 取消
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [optionsAlert addAction:cancelAction];

    // 为iPad设置弹出位置
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        optionsAlert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    }

    [self presentViewController:optionsAlert animated:YES completion:nil];
}

// 格式化文件大小
- (NSString *)formatFileSize:(long long)size {
    if (size < 1024) {
        return [NSString stringWithFormat:@"%lldB", size];
    } else if (size < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1fKB", size / 1024.0];
    } else {
        return [NSString stringWithFormat:@"%.1fMB", size / (1024.0 * 1024.0)];
    }
}

// 加载指针文件
- (void)loadPointerFileAtPath:(NSString *)filePath {
    NSError *error;
    NSString *content = [NSString stringWithContentsOfFile:filePath
                                                   encoding:NSUTF8StringEncoding
                                                      error:&error];

    if (!content) {
        [self showToastMessage:[NSString stringWithFormat:@"读取文件失败: %@", error.localizedDescription]];
        return;
    }

    // 解析指针链（跳过头部信息）
    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    NSMutableArray *results = [NSMutableArray array];

    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        // 跳过空行、头部信息
        if (trimmedLine.length == 0 ||
            [trimmedLine hasPrefix:@"Obsolete修改器"] ||
            [trimmedLine hasPrefix:@"共"]) {
            continue;
        }

        // 跳过数值行（以 "   (" 开头的行）
        if ([trimmedLine hasPrefix:@"   ("]) {
            continue;
        }

        // 只处理有序号的指针链行
        NSRange dotRange = [trimmedLine rangeOfString:@". "];
        if (dotRange.location == NSNotFound) {
            continue; // 不是指针链行，跳过
        }

        // 移除序号前缀（如 "1. "）
        trimmedLine = [trimmedLine substringFromIndex:dotRange.location + dotRange.length];

        // 解析指针链
        PointerChainResult *result = [self parsePointerChain:trimmedLine];
        if (result) {
            [results addObject:result];
        }
    }

    if (results.count > 0) {
        // 确保VMTool连接到当前选择的进程
        [self ensureVMToolConnection];

        // 询问是否替换当前结果
        NSString *message = [NSString stringWithFormat:@"文件包含 %lu 条指针链，是否加载？", (unsigned long)results.count];
        UIAlertController *confirmAlert = [UIAlertController alertControllerWithTitle:@"加载指针链"
                                                                              message:message
                                                                       preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *loadAction = [UIAlertAction actionWithTitle:@"加载"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
            // 更新扫描结果
            self.scanResults = [results copy];
            self.filteredResults = nil;
            self.enableValueFilter = NO;
            self.enableAddressFilter = NO;

            // 刷新界面
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.resultsTableView reloadData];
                [self updateResultsLabel];
                self.progressView.hidden = NO;
                self.progressView.progress = 1.0;
                [self updateStatusDisplay];
            });

            NSString *statusMessage = [NSString stringWithFormat:@"成功加载 %lu 条指针链", (unsigned long)results.count];
            [self showToastMessage:statusMessage];
        }];

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                               style:UIAlertActionStyleCancel
                                                             handler:nil];

        [confirmAlert addAction:loadAction];
        [confirmAlert addAction:cancelAction];

        [self presentViewController:confirmAlert animated:YES completion:nil];
    } else {
        [self showToastMessage:@"文件中没有找到有效的指针链"];
    }
}

// 编辑文件
- (void)editFileAtPath:(NSString *)filePath {
    PointerFileEditorViewController *editorVC = [[PointerFileEditorViewController alloc] initWithFilePath:filePath];
    editorVC.delegate = self;

    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:editorVC];
    navController.modalPresentationStyle = UIModalPresentationFullScreen;

    [self presentViewController:navController animated:YES completion:nil];
}

// 分享文件
- (void)shareFileAtPath:(NSString *)filePath {
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    [self presentShareActivityForFile:fileURL];
}

// 重命名文件
- (void)renameFileAtPath:(NSString *)filePath currentName:(NSString *)currentName {
    UIAlertController *renameAlert = [UIAlertController alertControllerWithTitle:@"重命名文件"
                                                                         message:@"请输入新的文件名"
                                                                  preferredStyle:UIAlertControllerStyleAlert];

    [renameAlert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = [currentName stringByDeletingPathExtension];
        textField.placeholder = @"文件名";
    }];

    UIAlertAction *renameAction = [UIAlertAction actionWithTitle:@"重命名"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
        UITextField *textField = renameAlert.textFields.firstObject;
        NSString *newName = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        if (newName.length == 0) {
            [self showToastMessage:@"文件名不能为空"];
            return;
        }

        // 确保有.txt扩展名
        if (![newName hasSuffix:@".txt"]) {
            newName = [newName stringByAppendingString:@".txt"];
        }

        NSString *newPath = [self.scanDataDirectory stringByAppendingPathComponent:newName];

        // 检查文件是否已存在
        if ([[NSFileManager defaultManager] fileExistsAtPath:newPath]) {
            [self showToastMessage:@"文件名已存在"];
            return;
        }

        NSError *error;
        BOOL success = [[NSFileManager defaultManager] moveItemAtPath:filePath toPath:newPath error:&error];

        if (success) {
            [self showToastMessage:@"重命名成功"];
        } else {
            [self showToastMessage:[NSString stringWithFormat:@"重命名失败: %@", error.localizedDescription]];
        }
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [renameAlert addAction:renameAction];
    [renameAlert addAction:cancelAction];

    [self presentViewController:renameAlert animated:YES completion:nil];
}

// 删除文件
- (void)deleteFileAtPath:(NSString *)filePath fileName:(NSString *)fileName {
    UIAlertController *deleteAlert = [UIAlertController alertControllerWithTitle:@"删除文件"
                                                                         message:[NSString stringWithFormat:@"确定要删除文件 \"%@\" 吗？此操作不可撤销。", fileName]
                                                                  preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"删除"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction * _Nonnull action) {
        NSError *error;
        BOOL success = [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];

        if (success) {
            [self showToastMessage:@"文件已删除"];
        } else {
            [self showToastMessage:[NSString stringWithFormat:@"删除失败: %@", error.localizedDescription]];
        }
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [deleteAlert addAction:deleteAction];
    [deleteAlert addAction:cancelAction];

    [self presentViewController:deleteAlert animated:YES completion:nil];
}

#pragma mark - PointerFileEditorDelegate

- (void)pointerFileDidSave:(NSString *)filePath {
    [self showToastMessage:@"文件编辑保存成功"];
}

// 生成指针链分享内容
- (NSString *)generatePointerChainsShareContent {
    @try {
        NSMutableString *content = [NSMutableString string];

        // 添加顶部标识和时间（紧凑格式）
        [content appendFormat:@"Obsolete修改器 %@\n", [self getCurrentTimeString]];
        [content appendFormat:@"共%lu条指针链\n", (unsigned long)self.scanResults.count];

        // 添加每个指针链，使用优化的格式
        for (NSInteger i = 0; i < self.scanResults.count; i++) {
            @try {
                PointerChainResult *result = self.scanResults[i];

                if (!result || !result.isValid) {
                    continue; // 跳过无效的结果
                }

                // 使用标准格式的指针链
                NSString *pointerChain = [self buildPointerChainStringForResult:result];
                if (!pointerChain || pointerChain.length == 0) {
                    pointerChain = @"无效指针链";
                }

                // 安全地计算最终地址并读取内存值
                NSString *allValues = @"N/A";
                @try {
                    uintptr_t finalAddress = [self calculateFinalAddressForResult:result];
                    if (finalAddress != 0) {
                        allValues = [self getAllValuesAtAddress:finalAddress];
                    }
                } @catch (NSException *exception) {
                    allValues = @"读取失败";
                }

                // 优化的格式：序号和指针链在一行，数值在下一行，然后空行分隔
                [content appendFormat:@"%ld. %@\n", (long)(i + 1), pointerChain];
                [content appendFormat:@"   (%@)\n", allValues ?: @"N/A"];
                [content appendString:@"\n"]; // 添加空行分隔每个指针链

            } @catch (NSException *exception) {
                // 单个指针链处理失败，继续处理下一个
                [content appendFormat:@"%ld. 处理失败\n\n", (long)(i + 1)];
            }
        }

        return [content copy];

    } @catch (NSException *exception) {
        // 整个方法失败，返回基本信息
        return [NSString stringWithFormat:@"Obsolete修改器 %@\n分享内容生成失败\n", [self getCurrentTimeString]];
    }
}

// 获取所有类型的数值
- (NSString *)getAllValuesAtAddress:(uintptr_t)address {
    @try {
        if (address == 0) {
            return @"N/A";
        }

        NSString *addressString = [NSString stringWithFormat:@"0x%lX", (unsigned long)address];

        // 安全地读取多种类型的数值
        NSString *i32Value = @"?";
        NSString *floatValue = @"?";
        NSString *i64Value = @"?";
        NSString *doubleValue = @"?";

        @try {
            VMTool *vmTool = [VMTool share];
            if (vmTool) {
                i32Value = [vmTool getValueFromAddress:addressString valueType:VMMemValueTypeSignedInt] ?: @"?";
                floatValue = [vmTool getValueFromAddress:addressString valueType:VMMemValueTypeFloat] ?: @"?";
                i64Value = [vmTool getValueFromAddress:addressString valueType:VMMemValueTypeSignedLong] ?: @"?";
                doubleValue = [vmTool getValueFromAddress:addressString valueType:VMMemValueTypeDouble] ?: @"?";
            }
        } @catch (NSException *exception) {
            // 读取失败，使用默认值
        }

        return [NSString stringWithFormat:@"I32:%@,F32:%@,I64:%@,F64:%@",
                i32Value, floatValue, i64Value, doubleValue];

    } @catch (NSException *exception) {
        return @"读取异常";
    }
}

// 获取简短的时间字符串
- (NSString *)getCurrentTimeString {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"MM-dd HH:mm";
    return [formatter stringFromDate:[NSDate date]];
}



// 显示分享界面（文件）
- (void)presentShareActivityForFile:(NSURL *)fileURL {
    NSArray *activityItems = @[fileURL];

    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:activityItems
                                                                             applicationActivities:nil];

    // 排除一些不需要的分享选项
    activityVC.excludedActivityTypes = @[
        UIActivityTypePostToFacebook,
        UIActivityTypePostToTwitter,
        UIActivityTypePostToWeibo,
        UIActivityTypePostToVimeo,
        UIActivityTypePostToFlickr,
        UIActivityTypePostToTencentWeibo
    ];

    // 为iPad设置弹出位置
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    }

    // 分享完成后的回调
    activityVC.completionWithItemsHandler = ^(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        if (completed) {
            [self showToastMessage:@"指针链文件分享成功"];
        }
    };

    [self presentViewController:activityVC animated:YES completion:nil];
}

// 获取当前时间戳
- (NSString *)getCurrentTimestamp {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMdd_HHmmss";
    return [formatter stringFromDate:[NSDate date]];
}

// 获取当前日期时间字符串
- (NSString *)getCurrentDateTimeString {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    return [formatter stringFromDate:[NSDate date]];
}

// 显示Toast消息
- (void)showToastMessage:(NSString *)message {
    UIAlertController *toast = [UIAlertController alertControllerWithTitle:nil
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [self presentViewController:toast animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [toast dismissViewControllerAnimated:YES completion:nil];
        });
    }];
}

#pragma mark - 按钮事件



- (void)selectModules {

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择模块"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];

    // 创建模块选择表格视图控制器
    ModuleSelectionTableViewController *tableViewController = [[ModuleSelectionTableViewController alloc] init];
    tableViewController.modules = self.modules;
    tableViewController.parentController = self;
    tableViewController.alertController = alert;

    // 设置表格大小
    CGFloat maxHeight = MIN(300, (self.modules.count + 1) * 35 + 20); // 最大300像素高度
    tableViewController.preferredContentSize = CGSizeMake(280, maxHeight);

    // 将表格视图控制器设置为alert的内容
    [alert setValue:tableViewController forKey:@"contentViewController"];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)scanButtonTapped {
    if (self.isScanning) {
        [self stopScan];
    } else {
        [self startScan];
    }
}

- (void)startScan {
    // 检查模块选择
    if (self.selectedModules.count == 0) {
        [self showAlert:@"提示" message:@"请先选择要扫描的模块"];
        return;
    }

    // 验证输入
    NSString *addressText = [self.addressField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (addressText.length == 0) {
        [self showAlert:@"错误" message:@"请输入目标地址"];
        return;
    }

    // 解析地址
    uintptr_t targetAddress = [self parseAddress:addressText];
    if (targetAddress == 0) {
        [self showAlert:@"错误" message:@"无效的地址格式"];
        return;
    }

    // 解析其他参数
    NSInteger maxDepth = [self.depthField.text integerValue] ?: 3;
    NSInteger scanRange = [self.rangeField.text integerValue] ?: 1000;  // 优化后的默认扫描范围
    NSInteger maxResults = [self.maxResultsField.text integerValue] ?: 1000;

    // 创建扫描配置
    PointerScanConfig *config = [PointerScanConfig defaultConfig];
    config.targetAddress = targetAddress;
    config.maxDepth = maxDepth;
    config.scanRangeLeft = 0;          // 向前偏移固定为0 (与Mac端 --range 0:1000 一致)
    config.scanRangeRight = scanRange; // 向后偏移使用用户输入的值
    config.maxResults = maxResults;

    // 更新UI状态
    self.isScanning = YES;
    [self.scanButton setTitle:@"停止扫描" forState:UIControlStateNormal];
    self.scanButton.backgroundColor = [UIColor systemRedColor];
    self.progressView.hidden = NO;
    self.progressView.progress = 0.0;
    self.statusLabel.text = @"正在扫描...";
    self.statusLabel.hidden = NO;  // 确保状态标签可见

    // 强制更新状态显示
    [self updateStatusDisplay];

    // 在后台线程执行扫描
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self performScanWithConfig:config];
    });
}

- (void)stopScan {
    self.isScanning = NO;
    [self.scanButton setTitle:@"开始扫描" forState:UIControlStateNormal];
    self.scanButton.backgroundColor = [UIColor systemBlueColor];

    // 如果没有扫描结果，隐藏进度条；如果有结果，保持进度条显示完成状态
    if (!self.scanResults || self.scanResults.count == 0) {
        self.progressView.hidden = YES;
    }

    // 更新状态显示
    [self updateStatusDisplay];
}

- (void)performScanWithConfig:(PointerScanConfig *)config {
    @try {
        NSError *error = nil;
        PointerScanManager *scanner = [PointerScanManager sharedManager];
        
    // 使用指针扫描专用目录
    NSString *pointerScanDir = [PointerScanManager pointerScanDirectory];
    NSString *timestamp = [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]];
    
    // 如果启用文件指针映射
    if (self.enableFileMapping) {
        // 步骤1: 生成模块文件（类似Mac的 list_modules 命令）
        dispatch_async(dispatch_get_main_queue(), ^{
            self.statusLabel.text = @"生成模块列表文件...";
            self.progressView.progress = 0.1;
        });

        // 根据用户选择决定使用哪些模块
        NSArray<ModuleInfo *> *modulesToUse;
        if (self.selectedModules && self.selectedModules.count > 0) {
            // 用户选择了模块，使用选择的模块
            modulesToUse = self.selectedModules;
        } else {
            // 用户没有选择模块，获取完整模块列表
            modulesToUse = [scanner getModuleList:&error forceRefresh:YES];
            if (!modulesToUse) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.statusLabel.text = [NSString stringWithFormat:@"获取模块列表失败: %@", error.localizedDescription];
                    [self stopScan];
                });
                return;
            }
        }

        // 创建模块文件（格式：start-end pathname）
        NSString *modulesFileName = @"modules.txt";
        NSString *modulesFilePath = [pointerScanDir stringByAppendingPathComponent:modulesFileName];

        NSMutableString *modulesContent = [NSMutableString string];
        for (ModuleInfo *module in modulesToUse) {
            [modulesContent appendFormat:@"%lx-%lx %@\n",
             (unsigned long)module.startAddress,
             (unsigned long)module.endAddress,
             module.name];
        }

        NSError *writeError = nil;
        if (![modulesContent writeToFile:modulesFilePath
                              atomically:YES
                                encoding:NSUTF8StringEncoding
                                   error:&writeError]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.statusLabel.text = [NSString stringWithFormat:@"保存模块文件失败: %@", writeError.localizedDescription];
                [self stopScan];
            });
            return;
        }

        // 显示模块文件生成成功
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *modeInfo = (self.selectedModules && self.selectedModules.count > 0) ?
                [NSString stringWithFormat:@"已选择 %lu 个模块", (unsigned long)self.selectedModules.count] :
                @"使用全部模块";
            self.statusLabel.text = [NSString stringWithFormat:@"模块文件已生成 (%@)，开始创建指针映射...", modeInfo];
            self.progressView.progress = 0.3;
        });

        // 步骤2: 创建指针映射（类似Mac的 create_pointer_map）
        // 创建 FFIModule 数组
        NSUInteger moduleCount = modulesToUse.count;
        FFIModule *ffiModules = (FFIModule *)malloc(sizeof(FFIModule) * moduleCount);

        for (NSUInteger i = 0; i < moduleCount; i++) {
            ModuleInfo *moduleInfo = modulesToUse[i];
            ffiModules[i].start = moduleInfo.startAddress;
            ffiModules[i].end = moduleInfo.endAddress;
            ffiModules[i].pathname = [moduleInfo.name UTF8String];
        }

        // 调用创建指针映射
        int createResult = ptrscan_create_pointer_map([scanner getScannerPtr], ffiModules, moduleCount);
        free(ffiModules);

        if (createResult != SUCCESS) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.statusLabel.text = [NSString stringWithFormat:@"创建指针映射失败: 错误码 %d", createResult];
                [self stopScan];
            });
            return;
        }

        // 显示指针映射创建成功
        dispatch_async(dispatch_get_main_queue(), ^{
            self.statusLabel.text = @"指针映射创建成功，开始扫描指针链...";
            self.progressView.progress = 0.6;
        });

        // 步骤3: 扫描指针链（类似Mac的 scan_pointer_chain）
        // 创建扫描参数
        uintptr_t maxResults = config.maxResults;   // 创建局部变量用于取地址
        FFIParam param;
        param.addr = config.targetAddress;
        param.depth = config.maxDepth;
        param.srange.left = config.scanRangeLeft;   // 0
        param.srange.right = config.scanRangeRight; // 1000（优化后的范围）
        param.lrange = NULL;                        // 不使用最后偏移范围
        param.node = NULL;                          // 不限制最短长度
        param.last = NULL;                          // 不限制结尾偏移
        param.max = &maxResults;                    // 最大结果数
        param.cycle = false;                        // 不处理循环引用
        param.raw1 = param.raw2 = param.raw3 = false; // 不使用原始格式

        // 创建输出文件路径（保存到数据目录）
        NSString *fileName = [NSString stringWithFormat:@"%lx.scandata", (unsigned long)config.targetAddress];
        NSString *outputFilePath = [pointerScanDir stringByAppendingPathComponent:fileName];

        // 如果文件已存在，先删除它（避免 create_new 失败）
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:outputFilePath]) {
            NSError *deleteError = nil;
            if (![fileManager removeItemAtPath:outputFilePath error:&deleteError]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.statusLabel.text = [NSString stringWithFormat:@"删除旧文件失败: %@", deleteError.localizedDescription];
                    [self stopScan];
                });
                return;
            }
        }

        // 调用扫描指针链
        int scanResult = ptrscan_scan_pointer_chain([scanner getScannerPtr], param, [outputFilePath UTF8String]);

        if (scanResult != SUCCESS) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.statusLabel.text = [NSString stringWithFormat:@"扫描指针链失败: 错误码 %d", scanResult];
                [self stopScan];
            });
            return;
        }

        // 扫描完成，加载并显示结果
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadScandataResults:outputFilePath];
        });
        return;
    } else {
        // 使用内存中的指针映射
        dispatch_async(dispatch_get_main_queue(), ^{
            self.statusLabel.text = @"创建指针映射...";
            self.progressView.progress = 0.2;
        });
        
        if (![scanner createPointerMapWithModules:self.selectedModules error:&error]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.statusLabel.text = [NSString stringWithFormat:@"创建指针映射失败: %@", error.localizedDescription];
                [self stopScan];
            });
            return;
        }
    }

    // 执行扫描
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = @"正在扫描指针链...";
        self.progressView.progress = self.enableFileMapping ? 0.5 : 0.5;
    });

    // 使用简单的ASCII文件名，避免特殊字符
    NSString *fileName = [NSString stringWithFormat:@"ptrscan_%@.txt", timestamp];
    NSString *outputPath = [pointerScanDir stringByAppendingPathComponent:fileName];

    BOOL success = [scanner scanPointerChain:config
                                  outputPath:outputPath
                               progressBlock:^(float progress, NSString *status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressView.progress = 0.5 + progress * 0.4;
            self.statusLabel.text = status;
        });
    } error:&error];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (success) {
            [self loadScanResults:outputPath];
        } else {
            NSString *errorMessage = [NSString stringWithFormat:@"扫描失败: %@", error.localizedDescription];
            self.statusLabel.text = errorMessage;
            [self showAlert:@"扫描失败" message:errorMessage];
        }
        [self stopScan];
    });

    } @catch (NSException *exception) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.statusLabel.text = [NSString stringWithFormat:@"扫描异常: %@", exception.reason];
            [self showAlert:@"扫描异常" message:exception.reason];
            [self stopScan];
        });
    }
}

- (void)loadScanResults:(NSString *)filePath {
    // 检查并刷新进程状态
    [self checkAndRefreshProcessState];

    // 确保扫描器已初始化
    if (![self ensureScannerInitialized]) {
        self.statusLabel.text = @"扫描器未初始化，无法加载结果";
        return;
    }

    NSError *error = nil;
    NSString *content = [NSString stringWithContentsOfFile:filePath
                                                   encoding:NSUTF8StringEncoding
                                                      error:&error];

    if (!content) {
        self.statusLabel.text = @"读取结果文件失败";
        return;
    }


    // 解析结果
    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    NSMutableArray *results = [NSMutableArray array];

    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmedLine.length > 0) {
            PointerChainResult *result = [self parsePointerChain:trimmedLine];
            if (result) {
                [results addObject:result];
            }
        }
    }

    self.scanResults = [results copy];

    // 重置过滤器
    self.filteredResults = nil;
    self.enableValueFilter = NO;
    self.enableAddressFilter = NO;

    [self.resultsTableView reloadData];

    [self updateResultsLabel];
    self.progressView.progress = 1.0;

    // 自动保存扫描结果
    if (self.scanResults.count > 0) {
        [self autoSaveScanResults];
    }


    // 确保表格视图可见并更新布局
    dispatch_async(dispatch_get_main_queue(), ^{
        // 强制更新状态显示
        [self updateStatusDisplay];

        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
        [self.scrollView setNeedsLayout];
        [self.scrollView layoutIfNeeded];

        // 不自动滚动，让用户可以看到扫描设置和结果
        // 用户可以手动滚动查看结果
    });

    // 清理临时文件
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
}

#pragma mark - 指针链解析

- (PointerChainResult *)parsePointerChain:(NSString *)chainString {

    PointerChainResult *result = [[PointerChainResult alloc] init];
    result.originalChain = chainString;
    result.isValid = YES;

    // 根据 libptrs 文档，指针链格式为：module.name+offset.offset.offset...
    // 我们需要将其转换为更易读的格式：module.name+offset+offset+offset...

    NSString *cleanChain = [self cleanPointerChainString:chainString];

    // 优先尝试解析现代格式：module+offset+offset+offset...
    if ([cleanChain containsString:@"+"] && ![cleanChain containsString:@"."] && ![cleanChain containsString:@"->"]) {
        result = [self parsePlusFormatChain:cleanChain];
    }
    // 尝试解析 libptrs 标准格式：module+offset.offset.offset...
    else if ([cleanChain containsString:@"+"] && [cleanChain containsString:@"."]) {
        result = [self parseDotFormatChain:cleanChain];
    }
    // 尝试解析 -> 分隔的格式（备用格式）
    else if ([cleanChain containsString:@"->"]) {
        result = [self parseArrowFormatChain:cleanChain];
    }
    else {
        // 如果都不匹配，创建一个基本的结果，直接显示原始内容
        result.displayText = cleanChain;
        result.moduleName = @"未知";
        return result;
    }

    // 根据设置决定是否过滤负偏移
    if (result && result.offsets) {
        for (NSNumber *offset in result.offsets) {
            long long offsetValue = offset.longLongValue;

            // 如果开启了偏移过滤，过滤掉所有负偏移
            if (self.filterNegativeOffsets && offsetValue < 0) {
                return nil; // 返回 nil 表示过滤掉这个结果
            }

            // 始终过滤过大的负偏移（小于-0x10000的认为是异常）
            if (offsetValue < -0x10000) {
                return nil; // 返回 nil 表示过滤掉这个结果
            }
        }
    }

    return result;
}

- (NSString *)cleanPointerChainString:(NSString *)original {
    NSString *result = original;

    // 移除路径部分，只保留文件名
    NSRange lastSlashRange = [result rangeOfString:@"/" options:NSBackwardsSearch];
    if (lastSlashRange.location != NSNotFound) {
        result = [result substringFromIndex:lastSlashRange.location + 1];
    }

    // 移除 .app 后缀
    result = [result stringByReplacingOccurrencesOfString:@".app" withString:@""];

    return result;
}

- (PointerChainResult *)parseArrowFormatChain:(NSString *)chainString {
    // 格式：module+baseOffset->offset1->offset2->...
    NSArray<NSString *> *parts = [chainString componentsSeparatedByString:@"->"];
    if (parts.count == 0) return nil;

    PointerChainResult *result = [[PointerChainResult alloc] init];
    result.originalChain = chainString;
    result.isValid = YES;

    // 解析基址部分
    NSString *basePart = parts[0];
    NSArray<NSString *> *baseComponents = [basePart componentsSeparatedByString:@"+"];
    if (baseComponents.count == 2) {
        result.moduleName = baseComponents[0];
        result.baseAddress = [self parseHexString:baseComponents[1]];

        // 解析偏移
        NSMutableArray *offsets = [NSMutableArray array];
        for (NSInteger i = 1; i < parts.count; i++) {
            // 使用有符号类型存储偏移，以正确处理负值
            long long offset = (long long)[self parseHexString:parts[i]];
            [offsets addObject:@(offset)];
        }
        result.offsets = [offsets copy];

        // 生成显示文本：模块名+基址+偏移1+偏移2+...，正确处理负值
        NSMutableString *displayText = [NSMutableString stringWithFormat:@"%@+0x%lX",
                                       result.moduleName, (unsigned long)result.baseAddress];
        for (NSNumber *offset in result.offsets) {
            long long signedOffset = offset.longLongValue;
            if (signedOffset < 0) {
                [displayText appendFormat:@"-0x%lX", (unsigned long)(-signedOffset)];
            } else {
                [displayText appendFormat:@"+0x%lX", (unsigned long)signedOffset];
            }
        }
        result.displayText = displayText;
    }

    return result;
}

- (PointerChainResult *)parseDotFormatChain:(NSString *)chainString {
    // 格式：module+baseOffset.offset1.offset2...
    // 转换为显示格式：module+baseOffset+offset1+offset2...
    NSLog(@"[DEBUG] 解析Dot格式指针链: %@", chainString);

    NSArray<NSString *> *baseParts = [chainString componentsSeparatedByString:@"+"];
    if (baseParts.count != 2) {
        NSLog(@"[DEBUG] Dot格式解析失败，基础部分数量: %lu", (unsigned long)baseParts.count);
        return nil;
    }

    PointerChainResult *result = [[PointerChainResult alloc] init];
    result.originalChain = chainString;
    result.isValid = YES;
    result.moduleName = baseParts[0];
    NSLog(@"[DEBUG] 模块名: %@", result.moduleName);

    NSString *offsetsPart = baseParts[1];
    NSLog(@"[DEBUG] 偏移部分: %@", offsetsPart);
    NSArray<NSString *> *offsetStrings = [offsetsPart componentsSeparatedByString:@"."];

    if (offsetStrings.count > 0) {
        result.baseAddress = [self parseHexString:offsetStrings[0]];
        NSLog(@"[DEBUG] 基址偏移字符串: %@, 解析结果: 0x%lX", offsetStrings[0], (unsigned long)result.baseAddress);

        NSMutableArray *offsets = [NSMutableArray array];
        for (NSInteger i = 1; i < offsetStrings.count; i++) {
            // 使用有符号类型存储偏移，以正确处理负值
            long long offset = (long long)[self parseHexString:offsetStrings[i]];
            NSLog(@"[DEBUG] 偏移字符串: %@, 解析结果: 0x%llX (%lld)", offsetStrings[i], offset, offset);
            [offsets addObject:@(offset)];
        }
        result.offsets = [offsets copy];

        // 生成显示文本：将点号格式转换为加号格式，正确处理负值
        NSMutableString *displayText = [NSMutableString stringWithFormat:@"%@+0x%lX",
                                       result.moduleName, (unsigned long)result.baseAddress];
        for (NSNumber *offset in result.offsets) {
            long long signedOffset = offset.longLongValue;
            if (signedOffset < 0) {
                [displayText appendFormat:@"-0x%lX", (unsigned long)(-signedOffset)];
            } else {
                [displayText appendFormat:@"+0x%lX", (unsigned long)signedOffset];
            }
        }
        result.displayText = displayText;
        NSLog(@"[DEBUG] 生成显示文本: %@", displayText);
    }

    NSLog(@"[DEBUG] Dot格式解析完成，偏移数组: %@", result.offsets);
    return result;
}

- (PointerChainResult *)parsePlusFormatChain:(NSString *)chainString {
    // 格式：module+baseOffset+offset1+offset2...
    NSLog(@"[DEBUG] 解析Plus格式指针链: %@", chainString);

    NSArray<NSString *> *parts = [chainString componentsSeparatedByString:@"+"];
    if (parts.count < 2) {
        NSLog(@"[DEBUG] Plus格式解析失败，部分数量不足: %lu", (unsigned long)parts.count);
        return nil;
    }

    PointerChainResult *result = [[PointerChainResult alloc] init];
    result.originalChain = chainString;
    result.isValid = YES;
    result.moduleName = parts[0];
    NSLog(@"[DEBUG] 模块名: %@", result.moduleName);

    // 解析基址偏移
    if (parts.count > 1) {
        result.baseAddress = [self parseHexString:parts[1]];
        NSLog(@"[DEBUG] 基址偏移字符串: %@, 解析结果: 0x%lX", parts[1], (unsigned long)result.baseAddress);
    }

    // 解析偏移链
    NSMutableArray *offsets = [NSMutableArray array];
    for (NSInteger i = 2; i < parts.count; i++) {
        // 使用有符号类型存储偏移，以正确处理负值
        long long offset = (long long)[self parseHexString:parts[i]];
        NSLog(@"[DEBUG] 偏移字符串: %@, 解析结果: 0x%llX (%lld)", parts[i], offset, offset);
        [offsets addObject:@(offset)];
    }
    result.offsets = [offsets copy];

    // 生成显示文本（保持原格式）
    result.displayText = chainString;

    NSLog(@"[DEBUG] Plus格式解析完成，偏移数组: %@", result.offsets);
    return result;
}

#pragma mark - 工具方法

- (uintptr_t)parseAddress:(NSString *)addressString {
    NSScanner *scanner = [NSScanner scannerWithString:addressString];
    if ([addressString hasPrefix:@"0x"] || [addressString hasPrefix:@"0X"]) {
        [scanner setScanLocation:2];
        unsigned long long value;
        if ([scanner scanHexLongLong:&value]) {
            return (uintptr_t)value;
        }
    } else {
        unsigned long long value;
        if ([scanner scanUnsignedLongLong:&value]) {
            return (uintptr_t)value;
        }
    }
    return 0;
}

- (uintptr_t)parseHexString:(NSString *)hexStr {
    if (!hexStr || hexStr.length == 0) {
        return 0;
    }

    // 处理负值
    BOOL isNegative = [hexStr hasPrefix:@"-"];
    NSString *cleanHexStr = isNegative ? [hexStr substringFromIndex:1] : hexStr;

    NSScanner *scanner = [NSScanner scannerWithString:cleanHexStr];
    unsigned long long value = 0;

    // 优先按十六进制解析（无论是否有0x前缀）
    if ([cleanHexStr hasPrefix:@"0x"] || [cleanHexStr hasPrefix:@"0X"]) {
        [scanner setScanLocation:2];
        if ([scanner scanHexLongLong:&value]) {
            return isNegative ? (uintptr_t)(-(long long)value) : (uintptr_t)value;
        }
    } else {
        // 没有0x前缀，但仍然尝试按十六进制解析
        if ([scanner scanHexLongLong:&value]) {
            return isNegative ? (uintptr_t)(-(long long)value) : (uintptr_t)value;
        }

        // 如果十六进制解析失败，重新创建scanner尝试十进制
        scanner = [NSScanner scannerWithString:cleanHexStr];
        if ([scanner scanUnsignedLongLong:&value]) {
            return isNegative ? (uintptr_t)(-(long long)value) : (uintptr_t)value;
        }
    }

    return 0;
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    [alert addAction:okAction];

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // 如果有过滤结果，使用过滤结果；否则使用原始结果
    NSArray *results = self.filteredResults ?: self.scanResults;
    return results.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    static NSString *cellIdentifier = @"PointerChainCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];

        // 设置单元格背景 - 去掉圆角
        cell.backgroundColor = [UIColor secondarySystemBackgroundColor];

        // 设置选中状态的背景色 - 去掉圆角
        UIView *selectedBackgroundView = [[UIView alloc] init];
        selectedBackgroundView.backgroundColor = [UIColor systemBlueColor];
        selectedBackgroundView.alpha = 0.15;
        cell.selectedBackgroundView = selectedBackgroundView;

        // 文本样式
        cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        cell.detailTextLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        cell.detailTextLabel.numberOfLines = 0; // 支持多行显示
        cell.detailTextLabel.lineBreakMode = NSLineBreakByWordWrapping;

        // 设置分隔线样式
        cell.separatorInset = UIEdgeInsetsMake(0, 16, 0, 0);
    }

    // 使用过滤后的结果或原始结果
    NSArray *results = self.filteredResults ?: self.scanResults;
    PointerChainResult *result = results[indexPath.row];

    // 计算最终地址
    uintptr_t finalAddress = [self calculateFinalAddressForResult:result];

    // 主标题显示编号和地址
    NSString *numberedAddress = [NSString stringWithFormat:@"%ld. 地址: 0x%lX",
                                (long)(indexPath.row + 1), (unsigned long)finalAddress];
    cell.textLabel.text = numberedAddress;

    // 副标题显示指针链和内存值
    NSString *valueString = [self readValuesAtAddress:finalAddress];
    NSString *pointerChain = result.displayText ?: result.originalChain;

    // 创建富文本以设置不同颜色
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] init];

    // 指针链部分 - 蓝色
    NSAttributedString *chainPart = [[NSAttributedString alloc]
        initWithString:[NSString stringWithFormat:@"%@\n", pointerChain]
        attributes:@{NSForegroundColorAttributeName: [UIColor systemBlueColor],
                    NSFontAttributeName: [UIFont systemFontOfSize:12]}];
    [attributedText appendAttributedString:chainPart];

    // 内存值部分 - 橙色
    NSAttributedString *valuePart = [[NSAttributedString alloc]
        initWithString:valueString
        attributes:@{NSForegroundColorAttributeName: [UIColor systemOrangeColor],
                    NSFontAttributeName: [UIFont fontWithName:@"Menlo" size:11]}];
    [attributedText appendAttributedString:valuePart];

    cell.detailTextLabel.attributedText = attributedText;

    // 根据有效性设置颜色
    if (result.isValid) {
        cell.textLabel.textColor = [UIColor labelColor];
    } else {
        cell.textLabel.textColor = [UIColor systemRedColor];
    }

    // 去掉右边的箭头符号
    cell.accessoryType = UITableViewCellAccessoryNone;

    return cell;
}

#pragma mark - UITableViewDelegate



- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    // 根据是否有过滤结果来选择正确的数组
    NSArray *results = self.filteredResults ?: self.scanResults;
    PointerChainResult *result = results[indexPath.row];

    // 获取目标地址（指针链最终指向的地址）
    NSString *targetAddress = [self extractTargetAddressFromResult:result];

    if (targetAddress) {
        // 读取当前内存值
        NSString *currentValue = [self readMemoryValueAtAddress:targetAddress];

        // 显示修改内存弹窗
        [self showModifyValueAlertForAddress:targetAddress currentValue:currentValue];
    } else {
        // 如果无法获取目标地址，显示原来的详细信息
        [self showPointerChainDetailsForResult:result];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 75; // 调整高度以容纳：编号+地址、指针链、内存值（两行）
}

#pragma mark - 测试方法

- (void)testPointerChainParsing {
    // 测试 libptrs 标准格式解析
    NSArray *testCases = @[
        @"UnityFramework+0x1234.0x10.0x20.0x30",
        @"libil2cpp+0xABC.0x8.0x18",
        @"MyApp+0x5000.0x0.0x4",
        @"TestModule+0xFF00"
    ];


    for (NSString *testCase in testCases) {
        PointerChainResult *result = [self parsePointerChain:testCase];
    }

}

#pragma mark - 地址计算和数值读取

- (NSString *)getAddressAndValueForResult:(PointerChainResult *)result {
    @try {
        if (!result || !result.isValid || !result.moduleName) {
            return @"地址: 无效\n数值: N/A";
        }

        // 计算最终地址
        uintptr_t finalAddress = [self calculateFinalAddressForResult:result];
        if (finalAddress == 0) {
            return @"地址: 计算失败\n数值: N/A";
        }

        // 读取该地址的数值
        NSString *valueString = [self readValuesAtAddress:finalAddress];

        return [NSString stringWithFormat:@"地址: 0x%lX\n%@", (unsigned long)finalAddress, valueString];

    } @catch (NSException *exception) {
        return @"地址: 异常\n数值: N/A";
    }
}

- (uintptr_t)calculateFinalAddressForResult:(PointerChainResult *)result {
    @try {
        // 调试信息
        NSLog(@"[DEBUG] 计算指针链地址:");
        NSLog(@"[DEBUG] 模块名: %@", result.moduleName);
        NSLog(@"[DEBUG] 基址偏移: 0x%lX", (unsigned long)result.baseAddress);
        NSLog(@"[DEBUG] 偏移数组: %@", result.offsets);

        // 获取模块基址
        PointerScanManager *scanner = [PointerScanManager sharedManager];
        NSError *error = nil;
        NSArray<ModuleInfo *> *modules = [scanner getModuleList:&error];

        if (!modules) {
            NSLog(@"[DEBUG] 获取模块列表失败");
            return 0;
        }

        ModuleInfo *targetModule = nil;
        for (ModuleInfo *module in modules) {
            if ([module.name isEqualToString:result.moduleName]) {
                targetModule = module;
                break;
            }
        }

        if (!targetModule) {
            NSLog(@"[DEBUG] 模块未找到: %@", result.moduleName);
            // 模块未找到，无法计算地址
            return 0;
        }

        NSLog(@"[DEBUG] 找到模块: %@, 起始地址: 0x%lX", targetModule.name, (unsigned long)targetModule.startAddress);

        // 计算起始地址：模块基址 + 基址偏移
        uintptr_t currentAddress = targetModule.startAddress + result.baseAddress;
        NSLog(@"[DEBUG] 初始地址: 0x%lX", (unsigned long)currentAddress);

        // 逐级解引用
        for (NSInteger i = 0; i < result.offsets.count; i++) {
            NSNumber *offset = result.offsets[i];
            NSLog(@"[DEBUG] 第%ld级解引用，当前地址: 0x%lX, 偏移: 0x%llX", (long)i, (unsigned long)currentAddress, offset.longLongValue);

            // 读取当前地址的值作为下一个地址
            NSError *readError = nil;
            NSData *data = [scanner readMemory:currentAddress size:sizeof(uintptr_t) error:&readError];
            if (!data || readError) {
                NSLog(@"[DEBUG] 内存读取失败，地址: 0x%lX, 错误: %@", (unsigned long)currentAddress, readError);
                return 0;
            }

            uintptr_t nextAddress = 0;
            [data getBytes:&nextAddress length:sizeof(uintptr_t)];
            NSLog(@"[DEBUG] 读取到的地址值: 0x%lX", (unsigned long)nextAddress);

            // 加上偏移（正确处理负偏移）
            long long signedOffset = offset.longLongValue;
            currentAddress = nextAddress + signedOffset;
            NSLog(@"[DEBUG] 加上偏移后的地址: 0x%lX", (unsigned long)currentAddress);
        }

        return currentAddress;

    } @catch (NSException *exception) {
        return 0;
    }
}

- (NSString *)readValuesAtAddress:(uintptr_t)address {
    PointerScanManager *scanner = [PointerScanManager sharedManager];
    NSError *error = nil;


    // 读取8字节数据以支持所有数据类型
    NSData *data = [scanner readMemory:address size:8 error:&error];
    if (!data || error) {
        return @"F32: 🚫 | F64: 🚫\nI32: 🚫 | I64: 🚫";
    }

    if (data.length < 8) {
        return @"F32: 🚫 | F64: 🚫\nI32: 🚫 | I64: 🚫";
    }

    const uint8_t *bytes = (const uint8_t *)data.bytes;

    // 读取不同类型的数值
    int32_t i32Value = *(int32_t *)bytes;
    int64_t i64Value = *(int64_t *)bytes;
    float f32Value = *(float *)bytes;
    double f64Value = *(double *)bytes;

    return [NSString stringWithFormat:@"F32: %.3f | F64: %.6f\nI32: %d | I64: %lld",
            f32Value, f64Value, i32Value, i64Value];
}

#pragma mark - 键盘处理

// 为数字键盘添加工具栏
- (void)addToolbarToTextField:(UITextField *)textField {
    UIToolbar *toolbar = [[UIToolbar alloc] init];
    toolbar.barStyle = UIBarStyleDefault;
    [toolbar sizeToFit];

    // 创建完成按钮
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc]
                                   initWithTitle:@"完成"
                                   style:UIBarButtonItemStyleDone
                                   target:self
                                   action:@selector(dismissKeyboard)];

    // 创建弹性空间
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc]
                                  initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                  target:nil
                                  action:nil];

    // 设置工具栏项目
    toolbar.items = @[flexSpace, doneButton];

    // 将工具栏设置为输入框的辅助视图
    textField.inputAccessoryView = toolbar;
}

// 隐藏键盘
- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

#pragma mark - UITextFieldDelegate

// 当用户点击返回键时隐藏键盘
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

// 当输入框失去焦点时的处理
- (void)textFieldDidEndEditing:(UITextField *)textField {
    // 可以在这里添加输入验证逻辑
}

// 点击空白区域隐藏键盘
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
    [super touchesBegan:touches withEvent:event];
}

#pragma mark - UIGestureRecognizerDelegate

// 手势识别器代理方法，确保右滑手势正常工作
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

// 手势开始时的处理
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.navigationController.interactivePopGestureRecognizer) {
        return YES;
    }
    return YES;
}

// 处理长按手势
- (void)handleLongPressOnResultsTable:(UILongPressGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        CGPoint touchPoint = [gestureRecognizer locationInView:self.resultsTableView];
        NSIndexPath *indexPath = [self.resultsTableView indexPathForRowAtPoint:touchPoint];
        
        // 使用过滤后的结果或原始结果
        NSArray *results = self.filteredResults ?: self.scanResults;
        
        if (indexPath && indexPath.row < results.count) {
            PointerChainResult *result = results[indexPath.row];
            [self showCopyPointerChainMenuForResult:result];
        }
    }
}

// 显示复制指针链的菜单
- (void)showCopyPointerChainMenuForResult:(PointerChainResult *)result {
    // 构建指针链字符串
    NSString *pointerChainString = [self buildPointerChainStringForResult:result];
    
    // 获取当前地址
    NSString *addressString = [self extractTargetAddressFromResult:result];
    if (!addressString) {
        addressString = @"无法获取地址";
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"指针链操作"
                                                                   message:pointerChainString
                                                            preferredStyle:UIAlertControllerStyleAlert];

    // 复制指针链按钮
    UIAlertAction *copyChainAction = [UIAlertAction actionWithTitle:@"复制指针链"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
        // 复制到剪贴板
        UIPasteboard.generalPasteboard.string = pointerChainString;

        // 显示复制成功提示
        [self showCopySuccessToast:@"指针链已复制到剪贴板"];
    }];
    
    // 复制地址按钮
    UIAlertAction *copyAddressAction = [UIAlertAction actionWithTitle:@"复制地址"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * _Nonnull action) {
        // 复制地址到剪贴板
        UIPasteboard.generalPasteboard.string = addressString;
        
        // 显示复制成功提示
        [self showCopySuccessToast:@"地址已复制到剪贴板"];
    }];

    // 取消按钮
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [alert addAction:copyChainAction];
    [alert addAction:copyAddressAction];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:nil];
}

// 构建指针链字符串
- (NSString *)buildPointerChainStringForResult:(PointerChainResult *)result {
    NSMutableString *chainString = [NSMutableString string];

    // 添加模块名
    if (result.moduleName && result.moduleName.length > 0) {
        [chainString appendString:result.moduleName];
    } else {
        [chainString appendString:@"wp2"]; // 默认使用wp2
    }

    // 添加基址偏移
    if (result.baseAddress > 0) {
        [chainString appendFormat:@"+0x%lX", (unsigned long)result.baseAddress];
    }

    // 添加偏移链
    if (result.offsets && result.offsets.count > 0) {
        for (NSNumber *offset in result.offsets) {
            // 处理负偏移，显示为"-0xXXX"格式
            long long signedOffset = offset.longLongValue;
            if (signedOffset < 0) {
                [chainString appendFormat:@"-0x%lX", (unsigned long)(-signedOffset)];
            } else {
                [chainString appendFormat:@"+0x%lX", (unsigned long)signedOffset];
            }
        }
    }

    return [chainString copy];
}

// 显示复制成功提示
- (void)showCopySuccessToast:(NSString *)message {
    UIAlertController *toast = [UIAlertController alertControllerWithTitle:nil
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [self presentViewController:toast animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [toast dismissViewControllerAnimated:YES completion:nil];
        });
    }];
}

#pragma mark - 状态显示更新

- (void)updateStatusDisplay {
    // 确保状态标签和进度条在抽屉状态变化时保持可见
    dispatch_async(dispatch_get_main_queue(), ^{
        // 如果有扫描结果，显示结果数量
        if (self.scanResults && self.scanResults.count > 0) {
            [self updateResultsLabel];
        }

        // 如果正在扫描，确保进度条可见
        if (self.isScanning) {
            self.progressView.hidden = NO;
            self.statusLabel.hidden = NO;
        }

        // 强制更新布局
        [self.statusLabel setNeedsDisplay];
        [self.progressView setNeedsDisplay];
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    });
}

#pragma mark - 内存修改相关方法

// 从指针链结果中提取目标地址
- (NSString *)extractTargetAddressFromResult:(PointerChainResult *)result {
    // 直接计算指针链的最终地址
    uintptr_t finalAddress = [self calculateFinalAddressForResult:result];

    if (finalAddress == 0) {
        return nil;
    }

    // 返回十六进制格式的地址字符串
    NSString *addressString = [NSString stringWithFormat:@"0x%lX", (unsigned long)finalAddress];

    return addressString;
}

// 读取指定地址的内存值
- (NSString *)readMemoryValueAtAddress:(NSString *)address {
    // 使用默认的I32类型读取内存值
    return [self readMemoryValueAtAddress:address withType:@"I32"];
}

// 根据指定类型读取指定地址的内存值
- (NSString *)readMemoryValueAtAddress:(NSString *)address withType:(NSString *)typeKey {
    NSLog(@"[DEBUG] PointerScan readMemoryValueAtAddress called with address: %@, typeKey: %@", address, typeKey);

    if (!address || !typeKey) {
        NSLog(@"[DEBUG] PointerScan address or typeKey is nil");
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

    NSLog(@"[DEBUG] PointerScan mapped valueType: %d", (int)valueType);

    // 使用VMTool读取内存值
    NSString *result = [[VMTool share] getValueFromAddress:address valueType:valueType];

    NSLog(@"[DEBUG] PointerScan VMTool returned result: %@", result);

    return result ?: @"0";
}

// 显示修改内存值的弹窗
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

    // 默认选择第一个类型
    typeSegment.selectedSegmentIndex = 0;

    // 根据默认选择的类型读取当前内存值
    NSString *defaultTypeKey = allKeys.count > 0 ? allKeys[0] : @"I32";
    NSString *actualCurrentValue = [self readMemoryValueAtAddress:address withType:defaultTypeKey];

    // 输入框
    UITextField *valueTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 100, containerWidth - 40, 35)];
    valueTextField.placeholder = @"请输入新值";
    valueTextField.text = actualCurrentValue;
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

    [containerView addSubview:titleLabel];
    [containerView addSubview:addressLabel];
    [containerView addSubview:typeSegment];
    [containerView addSubview:valueTextField];
    [containerView addSubview:confirmButton];
    [containerView addSubview:cancelButton];

    [backgroundView addSubview:containerView];
    [self.view addSubview:backgroundView];

    // 确认按钮点击事件
    [confirmButton addTarget:self action:@selector(pointerModifyConfirmButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    // 取消按钮点击事件
    [cancelButton addTarget:self action:@selector(pointerModifyCancelButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    // 类型分段控件值改变事件
    [typeSegment addTarget:self action:@selector(pointerModifyTypeSegmentChanged:) forControlEvents:UIControlEventValueChanged];

    // 存储引用以便在按钮回调中访问
    objc_setAssociatedObject(self, "pointerModifyBackgroundView", backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "pointerModifyContainerView", containerView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "pointerModifyValueTextField", valueTextField, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "pointerModifyTypeSegment", typeSegment, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "pointerModifyAddress", address, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 动画显示
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 1;
        containerView.transform = CGAffineTransformIdentity;
    }];
}

// 显示指针链详细信息（原来的弹窗）
- (void)showPointerChainDetailsForResult:(PointerChainResult *)result {
    // 显示详细信息
    NSMutableString *details = [NSMutableString string];
    [details appendFormat:@"原始指针链:\n%@\n\n", result.originalChain];

    if (result.moduleName) {
        [details appendFormat:@"模块名: %@\n", result.moduleName];
        [details appendFormat:@"基址: 0x%lX\n", (unsigned long)result.baseAddress];

        if (result.offsets.count > 0) {
            [details appendString:@"偏移列表:\n"];
            for (NSInteger i = 0; i < result.offsets.count; i++) {
                NSNumber *offset = result.offsets[i];
                [details appendFormat:@"  [%ld] 0x%lX\n", (long)i, (unsigned long)offset.unsignedIntegerValue];
            }
        }
    }

    [details appendFormat:@"\n显示格式:\n%@", result.displayText ?: @"无"];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"指针链详情"
                                                                   message:details
                                                            preferredStyle:UIAlertControllerStyleAlert];

    // 复制按钮
    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"复制"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
        UIPasteboard.generalPasteboard.string = result.displayText ?: result.originalChain;
    }];
    [alert addAction:copyAction];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    [alert addAction:okAction];

    [self presentViewController:alert animated:YES completion:nil];
}

// 确认修改按钮点击事件处理
- (void)pointerModifyConfirmButtonTapped:(UIButton *)sender {
    UITextField *valueTextField = objc_getAssociatedObject(self, "pointerModifyValueTextField");
    UISegmentedControl *typeSegment = objc_getAssociatedObject(self, "pointerModifyTypeSegment");
    NSString *address = objc_getAssociatedObject(self, "pointerModifyAddress");

    NSString *newValue = valueTextField.text;
    NSInteger selectedTypeIndex = typeSegment.selectedSegmentIndex;

    // 检查输入是否为空字符串
    if (newValue.length > 0) {
        // 根据选择的类型获取对应的VMMemValueType
        NSArray *allKeys = [[VMTool share] allKeys];
        NSString *selectedType = allKeys[selectedTypeIndex];
        VMMemValueType modifyType = (VMMemValueType)[[[VMTool share] keyValues][selectedType] integerValue];

        // 修改内存值
        [[VMTool share] modifyValue:newValue address:address type:modifyType];

        // 显示修改成功提示
        [self showSuccessToast:[NSString stringWithFormat:@"已修改地址 %@ 的值", address]];
    }

    // 关闭弹窗
    [self closePointerModifyValueAlert];
}

// 取消修改按钮点击事件处理
- (void)pointerModifyCancelButtonTapped:(UIButton *)sender {
    [self closePointerModifyValueAlert];
}

// 类型分段控件值改变事件处理
- (void)pointerModifyTypeSegmentChanged:(UISegmentedControl *)sender {
    UITextField *valueTextField = objc_getAssociatedObject(self, "pointerModifyValueTextField");
    NSString *address = objc_getAssociatedObject(self, "pointerModifyAddress");

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

// 关闭修改值弹窗
- (void)closePointerModifyValueAlert {
    UIView *backgroundView = objc_getAssociatedObject(self, "pointerModifyBackgroundView");
    UIView *containerView = objc_getAssociatedObject(self, "pointerModifyContainerView");

    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 0;
        containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    } completion:^(BOOL finished) {
        [backgroundView removeFromSuperview];

        // 清理Associated Objects
        objc_setAssociatedObject(self, "pointerModifyBackgroundView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "pointerModifyContainerView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "pointerModifyValueTextField", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "pointerModifyTypeSegment", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "pointerModifyAddress", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }];
}

// 显示成功提示
- (void)showSuccessToast:(NSString *)message {
    UILabel *toastLabel = [[UILabel alloc] init];
    toastLabel.backgroundColor = [UIColor colorWithRed:0.2 green:0.7 blue:0.2 alpha:0.9];
    toastLabel.textColor = [UIColor whiteColor];
    toastLabel.textAlignment = NSTextAlignmentCenter;
    toastLabel.font = [UIFont systemFontOfSize:14];
    toastLabel.text = message;
    toastLabel.alpha = 0.0;
    toastLabel.layer.cornerRadius = 10;
    toastLabel.clipsToBounds = YES;

    CGSize textSize = [message sizeWithAttributes:@{NSFontAttributeName: toastLabel.font}];
    toastLabel.frame = CGRectMake(0, 0, textSize.width + 20, 40);
    toastLabel.center = CGPointMake(self.view.center.x, self.view.center.y - 100);

    [self.view addSubview:toastLabel];

    [UIView animateWithDuration:0.3 animations:^{
        toastLabel.alpha = 1.0;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.3 delay:1.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            toastLabel.alpha = 0.0;
        } completion:^(BOOL finished) {
            [toastLabel removeFromSuperview];
        }];
    }];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count == 0) return;

    NSURL *selectedURL = urls.firstObject;

    // 开始访问安全范围资源
    BOOL startedAccessing = [selectedURL startAccessingSecurityScopedResource];

    @try {
        // 读取文件内容
        NSError *error;
        NSString *fileContent = [NSString stringWithContentsOfURL:selectedURL
                                                         encoding:NSUTF8StringEncoding
                                                            error:&error];

        if (error) {
            [self showAlert:@"读取失败" message:[NSString stringWithFormat:@"无法读取文件: %@", error.localizedDescription]];
            return;
        }

        // 根据操作类型处理文件
        if (self.isImportingPointers) {
            [self importPointerChainFile:fileContent];
        } else {
            [self processPointerChainFile:fileContent];
        }

    } @finally {
        if (startedAccessing) {
            [selectedURL stopAccessingSecurityScopedResource];
        }
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    // 重置标志
    self.isImportingPointers = NO;
}

#pragma mark - 指针链导入逻辑

- (void)importPointerChainFile:(NSString *)fileContent {
    @try {
        // 确保VMTool连接到当前选择的进程
        [self ensureVMToolConnection];

        // 解析文件中的指针链
        NSArray<PointerChainResult *> *importedChains = [self parsePointerChainsFromFile:fileContent];

        if (importedChains.count == 0) {
            [self showAlert:@"导入失败" message:@"文件中没有找到有效的指针链"];
            return;
        }

        // 直接使用所有导入的指针链，不进行过滤
        self.scanResults = [importedChains copy];

        // 刷新界面
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.resultsTableView reloadData];

            // 更新状态显示
            [self updateResultsLabel];
            NSString *statusMessage = [NSString stringWithFormat:@"成功导入 %lu 条指针链", (unsigned long)importedChains.count];

            // 显示进度条为完成状态
            self.progressView.hidden = NO;
            self.progressView.progress = 1.0;

            // 强制更新状态显示
            [self updateStatusDisplay];

            // 显示成功提示
            [self showToastMessage:statusMessage];
        });

    } @catch (NSException *exception) {
        [self showAlert:@"导入失败" message:[NSString stringWithFormat:@"导入过程中发生错误: %@", exception.reason]];
    } @finally {
        // 重置标志
        self.isImportingPointers = NO;
    }
}

// 确保VMTool连接到当前选择的进程
- (void)ensureVMToolConnection {
    ProcessManager *processManager = [ProcessManager sharedManager];

    if (!processManager.selectedProcessPID || !processManager.selectedProcessName) {
        NSLog(@"[DEBUG] 没有选择进程，无法连接VMTool");
        return;
    }

    pid_t pid = [processManager.selectedProcessPID intValue];
    NSString *processName = processManager.selectedProcessName;

    NSLog(@"[DEBUG] 确保VMTool连接到进程: PID=%d, Name=%@", pid, processName);

    // 连接VMTool到选择的进程
    [[VMTool share] setPid:pid name:processName];

    NSLog(@"[DEBUG] VMTool已连接到进程");
}

#pragma mark - 过滤设置界面

// 显示数值过滤设置界面
- (void)showValueFilterSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"数值过滤设置"
                                                                   message:@"设置要过滤的数值和类型"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    // 添加数值输入框
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"输入要过滤的数值";
        textField.text = self.filterValue ?: @"";
        textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    }];

    // 创建类型选择器
    UIAlertController *typeAlert = [UIAlertController alertControllerWithTitle:@"选择数值类型"
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];

    // 添加类型选项
    NSArray *types = @[@"I8", @"I16", @"I32", @"I64", @"F32", @"F64"];
    NSArray *typeNames = @[@"8位整数", @"16位整数", @"32位整数", @"64位整数", @"32位浮点", @"64位浮点"];

    for (int i = 0; i < types.count; i++) {
        NSString *typeKey = types[i];
        NSString *typeName = typeNames[i];

        UIAlertAction *typeAction = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@ (%@)", typeKey, typeName]
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction *action) {
            // 设置选择的类型
            VMMemValueType valueType = VMMemValueTypeSignedInt;
            if ([typeKey isEqualToString:@"I8"]) {
                valueType = VMMemValueTypeSignedByte;
            } else if ([typeKey isEqualToString:@"I16"]) {
                valueType = VMMemValueTypeSignedShort;
            } else if ([typeKey isEqualToString:@"I32"]) {
                valueType = VMMemValueTypeSignedInt;
            } else if ([typeKey isEqualToString:@"I64"]) {
                valueType = VMMemValueTypeSignedLong;
            } else if ([typeKey isEqualToString:@"F32"]) {
                valueType = VMMemValueTypeFloat;
            } else if ([typeKey isEqualToString:@"F64"]) {
                valueType = VMMemValueTypeDouble;
            }

            self.filterValueType = valueType;

            // 显示确认对话框
            [self showValueFilterConfirmation:alert];
        }];

        [typeAlert addAction:typeAction];
    }

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [typeAlert addAction:cancelAction];

    // 在iPad上设置popover
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        typeAlert.popoverPresentationController.sourceView = self.view;
        typeAlert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
    }

    [self presentViewController:typeAlert animated:YES completion:nil];
}

// 显示数值过滤确认对话框
- (void)showValueFilterConfirmation:(UIAlertController *)valueAlert {
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确定"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {
        UITextField *textField = valueAlert.textFields.firstObject;
        NSString *inputValue = textField.text;

        if (inputValue.length > 0) {
            self.filterValue = inputValue;
            self.enableValueFilter = YES;
            [self applyFilters];
            [self showToastMessage:[NSString stringWithFormat:@"已应用数值过滤: %@", inputValue]];
        }
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];

    [valueAlert addAction:confirmAction];
    [valueAlert addAction:cancelAction];

    [self presentViewController:valueAlert animated:YES completion:nil];
}

// 显示地址过滤设置界面
- (void)showAddressFilterSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"地址过滤设置"
                                                                   message:@"输入要过滤的地址（支持部分匹配）"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    // 添加地址输入框
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"输入地址，如: 0x1000 或 1000";
        textField.text = self.filterAddress ?: @"";
        textField.keyboardType = UIKeyboardTypeDefault;
    }];

    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确定"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {
        UITextField *textField = alert.textFields.firstObject;
        NSString *inputAddress = textField.text;

        if (inputAddress.length > 0) {
            self.filterAddress = inputAddress;
            self.enableAddressFilter = YES;
            [self applyFilters];
            [self showToastMessage:[NSString stringWithFormat:@"已应用地址过滤: %@", inputAddress]];
        }
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];

    [alert addAction:confirmAction];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:nil];
}

// 应用过滤器
- (void)applyFilters {
    if (!self.scanResults || self.scanResults.count == 0) {
        return;
    }

    NSMutableArray<PointerChainResult *> *filteredResults = [NSMutableArray array];

    for (PointerChainResult *result in self.scanResults) {
        BOOL shouldInclude = YES;

        // 应用数值过滤
        if (self.enableValueFilter && self.filterValue) {
            shouldInclude = [self checkValueFilter:result];
        }

        // 应用地址过滤
        if (shouldInclude && self.enableAddressFilter && self.filterAddress) {
            shouldInclude = [self checkAddressFilter:result];
        }

        if (shouldInclude) {
            [filteredResults addObject:result];
        }
    }

    // 更新显示的结果
    self.filteredResults = [filteredResults copy];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.resultsTableView reloadData];
        [self updateResultsLabel];
    });
}

// 检查数值过滤
- (BOOL)checkValueFilter:(PointerChainResult *)result {
    if (!self.filterValue) {
        return NO;
    }

    // 计算最终地址
    uintptr_t finalAddress = [self calculateFinalAddressForResult:result];
    if (finalAddress == 0) {
        return NO;
    }

    // 读取指针链最终地址的内存值
    NSString *addressString = [NSString stringWithFormat:@"0x%lX", (unsigned long)finalAddress];
    NSString *memoryValue = [[VMTool share] getValueFromAddress:addressString valueType:self.filterValueType];

    if (!memoryValue) {
        return NO;
    }

    // 比较值
    return [memoryValue isEqualToString:self.filterValue];
}

// 检查地址过滤
- (BOOL)checkAddressFilter:(PointerChainResult *)result {
    if (!self.filterAddress) {
        return NO;
    }

    // 计算最终地址
    uintptr_t finalAddress = [self calculateFinalAddressForResult:result];
    if (finalAddress == 0) {
        return NO;
    }

    // 转换过滤地址为统一格式
    NSString *filterAddr = [self normalizeAddress:self.filterAddress];
    NSString *resultAddr = [self normalizeAddress:[NSString stringWithFormat:@"0x%lX", (unsigned long)finalAddress]];

    // 支持部分匹配
    return [resultAddr containsString:filterAddr];
}

// 标准化地址格式
- (NSString *)normalizeAddress:(NSString *)address {
    if (!address) return @"";

    // 移除0x前缀并转为大写
    NSString *normalized = [address uppercaseString];
    if ([normalized hasPrefix:@"0X"]) {
        normalized = [normalized substringFromIndex:2];
    }

    return normalized;
}

// 更新结果标签
- (void)updateResultsLabel {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray *results = self.filteredResults ?: self.scanResults;

        if (results && results.count > 0) {
            NSString *statusMessage;
            if (self.filteredResults) {
                // 显示过滤后的结果
                statusMessage = [NSString stringWithFormat:@"过滤后显示 %lu 条指针链（共 %lu 条）",
                               (unsigned long)self.filteredResults.count,
                               (unsigned long)self.scanResults.count];
            } else {
                // 显示全部结果
                statusMessage = [NSString stringWithFormat:@"扫描完成，找到 %lu 条指针链",
                               (unsigned long)self.scanResults.count];
            }

            self.statusLabel.text = statusMessage;
            self.statusLabel.hidden = NO;
        }
    });
}

// 验证指针链是否有效
- (BOOL)validatePointerChain:(PointerChainResult *)chain {
    @try {
        if (!chain || !chain.isValid || !chain.moduleName || chain.moduleName.length == 0) {
            return NO;
        }

        // 验证模块是否存在
        PointerScanManager *scanner = [PointerScanManager sharedManager];
        NSError *error = nil;
        NSArray<ModuleInfo *> *modules = [scanner getModuleList:&error];

        if (!modules || error) {
            return NO;
        }

        BOOL moduleFound = NO;
        for (ModuleInfo *module in modules) {
            if ([module.name isEqualToString:chain.moduleName]) {
                moduleFound = YES;
                break;
            }
        }

        if (!moduleFound) {
            return NO;
        }

        // 验证偏移数组
        if (!chain.offsets || chain.offsets.count == 0) {
            return NO;
        }

        // 计算最终地址，验证是否可以读取
        uintptr_t finalAddress = [self calculateFinalAddressForResult:chain];
        if (finalAddress == 0) {
            return NO;
        }

        return YES;

    } @catch (NSException *exception) {
        return NO;
    }
}



#pragma mark - 指针链过滤逻辑

- (void)processPointerChainFile:(NSString *)fileContent {

    // 解析文件中的指针链
    NSArray<PointerChainResult *> *filePointerChains = [self parsePointerChainsFromFile:fileContent];

    if (filePointerChains.count == 0) {
        [self showAlert:@"解析失败" message:@"文件中没有找到有效的指针链"];
        return;
    }


    // 显示过滤选项
    [self showFilterOptionsWithPointerChains:filePointerChains];
}

- (NSArray<PointerChainResult *> *)parsePointerChainsFromFile:(NSString *)fileContent {
    NSMutableArray<PointerChainResult *> *results = [NSMutableArray array];


    // 按行分割内容
    NSArray<NSString *> *lines = [fileContent componentsSeparatedByString:@"\n"];

    for (NSInteger i = 0; i < lines.count; i++) {
        NSString *line = lines[i];
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        // 跳过空行
        if (trimmedLine.length == 0) {
            continue;
        }

        // 跳过标题行
        if ([trimmedLine hasPrefix:@"Obsolete修改器"] || [trimmedLine hasPrefix:@"共"]) {
            continue;
        }

        // 跳过数值信息行（以空格或括号开头）
        if ([trimmedLine hasPrefix:@"   ("] || [trimmedLine hasPrefix:@"("]) {
            continue;
        }

        // 解析序号行（如 "1. module+offset..."）
        if ([trimmedLine rangeOfString:@". "].location != NSNotFound) {
            NSRange dotRange = [trimmedLine rangeOfString:@". "];
            if (dotRange.location != NSNotFound && dotRange.location + dotRange.length < trimmedLine.length) {
                NSString *chainPart = [trimmedLine substringFromIndex:dotRange.location + dotRange.length];

                PointerChainResult *result = [self parsePointerChain:chainPart];
                if (result) {
                    [results addObject:result];
                } else {
                }
            }
        }
        // 直接解析指针链格式（没有序号的情况）
        else if ([trimmedLine containsString:@"+"]) {

            PointerChainResult *result = [self parsePointerChain:trimmedLine];
            if (result) {
                [results addObject:result];
            } else {
            }
        } else {
        }
    }

    return [results copy];
}

- (void)showFilterOptionsWithPointerChains:(NSArray<PointerChainResult *> *)filePointerChains {
    UIAlertController *filterAlert = [UIAlertController alertControllerWithTitle:@"指针链过滤"
                                                                         message:[NSString stringWithFormat:@"找到 %lu 条指针链，请选择过滤方式", (unsigned long)filePointerChains.count]
                                                                  preferredStyle:UIAlertControllerStyleAlert];

    // 添加数值类型选择
    UIAlertAction *i32Action = [UIAlertAction actionWithTitle:@"按 I32 数值过滤"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
        [self showValueInputForFilterWithPointerChains:filePointerChains valueType:VMMemValueTypeSignedInt];
    }];

    UIAlertAction *i64Action = [UIAlertAction actionWithTitle:@"按 I64 数值过滤"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
        [self showValueInputForFilterWithPointerChains:filePointerChains valueType:VMMemValueTypeSignedLong];
    }];

    UIAlertAction *f32Action = [UIAlertAction actionWithTitle:@"按 F32 数值过滤"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
        [self showValueInputForFilterWithPointerChains:filePointerChains valueType:VMMemValueTypeFloat];
    }];

    UIAlertAction *f64Action = [UIAlertAction actionWithTitle:@"按 F64 数值过滤"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
        [self showValueInputForFilterWithPointerChains:filePointerChains valueType:VMMemValueTypeDouble];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [filterAlert addAction:i32Action];
    [filterAlert addAction:i64Action];
    [filterAlert addAction:f32Action];
    [filterAlert addAction:f64Action];
    [filterAlert addAction:cancelAction];

    [self presentViewController:filterAlert animated:YES completion:nil];
}

- (void)showValueInputForFilterWithPointerChains:(NSArray<PointerChainResult *> *)filePointerChains valueType:(VMMemValueType)valueType {
    NSString *typeString = [self getValueTypeString:valueType];

    UIAlertController *valueAlert = [UIAlertController alertControllerWithTitle:@"输入期望数值"
                                                                        message:[NSString stringWithFormat:@"请输入期望的 %@ 数值，将过滤掉不匹配的指针链", typeString]
                                                                 preferredStyle:UIAlertControllerStyleAlert];

    [valueAlert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = [NSString stringWithFormat:@"输入 %@ 数值", typeString];
        textField.keyboardType = (valueType == VMMemValueTypeFloat || valueType == VMMemValueTypeDouble) ?
                                UIKeyboardTypeDecimalPad : UIKeyboardTypeNumberPad;
    }];

    UIAlertAction *filterAction = [UIAlertAction actionWithTitle:@"开始过滤"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
        UITextField *textField = valueAlert.textFields.firstObject;
        NSString *expectedValue = textField.text;

        if (expectedValue.length == 0) {
            [self showAlert:@"输入错误" message:@"请输入有效的数值"];
            return;
        }

        [self performFilterWithPointerChains:filePointerChains expectedValue:expectedValue valueType:valueType];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [valueAlert addAction:filterAction];
    [valueAlert addAction:cancelAction];

    [self presentViewController:valueAlert animated:YES completion:nil];
}

- (NSString *)getValueTypeString:(VMMemValueType)valueType {
    switch (valueType) {
        case VMMemValueTypeSignedInt: return @"I32";
        case VMMemValueTypeSignedLong: return @"I64";
        case VMMemValueTypeFloat: return @"F32";
        case VMMemValueTypeDouble: return @"F64";
        default: return @"Unknown";
    }
}

- (void)performFilterWithPointerChains:(NSArray<PointerChainResult *> *)filePointerChains
                         expectedValue:(NSString *)expectedValue
                             valueType:(VMMemValueType)valueType {


    // 显示进度提示
    UIAlertController *progressAlert = [UIAlertController alertControllerWithTitle:@"正在过滤指针链"
                                                                           message:@"正在初始化扫描器..."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:progressAlert animated:YES completion:nil];

    // 在后台线程执行过滤
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 确保扫描器已正确初始化
        BOOL scannerReady = [self ensureScannerInitialized];
        if (!scannerReady) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [progressAlert dismissViewControllerAnimated:YES completion:^{
                    [self showAlert:@"初始化失败" message:@"无法初始化扫描器，请确保已选择进程"];
                }];
            });
            return;
        }

        NSMutableArray<PointerChainResult *> *validChains = [NSMutableArray array];
        NSInteger totalChains = filePointerChains.count;
        NSInteger processedChains = 0;


        for (PointerChainResult *chain in filePointerChains) {
            processedChains++;

            // 计算指针链的最终地址
            uintptr_t finalAddress = [self calculateFinalAddressForResult:chain];

            if (finalAddress != 0) {
                // 读取该地址的数值
                NSString *actualValue = [self readValueAtAddress:finalAddress withType:valueType];

                // 比较数值
                if ([self compareValue:actualValue withExpected:expectedValue forType:valueType]) {
                    [validChains addObject:chain];
                }
            }

            // 每处理前几个指针链时输出详细信息
            if (processedChains <= 5) {
                // 详细信息已处理
            }

            // 更新进度（每处理10个更新一次）
            if (processedChains % 10 == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    progressAlert.message = [NSString stringWithFormat:@"已处理 %ld/%ld 条指针链",
                                           (long)processedChains, (long)totalChains];
                });
            }
        }

        // 回到主线程更新UI
        dispatch_async(dispatch_get_main_queue(), ^{
            [progressAlert dismissViewControllerAnimated:YES completion:^{
                [self showFilterResults:validChains originalCount:totalChains];
            }];
        });
    });
}

- (NSString *)readValueAtAddress:(uintptr_t)address withType:(VMMemValueType)valueType {
    if (address == 0) return @"0";

    @try {
        // 使用 PointerScanManager 读取内存，确保与指针链计算使用相同的连接
        PointerScanManager *scanner = [PointerScanManager sharedManager];
        NSError *error = nil;

        // 根据数据类型确定读取大小
        size_t readSize = 4; // 默认4字节
        switch (valueType) {
            case VMMemValueTypeSignedLong:
                readSize = 8;
                break;
            case VMMemValueTypeFloat:
                readSize = 4;
                break;
            case VMMemValueTypeDouble:
                readSize = 8;
                break;
            default:
                readSize = 4;
                break;
        }

        NSData *data = [scanner readMemory:address size:readSize error:&error];
        if (!data || error) {
            return @"读取失败";
        }

        if (data.length < readSize) {
            return @"数据不足";
        }

        const uint8_t *bytes = (const uint8_t *)data.bytes;

        // 根据类型解析数值
        switch (valueType) {
            case VMMemValueTypeSignedInt: {
                int32_t value = *(int32_t *)bytes;
                return [NSString stringWithFormat:@"%d", value];
            }
            case VMMemValueTypeSignedLong: {
                int64_t value = *(int64_t *)bytes;
                return [NSString stringWithFormat:@"%lld", value];
            }
            case VMMemValueTypeFloat: {
                float value = *(float *)bytes;
                return [NSString stringWithFormat:@"%.6f", value];
            }
            case VMMemValueTypeDouble: {
                double value = *(double *)bytes;
                return [NSString stringWithFormat:@"%.6f", value];
            }
            default:
                return @"未知类型";
        }

    } @catch (NSException *exception) {
        return @"读取异常";
    }
}

- (BOOL)compareValue:(NSString *)actualValue withExpected:(NSString *)expectedValue forType:(VMMemValueType)valueType {
    if (!actualValue || !expectedValue) return NO;

    // 去掉空格
    actualValue = [actualValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    expectedValue = [expectedValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    switch (valueType) {
        case VMMemValueTypeSignedInt:
        case VMMemValueTypeSignedLong: {
            // 整数比较
            long long actual = [actualValue longLongValue];
            long long expected = [expectedValue longLongValue];
            return actual == expected;
        }
        case VMMemValueTypeFloat:
        case VMMemValueTypeDouble: {
            // 浮点数比较（允许小的误差）
            double actual = [actualValue doubleValue];
            double expected = [expectedValue doubleValue];
            return fabs(actual - expected) < 0.0001;
        }
        default:
            return [actualValue isEqualToString:expectedValue];
    }
}

- (void)showFilterResults:(NSArray<PointerChainResult *> *)validChains originalCount:(NSInteger)originalCount {
    NSString *title = @"过滤完成";
    NSString *message = [NSString stringWithFormat:@"原始指针链: %ld 条\n有效指针链: %lu 条\n过滤掉: %ld 条",
                        (long)originalCount, (unsigned long)validChains.count, (long)(originalCount - validChains.count)];

    UIAlertController *resultAlert = [UIAlertController alertControllerWithTitle:title
                                                                         message:message
                                                                  preferredStyle:UIAlertControllerStyleAlert];

    if (validChains.count > 0) {
        // 根据是否有当前结果来决定按钮文字
        NSString *actionTitle = (self.scanResults && self.scanResults.count > 0) ? @"替换当前结果" : @"设为当前结果";

        UIAlertAction *setResultAction = [UIAlertAction actionWithTitle:actionTitle
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * _Nonnull action) {
            // 设置为当前的扫描结果
            if (!self.scanResults) {
                self.scanResults = [NSMutableArray array];
            }
            self.scanResults = [validChains mutableCopy];
            [self.resultsTableView reloadData];
            [self updateStatusDisplay];
            [self showToastMessage:[NSString stringWithFormat:@"已设置为 %lu 条有效指针链", (unsigned long)validChains.count]];
        }];
        [resultAlert addAction:setResultAction];
    }

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];

    [resultAlert addAction:okAction];
    [self presentViewController:resultAlert animated:YES completion:nil];
}

- (BOOL)ensureScannerInitialized {
    @try {

        // 检查是否已选择进程
        ProcessManager *processManager = [ProcessManager sharedManager];
        if (!processManager || !processManager.selectedProcessPID) {
            return NO;
        }

        // 获取扫描器实例
        PointerScanManager *scanner = [PointerScanManager sharedManager];

        // 尝试初始化扫描器
        NSError *error = nil;
        if (![scanner initializeWithError:&error]) {
            return NO;
        }

        // 附加到进程
        pid_t pid = [processManager selectedPid];
        if (![scanner attachToProcess:pid error:&error]) {
            return NO;
        }

        // 获取模块列表以验证连接
        NSArray<ModuleInfo *> *modules = [scanner getModuleList:&error];
        if (!modules || modules.count == 0) {
            return NO;
        }

        return YES;

    } @catch (NSException *exception) {
        return NO;
    }
}

#pragma mark - 进程状态检查

- (void)checkAndRefreshProcessState {
    @try {
        ProcessManager *processManager = [ProcessManager sharedManager];
        if (!processManager || !processManager.selectedProcessPID) {
            // 没有选择进程，清空状态
            self.statusLabel.text = @"请先选择进程";
            self.scanButton.enabled = NO;
            self.lastProcessPID = 0;
            return;
        }

        pid_t currentPID = [processManager selectedPid];

        // 检查进程是否发生变化
        if (self.lastProcessPID != currentPID) {
            NSLog(@"[DEBUG] 检测到进程变化: %d -> %d", self.lastProcessPID, currentPID);

            // 进程发生变化，需要重新初始化
            self.lastProcessPID = currentPID;

            // 清空旧的扫描结果
            self.scanResults = nil;
            self.filteredResults = nil;
            [self.resultsTableView reloadData];

            // 重新初始化扫描器和模块列表
            [self initializeScanner];

            NSLog(@"[DEBUG] 进程状态已刷新，模块数量: %lu", (unsigned long)self.modules.count);
        }

    } @catch (NSException *exception) {
        NSLog(@"[ERROR] 检查进程状态时发生异常: %@", exception.reason);
        self.statusLabel.text = @"检查进程状态失败";
        self.scanButton.enabled = NO;
    }
}

// 保存过滤后的指针链结果
- (void)saveFilteredResults {
    // 检查是否有过滤后的结果
    if (!self.filteredResults || self.filteredResults.count == 0) {
        [self showToastMessage:@"没有过滤后的结果可保存"];
        return;
    }
    
    // 在后台线程保存
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            NSMutableString *content = [NSMutableString string];
            
            // 添加顶部标识和时间（紧凑格式）
            [content appendFormat:@"Obsolete修改器 %@\n", [self getCurrentTimeString]];
            [content appendFormat:@"共%lu条过滤后的指针链\n", (unsigned long)self.filteredResults.count];
            
            // 添加每个指针链，使用优化的格式
            for (NSInteger i = 0; i < self.filteredResults.count; i++) {
                @try {
                    PointerChainResult *result = self.filteredResults[i];
                    
                    if (!result || !result.isValid) {
                        continue; // 跳过无效的结果
                    }
                    
                    // 使用标准格式的指针链
                    NSString *pointerChain = [self buildPointerChainStringForResult:result];
                    if (!pointerChain || pointerChain.length == 0) {
                        pointerChain = @"无效指针链";
                    }
                    
                    // 安全地计算最终地址并读取内存值
                    NSString *allValues = @"N/A";
                    @try {
                        uintptr_t finalAddress = [self calculateFinalAddressForResult:result];
                        if (finalAddress != 0) {
                            allValues = [self getAllValuesAtAddress:finalAddress];
                        }
                    } @catch (NSException *exception) {
                        allValues = @"读取失败";
                    }
                    
                    // 优化的格式：序号和指针链在一行，数值在下一行，然后空行分隔
                    [content appendFormat:@"%ld. %@\n", (long)(i + 1), pointerChain];
                    [content appendFormat:@"   (%@)\n", allValues ?: @"N/A"];
                    [content appendString:@"\n"]; // 添加空行分隔每个指针链
                    
                } @catch (NSException *exception) {
                    // 单个指针链处理失败，继续处理下一个
                    [content appendFormat:@"%ld. 处理失败\n\n", (long)(i + 1)];
                }
            }
            
            // 生成文件名（包含时间戳和指针数量）
            NSString *fileName = [NSString stringWithFormat:@"过滤结果_%@_%lu条.txt",
                                [self getCurrentTimestamp], (unsigned long)self.filteredResults.count];
            NSString *filePath = [self.scanDataDirectory stringByAppendingPathComponent:fileName];
            
            // 写入文件
            NSError *writeError;
            BOOL success = [content writeToFile:filePath
                                     atomically:YES
                                       encoding:NSUTF8StringEncoding
                                          error:&writeError];
            
            if (success) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showToastMessage:[NSString stringWithFormat:@"过滤结果已保存: %@", fileName]];
                });
            } else {
                NSLog(@"保存过滤结果失败: %@", writeError.localizedDescription);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showToastMessage:@"保存过滤结果失败"];
                });
            }
        } @catch (NSException *exception) {
            NSLog(@"保存过滤结果异常: %@", exception.reason);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToastMessage:@"保存过滤结果出现异常"];
            });
        }
    });
}

// 加载 .scandata 格式的扫描结果
- (void)loadScandataResults:(NSString *)filePath {
    // 检查文件是否存在
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:filePath]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.statusLabel.text = @"扫描结果文件不存在";
            [self stopScan];
        });
        return;
    }

    // 在后台线程读取和解析文件
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSString *content = [NSString stringWithContentsOfFile:filePath
                                                      encoding:NSUTF8StringEncoding
                                                         error:&error];

        if (error || !content) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.statusLabel.text = [NSString stringWithFormat:@"读取扫描结果失败: %@", error.localizedDescription ?: @"未知错误"];
                [self stopScan];
            });
            return;
        }

        // 解析指针链
        NSMutableArray<PointerChainResult *> *results = [NSMutableArray array];
        NSArray<NSString *> *lines = [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

        for (NSString *line in lines) {
            NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (trimmedLine.length == 0) {
                continue; // 跳过空行
            }

            // 解析 .scandata 格式的指针链
            PointerChainResult *result = [self parseScandataPointerChain:trimmedLine];
            if (result && result.isValid) {
                [results addObject:result];
            }
        }

        // 在主线程更新UI
        dispatch_async(dispatch_get_main_queue(), ^{
            self.scanResults = [results copy];

            // 重置过滤器
            self.filteredResults = nil;
            self.enableValueFilter = NO;
            self.enableAddressFilter = NO;

            [self.resultsTableView reloadData];
            [self updateResultsLabel];
            self.progressView.progress = 1.0;

            // 文件映射模式不需要额外保存txt文件，因为已经有.scandata文件了

            [self stopScan];

            // 显示成功消息
            NSString *message = [NSString stringWithFormat:@"扫描完成，找到 %lu 条指针链", (unsigned long)self.scanResults.count];
            self.statusLabel.text = message;
        });
    });
}

// 解析 .scandata 格式的指针链（格式：module_name+offset->offset->offset）
- (PointerChainResult *)parseScandataPointerChain:(NSString *)chainString {
    if (!chainString || chainString.length == 0) {
        return nil;
    }

    PointerChainResult *result = [[PointerChainResult alloc] init];
    result.originalChain = chainString;
    result.isValid = YES;

    // 解析格式：module_name+offset->offset->offset
    // 例如：UnityFramework+1A2B3C->10->20->30

    // 分割基址和偏移
    NSArray<NSString *> *parts = [chainString componentsSeparatedByString:@"->"];
    if (parts.count == 0) {
        result.isValid = NO;
        return result;
    }

    // 解析基址部分（module_name+offset）
    NSString *basePart = parts[0];
    NSRange plusRange = [basePart rangeOfString:@"+"];
    if (plusRange.location == NSNotFound) {
        result.isValid = NO;
        return result;
    }

    NSString *moduleName = [basePart substringToIndex:plusRange.location];
    NSString *baseOffsetStr = [basePart substringFromIndex:plusRange.location + 1];

    // 转换基址偏移（十六进制）
    unsigned long long baseOffset = strtoull([baseOffsetStr UTF8String], NULL, 16);

    // 解析后续偏移
    NSMutableArray<NSNumber *> *offsets = [NSMutableArray array];
    for (NSInteger i = 1; i < parts.count; i++) {
        NSString *offsetStr = [parts[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (offsetStr.length > 0) {
            // 处理负偏移（以-开头）
            BOOL isNegative = [offsetStr hasPrefix:@"-"];
            if (isNegative) {
                offsetStr = [offsetStr substringFromIndex:1]; // 去掉负号
            }

            unsigned long long offsetValue = strtoull([offsetStr UTF8String], NULL, 16);
            if (isNegative) {
                offsetValue = -offsetValue;
            }
            [offsets addObject:@(offsetValue)];
        }
    }

    // 构建结果
    result.moduleName = moduleName;
    result.baseAddress = baseOffset;  // 使用正确的属性名
    result.offsets = [offsets copy];

    // 生成显示用的指针链字符串（转换为传统格式：module+offset+offset+offset）
    NSMutableString *displayChain = [NSMutableString stringWithFormat:@"%@+0x%llX", moduleName, baseOffset];
    for (NSNumber *offset in offsets) {
        long long offsetValue = [offset longLongValue];
        if (offsetValue >= 0) {
            [displayChain appendFormat:@"+0x%llX", offsetValue];
        } else {
            [displayChain appendFormat:@"-0x%llX", -offsetValue];
        }
    }
    result.displayText = displayChain;  // 使用正确的属性名

    return result;
}

@end