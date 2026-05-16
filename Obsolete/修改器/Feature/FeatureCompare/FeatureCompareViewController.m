#import "FeatureCompareViewController.h"
#import "VMTool.h"
#import "ProcessManager.h"
#import "MemModel.h"

// 特征对比结果模型
@interface FeatureResult : NSObject
@property (nonatomic, strong) NSString *address;
@property (nonatomic, strong) NSString *firstValue;
@property (nonatomic, strong) NSString *secondValue;
@property (nonatomic, assign) NSInteger offset;
@property (nonatomic, assign) BOOL isStable;
@end

@implementation FeatureResult
@end

@interface FeatureCompareViewController ()
@property (nonatomic, assign) BOOL isFirstScanDone;
@property (nonatomic, strong) NSString *baseAddress;
@property (nonatomic, strong) NSDate *firstScanTime;
@property (nonatomic, strong) NSDate *secondScanTime;
@end

@implementation FeatureCompareViewController

- (instancetype)initWithAddresses:(NSArray *)addresses valueType:(VMMemValueType)valueType {
    self = [super init];
    if (self) {
        self.valueType = valueType;
        self.scanRange = 64; // 默认前后64字节
        self.featureResults = [NSMutableArray array];
        self.isFirstScanDone = NO;

        // 生成唯一的会话ID
        self.sessionId = [[NSUUID UUID] UUIDString];

        // 如果提供了地址，使用第一个作为基础地址
        if (addresses.count > 0) {
            self.baseAddress = addresses.firstObject;
        }

        // 尝试加载之前的会话数据
        [self loadSessionData];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    [self setupNavigationBar];
    [self setupUI];
    [self updateUIFromSessionData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = NO;
}

#pragma mark - UI Setup

- (void)setupNavigationBar {
    self.title = @"特征对比";

    // 添加帮助按钮
    UIBarButtonItem *helpButton = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"questionmark.circle"]
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(showHelp)];

    // 添加更多操作按钮
    UIBarButtonItem *moreButton = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"]
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(showMoreOptions)];

    self.navigationItem.rightBarButtonItems = @[moreButton, helpButton];
}

