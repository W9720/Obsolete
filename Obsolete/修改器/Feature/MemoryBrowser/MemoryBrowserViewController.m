#import "MemoryBrowserViewController.h"
#import "VMTool.h"
#import "MemModel.h"
#import <objc/runtime.h>
#import "ProcessManager.h"

@interface MemoryBrowserViewController () <UIScrollViewDelegate>

// 用于记录当前内存地址范围
@property (nonatomic, strong) NSString *firstAddress;
@property (nonatomic, strong) NSString *lastAddress;

// 用于记录是否正在加载数据
@property (nonatomic, assign) BOOL isLoadingMore;

// 用于记录加载方向 (YES: 向上加载更早地址, NO: 向下加载更高地址)
@property (nonatomic, assign) BOOL loadingDirection;

// 每次加载的数据量
@property (nonatomic, assign) NSInteger pageSize;

// 加载指示器
@property (nonatomic, strong) UIActivityIndicatorView *topLoadingIndicator;
@property (nonatomic, strong) UIActivityIndicatorView *bottomLoadingIndicator;

@end

@implementation MemoryBrowserViewController

- (instancetype)initWithAddress:(NSString *)address {
    self = [super init];
    if (self) {
        self.baseAddress = address ?: @""; // 不设置默认地址
        self.memoryData = [NSMutableArray array];
        self.currentValueType = VMMemValueTypeSignedInt; // 默认I32类型
        self.pageSize = 40; // 默认每页加载40条数据
        
        // 初始化选择模式相关属性
        self.isSelectionMode = NO;
        self.selectedAddresses = [NSMutableArray array];
        
        // 只有当提供了有效地址时才加载内存数据
        if (address.length > 0) {
            // 设置搜索的地址
            NSString *formattedAddress = address;
            if (![address hasPrefix:@"0x"] && ![address hasPrefix:@"0X"]) {
                formattedAddress = [NSString stringWithFormat:@"0x%@", address];
            }
            self.searchedAddress = formattedAddress;

            [self loadMemoryDataFromAddress:self.baseAddress withValueType:self.currentValueType];
        }
    }
    return self;
}

- (instancetype)initWithAddress:(NSString *)address valueType:(VMMemValueType)valueType {
    self = [super init];
    if (self) {
        self.baseAddress = address;
        self.memoryData = [NSMutableArray array];
        self.currentValueType = valueType;
        self.pageSize = 40; // 默认每页加载40条数据
        
        // 初始化选择模式相关属性
        self.isSelectionMode = NO;
        self.selectedAddresses = [NSMutableArray array];

        // 设置搜索的地址
        NSString *formattedAddress = address;
        if (![address hasPrefix:@"0x"] && ![address hasPrefix:@"0X"]) {
            formattedAddress = [NSString stringWithFormat:@"0x%@", address];
        }
        self.searchedAddress = formattedAddress;

        [self loadMemoryDataFromAddress:self.baseAddress withValueType:self.currentValueType];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 设置背景色适配深色/浅色模式
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
    }
    
    // 设置导航栏
    [self setupNavigationBar];
    
    // 设置地址输入框
    [self setupAddressField];
    
    // 设置数据类型选择器
    [self setupDataTypeSegment];
    
    // 设置表格视图
    [self setupTableView];
    
    // 设置加载指示器
    [self setupLoadingIndicators];
    
    // 添加长按手势
    [self setupLongPressGesture];
    
    // 确保表格内容不被底部标签栏遮挡
    [self adjustTableViewContentInsets];
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
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, tabBarHeight, 0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 确保导航栏可见
    self.navigationController.navigationBar.hidden = NO;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // 如果返回到主标签页，则需要再次隐藏导航栏
    if ([self.navigationController.viewControllers indexOfObject:self] == NSNotFound) {
        self.navigationController.navigationBar.hidden = YES;
    }
}

#pragma mark - UI Setup

- (void)setupNavigationBar {
    // 设置导航栏标题
    self.navigationItem.title = @"内存浏览";
    
    // 确保导航栏可见
    self.navigationController.navigationBar.hidden = NO;
    
    // 自定义返回按钮
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:@"返回"
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(backAction)];
    if (@available(iOS 13.0, *)) {
        backItem.tintColor = [UIColor systemBlueColor];
    } else {
        backItem.tintColor = [UIColor blueColor];
    }
    self.navigationItem.leftBarButtonItem = backItem;
    
    // 创建选择按钮
    if (@available(iOS 13.0, *)) {
        self.selectButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.circle"]
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(toggleSelectionMode)];
    } else {
        self.selectButton = [[UIBarButtonItem alloc] initWithTitle:@"选择"
                                                            style:UIBarButtonItemStylePlain
                                                           target:self
                                                           action:@selector(toggleSelectionMode)];
    }
    
    // 创建计算按钮
    if (@available(iOS 13.0, *)) {
        self.calculateButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"function"]
                                                               style:UIBarButtonItemStylePlain
                                                              target:self
                                                              action:@selector(calculateOffsetsBetweenSelectedAddresses)];
    } else {
        self.calculateButton = [[UIBarButtonItem alloc] initWithTitle:@"计算"
                                                              style:UIBarButtonItemStylePlain
                                                             target:self
                                                             action:@selector(calculateOffsetsBetweenSelectedAddresses)];
    }
    
    // 创建取消按钮
    if (@available(iOS 13.0, *)) {
        self.cancelButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"xmark.circle"]
                                                            style:UIBarButtonItemStylePlain
                                                           target:self
                                                           action:@selector(cancelSelectionMode)];
    } else {
        self.cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"取消"
                                                           style:UIBarButtonItemStylePlain
                                                          target:self
                                                          action:@selector(cancelSelectionMode)];
    }
    
    // 默认显示选择按钮
    self.navigationItem.rightBarButtonItem = self.selectButton;
    
    // 设置导航栏样式
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithDefaultBackground];
        
        // 适配深色/浅色模式
        appearance.backgroundColor = [UIColor systemBackgroundColor];
        appearance.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor labelColor]};
        
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
        self.navigationController.navigationBar.tintColor = [UIColor systemBlueColor];
    } else {
        self.navigationController.navigationBar.barTintColor = [UIColor whiteColor];
        self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor blackColor]};
        self.navigationController.navigationBar.tintColor = [UIColor blueColor];
    }
}

