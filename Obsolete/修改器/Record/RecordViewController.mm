#import "RecordViewController.h"
#import "VMTool.h"
#import "MemModel.h"
#import "ProcessManager.h"
#import "VMTypeHeader.h"
#import "PointerScanManager.h"
#import "MemoryBrowserViewController.h"
#import <objc/runtime.h>

@interface RecordViewController () <UITableViewDelegate, UITableViewDataSource, UIPickerViewDelegate, UIPickerViewDataSource>
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITableView *recordTableView;
@property (nonatomic, strong) NSMutableArray *recordItems;
@property (nonatomic, strong) UIButton *addButton;
@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong) UIButton *adjustButton;
@property (nonatomic, strong) UIButton *pointerManagerButton;
@property (nonatomic, strong) NSMutableArray *storedPointers; // 存储的指针列表
@end

@implementation RecordViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // 初始化记录数组
    self.recordItems = [NSMutableArray array];
    
    // 创建标题标签
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"记录";
    self.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = [UIColor labelColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.titleLabel];
    
    // 创建添加按钮
    self.addButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.addButton setTitle:@"添加" forState:UIControlStateNormal];
    self.addButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.addButton.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.addButton.layer.cornerRadius = 10;
    self.addButton.clipsToBounds = YES;
    self.addButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.addButton addTarget:self action:@selector(addButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.addButton];
    
    // 创建清空按钮
    self.clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.clearButton setTitle:@"清空" forState:UIControlStateNormal];
    self.clearButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.clearButton.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.clearButton.layer.cornerRadius = 10;
    self.clearButton.clipsToBounds = YES;
    self.clearButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.clearButton addTarget:self action:@selector(clearButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.clearButton];
    
    // 创建调整按钮
    self.adjustButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.adjustButton setTitle:@"计算" forState:UIControlStateNormal];
    self.adjustButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.adjustButton.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.adjustButton.layer.cornerRadius = 10;
    self.adjustButton.clipsToBounds = YES;
    self.adjustButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.adjustButton addTarget:self action:@selector(adjustButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.adjustButton];

    // 创建管理按钮
    self.pointerManagerButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self updatePointerManagerButtonTitle]; // 初始化标题
    self.pointerManagerButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.pointerManagerButton.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.pointerManagerButton.layer.cornerRadius = 10;
    self.pointerManagerButton.clipsToBounds = YES;
    self.pointerManagerButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.pointerManagerButton addTarget:self action:@selector(pointerManagerButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.pointerManagerButton];
    
    // 设置标题和按钮约束
    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.titleLabel.heightAnchor constraintEqualToConstant:30],

        // 四个按钮等宽平均分布
        [self.addButton.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:10],
        [self.addButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10],
        [self.addButton.heightAnchor constraintEqualToConstant:36],

        [self.adjustButton.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:10],
        [self.adjustButton.leadingAnchor constraintEqualToAnchor:self.addButton.trailingAnchor constant:5],
        [self.adjustButton.widthAnchor constraintEqualToAnchor:self.addButton.widthAnchor],
        [self.adjustButton.heightAnchor constraintEqualToConstant:36],

        [self.pointerManagerButton.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:10],
        [self.pointerManagerButton.leadingAnchor constraintEqualToAnchor:self.adjustButton.trailingAnchor constant:5],
        [self.pointerManagerButton.widthAnchor constraintEqualToAnchor:self.addButton.widthAnchor],
        [self.pointerManagerButton.heightAnchor constraintEqualToConstant:36],

        [self.clearButton.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:10],
        [self.clearButton.leadingAnchor constraintEqualToAnchor:self.pointerManagerButton.trailingAnchor constant:5],
        [self.clearButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-10],
        [self.clearButton.widthAnchor constraintEqualToAnchor:self.addButton.widthAnchor],
        [self.clearButton.heightAnchor constraintEqualToConstant:36]
    ]];
    
    // 创建表格视图，使用分组样式
    self.recordTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.recordTableView.delegate = self;
    self.recordTableView.dataSource = self;
    self.recordTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.recordTableView.rowHeight = 50.0;
    
    // 禁用默认分割线
    self.recordTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.recordTableView.separatorColor = [UIColor clearColor];
    
    [self.view addSubview:self.recordTableView];
    
    // 设置表格视图约束
    [NSLayoutConstraint activateConstraints:@[
        [self.recordTableView.topAnchor constraintEqualToAnchor:self.addButton.bottomAnchor constant:10],
        [self.recordTableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.recordTableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.recordTableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-10]
    ]];
    
    // 配置表格样式
    if (@available(iOS 13.0, *)) {
        self.recordTableView.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        self.recordTableView.backgroundColor = [UIColor whiteColor];
    }
    
    // 添加一个空状态提示标签
        UILabel *emptyLabel = [[UILabel alloc] init];
        emptyLabel.text = @"暂无记录";
        emptyLabel.textAlignment = NSTextAlignmentCenter;
        emptyLabel.textColor = [UIColor secondaryLabelColor];
        emptyLabel.font = [UIFont systemFontOfSize:16];
        self.recordTableView.backgroundView = emptyLabel;
    
    // 注册接收添加记录的通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAddRecordNotification:)
                                                 name:@"AddRecordNotification"
                                               object:nil];
    
    // 确保表格内容不被底部标签栏遮挡
    [self adjustTableViewContentInsets];
    
    // 加载保存的记录
    [self loadRecords];

    // 加载存储的指针
    [self loadStoredPointers];

    // 更新管理按钮标题
    [self updatePointerManagerButtonTitle];
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
    self.recordTableView.contentInset = UIEdgeInsetsMake(0, 0, tabBarHeight, 0);
    self.recordTableView.scrollIndicatorInsets = self.recordTableView.contentInset;
}

- (void)dealloc {
    // 移除通知观察者
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// 处理添加记录通知
- (void)handleAddRecordNotification:(NSNotification *)notification {
    NSDictionary *recordData = notification.userInfo;
    if (recordData) {
        // 创建可变副本，添加isActive字段
        NSMutableDictionary *mutableRecord = [recordData mutableCopy];
        [mutableRecord setObject:@NO forKey:@"isActive"]; // 默认为关闭状态
        
        // 将记录数据添加到记录数组
        [self.recordItems addObject:mutableRecord];
        
        // 更新表格视图
        dispatch_async(dispatch_get_main_queue(), ^{
            // 如果这是第一条记录，移除空状态提示
            if (self.recordItems.count == 1) {
        self.recordTableView.backgroundView = nil;
            }
            
            // 刷新表格
            [self.recordTableView reloadData];
            
            // 保存记录
            [self saveRecords];
        });
    }
}

#pragma mark - 按钮事件处理

- (void)addButtonTapped:(UIButton *)sender {
    // 创建操作表单
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"添加记录"
                                                                        message:nil
                                                                 preferredStyle:UIAlertControllerStyleActionSheet];
    
    // 添加地址选项
    UIAlertAction *addAddressAction = [UIAlertAction actionWithTitle:@"添加地址"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * _Nonnull action) {
        [self showAddAddressAlert];
    }];
    
    // 添加指针选项
    UIAlertAction *addPointerAction = [UIAlertAction actionWithTitle:@"添加指针"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
        [self showAddPointerAlert];
    }];
    
    // 取消选项
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil];
    
    // 添加操作到表单
    [actionSheet addAction:addAddressAction];
    [actionSheet addAction:addPointerAction];
    [actionSheet addAction:cancelAction];
    
    // 在iPad上设置弹出位置
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        actionSheet.popoverPresentationController.sourceView = sender;
        actionSheet.popoverPresentationController.sourceRect = sender.bounds;
    }
    
    // 显示操作表单
    [self presentViewController:actionSheet animated:YES completion:nil];
}

- (void)clearButtonTapped:(UIButton *)sender {
    // 清空按钮点击事件
    if (self.recordItems.count == 0) {
        return;
    }
    
    // 显示确认对话框
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认清空"
                                                                   message:@"确定要清空所有记录吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确定"
                                                            style:UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction * _Nonnull action) {
        // 清空记录数组
        [self.recordItems removeAllObjects];
        
        // 刷新表格
        [self.recordTableView reloadData];
        
        // 显示空状态
        UILabel *emptyLabel = [[UILabel alloc] init];
        emptyLabel.text = @"暂无记录";
        emptyLabel.textAlignment = NSTextAlignmentCenter;
        emptyLabel.textColor = [UIColor secondaryLabelColor];
        emptyLabel.font = [UIFont systemFontOfSize:16];
        self.recordTableView.backgroundView = emptyLabel;
        
        // 保存更改
        [self saveRecords];
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:confirmAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)adjustButtonTapped:(UIButton *)sender {
    // 创建操作表单
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"工具"
                                                                        message:nil
                                                                 preferredStyle:UIAlertControllerStyleActionSheet];
    
    // 添加调整地址选项
    UIAlertAction *adjustAddressAction = [UIAlertAction actionWithTitle:@"调整地址"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * _Nonnull action) {
        // 直接调用方法
        [self showAdjustAddressAlertDirect];
    }];
    
    // 添加计算转换选项
    UIAlertAction *calculationAction = [UIAlertAction actionWithTitle:@"进制转换"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
        // 实现计算转换功能
        [self showCalculationConverterAlert];
    }];
    
    // 添加加减计算选项
    UIAlertAction *addSubAction = [UIAlertAction actionWithTitle:@"加减计算"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
        // 直接显示加减计算界面
        [self showAddSubtractionCalculator];
    }];
    
    // 取消选项
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil];
    
    // 添加操作到表单
    [actionSheet addAction:adjustAddressAction];
    [actionSheet addAction:calculationAction];
    [actionSheet addAction:addSubAction];
    [actionSheet addAction:cancelAction];
    
    // 在iPad上设置弹出位置
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        actionSheet.popoverPresentationController.sourceView = sender;
        actionSheet.popoverPresentationController.sourceRect = sender.bounds;
    }
    
    // 显示操作表单
    [self presentViewController:actionSheet animated:YES completion:nil];
}