- (void)setupUI {
    // 地址输入框
    UILabel *addressLabel = [[UILabel alloc] init];
    addressLabel.text = @"内存地址:";
    addressLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    addressLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:addressLabel];
    
    self.addressTextField = [[UITextField alloc] init];
    self.addressTextField.placeholder = @"输入内存地址，如: 0x1000000";
    self.addressTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.addressTextField.text = self.baseAddress ?: @"";
    self.addressTextField.clearButtonMode = UITextFieldViewModeWhileEditing; // 添加清除按钮
    self.addressTextField.autocorrectionType = UITextAutocorrectionTypeNo; // 禁用自动纠错
    self.addressTextField.autocapitalizationType = UITextAutocapitalizationTypeNone; // 禁用自动大写
    self.addressTextField.keyboardType = UIKeyboardTypeDefault; // 使用默认键盘
    self.addressTextField.translatesAutoresizingMaskIntoConstraints = NO;

    // 添加长按手势用于快速清除和粘贴
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]
                                              initWithTarget:self
                                              action:@selector(addressFieldLongPressed:)];
    [self.addressTextField addGestureRecognizer:longPress];

    [self.view addSubview:self.addressTextField];
    
    // 数据类型选择
    UILabel *typeLabel = [[UILabel alloc] init];
    typeLabel.text = @"数据类型:";
    typeLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    typeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:typeLabel];

    self.typeSegment = [[UISegmentedControl alloc] initWithItems:@[@"I8", @"I16", @"I32", @"I64", @"F32", @"F64"]];
    // 根据当前valueType设置默认选择
    switch (self.valueType) {
        case VMMemValueTypeSignedByte:
        case VMMemValueTypeUnsignedByte:
            self.typeSegment.selectedSegmentIndex = 0; // I8
            break;
        case VMMemValueTypeSignedShort:
        case VMMemValueTypeUnsignedShort:
            self.typeSegment.selectedSegmentIndex = 1; // I16
            break;
        case VMMemValueTypeSignedInt:
        case VMMemValueTypeUnsignedInt:
            self.typeSegment.selectedSegmentIndex = 2; // I32
            break;
        case VMMemValueTypeSignedLong:
        case VMMemValueTypeUnsignedLong:
            self.typeSegment.selectedSegmentIndex = 3; // I64
            break;
        case VMMemValueTypeFloat:
            self.typeSegment.selectedSegmentIndex = 4; // F32
            break;
        case VMMemValueTypeDouble:
            self.typeSegment.selectedSegmentIndex = 5; // F64
            break;
        default:
            self.typeSegment.selectedSegmentIndex = 2; // 默认I32
            break;
    }
    self.typeSegment.translatesAutoresizingMaskIntoConstraints = NO;
    [self.typeSegment addTarget:self action:@selector(typeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.typeSegment];

    // 扫描范围选择
    UILabel *rangeLabel = [[UILabel alloc] init];
    rangeLabel.text = @"扫描范围:";
    rangeLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    rangeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:rangeLabel];

    self.rangeSegment = [[UISegmentedControl alloc] initWithItems:@[@"32字节", @"64字节", @"128字节", @"256字节", @"自定义"]];
    self.rangeSegment.selectedSegmentIndex = 1; // 默认64字节
    self.rangeSegment.translatesAutoresizingMaskIntoConstraints = NO;
    [self.rangeSegment addTarget:self action:@selector(rangeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.rangeSegment];

    // 范围值显示标签
    self.rangeValueLabel = [[UILabel alloc] init];
    self.rangeValueLabel.text = @"当前: 64 字节";
    self.rangeValueLabel.font = [UIFont systemFontOfSize:14];
    self.rangeValueLabel.textAlignment = NSTextAlignmentCenter;
    self.rangeValueLabel.textColor = [UIColor secondaryLabelColor];
    self.rangeValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.rangeValueLabel];
    
    // 状态标签
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"请输入内存地址，选择扫描范围，然后开始第一次扫描";
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.textColor = [UIColor secondaryLabelColor];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusLabel];
    
    // 扫描按钮
    self.scanButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.scanButton setTitle:@"开始第一次扫描" forState:UIControlStateNormal];
    self.scanButton.backgroundColor = [UIColor systemBlueColor];
    [self.scanButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.scanButton.layer.cornerRadius = 8;
    self.scanButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scanButton addTarget:self action:@selector(startScan) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.scanButton];
    
    // 对比按钮
    self.compareButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.compareButton setTitle:@"开始第二次扫描并对比" forState:UIControlStateNormal];
    self.compareButton.backgroundColor = [UIColor systemGreenColor];
    [self.compareButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.compareButton.layer.cornerRadius = 8;
    self.compareButton.enabled = NO;
    self.compareButton.alpha = 0.5;
    self.compareButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.compareButton addTarget:self action:@selector(startCompare) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.compareButton];
    
    // 结果表格
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];
    
    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        // 地址输入
        [addressLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [addressLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        
        [self.addressTextField.topAnchor constraintEqualToAnchor:addressLabel.bottomAnchor constant:8],
        [self.addressTextField.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.addressTextField.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.addressTextField.heightAnchor constraintEqualToConstant:40],

        // 数据类型选择
        [typeLabel.topAnchor constraintEqualToAnchor:self.addressTextField.bottomAnchor constant:20],
        [typeLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],

        [self.typeSegment.topAnchor constraintEqualToAnchor:typeLabel.bottomAnchor constant:8],
        [self.typeSegment.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.typeSegment.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        // 范围选择
        [rangeLabel.topAnchor constraintEqualToAnchor:self.typeSegment.bottomAnchor constant:20],
        [rangeLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],

        [self.rangeSegment.topAnchor constraintEqualToAnchor:rangeLabel.bottomAnchor constant:8],
        [self.rangeSegment.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.rangeSegment.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        // 范围值标签
        [self.rangeValueLabel.topAnchor constraintEqualToAnchor:self.rangeSegment.bottomAnchor constant:8],
        [self.rangeValueLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.rangeValueLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        // 状态和按钮
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.rangeValueLabel.bottomAnchor constant:15],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        
        [self.scanButton.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:15],
        [self.scanButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.scanButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.scanButton.heightAnchor constraintEqualToConstant:44],
        
        [self.compareButton.topAnchor constraintEqualToAnchor:self.scanButton.bottomAnchor constant:10],
        [self.compareButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.compareButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.compareButton.heightAnchor constraintEqualToConstant:44],
        
        // 表格
        [self.tableView.topAnchor constraintEqualToAnchor:self.compareButton.bottomAnchor constant:20],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
}

#pragma mark - Actions

- (void)typeChanged:(UISegmentedControl *)sender {
    switch (sender.selectedSegmentIndex) {
        case 0: // I8
            self.valueType = VMMemValueTypeSignedByte;
            break;
        case 1: // I16
            self.valueType = VMMemValueTypeSignedShort;
            break;
        case 2: // I32
            self.valueType = VMMemValueTypeSignedInt;
            break;
        case 3: // I64
            self.valueType = VMMemValueTypeSignedLong;
            break;
        case 4: // F32
            self.valueType = VMMemValueTypeFloat;
            break;
        case 5: // F64
            self.valueType = VMMemValueTypeDouble;
            break;
        default:
            self.valueType = VMMemValueTypeSignedInt;
            break;
    }

    NSLog(@"[特征对比] 数据类型已更改为: %ld", (long)self.valueType);
}

- (void)rangeChanged:(UISegmentedControl *)sender {
    if (sender.selectedSegmentIndex == 4) { // 自定义选项
        [self showCustomRangeDialog];
    } else {
        NSArray *ranges = @[@32, @64, @128, @256];
        self.scanRange = [ranges[sender.selectedSegmentIndex] integerValue];
        self.rangeValueLabel.text = [NSString stringWithFormat:@"当前: %ld 字节", (long)self.scanRange];
    }
}

- (void)addressFieldLongPressed:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"地址操作"
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];

        // 清除地址
        UIAlertAction *clearAction = [UIAlertAction actionWithTitle:@"清除地址"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action) {
            self.addressTextField.text = @"";
            [self.addressTextField becomeFirstResponder];
        }];

        // 粘贴地址
        NSString *clipboardText = UIPasteboard.generalPasteboard.string;
        if (clipboardText.length > 0) {
            UIAlertAction *pasteAction = [UIAlertAction actionWithTitle:@"粘贴地址"
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction *action) {
                // 简单验证是否像地址格式
                NSString *text = clipboardText;
                if ([self isValidAddressFormat:text]) {
                    self.addressTextField.text = text;
                } else {
                    // 尝试添加0x前缀
                    if (![text hasPrefix:@"0x"] && ![text hasPrefix:@"0X"]) {
                        text = [NSString stringWithFormat:@"0x%@", text];
                    }
                    self.addressTextField.text = text;
                }
            }];
            [alert addAction:pasteAction];
        }

        // 常用地址快捷输入
        UIAlertAction *commonAction = [UIAlertAction actionWithTitle:@"常用地址"
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *action) {
            [self showCommonAddresses];
        }];

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                               style:UIAlertActionStyleCancel
                                                             handler:nil];

        [alert addAction:clearAction];
        [alert addAction:commonAction];
        [alert addAction:cancelAction];

        // iPad适配
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            alert.popoverPresentationController.sourceView = self.addressTextField;
            alert.popoverPresentationController.sourceRect = self.addressTextField.bounds;
        }

        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (BOOL)isValidAddressFormat:(NSString *)text {
    if (!text || text.length == 0) return NO;

    // 移除空格
    text = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    // 检查是否为十六进制格式
    NSString *hexPattern = @"^(0x|0X)?[0-9a-fA-F]+$";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:hexPattern
                                                                           options:0
                                                                             error:nil];
    NSRange range = NSMakeRange(0, text.length);
    return [regex numberOfMatchesInString:text options:0 range:range] > 0;
}