- (void)backAction {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)setupAddressField {
    // 创建地址输入框
    self.addressTextField = [[UITextField alloc] init];
    self.addressTextField.text = self.baseAddress;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        self.addressTextField.textColor = [UIColor labelColor];
        self.addressTextField.backgroundColor = [UIColor systemGray6Color];
    } else {
        self.addressTextField.textColor = [UIColor darkTextColor];
        self.addressTextField.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    }
    
    self.addressTextField.layer.cornerRadius = 10;
    self.addressTextField.textAlignment = NSTextAlignmentCenter;
    self.addressTextField.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.addressTextField.translatesAutoresizingMaskIntoConstraints = NO;
    self.addressTextField.returnKeyType = UIReturnKeySearch;
    self.addressTextField.delegate = self;
    self.addressTextField.leftViewMode = UITextFieldViewModeAlways;
    self.addressTextField.attributedPlaceholder = [[NSAttributedString alloc] 
                                                  initWithString:@"输入内存地址" 
                                                  attributes:@{NSForegroundColorAttributeName: 
                                                                 [UIColor colorWithWhite:0.6 alpha:1.0]}];
    
    // 设置内边距
    self.addressTextField.layer.sublayerTransform = CATransform3DMakeTranslation(5, 0, 0);
    
    // 添加可点击的搜索按钮
    UIButton *searchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    if (@available(iOS 13.0, *)) {
        [searchButton setImage:[UIImage systemImageNamed:@"magnifyingglass"] forState:UIControlStateNormal];
        searchButton.tintColor = [UIColor secondaryLabelColor];
    } else {
        [searchButton setImage:[UIImage imageNamed:@"search"] forState:UIControlStateNormal];
        searchButton.tintColor = [UIColor darkGrayColor];
    }
    searchButton.contentMode = UIViewContentModeCenter;
    searchButton.frame = CGRectMake(0, 0, 40, 30);
    [searchButton addTarget:self action:@selector(performAddressSearch) forControlEvents:UIControlEventTouchUpInside];
    self.addressTextField.leftView = searchButton;
    
    // 添加清除按钮
    UIButton *clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
    if (@available(iOS 13.0, *)) {
        [clearButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
        clearButton.tintColor = [UIColor secondaryLabelColor];
    } else {
        [clearButton setImage:[UIImage imageNamed:@"clear"] forState:UIControlStateNormal];
        clearButton.tintColor = [UIColor darkGrayColor];
    }
    clearButton.contentMode = UIViewContentModeCenter;
    clearButton.frame = CGRectMake(0, 0, 30, 30);
    [clearButton addTarget:self action:@selector(clearAddressField) forControlEvents:UIControlEventTouchUpInside];
    self.addressTextField.rightView = clearButton;
    self.addressTextField.rightViewMode = UITextFieldViewModeWhileEditing;
    
    // 添加阴影效果
    self.addressTextField.layer.shadowColor = [UIColor blackColor].CGColor;
    self.addressTextField.layer.shadowOffset = CGSizeMake(0, 1);
    self.addressTextField.layer.shadowRadius = 2;
    self.addressTextField.layer.shadowOpacity = 0.1;
    
    [self.view addSubview:self.addressTextField];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.addressTextField.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10],
        [self.addressTextField.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.addressTextField.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.addressTextField.heightAnchor constraintEqualToConstant:35]
    ]];
}

- (void)setupDataTypeSegment {
    // 创建数据类型选择器
    NSArray *items = [[VMTool share] allKeys];
    self.dataTypeSegment = [[UISegmentedControl alloc] initWithItems:items];
    
    // 根据当前值类型设置选中的段
    NSDictionary *keyValues = [[VMTool share] keyValues];
    NSInteger defaultSelectedIndex = 4; // 默认选择I32
    
    // 遍历keyValues查找当前类型对应的索引
    NSInteger index = 0;
    for (NSString *key in items) {
        if ([keyValues[key] integerValue] == self.currentValueType) {
            defaultSelectedIndex = index;
            break;
        }
        index++;
    }
    
    self.dataTypeSegment.selectedSegmentIndex = defaultSelectedIndex;
    
    // 设置颜色和样式
    if (@available(iOS 13.0, *)) {
        self.dataTypeSegment.backgroundColor = [UIColor systemGray5Color];
        [self.dataTypeSegment setTitleTextAttributes:@{
            NSForegroundColorAttributeName: [UIColor labelColor],
            NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightMedium]
        } forState:UIControlStateNormal];
        
        [self.dataTypeSegment setTitleTextAttributes:@{
            NSForegroundColorAttributeName: [UIColor systemBackgroundColor],
            NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold]
        } forState:UIControlStateSelected];
        
        self.dataTypeSegment.selectedSegmentTintColor = [UIColor systemBlueColor];
    } else {
        self.dataTypeSegment.tintColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
        [self.dataTypeSegment setTitleTextAttributes:@{
            NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightMedium]
        } forState:UIControlStateNormal];
    }
    
    // 添加圆角
    self.dataTypeSegment.layer.cornerRadius = 8;
    self.dataTypeSegment.layer.masksToBounds = YES;
    
    [self.dataTypeSegment addTarget:self action:@selector(dataTypeChanged:) forControlEvents:UIControlEventValueChanged];
    self.dataTypeSegment.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.dataTypeSegment];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.dataTypeSegment.topAnchor constraintEqualToAnchor:self.addressTextField.bottomAnchor constant:15],
        [self.dataTypeSegment.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.dataTypeSegment.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.dataTypeSegment.heightAnchor constraintEqualToConstant:36]
    ]];
}

- (void)setupTableView {
    // 创建表格视图
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        self.tableView.backgroundColor = [UIColor systemBackgroundColor];
        self.tableView.separatorColor = [UIColor separatorColor];
    } else {
        self.tableView.backgroundColor = [UIColor whiteColor];
        self.tableView.separatorColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    }
    
    // 设置表格样式
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 15, 0, 15);
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.rowHeight = 50;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 完全移除圆角效果
    self.tableView.layer.cornerRadius = 0;
    self.tableView.layer.masksToBounds = NO;
    self.tableView.clipsToBounds = YES;
    
    // 直接添加到视图中，不使用容器
    [self.view addSubview:self.tableView];
    
    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.dataTypeSegment.bottomAnchor constant:15],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
    
    // 注册单元格
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"MemoryCell"];
}

- (void)setupLoadingIndicators {
    // 顶部加载指示器
    if (@available(iOS 13.0, *)) {
        self.topLoadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    } else {
        self.topLoadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    }
    self.topLoadingIndicator.hidesWhenStopped = YES;
    self.topLoadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.topLoadingIndicator];
    
    // 底部加载指示器
    if (@available(iOS 13.0, *)) {
        self.bottomLoadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    } else {
        self.bottomLoadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    }
    self.bottomLoadingIndicator.hidesWhenStopped = YES;
    self.bottomLoadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.bottomLoadingIndicator];
    
    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        [self.topLoadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.topLoadingIndicator.topAnchor constraintEqualToAnchor:self.dataTypeSegment.bottomAnchor constant:20],
        
        [self.bottomLoadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.bottomLoadingIndicator.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20]
    ]];
}

// 添加长按手势识别器
- (void)setupLongPressGesture {
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.5; // 长按时间
    [self.tableView addGestureRecognizer:longPress];
}

// 处理长按事件
- (void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        CGPoint point = [gestureRecognizer locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:point];
        
        if (indexPath) {
            // 获取长按的内存项
            if (indexPath.row < self.memoryData.count) {
                id item = self.memoryData[indexPath.row];
                if ([item isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *memDict = (NSDictionary *)item;
                    [self showSaveRecordAlertForMemDict:memDict];
                }
            }
        }
    }
}