// 直接显示调整地址弹窗
- (void)showAdjustAddressAlertDirect {
    // 如果没有记录，则显示提示
    if (self.recordItems.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                       message:@"当前没有可调整的地址记录"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                           style:UIAlertActionStyleDefault
                                                         handler:nil];
        [alert addAction:okAction];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // 定义固定尺寸
    CGFloat containerWidth = 300;
    CGFloat containerHeight = 180; // 减小高度，因为移除了记录列表
    
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
    titleLabel.text = @"调整地址";
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        titleLabel.textColor = [UIColor labelColor];
    } else {
        titleLabel.textColor = [UIColor darkTextColor];
    }
    
    // 说明标签
    UILabel *descriptionLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 35, containerWidth - 40, 40)];
    descriptionLabel.text = @"格式: 记录序号,偏移量\n例如: 2,+4 或 1,-8";
    descriptionLabel.font = [UIFont systemFontOfSize:14];
    descriptionLabel.textAlignment = NSTextAlignmentCenter;
    descriptionLabel.numberOfLines = 2;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        descriptionLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        descriptionLabel.textColor = [UIColor darkGrayColor];
    }
    
    // 输入框 - 位置上移
    UITextField *adjustTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 80, containerWidth - 40, 35)];
    adjustTextField.placeholder = @"例如: 2,+4";
    adjustTextField.borderStyle = UITextBorderStyleRoundedRect;
    adjustTextField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    adjustTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        adjustTextField.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        adjustTextField.textColor = [UIColor labelColor];
        adjustTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                               initWithString:@"例如: 2,+4"
                                               attributes:@{NSForegroundColorAttributeName: [UIColor secondaryLabelColor]}];
    } else {
        adjustTextField.backgroundColor = [UIColor colorWithWhite:0.98 alpha:1];
        adjustTextField.textColor = [UIColor darkTextColor];
    }
    
    // 确认按钮 - 位置上移
    UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
    confirmButton.frame = CGRectMake(containerWidth / 2 + 10, 125, (containerWidth - 60) / 2, 35);
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
    
    // 取消按钮 - 位置上移
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.frame = CGRectMake(20, 125, (containerWidth - 60) / 2, 35);
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
    
    // 结果标签
    UILabel *resultLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 170, containerWidth - 40, 0)]; // 高度设为0，不显示
    resultLabel.text = @"";
    resultLabel.font = [UIFont systemFontOfSize:14];
    resultLabel.textAlignment = NSTextAlignmentCenter;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        resultLabel.textColor = [UIColor systemGreenColor];
    } else {
        resultLabel.textColor = [UIColor greenColor];
    }
    
    // 添加视图
    [containerView addSubview:titleLabel];
    [containerView addSubview:descriptionLabel];
    [containerView addSubview:adjustTextField];
    [containerView addSubview:confirmButton];
    [containerView addSubview:cancelButton];
    [containerView addSubview:resultLabel];
    
    [backgroundView addSubview:containerView];
    [self.view addSubview:backgroundView];
    
    // 存储引用以便在按钮回调中访问
    objc_setAssociatedObject(self, "adjustBackgroundView", backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "adjustContainerView", containerView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "adjustTextField", adjustTextField, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "adjustResultLabel", resultLabel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 确认按钮点击事件
    [confirmButton addTarget:self action:@selector(confirmAdjustButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 取消按钮点击事件
    [cancelButton addTarget:self action:@selector(cancelAdjustButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 动画显示
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 1;
        containerView.transform = CGAffineTransformIdentity;
    }];
}

// 确认调整地址按钮点击事件
- (void)confirmAdjustButtonTapped:(UIButton *)sender {
    UITextField *adjustTextField = objc_getAssociatedObject(self, "adjustTextField");
    UILabel *resultLabel = objc_getAssociatedObject(self, "adjustResultLabel");
    
    NSString *inputText = adjustTextField.text;
    
    // 解析输入文本
    NSArray *components = [inputText componentsSeparatedByString:@","];
    if (components.count != 2) {
        resultLabel.text = @"格式错误，请使用: 序号,偏移量";
        return;
    }
    
    // 获取记录索引
    NSInteger recordIndex = [components[0] integerValue] - 1; // 用户输入1开始，转换为0开始
    
    // 检查索引是否有效
    if (recordIndex < 0 || recordIndex >= self.recordItems.count) {
        resultLabel.text = @"记录序号无效";
        return;
    }
    
    // 获取偏移量
    NSString *offsetStr = [components[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    // 检查偏移格式
    if (![offsetStr hasPrefix:@"+"] && ![offsetStr hasPrefix:@"-"]) {
        resultLabel.text = @"偏移量格式错误，需要+或-前缀";
        return;
    }
    
    // 获取原始地址
    NSMutableDictionary *record = [self.recordItems[recordIndex] mutableCopy];
    NSString *originalAddress = record[@"address"];
    
    // 解析原始地址为数值
    uint64_t addressValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:originalAddress];
    if ([originalAddress hasPrefix:@"0x"] || [originalAddress hasPrefix:@"0X"]) {
        [scanner scanHexLongLong:&addressValue];
    } else {
        addressValue = [originalAddress longLongValue];
    }
    
    // 计算偏移量
    int64_t offset = 0;
    if ([offsetStr hasPrefix:@"+"]) {
        offset = [[offsetStr substringFromIndex:1] longLongValue];
    } else if ([offsetStr hasPrefix:@"-"]) {
        offset = -[[offsetStr substringFromIndex:1] longLongValue];
    }
    
    // 应用偏移
    uint64_t newAddressValue = addressValue + offset;
    
    // 格式化新地址
    NSString *newAddress = [NSString stringWithFormat:@"0x%llX", newAddressValue];
    
    // 更新记录
    [record setObject:newAddress forKey:@"address"];
    
    // 获取当前值类型
    VMMemValueType valueType = (VMMemValueType)[record[@"valueType"] intValue];
    
    // 使用新方法获取最新的内存值
    NSString *currentValue = [[VMTool share] getValueFromAddress:newAddress valueType:valueType];
    
    // 更新记录中的值
    [record setObject:currentValue forKey:@"value"];
    
    // 更新记录名称
    NSString *recordName = record[@"recordName"];
    NSArray *nameParts = [recordName componentsSeparatedByString:@" - "];
    if (nameParts.count > 1) {
        recordName = [NSString stringWithFormat:@"%@ - %@", newAddress, nameParts[1]];
    } else {
        recordName = [NSString stringWithFormat:@"%@ - 调整后", newAddress];
    }
    [record setObject:recordName forKey:@"recordName"];
    
    // 更新记录数组
    self.recordItems[recordIndex] = record;
    
    // 刷新表格
    [self.recordTableView reloadData];
    
    // 保存记录
    [self saveRecords];
    
    // 显示成功消息
    resultLabel.text = [NSString stringWithFormat:@"地址已调整为: %@", newAddress];
    
    // 延迟关闭弹窗
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self cancelAdjustButtonTapped:nil];
    });
}

// 取消调整地址按钮点击事件
- (void)cancelAdjustButtonTapped:(UIButton *)sender {
    [self closeAdjustAlert];
}

// 关闭调整地址弹窗
- (void)closeAdjustAlert {
    UIView *backgroundView = objc_getAssociatedObject(self, "adjustBackgroundView");
    UIView *containerView = objc_getAssociatedObject(self, "adjustContainerView");
    
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 0;
        containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    } completion:^(BOOL finished) {
        [backgroundView removeFromSuperview];
        
        // 清除关联对象，防止内存泄漏
        objc_setAssociatedObject(self, "adjustBackgroundView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "adjustContainerView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "adjustTextField", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "adjustResultLabel", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }];
}