- (void)showCommonAddresses {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"常用地址"
                                                                   message:@"选择一个常用的内存地址格式"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    NSArray *commonAddresses = @[
        @"0x1000000",
        @"0x2000000",
        @"0x10000000",
        @"0x20000000",
        @"0x100000000",
        @"0x200000000"
    ];

    for (NSString *address in commonAddresses) {
        UIAlertAction *addressAction = [UIAlertAction actionWithTitle:address
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *action) {
            self.addressTextField.text = address;
        }];
        [alert addAction:addressAction];
    }

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showHelp {
    NSString *helpText = @"特征对比功能使用说明：\n\n"
                        @"1. 输入要分析的内存地址\n"
                        @"2. 选择扫描范围（地址前后的字节数）\n"
                        @"3. 进行第一次扫描，记录当前内存状态\n"
                        @"4. 等待游戏状态改变后，进行第二次扫描\n"
                        @"5. 系统会自动对比两次扫描结果\n"
                        @"6. 显示稳定特征（不变的值）和变化特征\n\n"
                        @"稳定特征可以作为更可靠的定位标识使用。";
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"使用帮助" 
                                                                   message:helpText 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" 
                                                       style:UIAlertActionStyleDefault 
                                                     handler:nil];
    
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showMoreOptions {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"更多操作"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    // 导出结果
    UIAlertAction *exportAction = [UIAlertAction actionWithTitle:@"导出对比结果"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
        [self exportResults];
    }];

    // 清除会话数据
    UIAlertAction *clearAction = [UIAlertAction actionWithTitle:@"清除会话数据"
                                                          style:UIAlertActionStyleDestructive
                                                        handler:^(UIAlertAction *action) {
        [self confirmClearSessionData];
    }];

    // 查看会话信息
    UIAlertAction *infoAction = [UIAlertAction actionWithTitle:@"查看会话信息"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action) {
        [self showSessionInfo];
    }];

    // 查看特征文件
    UIAlertAction *filesAction = [UIAlertAction actionWithTitle:@"查看特征文件"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action) {
        [self showFeatureFiles];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [alert addAction:exportAction];
    [alert addAction:infoAction];
    [alert addAction:filesAction];
    [alert addAction:clearAction];
    [alert addAction:cancelAction];

    // iPad适配
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.firstObject;
    }

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showCustomRangeDialog {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"自定义扫描范围"
                                                                   message:@"请输入扫描范围（字节数）"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"例如: 512";
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = [NSString stringWithFormat:@"%ld", (long)self.scanRange];
    }];

    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确定"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {
        UITextField *textField = alert.textFields.firstObject;
        NSString *rangeText = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        if (rangeText.length > 0) {
            NSInteger customRange = [rangeText integerValue];
            if (customRange > 0 && customRange <= 4096) { // 限制最大范围为4KB
                self.scanRange = customRange;
                // 更新分段控件显示
                [self updateRangeSegmentForCustomValue:customRange];
            } else {
                [self showAlert:@"错误" message:@"请输入有效的范围值（1-4096字节）"];
                // 恢复到之前的选择
                [self restorePreviousRangeSelection];
            }
        } else {
            // 恢复到之前的选择
            [self restorePreviousRangeSelection];
        }
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *action) {
        // 恢复到之前的选择
        [self restorePreviousRangeSelection];
    }];

    [alert addAction:confirmAction];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)updateRangeSegmentForCustomValue:(NSInteger)customRange {
    // 检查是否匹配预设值
    NSArray *ranges = @[@32, @64, @128, @256];
    for (NSInteger i = 0; i < ranges.count; i++) {
        if ([ranges[i] integerValue] == customRange) {
            self.rangeSegment.selectedSegmentIndex = i;
            self.rangeValueLabel.text = [NSString stringWithFormat:@"当前: %ld 字节", (long)customRange];
            return;
        }
    }

    // 如果是自定义值，保持"自定义"选项选中
    self.rangeSegment.selectedSegmentIndex = 4;
    self.rangeValueLabel.text = [NSString stringWithFormat:@"当前: %ld 字节 (自定义)", (long)customRange];
}

- (void)restorePreviousRangeSelection {
    // 根据当前scanRange值恢复选择
    NSArray *ranges = @[@32, @64, @128, @256];
    for (NSInteger i = 0; i < ranges.count; i++) {
        if ([ranges[i] integerValue] == self.scanRange) {
            self.rangeSegment.selectedSegmentIndex = i;
            return;
        }
    }

    // 如果是自定义值，保持"自定义"选项选中
    self.rangeSegment.selectedSegmentIndex = 4;
}

- (void)startScan {
    // 验证输入
    NSString *address = [self.addressTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (address.length == 0) {
        [self showAlert:@"错误" message:@"请输入内存地址"];
        return;
    }

    // 检查进程
    if (![ProcessManager sharedManager].selectedProcessPID) {
        [self showAlert:@"错误" message:@"请先选择进程"];
        return;
    }

    // 确保地址格式正确
    if (![address hasPrefix:@"0x"] && ![address hasPrefix:@"0X"]) {
        address = [NSString stringWithFormat:@"0x%@", address];
        self.addressTextField.text = address;
    }

    self.baseAddress = address;

    if (!self.isFirstScanDone) {
        [self performFirstScan];
    } else {
        [self performFirstScan]; // 允许重新开始
    }
}

- (void)startCompare {
    if (!self.isFirstScanDone) {
        [self showAlert:@"错误" message:@"请先完成第一次扫描"];
        return;
    }

    // 验证并更新第二次扫描的地址
    NSString *address = [self.addressTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (address.length == 0) {
        [self showAlert:@"错误" message:@"请输入第二次扫描的内存地址"];
        return;
    }

    // 检查进程
    if (![ProcessManager sharedManager].selectedProcessPID) {
        [self showAlert:@"错误" message:@"请先选择进程"];
        return;
    }

    // 确保地址格式正确
    if (![address hasPrefix:@"0x"] && ![address hasPrefix:@"0X"]) {
        address = [NSString stringWithFormat:@"0x%@", address];
        self.addressTextField.text = address;
    }

    // 更新baseAddress为第二次扫描的新地址
    NSString *oldBaseAddress = self.baseAddress;
    self.baseAddress = address;

    NSLog(@"[特征对比] 第二次扫描 - 旧地址: %@, 新地址: %@", oldBaseAddress, self.baseAddress);

    [self performSecondScanAndCompare];
}

- (void)performFirstScan {
    self.statusLabel.text = @"正在进行第一次扫描...";
    self.scanButton.enabled = NO;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 扫描内存并保存为文本文件
        BOOL success = [self scanAndSaveToFile:@"first_scan.txt" baseAddress:self.baseAddress];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                self.isFirstScanDone = YES;
                self.firstScanTime = [NSDate date];

                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                formatter.dateFormat = @"HH:mm:ss";
                NSString *timeString = [formatter stringFromDate:self.firstScanTime];

                self.statusLabel.text = [NSString stringWithFormat:@"第一次扫描完成 (%@)\n特征数据已保存到文件\n\n💡 提示：现在可以退出应用，改变游戏状态后重新进入进行第二次扫描", timeString];

                [self.scanButton setTitle:@"重新开始第一次扫描" forState:UIControlStateNormal];
                self.scanButton.enabled = YES;
                self.compareButton.enabled = YES;
                self.compareButton.alpha = 1.0;

                // 保存会话数据
                [self saveSessionData];
            } else {
                self.statusLabel.text = @"第一次扫描失败，请检查地址和进程";
                self.scanButton.enabled = YES;
            }
        });
    });
}