// 显示保存记录弹窗
- (void)showSaveRecordAlertForMemDict:(NSDictionary *)memDict {
    // 定义固定尺寸
    CGFloat containerWidth = 300;
    CGFloat containerHeight = 170;
    
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
        containerView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    } else {
        containerView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    }
    
    containerView.layer.cornerRadius = 15;
    containerView.layer.shadowColor = [UIColor blackColor].CGColor;
    containerView.layer.shadowOffset = CGSizeMake(0, 4);
    containerView.layer.shadowOpacity = 0.1;
    containerView.layer.shadowRadius = 10;
    containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 15, containerWidth - 40, 30)];
    titleLabel.text = @"保存记录";
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        titleLabel.textColor = [UIColor labelColor];
    } else {
        titleLabel.textColor = [UIColor darkTextColor];
    }
    
    // 信息标签
    UILabel *infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 45, containerWidth - 40, 20)];
    infoLabel.text = [NSString stringWithFormat:@"地址: %@", memDict[@"address"]];
    infoLabel.font = [UIFont systemFontOfSize:14];
    infoLabel.textAlignment = NSTextAlignmentCenter;
    
    // 名称输入框
    UITextField *nameTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 75, containerWidth - 40, 35)];
    nameTextField.placeholder = @"请输入记录名称";
    nameTextField.borderStyle = UITextBorderStyleRoundedRect;
    nameTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    
    // 保存按钮
    UIButton *saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    saveButton.frame = CGRectMake(containerWidth - 20 - (containerWidth - 60) / 3, 120, (containerWidth - 60) / 3, 35);
    [saveButton setTitle:@"保存" forState:UIControlStateNormal];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        saveButton.backgroundColor = [UIColor systemBlueColor];
    } else {
        saveButton.backgroundColor = [UIColor colorWithRed:0 green:0.5 blue:1.0 alpha:1.0];
    }
    
    saveButton.layer.cornerRadius = 8;
    [saveButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    // 复制按钮
    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    copyButton.frame = CGRectMake(20 + (containerWidth - 60) / 3 + 10, 120, (containerWidth - 60) / 3, 35);
    [copyButton setTitle:@"复制" forState:UIControlStateNormal];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        copyButton.backgroundColor = [UIColor systemOrangeColor];
    } else {
        copyButton.backgroundColor = [UIColor orangeColor];
    }
    
    copyButton.layer.cornerRadius = 8;
    [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    // 取消按钮
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.frame = CGRectMake(20, 120, (containerWidth - 60) / 3, 35);
    [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        cancelButton.backgroundColor = [UIColor systemGrayColor];
    } else {
        cancelButton.backgroundColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    }
    
    cancelButton.layer.cornerRadius = 8;
    [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    // 添加视图
    [containerView addSubview:titleLabel];
    [containerView addSubview:infoLabel];
    [containerView addSubview:nameTextField];
    [containerView addSubview:saveButton];
    [containerView addSubview:copyButton];
    [containerView addSubview:cancelButton];
    
    [backgroundView addSubview:containerView];
    [self.view addSubview:backgroundView];
    
    // 添加按钮事件
    [saveButton addTarget:self action:@selector(saveRecordButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [copyButton addTarget:self action:@selector(copyRecordButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [cancelButton addTarget:self action:@selector(cancelSaveRecordButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 保存引用
    objc_setAssociatedObject(self, "saveRecordBackgroundView", backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "saveRecordContainerView", containerView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "saveRecordNameTextField", nameTextField, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "saveRecordMemDict", memDict, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 动画显示
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 1;
        containerView.transform = CGAffineTransformIdentity;
    }];
}

// 保存记录按钮点击事件
- (void)saveRecordButtonTapped:(UIButton *)sender {
    UITextField *nameTextField = objc_getAssociatedObject(self, "saveRecordNameTextField");
    NSDictionary *memDict = objc_getAssociatedObject(self, "saveRecordMemDict");
    
    NSString *recordName = nameTextField.text;
    if (recordName.length == 0) {
        recordName = @"未命名记录";
    }
    
    // 创建记录数据
    NSMutableDictionary *recordData = [NSMutableDictionary dictionary];
    [recordData setObject:recordName forKey:@"recordName"];
    [recordData setObject:memDict[@"address"] forKey:@"address"];
    [recordData setObject:memDict[@"value"] forKey:@"value"];
    [recordData setObject:@(self.currentValueType) forKey:@"valueType"];
    [recordData setObject:[[ProcessManager sharedManager] selectedProcessName] ?: @"未知进程" forKey:@"processName"];
    [recordData setObject:[NSDate date] forKey:@"timestamp"];
    
    // 发送通知到记录界面
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AddRecordNotification" object:nil userInfo:recordData];
    
    // 关闭弹窗
    [self closeSaveRecordAlert];
    
    // 显示保存成功提示
    [self showSuccessToast:@"已保存到记录"];
}

// 复制记录按钮点击事件
- (void)copyRecordButtonTapped:(UIButton *)sender {
    NSDictionary *memDict = objc_getAssociatedObject(self, "saveRecordMemDict");
    
    // 只复制地址值
    NSString *copyContent = memDict[@"address"];
    
    // 复制到剪贴板
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    [pasteboard setString:copyContent];
    
    // 关闭弹窗
    [self closeSaveRecordAlert];
    
    // 显示复制成功提示
    [self showSuccessToast:@"已复制到剪贴板"];
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
        
        // 清除关联对象
        objc_setAssociatedObject(self, "saveRecordBackgroundView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "saveRecordContainerView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "saveRecordNameTextField", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "saveRecordMemDict", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }];
}

#pragma mark - Memory Operations

- (void)loadMemoryDataFromAddress:(NSString *)address withValueType:(VMMemValueType)valueType {
    // 基本安全检查
    if (!address || address.length == 0) {
        return;
    }

    // 清空当前数据
    [self.memoryData removeAllObjects];

    // 设置当前值类型
    self.currentValueType = valueType;

    // 确保地址格式正确（以0x开头）
    if (![address hasPrefix:@"0x"] && ![address hasPrefix:@"0X"]) {
        address = [NSString stringWithFormat:@"0x%@", address];
    }

    // 记录原始精确地址
    NSString *exactAddress = [address copy];

    // 更新地址输入框
    self.addressTextField.text = exactAddress;

    // 根据值类型确定搜索类型
    VMMemSearchType searchType;
    switch (valueType) {
        case VMMemValueTypeSignedByte:
        case VMMemValueTypeUnsignedByte:
            searchType = VMMemSearchType_1;
            break;
        case VMMemValueTypeSignedShort:
        case VMMemValueTypeUnsignedShort:
            searchType = VMMemSearchType_2;
            break;
        case VMMemValueTypeSignedInt:
        case VMMemValueTypeUnsignedInt:
        case VMMemValueTypeFloat:
            searchType = VMMemSearchType_4;
            break;
        case VMMemValueTypeSignedLong:
        case VMMemValueTypeUnsignedLong:
        case VMMemValueTypeDouble:
            searchType = VMMemSearchType_8;
            break;
        case VMMemValueTypeStr:
            searchType = VMMemSearchType_4; // 为字符串类型使用4字节对齐
            break;
        default:
            searchType = VMMemSearchType_4;
            break;
    }

    // 解析精确地址为数值
    uint64_t exactAddr = 0;
    NSScanner *scanner = [NSScanner scannerWithString:exactAddress];
    if ([exactAddress hasPrefix:@"0x"] || [exactAddress hasPrefix:@"0X"]) {
        [scanner scanHexLongLong:&exactAddr];
    } else {
        exactAddr = [exactAddress longLongValue];
    }

    // 使用原来的memory方法，但确保从精确地址开始
    NSString *sizeStr = [NSString stringWithFormat:@"%ld", (long)self.pageSize];
    NSLog(@"[DEBUG] 调用VMTool memory方法，地址: %@, 大小: %@, 类型: %d", exactAddress, sizeStr, (int)searchType);
    NSArray *memoryResults = [[VMTool share] memory:exactAddress size:sizeStr type:searchType valueType:valueType];
    NSLog(@"[DEBUG] VMTool返回结果数量: %lu", (unsigned long)memoryResults.count);

    if (memoryResults && memoryResults.count > 0) {
        // 添加内存数据到数组
        NSArray *processedData = [self processMemoryModels:memoryResults];
        NSLog(@"[DEBUG] 处理后的数据数量: %lu", (unsigned long)processedData.count);
        [self.memoryData addObjectsFromArray:processedData];
        NSLog(@"[DEBUG] memoryData总数量: %lu", (unsigned long)self.memoryData.count);

        // 记录当前显示的第一个和最后一个地址
        if (self.memoryData.count > 0) {
            self.firstAddress = [self.memoryData.firstObject[@"address"] copy];
            self.lastAddress = [self.memoryData.lastObject[@"address"] copy];
            NSLog(@"[DEBUG] 第一个地址: %@, 最后一个地址: %@", self.firstAddress, self.lastAddress);
        }
    } else {
        // 如果没有获取到任何数据，显示提示
        NSString *noDataMessage = [NSString stringWithFormat:@"无法从地址 %@ 读取内存数据", exactAddress];
        [self.memoryData addObject:noDataMessage];
        NSLog(@"[DEBUG] 没有获取到内存数据，添加提示信息");
    }

    // 重置加载状态
    self.isLoadingMore = NO;

    // 刷新表格视图
    NSLog(@"[DEBUG] 准备刷新表格视图，当前数据数量: %lu", (unsigned long)self.memoryData.count);
    [self.tableView reloadData];
    NSLog(@"[DEBUG] 表格视图刷新完成");

    // 自动滚动到搜索的地址（如果存在）
    [self scrollToSearchedAddress:exactAddress];
}

// 滚动到搜索的地址
- (void)scrollToSearchedAddress:(NSString *)searchAddress {
    if (!searchAddress || searchAddress.length == 0 || self.memoryData.count == 0) {
        return;
    }

    // 在主线程中执行滚动操作
    dispatch_async(dispatch_get_main_queue(), ^{
        // 查找包含搜索地址的行
        NSInteger targetRow = -1;
        for (NSInteger i = 0; i < self.memoryData.count; i++) {
            id item = self.memoryData[i];
            if ([item isKindOfClass:[NSDictionary class]]) {
                NSDictionary *memDict = (NSDictionary *)item;
                NSString *address = memDict[@"address"];

                // 比较地址（不区分大小写）
                if ([address caseInsensitiveCompare:searchAddress] == NSOrderedSame) {
                    targetRow = i;
                    break;
                }
            }
        }

        // 如果找到了目标行，滚动到该行
        if (targetRow >= 0) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:targetRow inSection:0];
            [self.tableView scrollToRowAtIndexPath:indexPath
                                  atScrollPosition:UITableViewScrollPositionMiddle
                                          animated:YES];
            NSLog(@"[DEBUG] 自动滚动到搜索地址 %@ 对应的行: %ld", searchAddress, (long)targetRow);
        } else {
            NSLog(@"[DEBUG] 未找到搜索地址 %@ 对应的行", searchAddress);
        }
    });
}



// 处理内存模型数据，转换为字典格式
- (NSArray *)processMemoryModels:(NSArray *)models {
    NSMutableArray *result = [NSMutableArray array];
    
    for (MemModel *model in models) {
        // 确保地址格式正确
        NSString *address = model.address;
        if (![address hasPrefix:@"0x"] && ![address hasPrefix:@"0X"]) {
            address = [NSString stringWithFormat:@"0x%@", address];
        }
        
        // 获取值和十六进制值
        NSString *value = model.value;
        NSString *hexValue = model.value_16;
        
        // 处理十六进制值，去掉前导的0
        NSString *trimmedHexValue = hexValue;
        if (hexValue && hexValue.length > 0) {
            // 找到第一个非0字符的位置
            NSUInteger firstNonZeroIndex = 0;
            for (NSUInteger i = 0; i < hexValue.length; i++) {
                unichar c = [hexValue characterAtIndex:i];
                if (c != '0') {
                    firstNonZeroIndex = i;
                    break;
                }
            }
            
            // 如果整个字符串都是0，则保留一个0
            if (firstNonZeroIndex == hexValue.length) {
                trimmedHexValue = @"0";
            } else {
                // 否则去掉前导的0
                trimmedHexValue = [hexValue substringFromIndex:firstNonZeroIndex];
            }
        }
        
        // 创建显示用的字典
        NSDictionary *memDict = @{
            @"address": address,
            @"value": value ?: @"",
            @"hexValue": [NSString stringWithFormat:@"0x%@", trimmedHexValue ?: @""],
            @"displayValue": value ?: @""
        };
        
        [result addObject:memDict];
    }
    
    return result;
}

#pragma mark - Actions

- (void)clearAddressField {
    self.addressTextField.text = @"";
}

- (void)dataTypeChanged:(UISegmentedControl *)sender {
    // 简单的防抖机制 - 防止过于频繁的切换
    static NSTimeInterval lastChangeTime = 0;
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];

    // 如果切换间隔小于0.2秒，则忽略
    if (currentTime - lastChangeTime < 0.2) {
        return;
    }
    lastChangeTime = currentTime;

    // 基本安全检查
    if (sender.selectedSegmentIndex < 0) {
        return;
    }

    NSArray *allKeys = [[VMTool share] allKeys];
    if (sender.selectedSegmentIndex >= allKeys.count) {
        return;
    }

    // 获取新的数据类型
    NSString *selectedKey = allKeys[sender.selectedSegmentIndex];
    NSDictionary *keyValues = [[VMTool share] keyValues];
    NSNumber *valueTypeNumber = keyValues[selectedKey];

    if (!valueTypeNumber) {
        return;
    }

    VMMemValueType newValueType = (VMMemValueType)[valueTypeNumber integerValue];

    // 如果类型没有变化，直接返回
    if (self.currentValueType == newValueType) {
        return;
    }

    // 更新当前类型
    self.currentValueType = newValueType;

    // 切换数据类型时需要重新加载内存数据，因为不同类型的地址偏移不同
    [self reloadMemoryDataWithNewType:newValueType];
}

// 切换数据类型时重新加载内存数据
- (void)reloadMemoryDataWithNewType:(VMMemValueType)newValueType {
    // 如果没有基础地址，直接返回
    if (!self.baseAddress || self.baseAddress.length == 0) {
        return;
    }

    // 清空现有数据
    [self.memoryData removeAllObjects];

    // 重新加载内存数据，使用新的数据类型
    [self loadMemoryDataFromAddress:self.baseAddress withValueType:newValueType];
}

// 重新格式化现有数据，避免重新读取内存
- (void)reformatExistingDataWithNewType:(VMMemValueType)newValueType {
    // 如果没有现有数据，则重新加载
    if (self.memoryData.count == 0) {
        [self loadMemoryDataFromAddress:self.baseAddress withValueType:newValueType];
        return;
    }

    // 创建一个新的数组来存储重新格式化的数据
    NSMutableArray *reformattedData = [NSMutableArray array];

    // 遍历现有数据，重新格式化每个地址的值
    for (NSDictionary *item in self.memoryData) {
        if (![item isKindOfClass:[NSDictionary class]]) {
            // 如果不是字典（可能是错误消息），直接添加
            [reformattedData addObject:item];
            continue;
        }

        NSString *address = item[@"address"];
        if (!address) {
            [reformattedData addObject:item];
            continue;
        }

        // 使用VMTool重新读取这个地址的值，按新类型格式化
        NSString *newValue = [[VMTool share] getValueFromAddress:address valueType:newValueType];

        // 创建新的字典，保持地址不变，更新值
        NSMutableDictionary *newItem = [item mutableCopy];
        newItem[@"value"] = newValue ?: @"0";
        newItem[@"displayValue"] = newValue ?: @"0";

        [reformattedData addObject:[newItem copy]];
    }

    // 更新数据数组
    [self.memoryData removeAllObjects];
    [self.memoryData addObjectsFromArray:reformattedData];

    // 刷新表格
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger count = self.memoryData.count;
    NSLog(@"[DEBUG] tableView numberOfRowsInSection 返回: %ld", (long)count);
    return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"MemoryCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        
        // 设置字体 - 默认字体大小，会根据内容长度动态调整
        cell.textLabel.font = [UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightMedium];
        cell.detailTextLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular];
        
        // 允许字体缩小以适应内容
        cell.textLabel.adjustsFontSizeToFitWidth = YES;
        cell.textLabel.minimumScaleFactor = 0.5; // 更小的缩放比例，确保F64能完全显示
        cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        
        // 设置选中样式
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        
        // 确保没有圆角
        cell.layer.cornerRadius = 0;
        cell.layer.masksToBounds = NO;
    }
    
    // 适配深色和浅色模式 - 每次配置单元格时都要设置
    if (@available(iOS 13.0, *)) {
        cell.backgroundColor = [UIColor systemBackgroundColor];
        cell.textLabel.textColor = [UIColor labelColor];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        cell.backgroundColor = [UIColor whiteColor];
        cell.textLabel.textColor = [UIColor blackColor];
        cell.detailTextLabel.textColor = [UIColor darkGrayColor];
    }
    
    // 设置单元格内容
    if (indexPath.row < self.memoryData.count) {
        id item = self.memoryData[indexPath.row];
        if ([item isKindOfClass:[NSString class]]) {
            cell.textLabel.text = (NSString *)item;
            cell.detailTextLabel.text = nil;
            cell.accessoryType = UITableViewCellAccessoryNone;
        } else if ([item isKindOfClass:[NSDictionary class]]) {
            NSDictionary *memDict = (NSDictionary *)item;
            NSString *address = memDict[@"address"];
            NSString *value = memDict[@"value"];
            NSString *hexValue = memDict[@"hexValue"];
            NSString *displayValue = memDict[@"displayValue"];
            
            // 确保地址有0x前缀
            if (![address hasPrefix:@"0x"] && ![address hasPrefix:@"0X"]) {
                address = [NSString stringWithFormat:@"0x%@", address];
            }
            
            // 根据当前类型自动调整字体大小和显示格式
            CGFloat fontSize = 16.0;
            NSString *cellText;
            
            // 为F64类型应用特殊处理
            if (self.currentValueType == VMMemValueTypeDouble) {
                // F64使用更小的字体
                fontSize = 11.0;
                
                // 使用完整地址，不缩短显示
                if (value.length > 0 && ![displayValue isEqualToString:@"无法读取"]) {
                    cellText = [NSString stringWithFormat:@"%@: %@ (%@)", address, hexValue, displayValue];
                } else {
                    cellText = [NSString stringWithFormat:@"%@: %@", address, @"无法读取"];
                }
            }
            // 为I64类型应用特殊处理
            else if (self.currentValueType == VMMemValueTypeSignedLong || 
                     self.currentValueType == VMMemValueTypeUnsignedLong) {
                fontSize = 12.0;
                
                if (value.length > 0 && ![displayValue isEqualToString:@"无法读取"]) {
                    cellText = [NSString stringWithFormat:@"%@: %@ (%@)", address, hexValue, displayValue];
                } else {
                    cellText = [NSString stringWithFormat:@"%@: %@", address, displayValue ?: @"无法读取"];
                }
            }
            // 为Str字符串类型应用特殊处理
            else if (self.currentValueType == VMMemValueTypeStr) {
                fontSize = 12.0;
                
                // 处理字符串显示
                if (value.length > 0) {
                    // 对于字符串，始终显示十六进制值和字符串值
                    cellText = [NSString stringWithFormat:@"%@: %@ (\"%@\")", address, hexValue, value];
                } else {
                    cellText = [NSString stringWithFormat:@"%@: %@", address, @"无法读取"];
                }
            }
            // 其他类型使用常规处理
            else {
                if (hexValue.length > 10 || displayValue.length > 10) {
                    fontSize = 14.0;
                }
                
                if (value.length > 0 && ![displayValue isEqualToString:@"无法读取"]) {
                    cellText = [NSString stringWithFormat:@"%@: %@ (%@)", address, hexValue, displayValue];
                } else {
                    cellText = [NSString stringWithFormat:@"%@: %@", address, displayValue ?: @"无法读取"];
                }
            }
            
            // 更新字体大小
            cell.textLabel.font = [UIFont monospacedDigitSystemFontOfSize:fontSize weight:UIFontWeightMedium];
            cell.textLabel.text = cellText;
            cell.detailTextLabel.text = nil;
            
            // 检查是否为搜索地址，高亮显示
            BOOL isSearchedAddress = [address caseInsensitiveCompare:self.addressTextField.text] == NSOrderedSame;
            
            // 在选择模式下，检查该地址是否已被选中
            BOOL isSelected = NO;
            if (self.isSelectionMode) {
                for (NSDictionary *selectedAddr in self.selectedAddresses) {
                    if ([selectedAddr[@"address"] isEqualToString:address]) {
                        isSelected = YES;
                        break;
                    }
                }
            }
            
            // 设置单元格样式
            if (isSearchedAddress) {
                // 搜索地址高亮显示
                if (@available(iOS 13.0, *)) {
                    cell.backgroundColor = [UIColor systemBlueColor];
                    cell.textLabel.textColor = [UIColor whiteColor];
                } else {
                    cell.backgroundColor = [UIColor blueColor];
                    cell.textLabel.textColor = [UIColor whiteColor];
                }
            } else if (isSelected) {
                // 选中地址高亮显示
                if (@available(iOS 13.0, *)) {
                    cell.backgroundColor = [UIColor systemGreenColor];
                    cell.textLabel.textColor = [UIColor whiteColor];
                } else {
                    cell.backgroundColor = [UIColor greenColor];
                    cell.textLabel.textColor = [UIColor whiteColor];
                }
            }
            
            // 设置附件视图
            if (self.isSelectionMode) {
                cell.accessoryType = isSelected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
            } else {
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
        }
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // 获取选中的内存项
    if (indexPath.row < self.memoryData.count) {
        id item = self.memoryData[indexPath.row];
        if ([item isKindOfClass:[NSDictionary class]]) {
            NSDictionary *memDict = (NSDictionary *)item;
            
            if (self.isSelectionMode) {
                // 选择模式下，切换地址的选中状态
                NSString *address = memDict[@"address"];
                BOOL isSelected = NO;
                
                // 检查地址是否已被选中
                NSInteger selectedIndex = -1;
                for (NSInteger i = 0; i < self.selectedAddresses.count; i++) {
                    NSDictionary *selectedAddr = self.selectedAddresses[i];
                    if ([selectedAddr[@"address"] isEqualToString:address]) {
                        isSelected = YES;
                        selectedIndex = i;
                        break;
                    }
                }
                
                if (isSelected) {
                    // 如果已选中，则取消选中
                    [self.selectedAddresses removeObjectAtIndex:selectedIndex];
                } else {
                    // 如果未选中，则添加到选中列表
                    [self.selectedAddresses addObject:memDict];
                }
                
                // 刷新单元格
                [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            } else {
                // 非选择模式下，显示修改内存值的弹窗
                NSString *address = memDict[@"address"];
                NSString *currentValue = memDict[@"value"];
                NSString *displayValue = memDict[@"displayValue"];
                
                // 显示修改内存值的弹窗
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"修改内存值"
                                                                            message:[NSString stringWithFormat:@"地址: %@\n当前值: %@", address, currentValue]
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                
                [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
                    textField.placeholder = @"输入新值";
                    textField.text = currentValue;
                    textField.clearButtonMode = UITextFieldViewModeWhileEditing;
                    textField.borderStyle = UITextBorderStyleRoundedRect;
                    textField.textAlignment = NSTextAlignmentCenter;
                    
                    // 根据值类型设置键盘类型
                    switch (self.currentValueType) {
                        case VMMemValueTypeFloat:
                        case VMMemValueTypeDouble:
                            textField.keyboardType = UIKeyboardTypeDecimalPad;
                            break;
                        case VMMemValueTypeStr:
                            textField.keyboardType = UIKeyboardTypeDefault;
                            break;
                        default:
                            textField.keyboardType = UIKeyboardTypeNumberPad;
                            break;
                    }
                }];
                
                // 添加取消按钮
                UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                                    style:UIAlertActionStyleCancel
                                                                    handler:nil];
                
                // 添加确定按钮
                UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确定"
                                                                    style:UIAlertActionStyleDefault
                                                                    handler:^(UIAlertAction * _Nonnull action) {
                    // 获取新值
                    NSString *newValue = alert.textFields.firstObject.text;
                    
                    // 直接使用VMTool修改内存值
                    [[VMTool share] modifyValue:newValue address:address type:self.currentValueType];
                    
                    // 重新加载内存数据以显示更新后的值
                    [self loadMemoryDataFromAddress:self.baseAddress withValueType:self.currentValueType];
                    
                    // 显示修改成功提示
                    [self showSuccessToast:[NSString stringWithFormat:@"已修改地址 %@ 的值", address]];
                }];
                
                [alert addAction:cancelAction];
                [alert addAction:confirmAction];
                
                [self presentViewController:alert animated:YES completion:nil];
            }
        }
    }
}