// 显示计算转换弹窗
- (void)showCalculationConverterAlert {
    // 定义固定尺寸
    CGFloat containerWidth = 300;
    CGFloat containerHeight = 300; // 初始高度
    
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
    titleLabel.text = @"进制转换";
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        titleLabel.textColor = [UIColor labelColor];
    } else {
        titleLabel.textColor = [UIColor darkTextColor];
    }
    
    // 创建进制转换类型选择器
    UISegmentedControl *conversionTypeSegment = [[UISegmentedControl alloc] initWithItems:@[@"十进制→十六进制", @"十六进制→十进制"]];
    conversionTypeSegment.frame = CGRectMake(20, 45, containerWidth - 40, 35);
    conversionTypeSegment.selectedSegmentIndex = 0;
    
    // 输入框标签
    UILabel *inputLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 90, containerWidth - 40, 20)];
    inputLabel.text = @"输入值:";
    inputLabel.font = [UIFont systemFontOfSize:14];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        inputLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        inputLabel.textColor = [UIColor darkGrayColor];
    }
    
    // 输入框
    UITextField *inputTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 115, containerWidth - 40, 35)];
    inputTextField.placeholder = @"输入要转换的数值";
    inputTextField.borderStyle = UITextBorderStyleRoundedRect;
    inputTextField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    inputTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        inputTextField.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        inputTextField.textColor = [UIColor labelColor];
    } else {
        inputTextField.backgroundColor = [UIColor colorWithWhite:0.98 alpha:1];
        inputTextField.textColor = [UIColor darkTextColor];
    }
    
    // 结果标签
    UILabel *resultTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 160, containerWidth - 40, 20)];
    resultTitleLabel.text = @"转换结果:";
    resultTitleLabel.font = [UIFont systemFontOfSize:14];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        resultTitleLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        resultTitleLabel.textColor = [UIColor darkGrayColor];
    }
    
    // 结果显示框
    UITextField *resultTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 185, containerWidth - 40, 35)];
    resultTextField.borderStyle = UITextBorderStyleRoundedRect;
    resultTextField.enabled = NO;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        resultTextField.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        resultTextField.textColor = [UIColor systemGreenColor];
    } else {
        resultTextField.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
        resultTextField.textColor = [UIColor greenColor];
    }
    
    // 确认按钮
    UIButton *convertButton = [UIButton buttonWithType:UIButtonTypeSystem];
    convertButton.frame = CGRectMake(containerWidth / 2 + 10, 240, (containerWidth - 60) / 2, 35);
    [convertButton setTitle:@"转换" forState:UIControlStateNormal];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        convertButton.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.2 green:0.22 blue:0.25 alpha:1.0];
            } else {
                return [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0];
            }
        }];
        [convertButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        convertButton.backgroundColor = [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0];
        [convertButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    
    convertButton.layer.cornerRadius = 8;
    
    // 取消按钮
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.frame = CGRectMake(20, 240, (containerWidth - 60) / 2, 35);
    [cancelButton setTitle:@"关闭" forState:UIControlStateNormal];
    
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
    [containerView addSubview:conversionTypeSegment];
    [containerView addSubview:inputLabel];
    [containerView addSubview:inputTextField];
    [containerView addSubview:resultTitleLabel];
    [containerView addSubview:resultTextField];
    [containerView addSubview:convertButton];
    [containerView addSubview:cancelButton];
    
    [backgroundView addSubview:containerView];
    [self.view addSubview:backgroundView];
    
    // 存储引用以便在按钮回调中访问
    objc_setAssociatedObject(self, "calculationBackgroundView", backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "calculationContainerView", containerView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "conversionTypeSegment", conversionTypeSegment, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "inputTextField", inputTextField, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "resultTextField", resultTextField, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 转换按钮点击事件
    [convertButton addTarget:self action:@selector(convertButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 取消按钮点击事件
    [cancelButton addTarget:self action:@selector(closeCalculationAlert:) forControlEvents:UIControlEventTouchUpInside];
    
    // 动画显示
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 1;
        containerView.transform = CGAffineTransformIdentity;
    }];
}

// 转换按钮点击事件
- (void)convertButtonTapped:(UIButton *)sender {
    UISegmentedControl *conversionTypeSegment = objc_getAssociatedObject(self, "conversionTypeSegment");
    UITextField *inputTextField = objc_getAssociatedObject(self, "inputTextField");
    UITextField *resultTextField = objc_getAssociatedObject(self, "resultTextField");
    
    NSString *inputText = inputTextField.text;
    
    // 检查输入是否为空
    if (inputText.length == 0) {
        resultTextField.text = @"请输入有效数值";
        return;
    }
    
    // 进制转换
    if (conversionTypeSegment.selectedSegmentIndex == 0) {
        // 十进制 → 十六进制
        NSInteger decimalValue = [inputText integerValue];
        resultTextField.text = [NSString stringWithFormat:@"0x%lX", (long)decimalValue];
    } else {
        // 十六进制 → 十进制
        // 移除可能的0x前缀
        NSString *hexText = inputText;
        if ([hexText hasPrefix:@"0x"] || [hexText hasPrefix:@"0X"]) {
            hexText = [hexText substringFromIndex:2];
        }
        
        // 尝试转换
        unsigned long long hexValue = 0;
        NSScanner *scanner = [NSScanner scannerWithString:hexText];
        BOOL success = [scanner scanHexLongLong:&hexValue];
        
        if (success) {
            resultTextField.text = [NSString stringWithFormat:@"%llu", hexValue];
        } else {
            resultTextField.text = @"无效的十六进制值";
        }
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (tableView == self.recordTableView) {
        // 记录表格视图
        return self.recordItems.count > 0 ? 1 : 0;
    } else {
        // 管理表格视图
        return 1;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.recordTableView) {
        return self.recordItems.count;
    } else {
        // 管理表格视图
        return self.storedPointers.count;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.recordTableView) {
        return [self recordTableViewCellForRowAtIndexPath:indexPath];
    } else {
        return [self pointerManagerTableViewCellForRowAtIndexPath:indexPath];
    }
}

// 记录表格视图的cell
- (UITableViewCell *)recordTableViewCellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"RecordCell";

    UITableViewCell *cell = [self.recordTableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];

        // 添加开关代替应用按钮
        UISwitch *toggleSwitch = [[UISwitch alloc] init];
        [toggleSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggleSwitch;
    }
    
    // 从数据源获取记录
    if (self.recordItems.count > indexPath.row) {
        NSDictionary *record = self.recordItems[indexPath.row];
        
        // 设置单元格内容
        NSString *recordName = record[@"recordName"];
        NSString *address = record[@"address"];
        NSString *value = record[@"value"];
        VMMemValueType valueType = (VMMemValueType)[record[@"valueType"] intValue];
        
        // 确保值是最新的，如果需要可以重新从内存读取
        if (value == nil || [value isEqualToString:@""]) {
            // 使用新方法直接获取内存值
            value = [[VMTool share] getValueFromAddress:address valueType:valueType];
            
            // 更新记录中的值
            NSMutableDictionary *updatedRecord = [record mutableCopy];
            [updatedRecord setObject:value forKey:@"value"];
            self.recordItems[indexPath.row] = updatedRecord;
        }
        
        // 检查是否为指针类型
        BOOL isPointer = [record[@"isPointer"] boolValue];
        NSString *pointerChain = record[@"pointerChain"];

        if (isPointer && pointerChain) {
            cell.textLabel.text = [NSString stringWithFormat:@"🔗 %@", recordName];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"指针: %@ → %@ | 值: %@", pointerChain, address, value];
        } else {
            cell.textLabel.text = [NSString stringWithFormat:@"%@", recordName];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"地址: %@ | 值: %@", address, value];
        }
        
        // 设置开关标签
        ((UISwitch *)cell.accessoryView).tag = indexPath.row;
        
        // 根据记录状态设置开关状态
        BOOL isActive = [record[@"isActive"] boolValue];
        ((UISwitch *)cell.accessoryView).on = isActive;
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

// 管理表格视图的cell
- (UITableViewCell *)pointerManagerTableViewCellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"PointerCell";

    UITableView *pointerTableView = objc_getAssociatedObject(self, "pointerManagerTableView");
    UITableViewCell *cell = [pointerTableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }

    // 从存储的指针数据获取信息
    if (self.storedPointers.count > indexPath.row) {
        NSDictionary *pointerData = self.storedPointers[indexPath.row];

        NSString *recordName = pointerData[@"recordName"];
        NSString *pointerChain = pointerData[@"pointerChain"];
        NSDate *dateStored = pointerData[@"dateStored"];
        NSString *valueType = pointerData[@"valueType"];
        NSString *lastValue = pointerData[@"value"];

        // 格式化存储日期
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"MM-dd HH:mm";
        NSString *dateString = [formatter stringFromDate:dateStored];

        // 获取数据类型名称
        NSArray *allKeys = [[VMTool share] allKeys];
        NSString *typeName = @"未知";
        if (valueType) {
            VMMemValueType type = (VMMemValueType)[valueType intValue];
            NSDictionary *keyValues = [[VMTool share] keyValues];
            for (NSString *key in allKeys) {
                if ([keyValues[key] intValue] == type) {
                    typeName = key;
                    break;
                }
            }
        }

        // 设置主标题 - 指针名称和类型
        cell.textLabel.text = [NSString stringWithFormat:@"🔗 %@ (%@)", recordName, typeName];
        cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];

        // 设置副标题 - 指针链和存储时间
        cell.detailTextLabel.text = [NSString stringWithFormat:@"指针链: %@\n存储时间: %@ | 最后值: %@",
                                    pointerChain, dateString, lastValue ?: @"N/A"];
        cell.detailTextLabel.numberOfLines = 2;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        if (@available(iOS 13.0, *)) {
            cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        } else {
            cell.detailTextLabel.textColor = [UIColor grayColor];
        }

        // 添加取出按钮
        UIButton *restoreButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [restoreButton setTitle:@"取出" forState:UIControlStateNormal];
        restoreButton.frame = CGRectMake(0, 0, 50, 30);
        restoreButton.backgroundColor = [UIColor systemBlueColor];
        [restoreButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        restoreButton.layer.cornerRadius = 6;
        restoreButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        restoreButton.tag = indexPath.row;
        [restoreButton addTarget:self action:@selector(restorePointerButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        cell.accessoryView = restoreButton;
    }

    // 适配深色和浅色模式的颜色
    if (@available(iOS 13.0, *)) {
        cell.textLabel.textColor = [UIColor labelColor];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        cell.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
    } else {
        cell.textLabel.textColor = [UIColor blackColor];
        cell.detailTextLabel.textColor = [UIColor darkGrayColor];
        cell.backgroundColor = [UIColor whiteColor];
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    // 获取当前分区的总行数
    NSInteger numberOfRows = [self tableView:tableView numberOfRowsInSection:indexPath.section];
    
    // 设置默认圆角为0（中间的cell不应该有圆角）
    cell.layer.cornerRadius = 0;
    cell.layer.masksToBounds = YES;
    
    // 清除之前可能设置的maskedCorners
    if (@available(iOS 11.0, *)) {
        cell.layer.maskedCorners = 0;
    }
    
    // 只为第一个和最后一个cell设置圆角
    if (numberOfRows == 1) {
        // 如果只有一行，则全部圆角
        cell.layer.cornerRadius = 8;
        if (@available(iOS 11.0, *)) {
            cell.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | 
                                      kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
        }
    } else if (indexPath.row == 0) {
        // 第一行只添加顶部圆角
        cell.layer.cornerRadius = 8;
        if (@available(iOS 11.0, *)) {
            cell.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
        }
    } else if (indexPath.row == numberOfRows - 1) {
        // 最后一行只添加底部圆角
        cell.layer.cornerRadius = 8;
        if (@available(iOS 11.0, *)) {
            cell.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
        }
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    // 获取选中的记录
    if (indexPath.row < self.recordItems.count) {
        NSMutableDictionary *record = [self.recordItems[indexPath.row] mutableCopy];

        // 显示操作选择菜单
        [self showActionMenuForRecord:record atIndexPath:indexPath];
    }
}

// 显示操作选择菜单
- (void)showActionMenuForRecord:(NSMutableDictionary *)record atIndexPath:(NSIndexPath *)indexPath {
    UIAlertController *actionMenu = [UIAlertController alertControllerWithTitle:@"选择操作"
                                                                        message:nil
                                                                 preferredStyle:UIAlertControllerStyleActionSheet];

    // 修改值选项
    UIAlertAction *modifyAction = [UIAlertAction actionWithTitle:@"修改值"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self showModifyValueAlertForRecord:record atIndexPath:indexPath];
    }];

    // 跳转到内存浏览器选项
    UIAlertAction *browseAction = [UIAlertAction actionWithTitle:@"内存浏览"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self jumpToMemoryBrowserWithRecord:record];
    }];

    // 取消选项
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [actionMenu addAction:modifyAction];
    [actionMenu addAction:browseAction];
    [actionMenu addAction:cancelAction];

    // 对于iPad，需要设置popover的源
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        UITableViewCell *cell = [self.recordTableView cellForRowAtIndexPath:indexPath];
        actionMenu.popoverPresentationController.sourceView = cell;
        actionMenu.popoverPresentationController.sourceRect = cell.bounds;
    }

    [self presentViewController:actionMenu animated:YES completion:nil];
}