- (void)performSecondScanAndCompare {
    self.statusLabel.text = @"正在进行第二次扫描并对比...";
    self.compareButton.enabled = NO;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 扫描内存并保存为文本文件
        BOOL scanSuccess = [self scanAndSaveToFile:@"second_scan.txt" baseAddress:self.baseAddress];

        if (scanSuccess) {
            // 对比两个文本文件
            [self compareTextFiles];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (scanSuccess) {
                self.secondScanTime = [NSDate date];

                NSInteger stableCount = 0;
                NSInteger changedCount = 0;
                for (FeatureResult *result in self.featureResults) {
                    if (result.isStable) {
                        stableCount++;
                    } else {
                        changedCount++;
                    }
                }

                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                formatter.dateFormat = @"HH:mm:ss";
                NSString *timeString = [formatter stringFromDate:self.secondScanTime];

                NSTimeInterval interval = [self.secondScanTime timeIntervalSinceDate:self.firstScanTime];
                NSInteger minutes = (NSInteger)(interval / 60);
                NSInteger seconds = (NSInteger)interval % 60;

                self.statusLabel.text = [NSString stringWithFormat:@"特征对比完成 (%@)\n稳定特征: %ld 个，变化特征: %ld 个\n时间间隔: %ld分%ld秒",
                                        timeString, (long)stableCount, (long)changedCount, (long)minutes, (long)seconds];

                // 刷新表格
                [self.tableView reloadData];

                // 保存会话数据
                [self saveSessionData];
            } else {
                self.statusLabel.text = @"第二次扫描失败，请检查地址和进程";
            }

            self.compareButton.enabled = YES;
        });
    });
}

- (BOOL)scanAndSaveToFile:(NSString *)fileName baseAddress:(NSString *)baseAddress {
    // 解析基础地址
    uint64_t addr = 0;
    NSScanner *scanner = [NSScanner scannerWithString:baseAddress];
    if ([baseAddress hasPrefix:@"0x"] || [baseAddress hasPrefix:@"0X"]) {
        [scanner scanHexLongLong:&addr];
    } else {
        addr = [baseAddress longLongValue];
    }

    // 计算扫描起始地址（向前偏移）
    uint64_t startAddr = addr - self.scanRange;
    NSString *startAddress = [NSString stringWithFormat:@"0x%llX", startAddr];

    // 计算扫描大小（前后范围 * 2）
    NSString *sizeStr = [NSString stringWithFormat:@"%ld", (long)(self.scanRange * 2)];

    NSLog(@"[特征扫描] 基础地址: %@, 扫描范围: %@ - 0x%llX, 大小: %@ 字节",
          baseAddress, startAddress, addr + self.scanRange, sizeStr);

    // 根据数据类型确定扫描类型
    VMMemSearchType scanType = VMMemSearchType_1; // 默认1字节
    switch (self.valueType) {
        case VMMemValueTypeSignedByte:
        case VMMemValueTypeUnsignedByte:
            scanType = VMMemSearchType_1;
            break;
        case VMMemValueTypeSignedShort:
        case VMMemValueTypeUnsignedShort:
            scanType = VMMemSearchType_2;
            break;
        case VMMemValueTypeSignedInt:
        case VMMemValueTypeUnsignedInt:
        case VMMemValueTypeFloat:
            scanType = VMMemSearchType_4;
            break;
        case VMMemValueTypeSignedLong:
        case VMMemValueTypeUnsignedLong:
        case VMMemValueTypeDouble:
            scanType = VMMemSearchType_8;
            break;
        default:
            scanType = VMMemSearchType_4;
            break;
    }

    NSLog(@"[特征扫描] 数据类型: %ld, 扫描类型: %d字节", (long)self.valueType, (int)scanType);

    // 使用VMTool读取内存
    NSArray *memoryResults = [[VMTool share] memory:startAddress
                                               size:sizeStr
                                               type:scanType
                                          valueType:self.valueType];

    if (!memoryResults || memoryResults.count == 0) {
        NSLog(@"[特征扫描] 扫描失败或无结果");
        return NO;
    }

    NSLog(@"[特征扫描] 扫描完成，获得 %lu 个内存地址", (unsigned long)memoryResults.count);

    // 创建特征文件夹
    NSString *featureDir = [self getFeatureCompareDirectory];
    if (!featureDir) {
        NSLog(@"[特征扫描] 无法创建特征文件夹");
        return NO;
    }

    // 生成文本内容
    NSMutableString *textContent = [NSMutableString string];
    [textContent appendFormat:@"# 特征扫描结果 - %@\n", fileName];
    [textContent appendFormat:@"# 基础地址: %@\n", baseAddress];
    [textContent appendFormat:@"# 扫描范围: %ld 字节\n", (long)self.scanRange];
    [textContent appendFormat:@"# 扫描时间: %@\n", [NSDate date]];
    [textContent appendString:@"# 格式: 偏移量:地址:数值\n\n"];

    // 按偏移量排序并写入
    NSLog(@"[特征扫描] 开始保存 %lu 个内存地址", (unsigned long)memoryResults.count);
    for (int i = 0; i < memoryResults.count; i++) {
        MemModel *mem = memoryResults[i];
        uint64_t memAddr = 0;
        NSScanner *memScanner = [NSScanner scannerWithString:mem.address];
        [memScanner scanHexLongLong:&memAddr];

        NSInteger offset = (NSInteger)(memAddr - addr);

        // 实时读取当前内存值，而不是使用缓存的搜索结果
        NSString *currentValue = [[VMTool share] getValueFromAddress:mem.address valueType:self.valueType];

        // 添加调试日志（只显示前几个）
        if (i < 5) {
            NSLog(@"[特征扫描] 地址[%d]: %@ -> 偏移: %+ld, 值: %@", i, mem.address, (long)offset, currentValue);
        }

        [textContent appendFormat:@"%+ld:%@:%@\n", (long)offset, mem.address, currentValue];
    }

    // 保存到文件
    NSString *filePath = [featureDir stringByAppendingPathComponent:fileName];
    NSError *error;
    BOOL success = [textContent writeToFile:filePath
                                 atomically:YES
                                   encoding:NSUTF8StringEncoding
                                      error:&error];

    if (success) {
        NSLog(@"[特征扫描] 特征文件已保存: %@", filePath);
    } else {
        NSLog(@"[特征扫描] 保存失败: %@", error.localizedDescription);
    }

    return success;
}