// 显示成功提示
- (void)showSuccessToast:(NSString *)message {
    UIView *toastView = [[UIView alloc] init];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        toastView.backgroundColor = [UIColor systemGreenColor];
    } else {
        toastView.backgroundColor = [UIColor colorWithRed:0.3 green:0.8 blue:0.4 alpha:1.0];
    }
    
    toastView.layer.cornerRadius = 20;
    toastView.alpha = 0;
    toastView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:toastView];
    
    // 添加成功图标
    UIImageView *checkmarkImageView = [[UIImageView alloc] init];
    if (@available(iOS 13.0, *)) {
        checkmarkImageView.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
    } else {
        // 对于iOS 13以下版本，可以使用自定义图像
        checkmarkImageView.backgroundColor = [UIColor whiteColor];
        checkmarkImageView.layer.cornerRadius = 10;
    }
    checkmarkImageView.tintColor = [UIColor whiteColor];
    checkmarkImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [toastView addSubview:checkmarkImageView];
    
    // 添加消息标签
    UILabel *messageLabel = [[UILabel alloc] init];
    messageLabel.text = message;
    messageLabel.textColor = [UIColor whiteColor];
    messageLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [toastView addSubview:messageLabel];
    
    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        [toastView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [toastView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-40],
        [toastView.heightAnchor constraintEqualToConstant:40],
        [toastView.widthAnchor constraintGreaterThanOrEqualToConstant:200],
        
        [checkmarkImageView.leadingAnchor constraintEqualToAnchor:toastView.leadingAnchor constant:15],
        [checkmarkImageView.centerYAnchor constraintEqualToAnchor:toastView.centerYAnchor],
        [checkmarkImageView.widthAnchor constraintEqualToConstant:20],
        [checkmarkImageView.heightAnchor constraintEqualToConstant:20],
        
        [messageLabel.leadingAnchor constraintEqualToAnchor:checkmarkImageView.trailingAnchor constant:10],
        [messageLabel.trailingAnchor constraintEqualToAnchor:toastView.trailingAnchor constant:-15],
        [messageLabel.centerYAnchor constraintEqualToAnchor:toastView.centerYAnchor]
    ]];
    
    // 显示动画
    [UIView animateWithDuration:0.3 animations:^{
        toastView.alpha = 1.0;
    } completion:^(BOOL finished) {
        // 2秒后隐藏
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.3 animations:^{
                toastView.alpha = 0.0;
            } completion:^(BOOL finished) {
                [toastView removeFromSuperview];
            }];
        });
    }];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0;
}