// 跳转到内存浏览器
- (void)jumpToMemoryBrowserWithRecord:(NSMutableDictionary *)record {
    NSString *address = record[@"address"];
    VMMemValueType valueType = (VMMemValueType)[record[@"valueType"] intValue];

    // 如果是指针类型，需要重新计算地址
    BOOL isPointer = [record[@"isPointer"] boolValue];
    if (isPointer) {
        NSString *pointerChain = record[@"pointerChain"];
        if (pointerChain) {
            // 重新计算指针链地址
            address = [self calculatePointerChainAddress:pointerChain];
        }
    }

    if (address && ![address isEqualToString:@"0x0"]) {
        // 确保VMTool使用正确的进程上下文
        NSString *pidString = [ProcessManager sharedManager].selectedProcessPID;
        NSString *processName = [ProcessManager sharedManager].selectedProcessName;
        if (pidString && processName) {
            [[VMTool share] setPid:[pidString intValue] name:processName];
        }

        // 创建内存浏览器视图控制器
        MemoryBrowserViewController *memoryBrowser = [[MemoryBrowserViewController alloc] initWithAddress:address valueType:valueType];

        // 推送到导航栈
        [self.navigationController pushViewController:memoryBrowser animated:YES];
    } else {
        // 地址无效，显示提示
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误"
                                                                       message:@"无效的内存地址"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                           style:UIAlertActionStyleDefault
                                                         handler:nil];
        [alert addAction:okAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

// 显示修改值的弹窗
- (void)showModifyValueAlertForRecord:(NSMutableDictionary *)record atIndexPath:(NSIndexPath *)indexPath {
    // 确保VMTool使用正确的进程上下文
    NSString *pidString = [ProcessManager sharedManager].selectedProcessPID;
    NSString *processName = [ProcessManager sharedManager].selectedProcessName;
    if (pidString && processName) {
        [[VMTool share] setPid:[pidString intValue] name:processName];
    }

    NSString *address = record[@"address"];
    NSString *currentValue = record[@"value"];
    NSNumber *valueTypeNumber = record[@"valueType"];
    VMMemValueType currentType = (VMMemValueType)[valueTypeNumber intValue];

    // 重新读取当前内存值，而不是使用记录中可能过时的值
    NSString *realTimeValue = nil;
    BOOL isPointer = [record[@"isPointer"] boolValue];
    if (isPointer) {
        // 如果是指针，重新计算指针链地址并读取值
        NSString *pointerChain = record[@"pointerChain"];
        if (pointerChain) {
            NSString *realTimeAddress = [self calculatePointerChainAddress:pointerChain];
            if (realTimeAddress) {
                // 根据当前类型读取实时值
                NSArray *allKeys = [[VMTool share] allKeys];
                NSString *currentTypeKey = nil;
                NSDictionary *keyValues = [[VMTool share] keyValues];
                for (NSString *key in allKeys) {
                    if ([keyValues[key] integerValue] == currentType) {
                        currentTypeKey = key;
                        break;
                    }
                }
                if (currentTypeKey) {
                    realTimeValue = [self readMemoryValueAtAddress:realTimeAddress withType:currentTypeKey];
                }
            }
        }
    } else {
        // 如果是普通地址，直接读取
        NSArray *allKeys = [[VMTool share] allKeys];
        NSString *currentTypeKey = nil;
        NSDictionary *keyValues = [[VMTool share] keyValues];
        for (NSString *key in allKeys) {
            if ([keyValues[key] integerValue] == currentType) {
                currentTypeKey = key;
                break;
            }
        }
        if (currentTypeKey) {
            realTimeValue = [self readMemoryValueAtAddress:address withType:currentTypeKey];
        }
    }

    // 使用实时值，如果读取失败则使用记录中的值作为备选
    if (realTimeValue && ![realTimeValue isEqualToString:@"0"]) {
        currentValue = realTimeValue;
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
        if ([keyValues[key] integerValue] == currentType) {
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
    
    // 存储引用以便在按钮回调中访问
    objc_setAssociatedObject(self, "modifyBackgroundView", backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "modifyContainerView", containerView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "modifyValueTextField", valueTextField, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "modifyTypeSegment", typeSegment, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "modifyRecord", record, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "modifyIndexPath", indexPath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 确认按钮点击事件
    [confirmButton addTarget:self action:@selector(confirmModifyButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    // 取消按钮点击事件
    [cancelButton addTarget:self action:@selector(cancelModifyButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    // 类型分段控件值改变事件
    [typeSegment addTarget:self action:@selector(recordModifyTypeSegmentChanged:) forControlEvents:UIControlEventValueChanged];
    
    // 动画显示
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 1;
        containerView.transform = CGAffineTransformIdentity;
    }];
}

// 确认按钮点击事件
- (void)confirmModifyButtonTapped:(UIButton *)sender {
    UITextField *valueTextField = objc_getAssociatedObject(self, "modifyValueTextField");
    UISegmentedControl *typeSegment = objc_getAssociatedObject(self, "modifyTypeSegment");
    NSMutableDictionary *record = objc_getAssociatedObject(self, "modifyRecord");
    NSIndexPath *indexPath = objc_getAssociatedObject(self, "modifyIndexPath");
    
    NSString *newValue = valueTextField.text;
    NSInteger selectedTypeIndex = typeSegment.selectedSegmentIndex;
    
    if (newValue.length > 0) {
        // 根据选择的类型获取对应的VMMemValueType
        NSArray *allKeys = [[VMTool share] allKeys];
        NSString *selectedType = allKeys[selectedTypeIndex];
        VMMemValueType modifyType = (VMMemValueType)[[[VMTool share] keyValues][selectedType] integerValue];
        
        // 更新记录中的值和类型
        [record setObject:newValue forKey:@"value"];
        [record setObject:@(modifyType) forKey:@"valueType"];
        self.recordItems[indexPath.row] = record;
        
        // 获取地址
        NSString *address = record[@"address"];
        
        // 如果开关是打开状态，立即应用修改
        UITableViewCell *cell = [self.recordTableView cellForRowAtIndexPath:indexPath];
        UISwitch *toggleSwitch = (UISwitch *)cell.accessoryView;
        
        if (toggleSwitch.isOn && address) {
            // 应用内存修改
            [[VMTool share] modifyValue:newValue address:address type:modifyType];
            
            // 使用新方法读取最新的内存值
            NSString *currentValue = [[VMTool share] getValueFromAddress:address valueType:modifyType];
            
            // 更新记录中的值
            [record setObject:currentValue forKey:@"value"];
            self.recordItems[indexPath.row] = record;
        }
        
        // 刷新表格
        [self.recordTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        
        // 保存记录
        [self saveRecords];
    }
    
    // 关闭弹窗
    [self closeModifyValueAlert];
}

// 取消按钮点击事件
- (void)cancelModifyButtonTapped:(UIButton *)sender {
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
        objc_setAssociatedObject(self, "modifyRecord", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "modifyIndexPath", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.recordTableView) {
        return YES; // 记录表格视图可以删除
    } else {
        return YES; // 管理表格视图也可以删除
    }
}

// 自定义删除按钮文字
- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return @"删除";
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        if (tableView == self.recordTableView) {
            // 记录表格视图的删除操作
            [self.recordItems removeObjectAtIndex:indexPath.row];

            // 刷新表格
            [tableView reloadData];

            // 如果没有记录了，显示空状态
            if (self.recordItems.count == 0) {
                UILabel *emptyLabel = [[UILabel alloc] init];
                emptyLabel.text = @"暂无记录";
                emptyLabel.textAlignment = NSTextAlignmentCenter;
                emptyLabel.textColor = [UIColor secondaryLabelColor];
                emptyLabel.font = [UIFont systemFontOfSize:16];
                self.recordTableView.backgroundView = emptyLabel;
            }

            // 保存更改
            [self saveRecords];
        } else {
            // 管理表格视图的删除操作
            if (indexPath.row < self.storedPointers.count) {
                [self.storedPointers removeObjectAtIndex:indexPath.row];
                [self saveStoredPointers];
                [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            }
        }
    }
}

#pragma mark - UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    // 返回数据类型的数量
    NSArray *allKeys = [[VMTool share] allKeys];
    return allKeys.count;
}

#pragma mark - UIPickerViewDelegate

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    NSArray *allKeys = [[VMTool share] allKeys];
    if (row < allKeys.count) {
        return allKeys[row];
    }
    return @"";
}

#pragma mark - 开关事件处理

- (void)switchChanged:(UISwitch *)sender {
    NSInteger index = sender.tag;
    if (index < self.recordItems.count) {
        NSMutableDictionary *record = [self.recordItems[index] mutableCopy];
        
        // 获取记录中的数据
        NSString *address = record[@"address"];
        NSString *value = record[@"value"];
        NSNumber *valueTypeNumber = record[@"valueType"];
        VMMemValueType valueType = (VMMemValueType)[valueTypeNumber intValue];
        
        // 更新记录的激活状态
        [record setObject:@(sender.isOn) forKey:@"isActive"];
        self.recordItems[index] = record;
        
        if (sender.isOn && address) {
            // 检查是否为指针类型
            BOOL isPointer = [record[@"isPointer"] boolValue];
            NSString *currentAddress = address;

            if (isPointer) {
                // 如果是指针，重新计算地址
                NSString *pointerChain = record[@"pointerChain"];
                if (pointerChain) {
                    NSString *newAddress = [self calculatePointerChainAddress:pointerChain];
                    if (newAddress) {
                        currentAddress = newAddress;
                        // 更新记录中的地址
                        [record setObject:newAddress forKey:@"address"];
                    }
                }
            }

            // 开关打开时，使用新方法获取最新的内存值
            NSString *currentValue = [[VMTool share] getValueFromAddress:currentAddress valueType:valueType];

            // 如果用户已经设置了要修改的值，则应用修改
            if (value && ![value isEqualToString:@"0"] && ![value isEqualToString:currentValue]) {
                [[VMTool share] modifyValue:value address:currentAddress type:valueType];

                // 重新读取确认修改生效
                currentValue = [[VMTool share] getValueFromAddress:currentAddress valueType:valueType];
            }

            // 更新记录中的值
            [record setObject:currentValue forKey:@"value"];
            self.recordItems[index] = record;
            
            // 获取VMTool中设置的定时修改间隔
            NSInteger duration1 = [[VMTool share] duration1];
            if (duration1 <= 0) {
                duration1 = 20; // 默认20毫秒
            }
            
            // 创建定时任务，定期修改内存值
            NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:duration1/1000.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
                // 再次检查开关状态，如果关闭了就停止定时器
                UITableViewCell *cell = [self.recordTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
                UISwitch *switchView = (UISwitch *)cell.accessoryView;
                
                if (!switchView.isOn) {
                    [timer invalidate];
                    return;
                }
                
                // 获取最新的记录数据
                NSMutableDictionary *currentRecord = [self.recordItems[index] mutableCopy];
                NSString *currentAddress = currentRecord[@"address"];
                NSString *currentValue = currentRecord[@"value"];
                NSNumber *currentTypeNumber = currentRecord[@"valueType"];
                
                // 定期应用修改
                if (currentValue && currentAddress && currentTypeNumber) {
                    [[VMTool share] modifyValue:currentValue address:currentAddress type:(VMMemValueType)[currentTypeNumber intValue]];
                }
            }];
            
            // 将定时器与记录关联
            objc_setAssociatedObject(record, "recordTimer", timer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

            // 刷新表格中的这一行
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
            [self.recordTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        } else if (!sender.isOn) {
            // 开关关闭时，停止定时器
            NSTimer *timer = objc_getAssociatedObject(record, "recordTimer");
            if (timer) {
                [timer invalidate];
                objc_setAssociatedObject(record, "recordTimer", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }
        
        // 保存记录状态
        [self saveRecords];
    }
}

- (void)showAddAddressAlert {
    // 定义固定尺寸
    CGFloat containerWidth = 300;
    CGFloat containerHeight = 170; // 增加高度以容纳类型选择器
    
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
    titleLabel.text = @"添加地址";
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        titleLabel.textColor = [UIColor labelColor];
    } else {
        titleLabel.textColor = [UIColor darkTextColor];
    }
    
    // 地址输入框
    UITextField *addressTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 40, containerWidth - 40, 35)];
    addressTextField.placeholder = @"内存地址 (如: 0x12345678)";
    addressTextField.borderStyle = UITextBorderStyleRoundedRect;
    addressTextField.keyboardType = UIKeyboardTypeDefault;
    addressTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        addressTextField.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        addressTextField.textColor = [UIColor labelColor];
        addressTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                               initWithString:@"内存地址 (如: 0x12345678)"
                                               attributes:@{NSForegroundColorAttributeName: [UIColor secondaryLabelColor]}];
    } else {
        addressTextField.backgroundColor = [UIColor colorWithWhite:0.98 alpha:1];
        addressTextField.textColor = [UIColor darkTextColor];
    }
    
    // 类型分段控件
    NSArray *allKeys = [[VMTool share] allKeys];
    UISegmentedControl *typeSegment = [[UISegmentedControl alloc] initWithItems:allKeys];
    typeSegment.frame = CGRectMake(20, 85, containerWidth - 40, 30);
    typeSegment.selectedSegmentIndex = 0; // 默认选择第一个类型
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        typeSegment.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        typeSegment.selectedSegmentTintColor = [UIColor systemBlueColor];
    }
    
    // 确认按钮
    UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
    confirmButton.frame = CGRectMake(containerWidth / 2 + 10, 125, (containerWidth - 60) / 2, 35);
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
    cancelButton.frame = CGRectMake(20, 125, (containerWidth - 60) / 2, 35);
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
    [containerView addSubview:addressTextField];
    [containerView addSubview:typeSegment];
    [containerView addSubview:confirmButton];
    [containerView addSubview:cancelButton];
    
    [backgroundView addSubview:containerView];
    [self.view addSubview:backgroundView];
    
    // 存储引用以便在按钮回调中访问
    objc_setAssociatedObject(self, "addBackgroundView", backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "addContainerView", containerView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "addAddressTextField", addressTextField, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "addTypeSegment", typeSegment, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 确认按钮点击事件
    [confirmButton addTarget:self action:@selector(confirmAddButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 取消按钮点击事件
    [cancelButton addTarget:self action:@selector(cancelAddButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 动画显示
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 1;
        containerView.transform = CGAffineTransformIdentity;
    }];
}

// 确认添加按钮点击事件
- (void)confirmAddButtonTapped:(UIButton *)sender {
    UITextField *addressTextField = objc_getAssociatedObject(self, "addAddressTextField");
    UISegmentedControl *typeSegment = objc_getAssociatedObject(self, "addTypeSegment");
    NSString *addressText = addressTextField.text;
    
    // 如果没有输入地址，则返回
    if (!addressText.length) {
        return;
    }
    
    // 确保地址格式正确
    if (![addressText hasPrefix:@"0x"] && ![addressText hasPrefix:@"0X"]) {
        addressText = [NSString stringWithFormat:@"0x%@", addressText];
    }
    
    // 获取选择的类型
    NSInteger selectedTypeIndex = typeSegment.selectedSegmentIndex;
    NSArray *allKeys = [[VMTool share] allKeys];
    NSString *selectedType = allKeys[selectedTypeIndex];
    VMMemValueType valueType = (VMMemValueType)[[[VMTool share] keyValues][selectedType] integerValue];
    
    // 使用新方法直接获取内存值
    NSString *currentValue = [[VMTool share] getValueFromAddress:addressText valueType:valueType];
    
    // 创建记录项
    NSDictionary *record = @{
        @"address": addressText,
        @"value": currentValue,
        @"recordName": [NSString stringWithFormat:@"%@ - %@", addressText, selectedType],
        @"valueType": @(valueType),
        @"isActive": @(NO)
    };
    
    // 添加到记录列表
    if (!self.recordItems) {
        self.recordItems = [NSMutableArray array];
    }
    [self.recordItems addObject:record];
    
    // 刷新表格
    [self.recordTableView reloadData];
    
    // 保存记录
    [self saveRecords];
    
    // 关闭弹窗
    [self cancelAddButtonTapped:nil];
}

// 取消添加按钮点击事件
- (void)cancelAddButtonTapped:(UIButton *)sender {
    [self closeAddAlert];
}

// 关闭添加地址弹窗
- (void)closeAddAlert {
    UIView *backgroundView = objc_getAssociatedObject(self, "addBackgroundView");
    UIView *containerView = objc_getAssociatedObject(self, "addContainerView");
    
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 0;
        containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    } completion:^(BOOL finished) {
        [backgroundView removeFromSuperview];
        
        // 清除关联对象，防止内存泄漏
        objc_setAssociatedObject(self, "addBackgroundView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "addContainerView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "addAddressTextField", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "addTypeSegment", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }];
}

// 保存记录到本地
- (void)saveRecords {
    // 将记录数组保存到用户默认设置
    if (self.recordItems) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:self.recordItems forKey:@"SavedRecords"];
        [defaults synchronize];
    }
}

// 从本地加载记录
- (void)loadRecords {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *savedRecords = [defaults arrayForKey:@"SavedRecords"];
    
    if (savedRecords) {
        self.recordItems = [savedRecords mutableCopy];
        
        // 如果有记录，移除空状态提示
        if (self.recordItems.count > 0) {
            self.recordTableView.backgroundView = nil;
        }
        
        [self.recordTableView reloadData];
    }
}

// 显示加减计算界面
- (void)showAddSubtractionCalculator {
    // 定义固定尺寸
    CGFloat containerWidth = 300;
    CGFloat containerHeight = 420; // 减小容器高度
    
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
    titleLabel.text = @"加减计算";
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        titleLabel.textColor = [UIColor labelColor];
    } else {
        titleLabel.textColor = [UIColor darkTextColor];
    }
    
    // 加减计算操作选择器
    UISegmentedControl *operationSegment = [[UISegmentedControl alloc] initWithItems:@[@"+", @"-"]];
    operationSegment.frame = CGRectMake((containerWidth - 80) / 2, 45, 80, 35);
    operationSegment.selectedSegmentIndex = 0;
    
    // 第一个输入框标签
    UILabel *inputLabel1 = [[UILabel alloc] initWithFrame:CGRectMake(20, 90, containerWidth - 40, 20)];
    inputLabel1.text = @"第一个值:";
    inputLabel1.font = [UIFont systemFontOfSize:14];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        inputLabel1.textColor = [UIColor secondaryLabelColor];
    } else {
        inputLabel1.textColor = [UIColor darkGrayColor];
    }
    
    // 第一个输入框
    UITextField *inputTextField1 = [[UITextField alloc] initWithFrame:CGRectMake(20, 115, containerWidth - 40, 35)];
    inputTextField1.placeholder = @"输入第一个数值";
    inputTextField1.borderStyle = UITextBorderStyleRoundedRect;
    inputTextField1.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    inputTextField1.clearButtonMode = UITextFieldViewModeWhileEditing;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        inputTextField1.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        inputTextField1.textColor = [UIColor labelColor];
    } else {
        inputTextField1.backgroundColor = [UIColor colorWithWhite:0.98 alpha:1];
        inputTextField1.textColor = [UIColor darkTextColor];
    }
    
    // 第二个输入框标签
    UILabel *inputLabel2 = [[UILabel alloc] initWithFrame:CGRectMake(20, 160, containerWidth - 40, 20)];
    inputLabel2.text = @"第二个值:";
    inputLabel2.font = [UIFont systemFontOfSize:14];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        inputLabel2.textColor = [UIColor secondaryLabelColor];
    } else {
        inputLabel2.textColor = [UIColor darkGrayColor];
    }
    
    // 第二个输入框
    UITextField *inputTextField2 = [[UITextField alloc] initWithFrame:CGRectMake(20, 185, containerWidth - 40, 35)];
    inputTextField2.placeholder = @"输入第二个数值";
    inputTextField2.borderStyle = UITextBorderStyleRoundedRect;
    inputTextField2.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    inputTextField2.clearButtonMode = UITextFieldViewModeWhileEditing;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        inputTextField2.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        inputTextField2.textColor = [UIColor labelColor];
    } else {
        inputTextField2.backgroundColor = [UIColor colorWithWhite:0.98 alpha:1];
        inputTextField2.textColor = [UIColor darkTextColor];
    }
    
    // 十进制结果标签
    UILabel *resultTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 230, containerWidth - 40, 20)];
    resultTitleLabel.text = @"十进制结果:";
    resultTitleLabel.font = [UIFont systemFontOfSize:14];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        resultTitleLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        resultTitleLabel.textColor = [UIColor darkGrayColor];
    }
    
    // 十进制结果显示框
    UITextField *resultTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 255, containerWidth - 40, 35)];
    resultTextField.borderStyle = UITextBorderStyleRoundedRect;
    resultTextField.enabled = NO;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        resultTextField.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        resultTextField.textColor = [UIColor systemGreenColor];
    } else {
        resultTextField.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
        resultTextField.textColor = [UIColor greenColor];
    }
    
    // 十六进制结果标签
    UILabel *hexResultLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 300, containerWidth - 40, 20)];
    hexResultLabel.text = @"十六进制结果:";
    hexResultLabel.font = [UIFont systemFontOfSize:14];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        hexResultLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        hexResultLabel.textColor = [UIColor darkGrayColor];
    }
    
    // 十六进制结果显示框
    UITextField *hexResultTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 325, containerWidth - 40, 35)];
    hexResultTextField.borderStyle = UITextBorderStyleRoundedRect;
    hexResultTextField.enabled = NO;
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        hexResultTextField.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        hexResultTextField.textColor = [UIColor systemBlueColor];
    } else {
        hexResultTextField.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
        hexResultTextField.textColor = [UIColor blueColor];
    }
    
    // 确认按钮 - 调整位置
    UIButton *convertButton = [UIButton buttonWithType:UIButtonTypeSystem];
    convertButton.frame = CGRectMake(containerWidth / 2 + 10, 370, (containerWidth - 60) / 2, 35);
    [convertButton setTitle:@"计算" forState:UIControlStateNormal];
    
    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        convertButton.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.2 green:0.22 blue:0.25 alpha:1.0];
            } else {
                return [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0];
            }
        }];
        [convertButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        convertButton.backgroundColor = [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0];
        [convertButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    
    convertButton.layer.cornerRadius = 8;
    
    // 取消按钮 - 调整位置
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.frame = CGRectMake(20, 370, (containerWidth - 60) / 2, 35);
    [cancelButton setTitle:@"关闭" forState:UIControlStateNormal];
    
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
    [containerView addSubview:operationSegment];
    [containerView addSubview:inputLabel1];
    [containerView addSubview:inputTextField1];
    [containerView addSubview:inputLabel2];
    [containerView addSubview:inputTextField2];
    [containerView addSubview:resultTitleLabel];
    [containerView addSubview:resultTextField];
    [containerView addSubview:hexResultLabel];
    [containerView addSubview:hexResultTextField];
    [containerView addSubview:convertButton];
    [containerView addSubview:cancelButton];
    
    [backgroundView addSubview:containerView];
    [self.view addSubview:backgroundView];
    
    // 存储引用以便在按钮回调中访问
    objc_setAssociatedObject(self, "calculationBackgroundView", backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "calculationContainerView", containerView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "operationSegment", operationSegment, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "inputTextField1", inputTextField1, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "inputTextField2", inputTextField2, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "resultTextField", resultTextField, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "hexResultTextField", hexResultTextField, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 计算按钮点击事件
    [convertButton addTarget:self action:@selector(calculateButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 取消按钮点击事件
    [cancelButton addTarget:self action:@selector(closeCalculationAlert:) forControlEvents:UIControlEventTouchUpInside];
    
    // 动画显示
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 1;
        containerView.transform = CGAffineTransformIdentity;
    }];
}

// 计算按钮点击事件
- (void)calculateButtonTapped:(UIButton *)sender {
    UISegmentedControl *operationSegment = objc_getAssociatedObject(self, "operationSegment");
    UITextField *inputTextField1 = objc_getAssociatedObject(self, "inputTextField1");
    UITextField *inputTextField2 = objc_getAssociatedObject(self, "inputTextField2");
    UITextField *resultTextField = objc_getAssociatedObject(self, "resultTextField");
    UITextField *hexResultTextField = objc_getAssociatedObject(self, "hexResultTextField");
    
    NSString *inputText1 = inputTextField1.text;
    NSString *inputText2 = inputTextField2.text;
    
    // 检查输入是否为空
    if (inputText1.length == 0) {
        resultTextField.text = @"请输入第一个数值";
        return;
    }
    
    // 检查第二个输入是否为空
    if (inputText2.length == 0) {
        resultTextField.text = @"请输入第二个数值";
        return;
    }
    
    // 解析输入值，支持十六进制格式
    unsigned long long uValue1 = 0;
    unsigned long long uValue2 = 0;
    long long value1 = 0;
    long long value2 = 0;
    
    // 解析第一个输入值
    if ([inputText1 hasPrefix:@"0x"] || [inputText1 hasPrefix:@"0X"]) {
        // 十六进制格式
        NSScanner *scanner = [NSScanner scannerWithString:inputText1];
        [scanner scanHexLongLong:&uValue1];
        value1 = (long long)uValue1;
    } else {
        // 十进制格式
        value1 = [inputText1 longLongValue];
    }
    
    // 解析第二个输入值
    if ([inputText2 hasPrefix:@"0x"] || [inputText2 hasPrefix:@"0X"]) {
        // 十六进制格式
        NSScanner *scanner = [NSScanner scannerWithString:inputText2];
        [scanner scanHexLongLong:&uValue2];
        value2 = (long long)uValue2;
    } else {
        // 十进制格式
        value2 = [inputText2 longLongValue];
    }
    
    long long result = 0;
    
    // 根据操作符执行计算
    if (operationSegment.selectedSegmentIndex == 0) {
        // 加法
        result = value1 + value2;
    } else {
        // 减法
        result = value1 - value2;
    }
    
    // 显示十进制结果
    resultTextField.text = [NSString stringWithFormat:@"%lld", result];
    
    // 显示十六进制结果
    hexResultTextField.text = [NSString stringWithFormat:@"0x%llX", result];
}

// 关闭计算转换弹窗
- (void)closeCalculationAlert:(UIButton *)sender {
    UIView *backgroundView = objc_getAssociatedObject(self, "calculationBackgroundView");
    UIView *containerView = objc_getAssociatedObject(self, "calculationContainerView");
    
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 0;
        containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    } completion:^(BOOL finished) {
        [backgroundView removeFromSuperview];
        
        // 清除关联对象，防止内存泄漏
        objc_setAssociatedObject(self, "calculationBackgroundView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "calculationContainerView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "conversionTypeSegment", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "inputTextField", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "resultTextField", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }];
}

#pragma mark - 添加指针功能

- (void)showAddPointerAlert {
    // 定义固定尺寸
    CGFloat containerWidth = 320;
    CGFloat containerHeight = 250;

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
    titleLabel.text = @"添加指针";
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;

    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        titleLabel.textColor = [UIColor labelColor];
    } else {
        titleLabel.textColor = [UIColor darkTextColor];
    }

    // 指针链输入框
    UITextField *pointerTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 40, containerWidth - 40, 35)];
    pointerTextField.placeholder = @"指针链 (如: wp2+0xF0D2B0+0x228+0x348+0x38C)";
    pointerTextField.borderStyle = UITextBorderStyleRoundedRect;
    pointerTextField.keyboardType = UIKeyboardTypeDefault;
    pointerTextField.clearButtonMode = UITextFieldViewModeWhileEditing;

    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        pointerTextField.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        pointerTextField.textColor = [UIColor labelColor];
        pointerTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                               initWithString:@"指针链 (如: wp2+0xEB6DB8→0xFE4)"
                                               attributes:@{NSForegroundColorAttributeName: [UIColor secondaryLabelColor]}];
    } else {
        pointerTextField.backgroundColor = [UIColor colorWithWhite:0.98 alpha:1];
        pointerTextField.textColor = [UIColor darkTextColor];
    }

    // 记录名称输入框
    UITextField *nameTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 85, containerWidth - 40, 35)];
    nameTextField.placeholder = @"记录名称 (可选)";
    nameTextField.borderStyle = UITextBorderStyleRoundedRect;
    nameTextField.keyboardType = UIKeyboardTypeDefault;
    nameTextField.clearButtonMode = UITextFieldViewModeWhileEditing;

    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        nameTextField.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        nameTextField.textColor = [UIColor labelColor];
        nameTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                               initWithString:@"记录名称 (可选)"
                                               attributes:@{NSForegroundColorAttributeName: [UIColor secondaryLabelColor]}];
    } else {
        nameTextField.backgroundColor = [UIColor colorWithWhite:0.98 alpha:1];
        nameTextField.textColor = [UIColor darkTextColor];
    }

    // 类型分段控件
    NSArray *allKeys = [[VMTool share] allKeys];
    UISegmentedControl *typeSegment = [[UISegmentedControl alloc] initWithItems:allKeys];
    typeSegment.frame = CGRectMake(20, 130, containerWidth - 40, 30);
    typeSegment.selectedSegmentIndex = 4; // 默认选择I32类型

    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        typeSegment.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        typeSegment.selectedSegmentTintColor = [UIColor systemBlueColor];
    }

    // 取消按钮
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.frame = CGRectMake(20, 175, (containerWidth - 60) / 2, 35);
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

    // 确认按钮
    UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
    confirmButton.frame = CGRectMake(containerWidth / 2 + 10, 175, (containerWidth - 60) / 2, 35);
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

    // 添加视图
    [containerView addSubview:titleLabel];
    [containerView addSubview:pointerTextField];
    [containerView addSubview:nameTextField];
    [containerView addSubview:typeSegment];
    [containerView addSubview:confirmButton];
    [containerView addSubview:cancelButton];

    [backgroundView addSubview:containerView];
    [self.view addSubview:backgroundView];

    // 存储引用以便在按钮回调中访问
    objc_setAssociatedObject(self, "pointerBackgroundView", backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "pointerContainerView", containerView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "pointerTextField", pointerTextField, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "pointerNameTextField", nameTextField, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "pointerTypeSegment", typeSegment, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 确认按钮点击事件
    [confirmButton addTarget:self action:@selector(confirmAddPointerButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    // 取消按钮点击事件
    [cancelButton addTarget:self action:@selector(cancelAddPointerButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    // 动画显示
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 1;
        containerView.transform = CGAffineTransformIdentity;
    }];
}

// 确认添加指针按钮点击事件
- (void)confirmAddPointerButtonTapped:(UIButton *)sender {
    UITextField *pointerTextField = objc_getAssociatedObject(self, "pointerTextField");
    UITextField *nameTextField = objc_getAssociatedObject(self, "pointerNameTextField");
    UISegmentedControl *typeSegment = objc_getAssociatedObject(self, "pointerTypeSegment");

    NSString *pointerChain = pointerTextField.text;
    NSString *recordName = nameTextField.text;

    // 如果没有输入指针链，则返回
    if (!pointerChain.length) {
        return;
    }

    // 获取选择的类型
    NSInteger selectedTypeIndex = typeSegment.selectedSegmentIndex;
    NSArray *allKeys = [[VMTool share] allKeys];
    NSString *selectedType = allKeys[selectedTypeIndex];
    VMMemValueType valueType = (VMMemValueType)[[[VMTool share] keyValues][selectedType] integerValue];

    // 解析指针链并计算最终地址
    NSString *finalAddress = [self calculatePointerChainAddress:pointerChain];

    if (!finalAddress) {
        // 显示错误提示
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误"
                                                                       message:@"指针链格式错误或无法解析"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                           style:UIAlertActionStyleDefault
                                                         handler:nil];
        [alert addAction:okAction];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    // 使用新方法直接获取内存值
    NSString *currentValue = [[VMTool share] getValueFromAddress:finalAddress valueType:valueType];

    // 如果没有输入记录名称，使用默认名称
    if (!recordName.length) {
        recordName = [NSString stringWithFormat:@"指针 - %@", selectedType];
    }

    // 创建记录项
    NSDictionary *record = @{
        @"address": finalAddress,
        @"value": currentValue,
        @"recordName": recordName,
        @"valueType": @(valueType),
        @"isActive": @(NO),
        @"pointerChain": pointerChain,  // 保存原始指针链
        @"isPointer": @(YES)            // 标记为指针类型
    };

    // 添加到记录列表
    if (!self.recordItems) {
        self.recordItems = [NSMutableArray array];
    }
    [self.recordItems addObject:record];

    // 刷新表格
    [self.recordTableView reloadData];

    // 保存记录
    [self saveRecords];

    // 关闭弹窗
    [self cancelAddPointerButtonTapped:nil];
}

// 取消添加指针按钮点击事件
- (void)cancelAddPointerButtonTapped:(UIButton *)sender {
    [self closeAddPointerAlert];
}

// 关闭添加指针弹窗
- (void)closeAddPointerAlert {
    UIView *backgroundView = objc_getAssociatedObject(self, "pointerBackgroundView");
    UIView *containerView = objc_getAssociatedObject(self, "pointerContainerView");

    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 0;
        containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    } completion:^(BOOL finished) {
        [backgroundView removeFromSuperview];
        [containerView removeFromSuperview];

        // 清除关联对象
        objc_setAssociatedObject(self, "pointerBackgroundView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "pointerContainerView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "pointerTextField", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "pointerNameTextField", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "pointerTypeSegment", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }];
}

// 计算指针链的最终地址
- (NSString *)calculatePointerChainAddress:(NSString *)pointerChain {
    // 清理输入字符串，移除状态符号和多余空格
    NSString *cleanChain = [pointerChain stringByReplacingOccurrencesOfString:@"✅ " withString:@""];
    cleanChain = [cleanChain stringByReplacingOccurrencesOfString:@"❌ " withString:@""];
    cleanChain = [cleanChain stringByReplacingOccurrencesOfString:@" " withString:@""];

    // 只支持指针扫描格式：wp2+0xF0D2B0+0x228+0x348+0x38C
    NSArray *components = [cleanChain componentsSeparatedByString:@"+"];

    if (components.count < 2) {
        return nil;
    }

    // 指针扫描格式：wp2+0xF0D2B0+0x228+0x348+0x38C
    // 第一个组件是模块名，第二个是基址偏移，后续都是指针偏移
    NSString *moduleName = components[0];
    NSString *baseOffsetString = components[1];

    // 获取模块基址
    uint64_t moduleBaseAddress = [self getModuleBaseAddress:moduleName];
    if (moduleBaseAddress == 0) {
        return nil;
    }

    // 解析基址偏移
    uint64_t baseOffset = [self parseHexString:baseOffsetString];
    uint64_t currentAddress = moduleBaseAddress + baseOffset;

    if (currentAddress == 0) {
        return nil;
    }

    // 获取当前进程信息
    NSString *pidString = [ProcessManager sharedManager].selectedProcessPID;
    if (!pidString) {
        return nil;
    }

    // 使用 PointerScanManager 来读取内存
    PointerScanManager *pointerManager = [PointerScanManager sharedManager];

    // 确保已附加到进程
    NSError *error = nil;
    if (![pointerManager attachToProcess:[pidString intValue] error:&error]) {
        return nil;
    }

    // 遍历指针链的偏移部分（从第3个组件开始）
    for (NSInteger i = 2; i < components.count; i++) {

        // 先尝试8字节，如果失败再尝试4字节
        NSData *data = [pointerManager readMemory:currentAddress size:8 error:&error];
        uint64_t pointerValue = 0;

        if (data && data.length >= 8) {
            pointerValue = *(uint64_t *)data.bytes;
        } else {
            // 尝试4字节读取
            data = [pointerManager readMemory:currentAddress size:4 error:&error];
            if (data && data.length >= 4) {
                pointerValue = *(uint32_t *)data.bytes;
            } else {
                return nil;
            }
        }

        // 解析偏移量
        NSString *offsetString = components[i];
        int64_t offset = (int64_t)[self parseHexString:offsetString];

        // 计算新地址
        currentAddress = pointerValue + offset;
    }

    return [NSString stringWithFormat:@"0x%llX", currentAddress];
}

// 解析十六进制字符串
- (uint64_t)parseHexString:(NSString *)hexString {
    if (!hexString || hexString.length == 0) {
        return 0;
    }

    uint64_t result = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];

    if ([hexString hasPrefix:@"0x"] || [hexString hasPrefix:@"0X"]) {
        // 标准十六进制格式：0x1234
        [scanner scanHexLongLong:&result];
    } else {
        // 尝试作为十六进制解析（如 F0D2B0）
        if ([scanner scanHexLongLong:&result]) {
            // 成功解析为十六进制
        } else {
            // 作为十进制解析
            result = [hexString longLongValue];
        }
    }

    return result;
}