- (void)compareTextFiles {
    [self.featureResults removeAllObjects];

    NSString *featureDir = [self getFeatureCompareDirectory];
    if (!featureDir) {
        NSLog(@"[文本对比] 特征文件夹不存在");
        return;
    }

    NSString *firstFilePath = [featureDir stringByAppendingPathComponent:@"first_scan.txt"];
    NSString *secondFilePath = [featureDir stringByAppendingPathComponent:@"second_scan.txt"];

    // 读取两个文件
    NSError *error;
    NSString *firstContent = [NSString stringWithContentsOfFile:firstFilePath
                                                       encoding:NSUTF8StringEncoding
                                                          error:&error];
    if (!firstContent) {
        NSLog(@"[文本对比] 无法读取第一次扫描文件: %@", error.localizedDescription);
        return;
    }

    NSString *secondContent = [NSString stringWithContentsOfFile:secondFilePath
                                                        encoding:NSUTF8StringEncoding
                                                           error:&error];
    if (!secondContent) {
        NSLog(@"[文本对比] 无法读取第二次扫描文件: %@", error.localizedDescription);
        return;
    }

    // 解析第一次扫描结果
    NSMutableDictionary *firstScanMap = [NSMutableDictionary dictionary];
    [self parseFeatureFile:firstContent intoMap:firstScanMap];

    // 解析第二次扫描结果
    NSMutableDictionary *secondScanMap = [NSMutableDictionary dictionary];
    [self parseFeatureFile:secondContent intoMap:secondScanMap];

    NSLog(@"[文本对比] 第一次扫描: %lu 个特征, 第二次扫描: %lu 个特征",
          (unsigned long)firstScanMap.count, (unsigned long)secondScanMap.count);

    // 对比相同偏移量的特征
    for (NSNumber *offsetKey in firstScanMap.allKeys) {
        NSDictionary *firstFeature = firstScanMap[offsetKey];
        NSDictionary *secondFeature = secondScanMap[offsetKey];

        if (secondFeature) {
            // 找到相同偏移量的特征
            FeatureResult *result = [[FeatureResult alloc] init];
            result.offset = [offsetKey integerValue];
            result.address = secondFeature[@"address"]; // 使用第二次的地址
            result.firstValue = firstFeature[@"value"];
            result.secondValue = secondFeature[@"value"];
            result.isStable = [result.firstValue isEqualToString:result.secondValue];

            [self.featureResults addObject:result];

            NSLog(@"[文本对比] 偏移 %+ld: %@ -> %@ (%@)",
                  (long)[offsetKey integerValue],
                  result.firstValue,
                  result.secondValue,
                  result.isStable ? @"稳定" : @"变化");
        }
    }

    NSLog(@"[文本对比] 对比完成，找到 %lu 个匹配特征", (unsigned long)self.featureResults.count);
}

- (void)parseFeatureFile:(NSString *)content intoMap:(NSMutableDictionary *)map {
    NSArray *lines = [content componentsSeparatedByString:@"\n"];

    for (NSString *line in lines) {
        // 跳过注释和空行
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmedLine.length == 0 || [trimmedLine hasPrefix:@"#"]) {
            continue;
        }

        // 解析格式: 偏移量:地址:数值
        NSArray *components = [trimmedLine componentsSeparatedByString:@":"];
        if (components.count >= 3) {
            NSInteger offset = [components[0] integerValue];
            NSString *address = components[1];
            NSString *value = components[2];

            map[@(offset)] = @{
                @"address": address,
                @"value": value
            };
        }
    }
}

- (NSString *)getFeatureCompareDirectory {
    // 获取Documents目录
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];

    // 创建特征对比文件夹
    NSString *featureDir = [documentsDirectory stringByAppendingPathComponent:@"特征对比"];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:featureDir]) {
        NSError *error;
        BOOL success = [fileManager createDirectoryAtPath:featureDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
        if (!success) {
            NSLog(@"[文件系统] 创建特征文件夹失败: %@", error.localizedDescription);
            return nil;
        }
    }

    return featureDir;
}

- (void)performFeatureComparison {
    // 这个方法现在由 compareTextFiles 替代
    NSLog(@"[特征对比] 使用文本对比方式，此方法已弃用");
}

// 旧的基础地址获取方法已不再需要，因为我们使用文本文件对比

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2; // 稳定特征 和 变化特征
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger count = 0;
    for (FeatureResult *result in self.featureResults) {
        if ((section == 0 && result.isStable) || (section == 1 && !result.isStable)) {
            count++;
        }
    }
    return count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSInteger count = 0;
    for (FeatureResult *result in self.featureResults) {
        if ((section == 0 && result.isStable) || (section == 1 && !result.isStable)) {
            count++;
        }
    }

    if (section == 0) {
        return [NSString stringWithFormat:@"稳定特征 (%ld)", (long)count];
    } else {
        return [NSString stringWithFormat:@"变化特征 (%ld)", (long)count];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"FeatureCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDetailButton;
    }

    FeatureResult *result = [self getResultForIndexPath:indexPath];

    if (result) {
        if (result.isStable) {
            cell.textLabel.text = [NSString stringWithFormat:@"偏移: %+ld  稳定值: %@", (long)result.offset, result.firstValue];
            cell.textLabel.textColor = [UIColor systemGreenColor];
        } else {
            cell.textLabel.text = [NSString stringWithFormat:@"偏移: %+ld  %@ → %@", (long)result.offset, result.firstValue, result.secondValue];
            cell.textLabel.textColor = [UIColor systemOrangeColor];
        }
        cell.detailTextLabel.text = result.address;
    }

    return cell;
}

- (FeatureResult *)getResultForIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray *sectionResults = [NSMutableArray array];

    for (FeatureResult *result in self.featureResults) {
        if ((indexPath.section == 0 && result.isStable) ||
            (indexPath.section == 1 && !result.isStable)) {
            [sectionResults addObject:result];
        }
    }

    if (indexPath.row < sectionResults.count) {
        return sectionResults[indexPath.row];
    }

    return nil;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    FeatureResult *result = [self getResultForIndexPath:indexPath];
    if (result) {
        [self showFeatureDetail:result];
    }
}