// 确保单元格没有圆角
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    // 强制移除所有圆角效果
    cell.layer.cornerRadius = 0;
    cell.layer.masksToBounds = NO;
    
    // 适配iOS 11以上的系统
    if (@available(iOS 11.0, *)) {
        cell.layer.maskedCorners = 0;
    }
    
    // 检查是否是搜索地址
    BOOL isHighlightedCell = NO;
    if (indexPath.row < self.memoryData.count) {
        id item = self.memoryData[indexPath.row];
        if ([item isKindOfClass:[NSDictionary class]]) {
            NSDictionary *memDict = (NSDictionary *)item;
            NSString *address = memDict[@"address"];
            
            // 高亮显示搜索地址
            if (self.searchedAddress && [address caseInsensitiveCompare:self.searchedAddress] == NSOrderedSame) {
                if (@available(iOS 13.0, *)) {
                    cell.backgroundColor = [UIColor systemBlueColor];
                    cell.textLabel.textColor = [UIColor whiteColor];
                } else {
                    cell.backgroundColor = [UIColor blueColor];
                    cell.textLabel.textColor = [UIColor whiteColor];
                }
                isHighlightedCell = YES;
            }
        }
    }
    
    // 如果不是高亮单元格，确保使用正确的颜色
    if (!isHighlightedCell) {
        if (@available(iOS 13.0, *)) {
            cell.backgroundColor = [UIColor systemBackgroundColor];
            cell.textLabel.textColor = [UIColor labelColor];
        } else {
            cell.backgroundColor = [UIColor whiteColor];
            cell.textLabel.textColor = [UIColor blackColor];
        }
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];

    // 处理地址搜索
    if (textField == self.addressTextField) {
        [self performAddressSearch];
    }

    return YES;
}