// 获取模块基址
- (uint64_t)getModuleBaseAddress:(NSString *)moduleName {
    // 使用 PointerScanManager 获取模块列表
    PointerScanManager *pointerManager = [PointerScanManager sharedManager];

    NSError *error = nil;
    NSArray<ModuleInfo *> *modules = [pointerManager getModuleList:&error];

    if (!modules) {
        // 尝试重新附加进程后再次获取
        NSString *pidString = [ProcessManager sharedManager].selectedProcessPID;
        if (pidString) {
            if ([pointerManager attachToProcess:[pidString intValue] error:&error]) {
                modules = [pointerManager getModuleList:&error];
                if (!modules) {
                    return 0;
                }
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    }

    // 查找匹配的模块
    for (ModuleInfo *module in modules) {
        if ([module.name isEqualToString:moduleName]) {
            return module.startAddress;
        }
    }

    return 0;
}

#pragma mark - 管理功能

- (void)pointerManagerButtonTapped:(UIButton *)sender {
    [self showPointerManagerView];
}

// 显示管理界面
- (void)showPointerManagerView {
    // 定义固定尺寸
    CGFloat containerWidth = 380;
    CGFloat containerHeight = 550;

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
    titleLabel.text = @"管理";
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;

    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        titleLabel.textColor = [UIColor labelColor];
    } else {
        titleLabel.textColor = [UIColor darkTextColor];
    }

    // 添加统计信息标签
    UILabel *statsLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 45, containerWidth - 40, 20)];
    statsLabel.font = [UIFont systemFontOfSize:14];
    statsLabel.textAlignment = NSTextAlignmentCenter;
    if (@available(iOS 13.0, *)) {
        statsLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        statsLabel.textColor = [UIColor grayColor];
    }

    // 更新统计信息
    NSInteger currentPointers = 0;
    NSInteger storedPointers = self.storedPointers.count;
    for (NSDictionary *record in self.recordItems) {
        if ([record[@"isPointer"] boolValue]) {
            currentPointers++;
        }
    }
    statsLabel.text = [NSString stringWithFormat:@"当前指针: %ld | 存储指针: %ld", (long)currentPointers, (long)storedPointers];

    // 保存统计标签引用
    objc_setAssociatedObject(self, "pointerStatsLabel", statsLabel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 创建表格视图显示存储的指针
    UITableView *pointerTableView = [[UITableView alloc] initWithFrame:CGRectMake(20, 75, containerWidth - 40, containerHeight - 155) style:UITableViewStylePlain];
    pointerTableView.delegate = self;
    pointerTableView.dataSource = self;
    pointerTableView.layer.cornerRadius = 8;
    pointerTableView.layer.borderWidth = 1;
    pointerTableView.rowHeight = 60; // 增加行高以显示更多信息

    if (@available(iOS 13.0, *)) {
        pointerTableView.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
        pointerTableView.layer.borderColor = [UIColor systemGray4Color].CGColor;
    } else {
        pointerTableView.backgroundColor = [UIColor colorWithWhite:0.98 alpha:1];
        pointerTableView.layer.borderColor = [UIColor colorWithWhite:0.9 alpha:1.0].CGColor;
    }

    // 添加空状态提示
    if (self.storedPointers.count == 0) {
        UILabel *emptyLabel = [[UILabel alloc] init];
        emptyLabel.text = @"暂无存储的指针\n点击\"存储指针\"保存当前指针";
        emptyLabel.numberOfLines = 2;
        emptyLabel.textAlignment = NSTextAlignmentCenter;
        emptyLabel.font = [UIFont systemFontOfSize:14];
        if (@available(iOS 13.0, *)) {
            emptyLabel.textColor = [UIColor secondaryLabelColor];
        } else {
            emptyLabel.textColor = [UIColor grayColor];
        }
        pointerTableView.backgroundView = emptyLabel;
    }

    // 底部按钮区域 - 四个按钮，分两行
    CGFloat buttonWidth = (containerWidth - 60) / 2;
    CGFloat buttonHeight = 32;

    // 第一行按钮
    UIButton *storeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    storeButton.frame = CGRectMake(20, containerHeight - 80, buttonWidth, buttonHeight);
    [storeButton setTitle:@"存储指针" forState:UIControlStateNormal];
    storeButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];

    UIButton *restoreAllButton = [UIButton buttonWithType:UIButtonTypeSystem];
    restoreAllButton.frame = CGRectMake(30 + buttonWidth, containerHeight - 80, buttonWidth, buttonHeight);
    [restoreAllButton setTitle:@"取出全部" forState:UIControlStateNormal];
    restoreAllButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];

    // 第二行按钮
    UIButton *clearStoredButton = [UIButton buttonWithType:UIButtonTypeSystem];
    clearStoredButton.frame = CGRectMake(20, containerHeight - 42, buttonWidth, buttonHeight);
    [clearStoredButton setTitle:@"清空存储" forState:UIControlStateNormal];
    clearStoredButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake(30 + buttonWidth, containerHeight - 42, buttonWidth, buttonHeight);
    [closeButton setTitle:@"关闭" forState:UIControlStateNormal];
    closeButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];

    // 适配深色和浅色模式
    if (@available(iOS 13.0, *)) {
        // 存储按钮 - 蓝色
        storeButton.backgroundColor = [UIColor systemBlueColor];
        [storeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

        // 取出全部按钮 - 绿色
        restoreAllButton.backgroundColor = [UIColor systemGreenColor];
        [restoreAllButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

        // 清空按钮 - 红色
        clearStoredButton.backgroundColor = [UIColor systemRedColor];
        [clearStoredButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

        // 关闭按钮 - 灰色
        closeButton.backgroundColor = [UIColor systemGrayColor];
        [closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        storeButton.backgroundColor = [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0];
        [storeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

        restoreAllButton.backgroundColor = [UIColor colorWithRed:0.3 green:0.8 blue:0.3 alpha:1.0];
        [restoreAllButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

        clearStoredButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.3 blue:0.3 alpha:1.0];
        [clearStoredButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

        closeButton.backgroundColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
        [closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }

    storeButton.layer.cornerRadius = 8;
    restoreAllButton.layer.cornerRadius = 8;
    clearStoredButton.layer.cornerRadius = 8;
    closeButton.layer.cornerRadius = 8;

    // 添加视图
    [containerView addSubview:titleLabel];
    [containerView addSubview:statsLabel];
    [containerView addSubview:pointerTableView];
    [containerView addSubview:storeButton];
    [containerView addSubview:restoreAllButton];
    [containerView addSubview:clearStoredButton];
    [containerView addSubview:closeButton];

    [backgroundView addSubview:containerView];
    [self.view addSubview:backgroundView];

    // 存储引用以便在按钮回调中访问
    objc_setAssociatedObject(self, "pointerManagerBackgroundView", backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "pointerManagerContainerView", containerView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "pointerManagerTableView", pointerTableView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 按钮点击事件
    [storeButton addTarget:self action:@selector(storePointersButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [restoreAllButton addTarget:self action:@selector(restoreAllPointersButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [clearStoredButton addTarget:self action:@selector(clearStoredPointersButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [closeButton addTarget:self action:@selector(closePointerManagerButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    // 动画显示
    [UIView animateWithDuration:0.3 animations:^{
        backgroundView.alpha = 1;
        containerView.transform = CGAffineTransformIdentity;
    }];
}

// 存储指针按钮点击事件
- (void)storePointersButtonTapped:(UIButton *)sender {
    // 获取当前记录中的所有指针
    NSMutableArray *pointersToStore = [NSMutableArray array];

    for (NSDictionary *record in self.recordItems) {
        BOOL isPointer = [record[@"isPointer"] boolValue];
        if (isPointer) {
            // 创建指针存储数据
            NSDictionary *pointerData = @{
                @"pointerChain": record[@"pointerChain"] ?: @"",
                @"recordName": record[@"recordName"] ?: @"",
                @"valueType": record[@"valueType"] ?: @(VMMemValueTypeUnsignedInt),
                @"address": record[@"address"] ?: @"",
                @"value": record[@"value"] ?: @"",
                @"dateStored": [NSDate date]
            };
            [pointersToStore addObject:pointerData];
        }
    }

    if (pointersToStore.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                       message:@"当前没有指针记录可以存储"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                           style:UIAlertActionStyleDefault
                                                         handler:nil];
        [alert addAction:okAction];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    // 添加到存储列表
    [self.storedPointers addObjectsFromArray:pointersToStore];

    // 保存到本地
    [self saveStoredPointers];

    // 刷新表格和统计信息
    UITableView *pointerTableView = objc_getAssociatedObject(self, "pointerManagerTableView");
    [pointerTableView reloadData];
    [self updatePointerManagerStats];
    [self updatePointerManagerButtonTitle];

    // 从当前记录中移除指针（存储到管理中）
    NSMutableArray *nonPointerRecords = [NSMutableArray array];
    for (NSDictionary *record in self.recordItems) {
        BOOL isPointer = [record[@"isPointer"] boolValue];
        if (!isPointer) {
            [nonPointerRecords addObject:record];
        }
    }

    self.recordItems = nonPointerRecords;
    [self.recordTableView reloadData];
    [self saveRecords];

    // 显示成功提示
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"存储成功"
                                                                   message:[NSString stringWithFormat:@"已存储 %lu 个指针到管理中心\n这些指针已从当前记录中移除", (unsigned long)pointersToStore.count]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

// 取出全部指针按钮点击事件
- (void)restoreAllPointersButtonTapped:(UIButton *)sender {
    if (self.storedPointers.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                       message:@"没有存储的指针可以取出"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                           style:UIAlertActionStyleDefault
                                                         handler:nil];
        [alert addAction:okAction];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"批量取出指针"
                                                                   message:[NSString stringWithFormat:@"确定要取出所有 %lu 个存储的指针吗？\n无效指针将被自动删除。", (unsigned long)self.storedPointers.count]
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确定取出"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * _Nonnull action) {
        [self performBatchRestorePointers];
    }];

    [alert addAction:cancelAction];
    [alert addAction:confirmAction];
    [self presentViewController:alert animated:YES completion:nil];
}

// 执行批量取出指针
- (void)performBatchRestorePointers {
    NSMutableArray *validPointers = [NSMutableArray array];
    NSMutableArray *invalidPointers = [NSMutableArray array];
    NSMutableArray *restoredRecords = [NSMutableArray array];

    // 遍历所有存储的指针
    for (NSInteger i = self.storedPointers.count - 1; i >= 0; i--) {
        NSDictionary *pointerData = self.storedPointers[i];
        NSString *pointerChain = pointerData[@"pointerChain"];

        // 尝试计算指针链地址
        NSString *finalAddress = [self calculatePointerChainAddressWithErrorInfo:pointerChain];

        if (finalAddress) {
            // 指针有效，创建记录
            VMMemValueType valueType = (VMMemValueType)[pointerData[@"valueType"] intValue];
            NSString *currentValue = [[VMTool share] getValueFromAddress:finalAddress valueType:valueType];

            NSDictionary *record = @{
                @"address": finalAddress,
                @"value": currentValue,
                @"recordName": pointerData[@"recordName"],
                @"valueType": pointerData[@"valueType"],
                @"isActive": @(NO),
                @"pointerChain": pointerChain,
                @"isPointer": @(YES)
            };

            [restoredRecords addObject:record];
            [validPointers addObject:pointerData];
        } else {
            // 指针无效
            [invalidPointers addObject:pointerData];
        }
    }

    // 添加有效指针到记录列表
    if (!self.recordItems) {
        self.recordItems = [NSMutableArray array];
    }
    [self.recordItems addObjectsFromArray:restoredRecords];

    // 从存储列表中移除所有指针（包括无效的）
    [self.storedPointers removeAllObjects];

    // 保存更改
    [self saveRecords];
    [self saveStoredPointers];

    // 刷新界面
    [self.recordTableView reloadData];
    UITableView *pointerTableView = objc_getAssociatedObject(self, "pointerManagerTableView");
    [pointerTableView reloadData];
    [self updatePointerManagerStats];
    [self updatePointerManagerButtonTitle];

    // 显示结果
    NSString *message;
    if (invalidPointers.count == 0) {
        message = [NSString stringWithFormat:@"成功取出 %lu 个指针", (unsigned long)validPointers.count];
    } else {
        message = [NSString stringWithFormat:@"成功取出 %lu 个有效指针\n删除了 %lu 个无效指针",
                  (unsigned long)validPointers.count, (unsigned long)invalidPointers.count];
    }

    UIAlertController *resultAlert = [UIAlertController alertControllerWithTitle:@"批量取出完成"
                                                                          message:message
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    [resultAlert addAction:okAction];
    [self presentViewController:resultAlert animated:YES completion:nil];
}

// 清空存储指针按钮点击事件
- (void)clearStoredPointersButtonTapped:(UIButton *)sender {
    if (self.storedPointers.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                       message:@"没有存储的指针可以清空"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                           style:UIAlertActionStyleDefault
                                                         handler:nil];
        [alert addAction:okAction];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认清空"
                                                                   message:[NSString stringWithFormat:@"确定要清空所有 %lu 个存储的指针吗？此操作不可撤销。", (unsigned long)self.storedPointers.count]
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确定清空"
                                                            style:UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction * _Nonnull action) {
        // 清空存储的指针
        [self.storedPointers removeAllObjects];
        [self saveStoredPointers];

        // 刷新表格和统计信息
        UITableView *pointerTableView = objc_getAssociatedObject(self, "pointerManagerTableView");
        [pointerTableView reloadData];
        [self updatePointerManagerStats];
        [self updatePointerManagerButtonTitle];

        // 显示成功提示
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"清空成功"
                                                                               message:@"所有存储的指针已清空"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                           style:UIAlertActionStyleDefault
                                                         handler:nil];
        [successAlert addAction:okAction];
        [self presentViewController:successAlert animated:YES completion:nil];
    }];

    [alert addAction:cancelAction];
    [alert addAction:confirmAction];
    [self presentViewController:alert animated:YES completion:nil];
}

// 更新管理统计信息
- (void)updatePointerManagerStats {
    UILabel *statsLabel = objc_getAssociatedObject(self, "pointerStatsLabel");
    if (statsLabel) {
        NSInteger currentPointers = 0;
        NSInteger storedPointers = self.storedPointers.count;
        for (NSDictionary *record in self.recordItems) {
            if ([record[@"isPointer"] boolValue]) {
                currentPointers++;
            }
        }
        statsLabel.text = [NSString stringWithFormat:@"当前指针: %ld | 存储指针: %ld", (long)currentPointers, (long)storedPointers];

        // 更新表格空状态
        UITableView *pointerTableView = objc_getAssociatedObject(self, "pointerManagerTableView");
        if (pointerTableView) {
            if (self.storedPointers.count == 0) {
                UILabel *emptyLabel = [[UILabel alloc] init];
                emptyLabel.text = @"暂无存储的指针\n点击\"存储指针\"保存当前指针";
                emptyLabel.numberOfLines = 2;
                emptyLabel.textAlignment = NSTextAlignmentCenter;
                emptyLabel.font = [UIFont systemFontOfSize:14];
                if (@available(iOS 13.0, *)) {
                    emptyLabel.textColor = [UIColor secondaryLabelColor];
                } else {
                    emptyLabel.textColor = [UIColor grayColor];
                }
                pointerTableView.backgroundView = emptyLabel;
            } else {
                pointerTableView.backgroundView = nil;
            }
        }
    }
}

// 关闭管理按钮点击事件
- (void)closePointerManagerButtonTapped:(UIButton *)sender {
    [self closePointerManagerView];
}

// 关闭管理界面
- (void)closePointerManagerView {
    UIView *backgroundView = objc_getAssociatedObject(self, "pointerManagerBackgroundView");
    UIView *containerView = objc_getAssociatedObject(self, "pointerManagerContainerView");

    if (backgroundView && containerView) {
        [UIView animateWithDuration:0.3 animations:^{
            backgroundView.alpha = 0;
            containerView.transform = CGAffineTransformMakeScale(0.8, 0.8);
        } completion:^(BOOL finished) {
            [backgroundView removeFromSuperview];

            // 清理关联对象
            objc_setAssociatedObject(self, "pointerManagerBackgroundView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(self, "pointerManagerContainerView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(self, "pointerManagerTableView", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(self, "pointerStatsLabel", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }];
    }
}

// 加载存储的指针
- (void)loadStoredPointers {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *savedPointers = [defaults arrayForKey:@"StoredPointers"];

    if (savedPointers) {
        self.storedPointers = [savedPointers mutableCopy];
    } else {
        self.storedPointers = [NSMutableArray array];
    }
}

// 保存存储的指针
- (void)saveStoredPointers {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.storedPointers forKey:@"StoredPointers"];
    [defaults synchronize];
}

// 取出指针按钮点击事件
- (void)restorePointerButtonTapped:(UIButton *)sender {
    NSInteger index = sender.tag;

    if (index < self.storedPointers.count) {
        NSDictionary *pointerData = self.storedPointers[index];

        // 重新计算指针链的最终地址
        NSString *pointerChain = pointerData[@"pointerChain"];

        NSString *finalAddress = [self calculatePointerChainAddressWithErrorInfo:pointerChain];

        if (!finalAddress) {
            // 显示更详细的错误信息和选项
            NSString *errorMessage = [NSString stringWithFormat:@"指针链解析失败: %@\n\n可能原因:\n• 进程已重启，模块基址改变\n• 指针链中的地址无效\n• 内存访问权限不足\n\n建议删除此无效指针以保持列表整洁", pointerChain];

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"指针无效"
                                                                           message:errorMessage
                                                                    preferredStyle:UIAlertControllerStyleAlert];

            // 添加删除按钮
            UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"删除无效指针"
                                                                   style:UIAlertActionStyleDestructive
                                                                 handler:^(UIAlertAction * _Nonnull action) {
                // 删除无效指针
                [self.storedPointers removeObjectAtIndex:index];
                [self saveStoredPointers];

                // 刷新表格和统计信息
                UITableView *pointerTableView = objc_getAssociatedObject(self, "pointerManagerTableView");
                [pointerTableView reloadData];
                [self updatePointerManagerStats];
                [self updatePointerManagerButtonTitle];

                // 显示删除成功提示
                UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"删除成功"
                                                                                       message:@"无效指针已删除"
                                                                                preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                                   style:UIAlertActionStyleDefault
                                                                 handler:nil];
                [successAlert addAction:okAction];
                [self presentViewController:successAlert animated:YES completion:nil];
            }];
            [alert addAction:deleteAction];

            // 添加重试按钮
            UIAlertAction *retryAction = [UIAlertAction actionWithTitle:@"重试"
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * _Nonnull action) {
                // 重新尝试
                [self restorePointerButtonTapped:sender];
            }];
            [alert addAction:retryAction];

            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                                   style:UIAlertActionStyleCancel
                                                                 handler:nil];
            [alert addAction:cancelAction];

            [self presentViewController:alert animated:YES completion:nil];
            return;
        }

        // 读取当前内存值
        VMMemValueType valueType = (VMMemValueType)[pointerData[@"valueType"] intValue];
        NSString *currentValue = [[VMTool share] getValueFromAddress:finalAddress valueType:valueType];

        // 创建新的记录项
        NSDictionary *record = @{
            @"address": finalAddress,
            @"value": currentValue,
            @"recordName": pointerData[@"recordName"],
            @"valueType": pointerData[@"valueType"],
            @"isActive": @(NO),
            @"pointerChain": pointerChain,
            @"isPointer": @(YES)
        };

        // 添加到记录列表
        if (!self.recordItems) {
            self.recordItems = [NSMutableArray array];
        }
        [self.recordItems addObject:record];

        // 从存储列表中移除
        [self.storedPointers removeObjectAtIndex:index];

        // 保存更改
        [self saveRecords];
        [self saveStoredPointers];

        // 刷新两个表格和统计信息
        [self.recordTableView reloadData];
        UITableView *pointerTableView = objc_getAssociatedObject(self, "pointerManagerTableView");
        [pointerTableView reloadData];
        [self updatePointerManagerStats];
        [self updatePointerManagerButtonTitle];

        // 显示成功提示
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"取出成功"
                                                                       message:[NSString stringWithFormat:@"指针已从存储中取出到记录列表\n指针链: %@\n最终地址: %@", pointerChain, finalAddress]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                           style:UIAlertActionStyleDefault
                                                         handler:nil];
        [alert addAction:okAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

// 带错误信息的指针链地址计算
- (NSString *)calculatePointerChainAddressWithErrorInfo:(NSString *)pointerChain {
    // 检查进程状态
    NSString *pidString = [ProcessManager sharedManager].selectedProcessPID;
    NSString *processName = [ProcessManager sharedManager].selectedProcessName;

    if (!pidString || !processName) {
        return nil;
    }

    // 使用原有的方法，但添加更多错误检查
    NSString *result = [self calculatePointerChainAddress:pointerChain];

    if (!result) {
        // 尝试重新附加进程
        PointerScanManager *pointerManager = [PointerScanManager sharedManager];
        NSError *error = nil;

        if ([pointerManager attachToProcess:[pidString intValue] error:&error]) {
            result = [self calculatePointerChainAddress:pointerChain];
        }
    }

    return result;
}

// 更新管理按钮标题
- (void)updatePointerManagerButtonTitle {
    NSInteger storedCount = self.storedPointers.count;
    if (storedCount > 0) {
        [self.pointerManagerButton setTitle:[NSString stringWithFormat:@"管理(%ld)", (long)storedCount] forState:UIControlStateNormal];
        // 如果有存储的指针，使用不同的颜色提示
        if (@available(iOS 13.0, *)) {
            self.pointerManagerButton.backgroundColor = [UIColor systemBlueColor];
            [self.pointerManagerButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        } else {
            self.pointerManagerButton.backgroundColor = [UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0];
            [self.pointerManagerButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        }
    } else {
        [self.pointerManagerButton setTitle:@"管理" forState:UIControlStateNormal];
        // 恢复默认样式
        self.pointerManagerButton.backgroundColor = [UIColor secondarySystemBackgroundColor];
        if (@available(iOS 13.0, *)) {
            [self.pointerManagerButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
        } else {
            [self.pointerManagerButton setTitleColor:[UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1.0] forState:UIControlStateNormal];
        }
    }
}

// 记录界面修改值弹窗中类型分段控件值改变事件处理
- (void)recordModifyTypeSegmentChanged:(UISegmentedControl *)sender {
    UITextField *valueTextField = objc_getAssociatedObject(self, "modifyValueTextField");
    NSMutableDictionary *record = objc_getAssociatedObject(self, "modifyRecord");

    if (!valueTextField || !record) {
        return;
    }

    // 确保VMTool使用正确的进程上下文
    NSString *pidString = [ProcessManager sharedManager].selectedProcessPID;
    NSString *processName = [ProcessManager sharedManager].selectedProcessName;
    if (pidString && processName) {
        [[VMTool share] setPid:[pidString intValue] name:processName];
    }

    // 获取选中的类型
    NSArray *allKeys = [[VMTool share] allKeys];

    if (sender.selectedSegmentIndex >= 0 && sender.selectedSegmentIndex < allKeys.count) {
        NSString *selectedType = allKeys[sender.selectedSegmentIndex];

        // 获取实时地址
        NSString *currentAddress = nil;
        BOOL isPointer = [record[@"isPointer"] boolValue];

        if (isPointer) {
            // 如果是指针，重新计算指针链地址
            NSString *pointerChain = record[@"pointerChain"];
            if (pointerChain) {
                currentAddress = [self calculatePointerChainAddress:pointerChain];
            }
        } else {
            // 如果是普通地址，直接使用
            currentAddress = record[@"address"];
        }

        if (currentAddress) {
            // 根据选中的类型重新读取内存值
            NSString *currentValue = [self readMemoryValueAtAddress:currentAddress withType:selectedType];

            // 更新输入框的值
            valueTextField.text = currentValue;
        } else {
            // 如果地址无效，显示0
            valueTextField.text = @"0";
        }
    }
}

// 根据指定类型读取指定地址的内存值（与搜索界面相同的实现）
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

@end