- (void)showFeatureDetail:(FeatureResult *)result {
    NSString *title = result.isStable ? @"稳定特征详情" : @"变化特征详情";
    NSString *message = [NSString stringWithFormat:
        @"地址: %@\n偏移量: %+ld\n第一次值: %@\n第二次值: %@\n状态: %@",
        result.address,
        (long)result.offset,
        result.firstValue,
        result.secondValue,
        result.isStable ? @"稳定" : @"变化"
    ];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"复制地址"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action) {
        UIPasteboard.generalPasteboard.string = result.address;
        [self showAlert:@"已复制" message:@"地址已复制到剪贴板"];
    }];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];

    [alert addAction:copyAction];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Helper Methods

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

- (void)updateUIFromSessionData {
    // 更新地址输入框
    if (self.baseAddress) {
        self.addressTextField.text = self.baseAddress;
    }

    // 更新范围选择
    [self updateRangeSegmentForCustomValue:self.scanRange];

    // 更新按钮状态和文本
    if (self.isFirstScanDone) {
        [self.scanButton setTitle:@"重新开始第一次扫描" forState:UIControlStateNormal];
        self.compareButton.enabled = YES;
        self.compareButton.alpha = 1.0;

        // 更新状态标签
        if (self.featureResults.count > 0) {
            NSInteger stableCount = 0;
            NSInteger changedCount = 0;
            for (FeatureResult *result in self.featureResults) {
                if (result.isStable) {
                    stableCount++;
                } else {
                    changedCount++;
                }
            }

            if (self.secondScanTime) {
                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                formatter.dateFormat = @"HH:mm:ss";
                NSString *timeString = [formatter stringFromDate:self.secondScanTime];

                NSTimeInterval interval = [self.secondScanTime timeIntervalSinceDate:self.firstScanTime];
                NSInteger minutes = (NSInteger)(interval / 60);
                NSInteger seconds = (NSInteger)interval % 60;

                self.statusLabel.text = [NSString stringWithFormat:@"已恢复会话数据\n特征对比完成 (%@)\n稳定特征: %ld 个，变化特征: %ld 个\n时间间隔: %ld分%ld秒",
                                        timeString, (long)stableCount, (long)changedCount, (long)minutes, (long)seconds];
            } else {
                self.statusLabel.text = [NSString stringWithFormat:@"已恢复会话数据\n稳定特征: %ld 个，变化特征: %ld 个", (long)stableCount, (long)changedCount];
            }
        } else if (self.firstScanTime) {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = @"HH:mm:ss";
            NSString *timeString = [formatter stringFromDate:self.firstScanTime];

            self.statusLabel.text = [NSString stringWithFormat:@"已恢复会话数据\n第一次扫描完成 (%@)\n\n💡 提示：现在可以进行第二次扫描对比", timeString];
        }

        // 刷新表格
        [self.tableView reloadData];
    }
}

#pragma mark - 数据持久化