// 执行地址搜索
- (void)performAddressSearch {
    NSString *addressText = self.addressTextField.text;
    NSLog(@"[DEBUG] 执行地址搜索: %@", addressText);

    // 检查地址是否有效
    if (!addressText || addressText.length == 0) {
        NSLog(@"[DEBUG] 地址为空，清空数据");
        // 如果地址为空，清空数据
        [self.memoryData removeAllObjects];
        [self.tableView reloadData];
        return;
    }

    // 更新基础地址并加载内存数据 - 使用与搜索界面完全相同的逻辑
    self.baseAddress = addressText;

    // 确保地址格式正确（以0x开头）
    NSString *formattedAddress = addressText;
    if (![addressText hasPrefix:@"0x"] && ![addressText hasPrefix:@"0X"]) {
        formattedAddress = [NSString stringWithFormat:@"0x%@", addressText];
    }

    // 设置搜索的地址，用于高亮显示
    self.searchedAddress = formattedAddress;

    NSLog(@"[DEBUG] 开始加载内存数据，地址: %@, 类型: %ld", self.baseAddress, (long)self.currentValueType);
    [self loadMemoryDataFromAddress:self.baseAddress withValueType:self.currentValueType];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView != self.tableView || self.isLoadingMore) {
        return;
    }
    
    // 检测是否滚动到顶部或底部
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentHeight = scrollView.contentSize.height;
    CGFloat frameHeight = scrollView.frame.size.height;
    
    // 静态变量记录上次触发时间，防止频繁触发
    static NSTimeInterval lastTopLoadTime = 0;
    static NSTimeInterval lastBottomLoadTime = 0;
    NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
    
    // 当滚动到顶部附近时，加载更早的地址
    // 增加时间间隔和更严格的阈值，防止频繁触发
    if (offsetY < 5 && !self.isLoadingMore && (currentTime - lastTopLoadTime > 1.0)) {
        lastTopLoadTime = currentTime;
        [self loadMoreDataAbove];
    }
    
    // 当滚动到底部附近时，加载更高的地址
    // 增加时间间隔和更严格的阈值，防止频繁触发
    if (contentHeight > frameHeight && offsetY > contentHeight - frameHeight - 5 && !self.isLoadingMore && (currentTime - lastBottomLoadTime > 1.0)) {
        lastBottomLoadTime = currentTime;
        [self loadMoreDataBelow];
    }
}

// 向上加载更多数据（更早的地址）
- (void)loadMoreDataAbove {
    // 如果已经在加载中，则不再触发
    if (self.isLoadingMore || self.memoryData.count == 0 || ![self.firstAddress hasPrefix:@"0x"]) {
        return;
    }
    
    self.isLoadingMore = YES;
    self.loadingDirection = YES;
    
    // 显示顶部加载指示器
    [self.topLoadingIndicator startAnimating];
    
    // 获取当前第一个地址
    NSString *firstAddr = self.firstAddress;
    
    // 根据值类型确定搜索类型
    VMMemSearchType searchType;
    switch (self.currentValueType) {
        case VMMemValueTypeSignedByte:
        case VMMemValueTypeUnsignedByte:
            searchType = VMMemSearchType_1;
            break;
        case VMMemValueTypeSignedShort:
        case VMMemValueTypeUnsignedShort:
            searchType = VMMemSearchType_2;
            break;
        case VMMemValueTypeSignedInt:
        case VMMemValueTypeUnsignedInt:
        case VMMemValueTypeFloat:
            searchType = VMMemSearchType_4;
            break;
        case VMMemValueTypeSignedLong:
        case VMMemValueTypeUnsignedLong:
        case VMMemValueTypeDouble:
            searchType = VMMemSearchType_8;
            break;
        case VMMemValueTypeStr:
            searchType = VMMemSearchType_4; // 为字符串类型使用4字节对齐
            break;
        default:
            searchType = VMMemSearchType_4;
            break;
    }
    
    // 解析当前第一个地址为数值
    uint64_t currentAddr = 0;
    NSScanner *scanner = [NSScanner scannerWithString:firstAddr];
    if ([firstAddr hasPrefix:@"0x"] || [firstAddr hasPrefix:@"0X"]) {
        [scanner scanHexLongLong:&currentAddr];
    } else {
        currentAddr = [firstAddr longLongValue];
    }
    
    // 计算要加载的新地址 - 从当前第一个地址向前加载一些数据，确保连续
    uint64_t bytesPerItem = searchType;
    // 向前加载较少的数据项，比如10个，这样既保证连续性又有合理的加载量
    uint64_t itemsToLoad = 10;
    uint64_t totalBytesToLoad = bytesPerItem * itemsToLoad;
    uint64_t newAddr = currentAddr - totalBytesToLoad;
    
    // 如果发生溢出（新地址大于当前地址），则设为0
    if (newAddr > currentAddr) { // 处理溢出情况
        newAddr = 0;
    }

    // 确保新地址不会太小
    if (newAddr < totalBytesToLoad) {
        newAddr = 0;
    }
    
    // 从新地址开始获取数据
    NSString *newAddress = [NSString stringWithFormat:@"0x%llX", newAddr];
    NSString *sizeStr = [NSString stringWithFormat:@"%llu", itemsToLoad];
    
    // 在加载数据前记录当前的滚动位置
    CGFloat oldOffset = self.tableView.contentOffset.y;
    
    // 在后台线程加载数据
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *memoryResults = [[VMTool share] memory:newAddress size:sizeStr type:searchType valueType:self.currentValueType];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (memoryResults && memoryResults.count > 0) {
                // 处理内存模型数据
                NSArray *newItems = [self processMemoryModels:memoryResults];
                
                // 检查新数据中是否有与现有数据重复的地址
                NSMutableArray *uniqueItems = [NSMutableArray array];

                // 正序处理新数据，保持原有顺序
                for (NSDictionary *newItem in newItems) {
                    BOOL isDuplicate = NO;
                    NSString *newAddress = newItem[@"address"];

                    // 检查是否与现有数据重复
                    for (NSDictionary *existingItem in self.memoryData) {
                        if ([existingItem isKindOfClass:[NSDictionary class]]) {
                            NSString *existingAddress = existingItem[@"address"];
                            if ([newAddress caseInsensitiveCompare:existingAddress] == NSOrderedSame) {
                                isDuplicate = YES;
                                break;
                            }
                        }
                    }

                    // 如果不是重复项，则添加到唯一项列表
                    if (!isDuplicate) {
                        [uniqueItems addObject:newItem];
                    }
                }
                
                // 将唯一的新数据添加到现有数据前面
                if (uniqueItems.count > 0) {
                    // 关闭tableView动画更新
                    [UIView setAnimationsEnabled:NO];
                    
                    // 计算新数据的高度
                    CGFloat newRowsHeight = uniqueItems.count * self.tableView.rowHeight;
                    
                    // 先暂时保存原始数据
                    NSArray *originalData = [self.memoryData copy];
                    
                    // 清空现有数据并按正确顺序重新添加
                    [self.memoryData removeAllObjects];
                    [self.memoryData addObjectsFromArray:uniqueItems];
                    [self.memoryData addObjectsFromArray:originalData];
                    
                    // 更新第一个地址
                    if (self.memoryData.count > 0) {
                        self.firstAddress = [self.memoryData.firstObject[@"address"] copy];
                    }
                    
                    // 刷新表格视图
                    [self.tableView reloadData];
                    
                    // 调整滚动位置，使旧内容保持在相同位置
                    [self.tableView setContentOffset:CGPointMake(0, oldOffset + newRowsHeight) animated:NO];
                    
                    // 恢复动画
                    [UIView setAnimationsEnabled:YES];
                }
            }
            
            // 隐藏加载指示器
            [self.topLoadingIndicator stopAnimating];
            
            // 延迟重置加载状态，防止连续触发
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.isLoadingMore = NO;
            });
        });
    });
}

// 向下加载更多数据（更高的地址）
- (void)loadMoreDataBelow {
    // 如果已经在加载中，则不再触发
    if (self.isLoadingMore || self.memoryData.count == 0 || ![self.lastAddress hasPrefix:@"0x"]) {
        return;
    }
    
    self.isLoadingMore = YES;
    self.loadingDirection = NO;
    
    // 显示底部加载指示器
    [self.bottomLoadingIndicator startAnimating];
    
    // 获取当前最后一个地址
    NSString *lastAddr = self.lastAddress;
    
    // 根据值类型确定搜索类型
    VMMemSearchType searchType;
    switch (self.currentValueType) {
        case VMMemValueTypeSignedByte:
        case VMMemValueTypeUnsignedByte:
            searchType = VMMemSearchType_1;
            break;
        case VMMemValueTypeSignedShort:
        case VMMemValueTypeUnsignedShort:
            searchType = VMMemSearchType_2;
            break;
        case VMMemValueTypeSignedInt:
        case VMMemValueTypeUnsignedInt:
        case VMMemValueTypeFloat:
            searchType = VMMemSearchType_4;
            break;
        case VMMemValueTypeSignedLong:
        case VMMemValueTypeUnsignedLong:
        case VMMemValueTypeDouble:
            searchType = VMMemSearchType_8;
            break;
        case VMMemValueTypeStr:
            searchType = VMMemSearchType_4; // 为字符串类型使用4字节对齐
            break;
        default:
            searchType = VMMemSearchType_4;
            break;
    }
    
    // 解析当前最后一个地址为数值
    uint64_t currentAddr = 0;
    NSScanner *scanner = [NSScanner scannerWithString:lastAddr];
    if ([lastAddr hasPrefix:@"0x"] || [lastAddr hasPrefix:@"0X"]) {
        [scanner scanHexLongLong:&currentAddr];
    } else {
        currentAddr = [lastAddr longLongValue];
    }
    
    // 计算要加载的新地址（当前最后一个地址加上一个类型大小）
    uint64_t bytesPerItem = searchType;
    uint64_t newAddr = currentAddr + bytesPerItem;
    
    // 从新地址开始获取数据
    NSString *newAddress = [NSString stringWithFormat:@"0x%llX", newAddr];
    NSString *sizeStr = [NSString stringWithFormat:@"%ld", (long)self.pageSize];
    
    // 在后台线程加载数据
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *memoryResults = [[VMTool share] memory:newAddress size:sizeStr type:searchType valueType:self.currentValueType];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (memoryResults && memoryResults.count > 0) {
                // 处理内存模型数据
                NSArray *newItems = [self processMemoryModels:memoryResults];
                
                // 检查新数据中是否有与现有数据重复的地址
                NSMutableArray *uniqueItems = [NSMutableArray array];
                for (NSDictionary *newItem in newItems) {
                    BOOL isDuplicate = NO;
                    NSString *newAddress = newItem[@"address"];
                    
                    // 检查是否与现有数据重复
                    for (NSDictionary *existingItem in self.memoryData) {
                        if ([existingItem isKindOfClass:[NSDictionary class]]) {
                            NSString *existingAddress = existingItem[@"address"];
                            if ([newAddress caseInsensitiveCompare:existingAddress] == NSOrderedSame) {
                                isDuplicate = YES;
                                break;
                            }
                        }
                    }
                    
                    // 如果不是重复项，则添加到唯一项列表
                    if (!isDuplicate) {
                        [uniqueItems addObject:newItem];
                    }
                }
                
                // 将唯一的新数据添加到现有数据后面
                if (uniqueItems.count > 0) {
                    [self.memoryData addObjectsFromArray:uniqueItems];
                    
                    // 更新最后一个地址
                    self.lastAddress = [self.memoryData.lastObject[@"address"] copy];
                    
                    // 刷新表格视图
                    [self.tableView reloadData];
                }
            }
            
            // 隐藏加载指示器
            [self.bottomLoadingIndicator stopAnimating];
            
            // 延迟重置加载状态，防止连续触发
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.isLoadingMore = NO;
            });
        });
    });
}