- (void)saveSessionData {
    NSMutableDictionary *sessionData = [NSMutableDictionary dictionary];

    // 基本信息
    if (self.baseAddress) sessionData[@"baseAddress"] = self.baseAddress;
    sessionData[@"scanRange"] = @(self.scanRange);
    sessionData[@"valueType"] = @(self.valueType);
    sessionData[@"isFirstScanDone"] = @(self.isFirstScanDone);

    // 保存第一次扫描的基础地址（用于跨会话特征对比）
    if (self.isFirstScanDone && self.baseAddress) {
        // 第一次扫描完成时，保存当前的baseAddress作为第一次的基础地址
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *existingFirstBase = [defaults objectForKey:@"FeatureCompare_FirstBaseAddress"];
        if (!existingFirstBase) {
            // 只在第一次保存时设置，避免第二次扫描时覆盖
            [defaults setObject:self.baseAddress forKey:@"FeatureCompare_FirstBaseAddress"];
            [defaults synchronize];
            NSLog(@"[特征对比] 保存第一次基础地址: %@", self.baseAddress);
        }
    }

    // 时间信息
    if (self.firstScanTime) sessionData[@"firstScanTime"] = self.firstScanTime;
    if (self.secondScanTime) sessionData[@"secondScanTime"] = self.secondScanTime;

    // 扫描结果
    if (self.firstScanResults) {
        NSMutableArray *firstResults = [NSMutableArray array];
        for (MemModel *mem in self.firstScanResults) {
            [firstResults addObject:@{
                @"address": mem.address ?: @"",
                @"value": mem.value ?: @""
            }];
        }
        sessionData[@"firstScanResults"] = firstResults;
    }

    if (self.secondScanResults) {
        NSMutableArray *secondResults = [NSMutableArray array];
        for (MemModel *mem in self.secondScanResults) {
            [secondResults addObject:@{
                @"address": mem.address ?: @"",
                @"value": mem.value ?: @""
            }];
        }
        sessionData[@"secondScanResults"] = secondResults;
    }

    // 特征对比结果
    if (self.featureResults.count > 0) {
        NSMutableArray *features = [NSMutableArray array];
        for (FeatureResult *result in self.featureResults) {
            [features addObject:@{
                @"address": result.address ?: @"",
                @"firstValue": result.firstValue ?: @"",
                @"secondValue": result.secondValue ?: @"",
                @"offset": @(result.offset),
                @"isStable": @(result.isStable)
            }];
        }
        sessionData[@"featureResults"] = features;
    }

    // 保存到UserDefaults
    NSString *key = [NSString stringWithFormat:@"FeatureCompareSession_%@", self.sessionId];
    [[NSUserDefaults standardUserDefaults] setObject:sessionData forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSLog(@"会话数据已保存: %@, 数据内容: %@", key, sessionData);
}

- (void)loadSessionData {
    // 尝试加载最近的会话
    NSString *key = [self findLatestSessionKey];
    NSLog(@"尝试加载会话数据，找到的最新会话key: %@", key);
    if (!key) {
        NSLog(@"没有找到会话数据");
        return;
    }

    NSDictionary *sessionData = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    NSLog(@"会话数据内容: %@", sessionData);
    if (!sessionData) {
        NSLog(@"会话数据为空");
        return;
    }

    // 恢复基本信息
    self.baseAddress = sessionData[@"baseAddress"];
    self.scanRange = [sessionData[@"scanRange"] integerValue];
    self.valueType = [sessionData[@"valueType"] integerValue];
    self.isFirstScanDone = [sessionData[@"isFirstScanDone"] boolValue];

    NSLog(@"恢复的数据 - baseAddress: %@, scanRange: %ld, valueType: %ld, isFirstScanDone: %d",
          self.baseAddress, (long)self.scanRange, (long)self.valueType, self.isFirstScanDone);

    // 恢复时间信息
    self.firstScanTime = sessionData[@"firstScanTime"];
    self.secondScanTime = sessionData[@"secondScanTime"];

    // 恢复扫描结果（这里简化处理，实际应用中可能需要重新创建MemModel对象）
    // 由于MemModel的复杂性，这里只恢复基本的特征结果

    // 恢复特征对比结果
    NSArray *featuresData = sessionData[@"featureResults"];
    if (featuresData) {
        [self.featureResults removeAllObjects];
        for (NSDictionary *featureDict in featuresData) {
            FeatureResult *result = [[FeatureResult alloc] init];
            result.address = featureDict[@"address"];
            result.firstValue = featureDict[@"firstValue"];
            result.secondValue = featureDict[@"secondValue"];
            result.offset = [featureDict[@"offset"] integerValue];
            result.isStable = [featureDict[@"isStable"] boolValue];
            [self.featureResults addObject:result];
        }
        NSLog(@"恢复了 %ld 个特征结果", (long)self.featureResults.count);
    }

    NSLog(@"会话数据已加载: %@", key);
}

- (NSString *)findLatestSessionKey {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *allDefaults = [defaults dictionaryRepresentation];

    NSString *latestKey = nil;
    NSDate *latestDate = nil;

    for (NSString *key in allDefaults.allKeys) {
        if ([key hasPrefix:@"FeatureCompareSession_"]) {
            NSDictionary *sessionData = allDefaults[key];
            NSDate *firstScanTime = sessionData[@"firstScanTime"];

            if (firstScanTime && (!latestDate || [firstScanTime compare:latestDate] == NSOrderedDescending)) {
                latestDate = firstScanTime;
                latestKey = key;
            }
        }
    }

    return latestKey;
}

- (void)clearSessionData {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *allDefaults = [defaults dictionaryRepresentation];

    // 清除所有特征对比会话数据
    for (NSString *key in allDefaults.allKeys) {
        if ([key hasPrefix:@"FeatureCompareSession_"]) {
            [defaults removeObjectForKey:key];
        }
    }

    // 清除第一次基础地址记录
    [defaults removeObjectForKey:@"FeatureCompare_FirstBaseAddress"];
    [defaults synchronize];

    // 删除扫描文件
    [self deleteScanFiles];

    // 重置当前数据
    self.firstScanResults = nil;
    self.secondScanResults = nil;
    [self.featureResults removeAllObjects];
    self.isFirstScanDone = NO;
    self.firstScanTime = nil;
    self.secondScanTime = nil;

    self.statusLabel.text = @"会话数据和扫描文件已清除，请重新开始扫描";
    [self.scanButton setTitle:@"开始第一次扫描" forState:UIControlStateNormal];
    self.compareButton.enabled = NO;
    self.compareButton.alpha = 0.5;

    [self.tableView reloadData];
}

- (void)deleteScanFiles {
    NSString *featureDir = [self getFeatureCompareDirectory];
    if (!featureDir) {
        NSLog(@"[文件清理] 无法获取特征对比目录");
        return;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;

    // 删除第一次扫描文件
    NSString *firstScanPath = [featureDir stringByAppendingPathComponent:@"first_scan.txt"];
    if ([fileManager fileExistsAtPath:firstScanPath]) {
        BOOL success = [fileManager removeItemAtPath:firstScanPath error:&error];
        if (success) {
            NSLog(@"[文件清理] 已删除第一次扫描文件: %@", firstScanPath);
        } else {
            NSLog(@"[文件清理] 删除第一次扫描文件失败: %@", error.localizedDescription);
        }
    }

    // 删除第二次扫描文件
    NSString *secondScanPath = [featureDir stringByAppendingPathComponent:@"second_scan.txt"];
    if ([fileManager fileExistsAtPath:secondScanPath]) {
        BOOL success = [fileManager removeItemAtPath:secondScanPath error:&error];
        if (success) {
            NSLog(@"[文件清理] 已删除第二次扫描文件: %@", secondScanPath);
        } else {
            NSLog(@"[文件清理] 删除第二次扫描文件失败: %@", error.localizedDescription);
        }
    }

    // 删除所有特征对比结果文件（以"特征对比结果_"开头的文件）
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:featureDir error:&error];
    if (contents) {
        for (NSString *fileName in contents) {
            if ([fileName hasPrefix:@"特征对比结果_"] && [fileName hasSuffix:@".txt"]) {
                NSString *filePath = [featureDir stringByAppendingPathComponent:fileName];
                BOOL success = [fileManager removeItemAtPath:filePath error:&error];
                if (success) {
                    NSLog(@"[文件清理] 已删除特征对比结果文件: %@", fileName);
                } else {
                    NSLog(@"[文件清理] 删除特征对比结果文件失败: %@", error.localizedDescription);
                }
            }
        }
    } else {
        NSLog(@"[文件清理] 读取目录内容失败: %@", error.localizedDescription);
    }
}

- (void)confirmClearSessionData {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认清除"
                                                                   message:@"这将清除所有保存的特征对比数据，确定要继续吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确定清除"
                                                            style:UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction *action) {
        [self clearSessionData];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [alert addAction:confirmAction];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showSessionInfo {
    NSMutableString *info = [NSMutableString string];

    if (self.baseAddress) {
        [info appendFormat:@"基础地址: %@\n", self.baseAddress];
    }

    [info appendFormat:@"扫描范围: %ld 字节\n", (long)self.scanRange];

    if (self.firstScanTime) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
        [info appendFormat:@"第一次扫描: %@\n", [formatter stringFromDate:self.firstScanTime]];
    }

    if (self.secondScanTime) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
        [info appendFormat:@"第二次扫描: %@\n", [formatter stringFromDate:self.secondScanTime]];

        NSTimeInterval interval = [self.secondScanTime timeIntervalSinceDate:self.firstScanTime];
        NSInteger minutes = (NSInteger)(interval / 60);
        NSInteger seconds = (NSInteger)interval % 60;
        [info appendFormat:@"时间间隔: %ld分%ld秒\n", (long)minutes, (long)seconds];
    }

    [info appendFormat:@"特征结果: %lu 个", (unsigned long)self.featureResults.count];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"会话信息"
                                                                   message:info
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];

    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showFeatureFiles {
    NSString *featureDir = [self getFeatureCompareDirectory];
    if (!featureDir) {
        [self showAlert:@"错误" message:@"特征文件夹不存在"];
        return;
    }

    NSString *firstFilePath = [featureDir stringByAppendingPathComponent:@"first_scan.txt"];
    NSString *secondFilePath = [featureDir stringByAppendingPathComponent:@"second_scan.txt"];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL firstExists = [fileManager fileExistsAtPath:firstFilePath];
    BOOL secondExists = [fileManager fileExistsAtPath:secondFilePath];

    NSMutableString *info = [NSMutableString string];
    [info appendFormat:@"📄 文件状态:\n"];
    [info appendFormat:@"第一次扫描: %@\n", firstExists ? @"✅ first_scan.txt" : @"❌ 未生成"];
    [info appendFormat:@"第二次扫描: %@\n\n", secondExists ? @"✅ second_scan.txt" : @"❌ 未生成"];

    if (firstExists) {
        NSError *error;
        NSString *firstContent = [NSString stringWithContentsOfFile:firstFilePath
                                                           encoding:NSUTF8StringEncoding
                                                              error:&error];
        if (firstContent) {
            NSArray *lines = [firstContent componentsSeparatedByString:@"\n"];
            NSInteger dataLines = 0;
            for (NSString *line in lines) {
                if (![line hasPrefix:@"#"] && line.length > 0) {
                    dataLines++;
                }
            }
            [info appendFormat:@"第一次扫描: %ld 个特征\n", (long)dataLines];
        }
    }

    if (secondExists) {
        NSError *error;
        NSString *secondContent = [NSString stringWithContentsOfFile:secondFilePath
                                                            encoding:NSUTF8StringEncoding
                                                               error:&error];
        if (secondContent) {
            NSArray *lines = [secondContent componentsSeparatedByString:@"\n"];
            NSInteger dataLines = 0;
            for (NSString *line in lines) {
                if (![line hasPrefix:@"#"] && line.length > 0) {
                    dataLines++;
                }
            }
            [info appendFormat:@"第二次扫描: %ld 个特征\n", (long)dataLines];
        }
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"特征文件信息"
                                                                   message:info
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];

    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)exportResults {
    if (self.featureResults.count == 0) {
        [self showAlert:@"提示" message:@"没有可导出的对比结果"];
        return;
    }

    // 生成导出内容
    NSMutableString *exportText = [NSMutableString string];
    [exportText appendString:@"特征对比结果导出\n"];
    [exportText appendString:@"==================\n\n"];

    if (self.baseAddress) {
        [exportText appendFormat:@"基础地址: %@\n", self.baseAddress];
    }
    [exportText appendFormat:@"扫描范围: %ld 字节\n", (long)self.scanRange];

    // 添加特征文件路径信息
    NSString *featureDir = [self getFeatureCompareDirectory];
    if (featureDir) {
        [exportText appendFormat:@"特征文件目录: %@\n", featureDir];
        [exportText appendString:@"第一次扫描文件: first_scan.txt\n"];
        [exportText appendString:@"第二次扫描文件: second_scan.txt\n"];
    }

    if (self.firstScanTime && self.secondScanTime) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
        [exportText appendFormat:@"第一次扫描: %@\n", [formatter stringFromDate:self.firstScanTime]];
        [exportText appendFormat:@"第二次扫描: %@\n", [formatter stringFromDate:self.secondScanTime]];

        NSTimeInterval interval = [self.secondScanTime timeIntervalSinceDate:self.firstScanTime];
        NSInteger minutes = (NSInteger)(interval / 60);
        NSInteger seconds = (NSInteger)interval % 60;
        [exportText appendFormat:@"时间间隔: %ld分%ld秒\n", (long)minutes, (long)seconds];
    }

    // 统计数量
    NSInteger stableCount = 0;
    NSInteger changedCount = 0;
    for (FeatureResult *result in self.featureResults) {
        if (result.isStable) {
            stableCount++;
        } else {
            changedCount++;
        }
    }

    [exportText appendFormat:@"稳定特征数量: %ld\n", (long)stableCount];
    [exportText appendFormat:@"变化特征数量: %ld\n", (long)changedCount];

    [exportText appendString:@"\n稳定特征:\n"];
    [exportText appendString:@"----------\n"];
    if (stableCount == 0) {
        [exportText appendString:@"无稳定特征\n"];
    } else {
        for (FeatureResult *result in self.featureResults) {
            if (result.isStable) {
                [exportText appendFormat:@"地址: %@, 偏移: %+ld, 值: %@\n",
                 result.address, (long)result.offset, result.firstValue];
            }
        }
    }

    [exportText appendString:@"\n变化特征:\n"];
    [exportText appendString:@"----------\n"];
    if (changedCount == 0) {
        [exportText appendString:@"无变化特征\n"];
    } else {
        for (FeatureResult *result in self.featureResults) {
            if (!result.isStable) {
                [exportText appendFormat:@"地址: %@, 偏移: %+ld, %@ → %@\n",
                 result.address, (long)result.offset, result.firstValue, result.secondValue];
            }
        }
    }

    // 保存为txt文件
    [self saveTextToFile:exportText];
}