#pragma mark - 选择模式相关方法

// 切换选择模式
- (void)toggleSelectionMode {
    self.isSelectionMode = YES;
    
    // 清空已选择的地址
    [self.selectedAddresses removeAllObjects];
    
    // 更新导航栏按钮
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                              target:nil
                                                                              action:nil];
    
    self.navigationItem.rightBarButtonItems = @[self.cancelButton, flexSpace, self.calculateButton];
    
    // 更新导航栏标题
    self.navigationItem.title = @"选择内存地址";
    
    // 刷新表格，更新单元格显示
    [self.tableView reloadData];
}

// 取消选择模式
- (void)cancelSelectionMode {
    self.isSelectionMode = NO;
    
    // 清空已选择的地址
    [self.selectedAddresses removeAllObjects];
    
    // 恢复导航栏按钮
    self.navigationItem.rightBarButtonItem = self.selectButton;
    
    // 恢复导航栏标题
    self.navigationItem.title = @"内存浏览";
    
    // 刷新表格，更新单元格显示
    [self.tableView reloadData];
}

// 计算选中地址之间的偏移
- (void)calculateOffsetsBetweenSelectedAddresses {
    // 检查是否有选中的地址
    if (self.selectedAddresses.count < 2) {
        // 显示提示，需要至少选择两个地址
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                       message:@"请至少选择两个地址进行偏移计算"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                           style:UIAlertActionStyleDefault
                                                         handler:nil];
        
        [alert addAction:okAction];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // 对选中的地址进行排序
    NSArray *sortedAddresses = [self.selectedAddresses sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *addr1, NSDictionary *addr2) {
        NSString *addrStr1 = addr1[@"address"];
        NSString *addrStr2 = addr2[@"address"];
        
        uint64_t addr1Value = 0;
        uint64_t addr2Value = 0;
        
        // 解析地址字符串为数值
        NSScanner *scanner1 = [NSScanner scannerWithString:addrStr1];
        NSScanner *scanner2 = [NSScanner scannerWithString:addrStr2];
        
        if ([addrStr1 hasPrefix:@"0x"] || [addrStr1 hasPrefix:@"0X"]) {
            [scanner1 scanHexLongLong:&addr1Value];
        } else {
            addr1Value = [addrStr1 longLongValue];
        }
        
        if ([addrStr2 hasPrefix:@"0x"] || [addrStr2 hasPrefix:@"0X"]) {
            [scanner2 scanHexLongLong:&addr2Value];
        } else {
            addr2Value = [addrStr2 longLongValue];
        }
        
        if (addr1Value < addr2Value) {
            return NSOrderedAscending;
        } else if (addr1Value > addr2Value) {
            return NSOrderedDescending;
        } else {
            return NSOrderedSame;
        }
    }];
    
    // 准备偏移计算结果
    NSMutableString *offsetResults = [NSMutableString string];
    
    // 计算相邻地址之间的偏移
    for (NSInteger i = 0; i < sortedAddresses.count - 1; i++) {
        NSDictionary *currentAddr = sortedAddresses[i];
        NSDictionary *nextAddr = sortedAddresses[i + 1];
        
        NSString *currentAddrStr = currentAddr[@"address"];
        NSString *nextAddrStr = nextAddr[@"address"];
        
        uint64_t currentAddrValue = 0;
        uint64_t nextAddrValue = 0;
        
        // 解析地址字符串为数值
        NSScanner *scanner1 = [NSScanner scannerWithString:currentAddrStr];
        NSScanner *scanner2 = [NSScanner scannerWithString:nextAddrStr];
        
        if ([currentAddrStr hasPrefix:@"0x"] || [currentAddrStr hasPrefix:@"0X"]) {
            [scanner1 scanHexLongLong:&currentAddrValue];
        } else {
            currentAddrValue = [currentAddrStr longLongValue];
        }
        
        if ([nextAddrStr hasPrefix:@"0x"] || [nextAddrStr hasPrefix:@"0X"]) {
            [scanner2 scanHexLongLong:&nextAddrValue];
        } else {
            nextAddrValue = [nextAddrStr longLongValue];
        }
        
        // 计算偏移
        int64_t offset = nextAddrValue - currentAddrValue;
        
        // 添加到结果字符串
        [offsetResults appendFormat:@"%@ → %@: 偏移 0x%llX (%lld 字节)\n", 
                      currentAddrStr, nextAddrStr, offset, offset];
    }
    
    // 如果选择了多于两个地址，计算第一个和最后一个地址之间的总偏移
    if (sortedAddresses.count > 2) {
        NSDictionary *firstAddr = sortedAddresses.firstObject;
        NSDictionary *lastAddr = sortedAddresses.lastObject;
        
        NSString *firstAddrStr = firstAddr[@"address"];
        NSString *lastAddrStr = lastAddr[@"address"];
        
        uint64_t firstAddrValue = 0;
        uint64_t lastAddrValue = 0;
        
        // 解析地址字符串为数值
        NSScanner *scanner1 = [NSScanner scannerWithString:firstAddrStr];
        NSScanner *scanner2 = [NSScanner scannerWithString:lastAddrStr];
        
        if ([firstAddrStr hasPrefix:@"0x"] || [firstAddrStr hasPrefix:@"0X"]) {
            [scanner1 scanHexLongLong:&firstAddrValue];
        } else {
            firstAddrValue = [firstAddrStr longLongValue];
        }
        
        if ([lastAddrStr hasPrefix:@"0x"] || [lastAddrStr hasPrefix:@"0X"]) {
            [scanner2 scanHexLongLong:&lastAddrValue];
        } else {
            lastAddrValue = [lastAddrStr longLongValue];
        }
        
        // 计算总偏移
        int64_t totalOffset = lastAddrValue - firstAddrValue;
        
        // 添加到结果字符串
        [offsetResults appendFormat:@"\n总偏移 (%@ → %@): 0x%llX (%lld 字节)", 
                      firstAddrStr, lastAddrStr, totalOffset, totalOffset];
    }
    
    // 显示偏移计算结果
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"地址偏移计算结果"
                                                                   message:offsetResults
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    // 添加复制按钮
    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"复制结果"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
        // 复制结果到剪贴板
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = offsetResults;
        
        // 显示复制成功提示
        [self showToast:@"已复制偏移计算结果到剪贴板"];
    }];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {
        // 退出选择模式
        [self cancelSelectionMode];
    }];
    
    [alert addAction:copyAction];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

// 显示提示信息
- (void)showToast:(NSString *)message {
    UIAlertController *toast = [UIAlertController alertControllerWithTitle:nil
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [self presentViewController:toast animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [toast dismissViewControllerAnimated:YES completion:nil];
        });
    }];
}

// 修改内存值
- (void)modifyMemoryValue:(NSString *)newValue atAddress:(NSString *)address withValueType:(VMMemValueType)valueType {
    // 直接使用VMTool修改内存值
    [[VMTool share] modifyValue:newValue address:address type:valueType];
    
    // 重新加载内存数据以显示更新后的值
    [self loadMemoryDataFromAddress:self.baseAddress withValueType:self.currentValueType];
    
    // 显示修改成功提示
    [self showSuccessToast:[NSString stringWithFormat:@"已修改地址 %@ 的值", address]];
}

@end 