- (void)saveTextToFile:(NSString *)text {
    // 生成文件名
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMdd_HHmmss";
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    NSString *fileName = [NSString stringWithFormat:@"特征对比结果_%@.txt", timestamp];

    // 获取Documents目录
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:fileName];

    // 写入文件
    NSError *error;
    BOOL success = [text writeToFile:filePath
                          atomically:YES
                            encoding:NSUTF8StringEncoding
                               error:&error];

    if (success) {
        // 显示成功提示和选项
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"导出成功"
                                                                       message:[NSString stringWithFormat:@"文件已保存到:\n%@", filePath]
                                                                preferredStyle:UIAlertControllerStyleAlert];

        // 复制路径
        UIAlertAction *copyPathAction = [UIAlertAction actionWithTitle:@"复制文件路径"
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction *action) {
            UIPasteboard.generalPasteboard.string = filePath;
            [self showAlert:@"已复制" message:@"文件路径已复制到剪贴板"];
        }];

        // 复制内容
        UIAlertAction *copyContentAction = [UIAlertAction actionWithTitle:@"复制文件内容"
                                                                    style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction *action) {
            UIPasteboard.generalPasteboard.string = text;
            [self showAlert:@"已复制" message:@"文件内容已复制到剪贴板"];
        }];

        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                           style:UIAlertActionStyleDefault
                                                         handler:nil];

        [alert addAction:copyPathAction];
        [alert addAction:copyContentAction];
        [alert addAction:okAction];
        [self presentViewController:alert animated:YES completion:nil];

    } else {
        [self showAlert:@"导出失败" message:[NSString stringWithFormat:@"无法保存文件: %@", error.localizedDescription]];
    }
}

@end
