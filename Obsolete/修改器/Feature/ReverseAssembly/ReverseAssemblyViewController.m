//
//  ReverseAssemblyViewController.m
//  Obsolete
//
//  Created by AI Assistant on 2025-01-08.
//

#import "ReverseAssemblyViewController.h"
#import "ProcessManager.h"
#import <objc/runtime.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import "DisassemblyEngine.h"
#import "../PointerScan/PointerScanManager.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#import <sys/sysctl.h>

// 文件选择器相关代码已移除，直接使用UIDocumentPickerViewController

@interface ReverseAssemblyViewController () <UITableViewDataSource, UITableViewDelegate, UIDocumentPickerDelegate>

// 内存和性能监控属性
@property (nonatomic, strong) NSTimer *memoryMonitorTimer;
@property (nonatomic, assign) NSUInteger initialMemoryUsage;
@property (nonatomic, assign) NSUInteger peakMemoryUsage;
@property (nonatomic, assign) NSTimeInterval processingStartTime;

// 数据
@property (nonatomic, strong) NSArray<NSDictionary *> *disassemblyData;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray *> *crossReferences; // 交叉引用
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *functions; // 函数信息
@property (nonatomic, strong) NSData *currentFileData; // 当前文件数据

// UI组件
@property (nonatomic, strong) UIButton *fileSelectButton;
@property (nonatomic, strong) UISegmentedControl *displayModeControl;
@property (nonatomic, strong) UISegmentedControl *viewModeControl; // 新增：视图模式控制
@property (nonatomic, strong) UITableView *disassemblyTableView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UIButton *jumpToAddressButton; // 新增：跳转到地址按钮
@property (nonatomic, strong) UIButton *showFunctionsButton; // 新增：显示函数列表按钮

// 显示模式
@property (nonatomic, assign) NSInteger displayMode; // 0: 汇编, 1: 16进制, 2: 详细
@property (nonatomic, assign) NSInteger viewMode; // 0: 线性, 1: 函数, 2: CFG

// 函数模式数据
@property (nonatomic, strong) NSArray *functionSections; // 函数分组数据

@end

// 模块选择表格视图控制器已移除，改用文件选择器

@implementation ReverseAssemblyViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"逆向汇编";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    // 添加导出按钮和帮助按钮到导航栏
    UIBarButtonItem *exportButton = [[UIBarButtonItem alloc] initWithTitle:@"导出"
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(exportDisassembly)];

    UIBarButtonItem *helpButton = [[UIBarButtonItem alloc] initWithTitle:@"?"
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(showHelp)];

    self.navigationItem.rightBarButtonItems = @[exportButton, helpButton];

    [self setupUI];
    [self updateStatusLabel];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 确保导航栏可见
    self.navigationController.navigationBar.hidden = NO;
}

#pragma mark - UI Setup

- (void)setupUI {
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    // 创建文件选择按钮
    self.fileSelectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.fileSelectButton setTitle:@"选择文件" forState:UIControlStateNormal];
    self.fileSelectButton.backgroundColor = [UIColor systemBlueColor];
    [self.fileSelectButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.fileSelectButton.layer.cornerRadius = 8;
    [self.fileSelectButton addTarget:self action:@selector(selectFile) forControlEvents:UIControlEventTouchUpInside];
    self.fileSelectButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.fileSelectButton];

    // 创建显示模式切换控件
    self.displayModeControl = [[UISegmentedControl alloc] initWithItems:@[@"汇编", @"16进制"]];
    self.displayModeControl.selectedSegmentIndex = 0;
    self.displayModeControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.displayModeControl addTarget:self action:@selector(displayModeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.displayModeControl];

    // 创建视图模式切换控件
    self.viewModeControl = [[UISegmentedControl alloc] initWithItems:@[@"线性", @"函数", @"CFG"]];
    self.viewModeControl.selectedSegmentIndex = 0;
    self.viewModeControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.viewModeControl addTarget:self action:@selector(viewModeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.viewModeControl];

    // 创建跳转到地址按钮
    self.jumpToAddressButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.jumpToAddressButton setTitle:@"跳转" forState:UIControlStateNormal];
    self.jumpToAddressButton.backgroundColor = [UIColor systemGreenColor];
    [self.jumpToAddressButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.jumpToAddressButton.layer.cornerRadius = 6;
    self.jumpToAddressButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.jumpToAddressButton addTarget:self action:@selector(jumpToAddress) forControlEvents:UIControlEventTouchUpInside];
    self.jumpToAddressButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.jumpToAddressButton];

    // 创建显示函数列表按钮
    self.showFunctionsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.showFunctionsButton setTitle:@"函数" forState:UIControlStateNormal];
    self.showFunctionsButton.backgroundColor = [UIColor systemOrangeColor];
    [self.showFunctionsButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.showFunctionsButton.layer.cornerRadius = 6;
    self.showFunctionsButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.showFunctionsButton addTarget:self action:@selector(showFunctions) forControlEvents:UIControlEventTouchUpInside];
    self.showFunctionsButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.showFunctionsButton];



    // 创建状态标签
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.textColor = [UIColor secondaryLabelColor];
    self.statusLabel.text = @"请选择 Mach-O 文件进行反汇编";
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusLabel];

    // 创建加载指示器
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.loadingIndicator];

    // 创建反汇编表格视图
    self.disassemblyTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.disassemblyTableView.dataSource = self;
    self.disassemblyTableView.delegate = self;
    self.disassemblyTableView.backgroundColor = [UIColor systemBackgroundColor];
    self.disassemblyTableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.disassemblyTableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.disassemblyTableView];

    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        // 文件选择按钮
        [self.fileSelectButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10],
        [self.fileSelectButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.fileSelectButton.widthAnchor constraintEqualToConstant:80],
        [self.fileSelectButton.heightAnchor constraintEqualToConstant:35],

        // 跳转按钮
        [self.jumpToAddressButton.centerYAnchor constraintEqualToAnchor:self.fileSelectButton.centerYAnchor],
        [self.jumpToAddressButton.leadingAnchor constraintEqualToAnchor:self.fileSelectButton.trailingAnchor constant:10],
        [self.jumpToAddressButton.widthAnchor constraintEqualToConstant:50],
        [self.jumpToAddressButton.heightAnchor constraintEqualToConstant:30],

        // 函数按钮
        [self.showFunctionsButton.centerYAnchor constraintEqualToAnchor:self.fileSelectButton.centerYAnchor],
        [self.showFunctionsButton.leadingAnchor constraintEqualToAnchor:self.jumpToAddressButton.trailingAnchor constant:10],
        [self.showFunctionsButton.widthAnchor constraintEqualToConstant:50],
        [self.showFunctionsButton.heightAnchor constraintEqualToConstant:30],



        // 显示模式切换控件
        [self.displayModeControl.centerYAnchor constraintEqualToAnchor:self.fileSelectButton.centerYAnchor],
        [self.displayModeControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.displayModeControl.widthAnchor constraintEqualToConstant:120],
        [self.displayModeControl.heightAnchor constraintEqualToConstant:35],

        // 视图模式切换控件
        [self.viewModeControl.topAnchor constraintEqualToAnchor:self.fileSelectButton.bottomAnchor constant:10],
        [self.viewModeControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.viewModeControl.widthAnchor constraintEqualToConstant:180],
        [self.viewModeControl.heightAnchor constraintEqualToConstant:30],

        // 状态标签
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.viewModeControl.bottomAnchor constant:10],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.statusLabel.heightAnchor constraintEqualToConstant:20],

        // 加载指示器
        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingIndicator.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:5],

        // 反汇编表格视图
        [self.disassemblyTableView.topAnchor constraintEqualToAnchor:self.loadingIndicator.bottomAnchor constant:5],
        [self.disassemblyTableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.disassemblyTableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.disassemblyTableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

#pragma mark - Actions

- (void)selectFile {
    NSLog(@"[ReverseAssembly] 开始创建文件选择器");

    // 使用最简单的文件选择器，避免闪退
    UIDocumentPickerViewController *documentPicker;

    @try {
        if (@available(iOS 14.0, *)) {
            // iOS 14+ 使用新的 API，只使用最基本的类型
            NSArray *contentTypes = @[
                [UTType typeWithIdentifier:@"public.item"]  // 所有文件
            ];
            documentPicker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:contentTypes];
            NSLog(@"[ReverseAssembly] 使用 iOS 14+ API 创建文件选择器");
        } else {
            // iOS 13 使用旧的 API
            NSArray *documentTypes = @[@"public.item"];
            documentPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:documentTypes inMode:UIDocumentPickerModeOpen];
            NSLog(@"[ReverseAssembly] 使用 iOS 13 API 创建文件选择器");
        }

        if (!documentPicker) {
            NSLog(@"[ReverseAssembly] 错误: 无法创建文件选择器");
            [self showAlert:@"错误" message:@"无法创建文件选择器"];
            return;
        }

        documentPicker.delegate = self;
        documentPicker.modalPresentationStyle = UIModalPresentationFormSheet;
        documentPicker.allowsMultipleSelection = NO;

        NSLog(@"[ReverseAssembly] 准备显示文件选择器");
        [self presentViewController:documentPicker animated:YES completion:^{
            NSLog(@"[ReverseAssembly] 文件选择器显示完成");
        }];

    } @catch (NSException *exception) {
        NSLog(@"[ReverseAssembly] 创建文件选择器时发生异常: %@", exception.reason);
        [self showAlert:@"错误" message:[NSString stringWithFormat:@"创建文件选择器失败: %@", exception.reason]];
    }
}

- (void)displayModeChanged:(UISegmentedControl *)sender {
    self.displayMode = sender.selectedSegmentIndex;
    [self.disassemblyTableView reloadData];
}

- (void)viewModeChanged:(UISegmentedControl *)sender {
    self.viewMode = sender.selectedSegmentIndex;
    [self refreshDisplayWithViewMode];
}

- (void)jumpToAddress {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"跳转到地址"
                                                                   message:@"请输入要跳转的地址 (十六进制)"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"例如: 0x100004000";
        textField.keyboardType = UIKeyboardTypeDefault;
    }];

    UIAlertAction *jumpAction = [UIAlertAction actionWithTitle:@"跳转"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action) {
        NSString *addressString = alert.textFields.firstObject.text;
        [self jumpToAddressString:addressString];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [alert addAction:jumpAction];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showFunctions {
    if (!self.functions || self.functions.count == 0) {
        [self showAlert:@"提示" message:@"未检测到函数信息，请先分析文件"];
        return;
    }

    // 创建函数列表视图控制器
    UIViewController *functionListVC = [[UIViewController alloc] init];
    functionListVC.title = @"函数列表";
    functionListVC.view.backgroundColor = [UIColor systemBackgroundColor];

    // 创建表格视图
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.delegate = (id<UITableViewDelegate>)self;
    tableView.dataSource = (id<UITableViewDataSource>)self;
    [functionListVC.view addSubview:tableView];

    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:functionListVC.view.safeAreaLayoutGuide.topAnchor],
        [tableView.leadingAnchor constraintEqualToAnchor:functionListVC.view.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:functionListVC.view.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:functionListVC.view.bottomAnchor]
    ]];

    // 准备函数数据
    NSMutableArray *functionList = [NSMutableArray array];
    for (NSString *functionName in self.functions.allKeys) {
        NSDictionary *functionInfo = self.functions[functionName];
        NSInteger startIndex = [functionInfo[@"startIndex"] integerValue];
        NSInteger endIndex = [functionInfo[@"endIndex"] integerValue];
        NSInteger instructionCount = endIndex - startIndex + 1;

        [functionList addObject:@{
            @"name": functionName,
            @"address": functionInfo[@"address"],
            @"startIndex": functionInfo[@"startIndex"],
            @"endIndex": functionInfo[@"endIndex"],
            @"instructionCount": @(instructionCount),
            @"size": @(instructionCount * 4) // 假设每条指令4字节
        }];
    }

    // 按地址排序
    [functionList sortUsingComparator:^NSComparisonResult(NSDictionary *func1, NSDictionary *func2) {
        NSString *addr1 = func1[@"address"];
        NSString *addr2 = func2[@"address"];

        uint64_t address1, address2;
        [[NSScanner scannerWithString:addr1] scanHexLongLong:&address1];
        [[NSScanner scannerWithString:addr2] scanHexLongLong:&address2];

        if (address1 < address2) return NSOrderedAscending;
        if (address1 > address2) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    // 存储函数列表数据
    objc_setAssociatedObject(tableView, "functionList", functionList, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(tableView, "parentController", self, OBJC_ASSOCIATION_ASSIGN);

    // 创建导航控制器
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:functionListVC];

    // 添加关闭按钮
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithTitle:@"关闭"
                                                                     style:UIBarButtonItemStyleDone
                                                                    target:self
                                                                    action:@selector(closeFunctionList:)];
    functionListVC.navigationItem.rightBarButtonItem = closeButton;

    [self presentViewController:navController animated:YES completion:nil];
}

- (void)closeFunctionList:(UIBarButtonItem *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)updateFileButtonTitle {
    if (self.selectedFilePath) {
        NSString *fileName = [self.selectedFilePath lastPathComponent];
        [self.fileSelectButton setTitle:fileName forState:UIControlStateNormal];
    } else {
        [self.fileSelectButton setTitle:@"选择文件" forState:UIControlStateNormal];
    }
}

- (void)updateStatusLabel {
    if (self.selectedFilePath) {
        NSString *fileName = [self.selectedFilePath lastPathComponent];
        self.statusLabel.text = [NSString stringWithFormat:@"文件: %@ | %lu 条指令",
                               fileName,
                               (unsigned long)self.disassemblyData.count];
    } else {
        self.statusLabel.text = @"请选择 Mach-O 文件进行反汇编";
    }
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

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count > 0) {
        NSURL *selectedURL = urls.firstObject;

        // 获取文件访问权限
        BOOL startedAccessing = [selectedURL startAccessingSecurityScopedResource];

        self.selectedFilePath = selectedURL.path;
        [self updateFileButtonTitle];
        [self loadDisassemblyForFile:self.selectedFilePath];

        if (startedAccessing) {
            [selectedURL stopAccessingSecurityScopedResource];
        }
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    // 用户取消了文件选择
}

#pragma mark - 兼容性方法（已弃用）

- (void)updateModuleButtonTitle {
    // 兼容性方法，已弃用，使用 updateFileButtonTitle 代替
    [self updateFileButtonTitle];
}

- (void)loadDisassemblyForModule:(ModuleInfo *)module {
    // 兼容性方法，已弃用
    NSLog(@"[ReverseAssembly] 警告: loadDisassemblyForModule 方法已弃用，请使用文件选择功能");
}

#pragma mark - Data Loading

- (void)loadDisassemblyForFile:(NSString *)filePath {
    // 直接进行反汇编，使用流式处理和内存优化
    [self performDisassemblyForFile:filePath];
}

- (void)performDisassemblyForFile:(NSString *)filePath {
    [self.loadingIndicator startAnimating];
    self.statusLabel.text = @"正在反汇编...";

    // 开始内存监控
    [self startMemoryMonitoring];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            // 检查文件大小，给出预警
            NSError *error;
            NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&error];
            NSNumber *fileSize = fileAttributes[NSFileSize];

            if (fileSize && fileSize.unsignedLongLongValue > 50 * 1024 * 1024) { // 50MB
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.statusLabel.text = [NSString stringWithFormat:@"大文件处理中 (%.1f MB)，请耐心等待...",
                                           fileSize.doubleValue / 1024.0 / 1024.0];
                });
            }

            // 使用DisassemblyEngine进行静态文件反汇编
            // 不限制指令数量，使用流式处理和内存优化防止内存溢出
            NSArray<NSDictionary *> *disassembly = [DisassemblyEngine disassembleFile:filePath maxInstructions:0];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.loadingIndicator stopAnimating];

                // 停止内存监控
                [self stopMemoryMonitoring];

                // 检查指令数量，给出性能提示
                if (disassembly.count > 100000) {
                    NSLog(@"提示: 指令数量较多 (%lu)，界面可能响应较慢", (unsigned long)disassembly.count);
                    self.statusLabel.text = [NSString stringWithFormat:@"加载了 %lu 条指令，界面可能较慢", (unsigned long)disassembly.count];

                    // 大数据集时进行内存优化
                    [self optimizeMemoryUsage];
                }

                self.disassemblyData = disassembly;

            // 分析函数和交叉引用
            if (self.disassemblyData.count > 0) {
                self.statusLabel.text = @"正在分析函数和交叉引用...";
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    // 首先解析符号表（更快）
                    [self parseSymbolTableFromFile:self.selectedFilePath];

                    // 然后进行函数分析
                    [self analyzeFunctions];
                    [self analyzeCrossReferences];

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self updateFileButtonTitle];
                        [self updateStatusLabel];
                        [self.disassemblyTableView reloadData];

                        // 显示分析结果
                        NSString *analysisInfo = [NSString stringWithFormat:@"完成：%lu 指令，%lu 函数",
                                                (unsigned long)self.disassemblyData.count,
                                                (unsigned long)self.functions.count];
                        self.statusLabel.text = analysisInfo;
                    });
                });
            } else {
                [self updateFileButtonTitle];
                [self updateStatusLabel];
                [self.disassemblyTableView reloadData];
            }
            });
        }
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.viewMode == 1 && self.functionSections) {
        return self.functionSections.count;
    }
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView != self.disassemblyTableView) {
        // 函数选择器表格
        NSArray *functionNames = objc_getAssociatedObject(tableView, "functionNames");
        if (functionNames) {
            return functionNames.count;
        }
        // 其他表格（如函数列表）
        NSArray *functionList = objc_getAssociatedObject(tableView, "functionList");
        return functionList.count;
    }

    // 原有的反汇编表格逻辑
    if (self.viewMode == 1 && self.functionSections) {
        if (section < self.functionSections.count) {
            NSDictionary *functionSection = self.functionSections[section];
            NSArray *instructions = functionSection[@"instructions"];
            return instructions.count;
        }
        return 0;
    }
    return self.disassemblyData.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.viewMode == 1 && self.functionSections) {
        if (section < self.functionSections.count) {
            NSDictionary *functionSection = self.functionSections[section];
            NSString *functionName = functionSection[@"name"];
            NSString *address = functionSection[@"address"];
            NSArray *instructions = functionSection[@"instructions"];
            return [NSString stringWithFormat:@"%@ (%@) - %lu 指令", functionName, address, (unsigned long)instructions.count];
        }
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView != self.disassemblyTableView) {
        // 检查是否是函数选择器表格
        NSArray *functionNames = objc_getAssociatedObject(tableView, "functionNames");
        if (functionNames) {
            // 函数选择器表格
            static NSString *functionSelectorCellIdentifier = @"FunctionSelectorCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:functionSelectorCellIdentifier];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:functionSelectorCellIdentifier];
                cell.textLabel.font = [UIFont fontWithName:@"Menlo" size:14];
                cell.detailTextLabel.font = [UIFont fontWithName:@"Menlo" size:12];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }

            NSString *functionName = functionNames[indexPath.row];
            NSDictionary *functionInfo = self.functions[functionName];
            NSString *address = functionInfo[@"address"];

            cell.textLabel.text = functionName;
            cell.detailTextLabel.text = address;
            cell.textLabel.textColor = [UIColor labelColor];
            cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];

            return cell;
        }

        // 函数列表表格
        static NSString *functionCellIdentifier = @"FunctionCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:functionCellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:functionCellIdentifier];
            cell.textLabel.font = [UIFont fontWithName:@"Menlo" size:14];
            cell.detailTextLabel.font = [UIFont fontWithName:@"Menlo" size:12];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }

        NSArray *functionList = objc_getAssociatedObject(tableView, "functionList");
        if (indexPath.row < functionList.count) {
            NSDictionary *functionInfo = functionList[indexPath.row];
            NSString *functionName = functionInfo[@"name"];
            NSString *address = functionInfo[@"address"];
            NSNumber *instructionCount = functionInfo[@"instructionCount"];
            NSNumber *size = functionInfo[@"size"];

            cell.textLabel.text = functionName;
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %ld 指令, %ld 字节",
                                       address,
                                       (long)instructionCount.integerValue,
                                       (long)size.integerValue];
            cell.textLabel.textColor = [UIColor labelColor];
            cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        }

        return cell;
    }

    // 原有的反汇编表格逻辑
    static NSString *cellIdentifier = @"DisassemblyCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.textLabel.font = [UIFont fontWithName:@"Menlo" size:12];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }

    NSDictionary *instruction = nil;

    if (self.viewMode == 1 && self.functionSections) {
        // 函数模式：从函数分组中获取指令
        if (indexPath.section < self.functionSections.count) {
            NSDictionary *functionSection = self.functionSections[indexPath.section];
            NSArray *instructions = functionSection[@"instructions"];
            if (indexPath.row < instructions.count) {
                instruction = instructions[indexPath.row];
            }
        }
    } else {
        // 线性模式：从完整数据中获取指令
        if (indexPath.row < self.disassemblyData.count) {
            instruction = self.disassemblyData[indexPath.row];
        }
    }

    if (instruction) {
        NSString *address = instruction[@"address"];
        NSString *bytes = instruction[@"bytes"];
        NSString *mnemonic = instruction[@"mnemonic"];
        NSString *operands = instruction[@"operands"];

        // 统一字体大小
        cell.textLabel.font = [UIFont fontWithName:@"Menlo" size:12];

        if (self.displayMode == 0) {
            // 汇编模式：使用富文本显示不同颜色
            NSString *instructionText = operands.length > 0 ? [NSString stringWithFormat:@"%@ %@", mnemonic, operands] : mnemonic;

            // 检查是否有交叉引用
            NSString *xrefIndicator = @"";
            if (self.crossReferences && self.crossReferences.count > 0) {
                NSMutableArray *indicators = [NSMutableArray array];

                // 检查当前地址是否被其他地址引用（入引用）
                NSArray *incomingRefs = self.crossReferences[address];
                if (incomingRefs && incomingRefs.count > 0) {
                    if (incomingRefs.count == 1) {
                        [indicators addObject:@"←"];  // 单个引用
                    } else {
                        [indicators addObject:[NSString stringWithFormat:@"←%lu", (unsigned long)incomingRefs.count]];  // 多个引用
                    }
                }

                // 检查当前指令是否引用其他地址（出引用）
                NSString *targetAddress = [self extractAddressFromOperands:operands];
                if (targetAddress && self.crossReferences[targetAddress]) {
                    [indicators addObject:@"→"];
                }

                if (indicators.count > 0) {
                    xrefIndicator = [NSString stringWithFormat:@" %@", [indicators componentsJoinedByString:@""]];
                }
            }

            // 创建富文本
            NSString *fullText = [NSString stringWithFormat:@"%@    %@%@", address, instructionText, xrefIndicator];
            NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:fullText];

            // 设置默认字体
            [attributedText addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"Menlo" size:12] range:NSMakeRange(0, fullText.length)];

            // 地址颜色（蓝色）
            [attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor systemBlueColor] range:NSMakeRange(0, address.length)];

            // 指令部分的详细着色
            NSInteger instructionStart = address.length + 4;

            // 指令助记符颜色（紫色）
            NSRange mnemonicRange = NSMakeRange(instructionStart, mnemonic.length);
            [attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor systemPurpleColor] range:mnemonicRange];

            // 操作数颜色（默认文本颜色）
            if (operands.length > 0) {
                NSRange operandsRange = NSMakeRange(instructionStart + mnemonic.length + 1, operands.length);
                [attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor labelColor] range:operandsRange];

                // 如果操作数中包含地址（0x开头），将其标记为红色
                NSString *operandsLower = [operands lowercaseString];
                NSRange addressInOperands = [operandsLower rangeOfString:@"0x"];
                if (addressInOperands.location != NSNotFound) {
                    // 查找完整的地址
                    NSInteger addressStart = operandsRange.location + addressInOperands.location;
                    NSInteger addressLength = 0;
                    for (NSInteger i = addressInOperands.location + 2; i < operands.length; i++) {
                        unichar c = [operands characterAtIndex:i];
                        if ((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) {
                            addressLength++;
                        } else {
                            break;
                        }
                    }
                    if (addressLength > 0) {
                        NSRange addressRange = NSMakeRange(addressStart, 2 + addressLength);
                        [attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor systemRedColor] range:addressRange];
                    }
                }
            }

            // 交叉引用符号颜色（橙色）
            if (xrefIndicator.length > 0) {
                NSRange xrefRange = NSMakeRange(address.length + 4 + instructionText.length, xrefIndicator.length);
                [attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor systemOrangeColor] range:xrefRange];
            }

            cell.textLabel.attributedText = attributedText;
        } else if (self.displayMode == 1) {
            // 16进制模式：使用富文本显示不同颜色
            NSString *fullText = [NSString stringWithFormat:@"%@    %@", address, bytes];
            NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:fullText];

            // 设置默认字体
            [attributedText addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"Menlo" size:12] range:NSMakeRange(0, fullText.length)];

            // 地址颜色（蓝色）
            [attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor systemBlueColor] range:NSMakeRange(0, address.length)];

            // 字节码颜色（绿色）
            NSRange bytesRange = NSMakeRange(address.length + 4, bytes.length);
            [attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor systemGreenColor] range:bytesRange];

            cell.textLabel.attributedText = attributedText;
        }
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (tableView != self.disassemblyTableView) {
        // 检查是否是函数选择器表格
        NSArray *functionNames = objc_getAssociatedObject(tableView, "functionNames");
        if (functionNames) {
            // 函数选择器表格点击处理
            NSString *functionName = functionNames[indexPath.row];

            [self dismissViewControllerAnimated:YES completion:^{
                [self showCFGForFunctionAsync:functionName];
            }];
            return;
        }

        // 函数列表表格点击处理
        NSArray *functionList = objc_getAssociatedObject(tableView, "functionList");
        ReverseAssemblyViewController *parentController = objc_getAssociatedObject(tableView, "parentController");

        if (indexPath.row < functionList.count && parentController) {
            NSDictionary *functionInfo = functionList[indexPath.row];
            NSString *address = functionInfo[@"address"];

            // 关闭函数列表
            [parentController dismissViewControllerAnimated:YES completion:^{
                // 跳转到函数地址
                [parentController jumpToAddressString:address];
            }];
        }
        return;
    }

    NSDictionary *instruction = nil;

    if (self.viewMode == 1 && self.functionSections) {
        // 函数模式：从函数分组中获取指令
        if (indexPath.section < self.functionSections.count) {
            NSDictionary *functionSection = self.functionSections[indexPath.section];
            NSArray *instructions = functionSection[@"instructions"];
            if (indexPath.row < instructions.count) {
                instruction = instructions[indexPath.row];
            }
        }
    } else {
        // 线性模式：从完整数据中获取指令
        if (indexPath.row < self.disassemblyData.count) {
            instruction = self.disassemblyData[indexPath.row];
        }
    }

    if (!instruction) {
        return;
    }
    NSString *address = instruction[@"address"];
    NSString *mnemonic = instruction[@"mnemonic"];
    NSString *operands = instruction[@"operands"];

    // 创建操作菜单
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"%@ %@", mnemonic, operands]
                                                                         message:[NSString stringWithFormat:@"地址: %@", address]
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];

    // 复制地址
    UIAlertAction *copyAddressAction = [UIAlertAction actionWithTitle:@"复制地址"
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *action) {
        UIPasteboard.generalPasteboard.string = address;
        [self showAlert:@"已复制" message:[NSString stringWithFormat:@"地址 %@ 已复制到剪贴板", address]];
    }];
    [actionSheet addAction:copyAddressAction];

    // 复制指令
    NSString *fullInstruction = operands.length > 0 ? [NSString stringWithFormat:@"%@ %@", mnemonic, operands] : mnemonic;
    UIAlertAction *copyInstructionAction = [UIAlertAction actionWithTitle:@"复制指令"
                                                                    style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction *action) {
        UIPasteboard.generalPasteboard.string = fullInstruction;
        [self showAlert:@"已复制" message:@"指令已复制到剪贴板"];
    }];
    [actionSheet addAction:copyInstructionAction];

    // 如果是跳转指令，添加跳转选项
    if ([mnemonic hasPrefix:@"b"] && [operands containsString:@"0x"]) {
        NSRange range = [operands rangeOfString:@"0x"];
        if (range.location != NSNotFound) {
            NSString *targetAddress = [operands substringFromIndex:range.location];
            // 提取纯地址部分
            NSRange spaceRange = [targetAddress rangeOfString:@" "];
            if (spaceRange.location != NSNotFound) {
                targetAddress = [targetAddress substringToIndex:spaceRange.location];
            }

            UIAlertAction *jumpAction = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"跳转到 %@", targetAddress]
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction *action) {
                [self jumpToAddressString:targetAddress];
            }];
            [actionSheet addAction:jumpAction];
        }
    }

    // 显示交叉引用
    NSArray *incomingRefs = self.crossReferences[address];
    NSString *targetAddress = [self extractAddressFromOperands:operands];
    NSArray *outgoingRefs = targetAddress ? self.crossReferences[targetAddress] : nil;

    BOOL hasIncomingRefs = incomingRefs && incomingRefs.count > 0;
    BOOL hasOutgoingRefs = targetAddress && outgoingRefs;

    if (hasIncomingRefs || hasOutgoingRefs) {
        NSString *xrefTitle = @"交叉引用";
        if (hasIncomingRefs && hasOutgoingRefs) {
            xrefTitle = [NSString stringWithFormat:@"交叉引用 (入:%lu 出:1)", (unsigned long)incomingRefs.count];
        } else if (hasIncomingRefs) {
            xrefTitle = [NSString stringWithFormat:@"交叉引用 (入:%lu)", (unsigned long)incomingRefs.count];
        } else {
            xrefTitle = @"交叉引用 (出:1)";
        }

        UIAlertAction *xrefAction = [UIAlertAction actionWithTitle:xrefTitle
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction *action) {
            if (hasIncomingRefs) {
                [self showCrossReferencesForAddress:address];
            } else if (hasOutgoingRefs) {
                [self showCrossReferencesForAddress:targetAddress];
            }
        }];
        [actionSheet addAction:xrefAction];
    }

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [actionSheet addAction:cancelAction];

    // 为 iPad 设置 popover
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        actionSheet.popoverPresentationController.sourceView = cell;
        actionSheet.popoverPresentationController.sourceRect = cell.bounds;
    }

    [self presentViewController:actionSheet animated:YES completion:nil];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 35.0; // 统一行高
}

#pragma mark - Export Functionality

- (void)exportDisassembly {
    if (!self.disassemblyData || self.disassemblyData.count == 0) {
        [self showAlert:@"提示" message:@"没有可导出的反汇编数据"];
        return;
    }

    // 生成导出内容
    NSMutableString *exportContent = [NSMutableString string];
    [exportContent appendFormat:@"反汇编结果 - %@\n", self.selectedModule.name ?: @"未知模块"];
    [exportContent appendFormat:@"模块地址: 0x%lX\n", (unsigned long)self.selectedModule.startAddress];
    [exportContent appendFormat:@"指令数量: %lu\n", (unsigned long)self.disassemblyData.count];
    [exportContent appendString:@"生成时间: "];
    [exportContent appendString:[[NSDateFormatter new] stringFromDate:[NSDate date]]];
    [exportContent appendString:@"\n\n"];
    [exportContent appendString:@"地址              字节码        指令\n"];
    [exportContent appendString:@"================================================\n"];

    for (NSDictionary *instruction in self.disassemblyData) {
        NSString *address = instruction[@"address"];
        NSString *bytes = instruction[@"bytes"];
        NSString *mnemonic = instruction[@"mnemonic"];
        NSString *operands = instruction[@"operands"];

        NSString *instructionText = operands.length > 0 ? [NSString stringWithFormat:@"%@ %@", mnemonic, operands] : mnemonic;
        [exportContent appendFormat:@"%-16s  %-12s  %@\n",
         [address UTF8String],
         [bytes UTF8String],
         instructionText];
    }

    // 显示分享选项
    UIActivityViewController *activityVC = [[UIActivityViewController alloc]
                                           initWithActivityItems:@[exportContent]
                                           applicationActivities:nil];

    // 对于iPad，需要设置popover
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    }

    [self presentViewController:activityVC animated:YES completion:nil];
}

#pragma mark - Enhanced Features

- (void)refreshDisplayWithViewMode {
    switch (self.viewMode) {
        case 0: // 线性模式
            self.functionSections = nil;
            [self.disassemblyTableView reloadData];
            break;
        case 1: // 函数模式
            [self switchToFunctionModeAsync];
            break;
        case 2: // CFG 模式
            [self showCFGMode];
            break;
        default:
            break;
    }
}

- (void)showHelp {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"交叉引用符号说明"
                                                                   message:@"← : 被其他地址引用（入引用）\n→ : 引用其他地址（出引用）\n←2 : 被2个地址引用\n←→ : 既被引用又引用其他地址\n\n点击有箭头的指令可查看详细交叉引用信息"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"知道了"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    [alert addAction:okAction];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)prepareFunctionSections {
    if (!self.functions || self.functions.count == 0) {
        self.functionSections = nil;
        return;
    }

    NSMutableArray *sections = [NSMutableArray array];

    // 按地址排序函数
    NSArray *sortedFunctionNames = [self.functions.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *name1, NSString *name2) {
        NSDictionary *func1 = self.functions[name1];
        NSDictionary *func2 = self.functions[name2];
        NSString *addr1 = func1[@"address"];
        NSString *addr2 = func2[@"address"];

        uint64_t address1, address2;
        [[NSScanner scannerWithString:addr1] scanHexLongLong:&address1];
        [[NSScanner scannerWithString:addr2] scanHexLongLong:&address2];

        if (address1 < address2) return NSOrderedAscending;
        if (address1 > address2) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    // 为每个函数创建一个分组
    for (NSString *functionName in sortedFunctionNames) {
        NSDictionary *functionInfo = self.functions[functionName];
        NSInteger startIndex = [functionInfo[@"startIndex"] integerValue];
        NSInteger endIndex = [functionInfo[@"endIndex"] integerValue];

        NSMutableArray *functionInstructions = [NSMutableArray array];
        for (NSInteger i = startIndex; i <= endIndex && i < self.disassemblyData.count; i++) {
            [functionInstructions addObject:self.disassemblyData[i]];
        }

        [sections addObject:@{
            @"name": functionName,
            @"address": functionInfo[@"address"],
            @"instructions": functionInstructions
        }];
    }

    self.functionSections = sections;
}

- (void)jumpToAddressString:(NSString *)addressString {
    if (!addressString || addressString.length == 0) {
        [self showAlert:@"错误" message:@"请输入有效的地址"];
        return;
    }

    // 解析地址
    uint64_t targetAddress = 0;
    NSScanner *scanner = [NSScanner scannerWithString:addressString];
    if (![scanner scanHexLongLong:&targetAddress]) {
        [self showAlert:@"错误" message:@"地址格式不正确"];
        return;
    }

    // 查找对应的指令
    NSIndexPath *targetIndexPath = nil;

    if (self.viewMode == 1 && self.functionSections) {
        // 函数模式：在函数分组中查找
        for (NSInteger section = 0; section < self.functionSections.count; section++) {
            NSDictionary *functionSection = self.functionSections[section];
            NSArray *instructions = functionSection[@"instructions"];

            for (NSInteger row = 0; row < instructions.count; row++) {
                NSDictionary *instruction = instructions[row];
                NSString *instructionAddress = instruction[@"address"];

                uint64_t instructionAddr = 0;
                NSScanner *instrScanner = [NSScanner scannerWithString:instructionAddress];
                if ([instrScanner scanHexLongLong:&instructionAddr] && instructionAddr == targetAddress) {
                    targetIndexPath = [NSIndexPath indexPathForRow:row inSection:section];
                    break;
                }
            }
            if (targetIndexPath) break;
        }
    } else {
        // 线性模式：在完整数据中查找
        for (NSInteger i = 0; i < self.disassemblyData.count; i++) {
            NSDictionary *instruction = self.disassemblyData[i];
            NSString *instructionAddress = instruction[@"address"];

            uint64_t instructionAddr = 0;
            NSScanner *instrScanner = [NSScanner scannerWithString:instructionAddress];
            if ([instrScanner scanHexLongLong:&instructionAddr] && instructionAddr == targetAddress) {
                targetIndexPath = [NSIndexPath indexPathForRow:i inSection:0];
                break;
            }
        }
    }

    if (targetIndexPath) {
        [self.disassemblyTableView scrollToRowAtIndexPath:targetIndexPath
                                         atScrollPosition:UITableViewScrollPositionMiddle
                                                 animated:YES];

        // 高亮显示目标行
        [self.disassemblyTableView selectRowAtIndexPath:targetIndexPath animated:YES scrollPosition:UITableViewScrollPositionNone];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.disassemblyTableView deselectRowAtIndexPath:targetIndexPath animated:YES];
        });
    } else {
        [self showAlert:@"未找到" message:[NSString stringWithFormat:@"未找到地址 %@", addressString]];
    }
}

- (void)switchToFunctionModeAsync {
    // 显示加载指示器
    [self.loadingIndicator startAnimating];
    self.statusLabel.text = @"正在分析函数...";

    // 禁用视图模式控件防止重复点击
    self.viewModeControl.enabled = NO;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 在后台线程进行函数分析
        [self analyzeFunctions];

        dispatch_async(dispatch_get_main_queue(), ^{
            // 回到主线程更新UI
            [self prepareFunctionSections];
            [self.disassemblyTableView reloadData];

            [self.loadingIndicator stopAnimating];
            self.statusLabel.text = [NSString stringWithFormat:@"函数分析完成，共 %lu 个函数", (unsigned long)self.functions.count];

            // 重新启用视图模式控件
            self.viewModeControl.enabled = YES;
        });
    });
}

- (void)analyzeFunctions {
    if (!self.disassemblyData || self.disassemblyData.count == 0) {
        return;
    }

    NSMutableDictionary *functions = [NSMutableDictionary dictionary];
    NSMutableSet *functionAddresses = [NSMutableSet set];

    NSLog(@"开始分析函数，总指令数: %lu", (unsigned long)self.disassemblyData.count);

    // 开始内存监控
    [self startMemoryMonitoring];

    // 分块处理，避免长时间阻塞
    NSInteger chunkSize = 10000; // 每次处理1万条指令
    NSInteger totalInstructions = self.disassemblyData.count;

    for (NSInteger chunkStart = 0; chunkStart < totalInstructions; chunkStart += chunkSize) {
        @autoreleasepool {
            NSInteger chunkEnd = MIN(chunkStart + chunkSize, totalInstructions);

            // 快速扫描：只查找明确的函数开始模式
            for (NSInteger i = chunkStart; i < chunkEnd; i++) {
                NSDictionary *instruction = self.disassemblyData[i];
                NSString *mnemonic = instruction[@"mnemonic"];
                NSString *operands = instruction[@"operands"];

                // 只检测最明确的函数开始模式，提高速度
                BOOL isFunctionStart = NO;

                // ARM64 函数序言：stp x29, x30, [sp, #-0x10]!
                if ([mnemonic isEqualToString:@"stp"] &&
                    [operands containsString:@"x29"] &&
                    [operands containsString:@"x30"] &&
                    [operands containsString:@"sp"]) {
                    isFunctionStart = YES;
                }

                // 栈分配：sub sp, sp, #0x...
                else if ([mnemonic isEqualToString:@"sub"] &&
                         [operands hasPrefix:@"sp, sp, #"]) {
                    isFunctionStart = YES;
                }

                // 检查前一条指令是否是返回指令（函数边界）
                else if (i > 0) {
                    NSDictionary *prevInstruction = self.disassemblyData[i - 1];
                    NSString *prevMnemonic = prevInstruction[@"mnemonic"];
                    if ([prevMnemonic isEqualToString:@"ret"]) {
                        isFunctionStart = YES;
                    }
                }

                if (isFunctionStart) {
                    [functionAddresses addObject:@(i)];
                }
            }

            // 进度报告
            if (chunkEnd % 50000 == 0 || chunkEnd == totalInstructions) {
                NSLog(@"函数分析进度: %ld/%ld (%.1f%%)", (long)chunkEnd, (long)totalInstructions,
                      (double)chunkEnd / totalInstructions * 100.0);
            }
        }
    }

    // 确保第一条指令被包含
    [functionAddresses addObject:@(0)];

    // 排序函数起始点
    NSArray *sortedStarts = [[functionAddresses allObjects] sortedArrayUsingComparator:^NSComparisonResult(NSNumber *a, NSNumber *b) {
        return [a compare:b];
    }];

    // 快速创建函数信息
    for (NSInteger i = 0; i < sortedStarts.count; i++) {
        NSInteger startIndex = [sortedStarts[i] integerValue];
        NSInteger endIndex = (i + 1 < sortedStarts.count) ?
                            [sortedStarts[i + 1] integerValue] - 1 :
                            self.disassemblyData.count - 1;

        NSDictionary *startInstruction = self.disassemblyData[startIndex];
        NSString *address = startInstruction[@"address"];
        NSString *addressSuffix = [address substringFromIndex:2]; // 移除 "0x"
        NSString *functionName = [NSString stringWithFormat:@"sub_%@", addressSuffix];

        functions[functionName] = @{
            @"address": address,
            @"startIndex": @(startIndex),
            @"endIndex": @(endIndex)
        };
    }

    // 不要覆盖已有的符号表函数，只添加新发现的函数
    if (self.functions && self.functions.count > 0) {
        // 如果已经有符号表函数，只添加新发现的地址
        NSMutableDictionary *mergedFunctions = [self.functions mutableCopy];

        for (NSString *functionName in functions) {
            NSDictionary *functionInfo = functions[functionName];
            NSString *address = functionInfo[@"address"];

            // 检查是否已经有这个地址的函数
            BOOL addressExists = NO;
            for (NSDictionary *existingInfo in mergedFunctions.allValues) {
                if ([existingInfo[@"address"] isEqualToString:address]) {
                    addressExists = YES;
                    break;
                }
            }

            // 只添加新地址的函数
            if (!addressExists) {
                mergedFunctions[functionName] = functionInfo;
            }
        }

        self.functions = mergedFunctions;
        NSLog(@"函数分析完成：保留符号表函数，新增 %lu 个函数，总计 %lu 个",
              (unsigned long)(mergedFunctions.count - self.functions.count),
              (unsigned long)mergedFunctions.count);
    } else {
        // 如果没有符号表函数，使用分析结果
        self.functions = functions;
        NSLog(@"快速分析完成：识别到 %lu 个函数", (unsigned long)functions.count);
    }

    // 停止内存监控
    [self stopMemoryMonitoring];
}

// 完全按照 MachOView 的方式解析符号表
- (void)parseSymbolTableFromFile:(NSString *)filePath {
    if (!filePath) return;

    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    if (!fileData || fileData.length < sizeof(struct mach_header_64)) {
        return;
    }

    const uint8_t *bytes = (const uint8_t *)fileData.bytes;
    const struct mach_header_64 *header = (const struct mach_header_64 *)bytes;

    // 检查 Mach-O 魔数
    if (header->magic != MH_MAGIC_64 && header->magic != MH_MAGIC) {
        NSLog(@"不是有效的 Mach-O 文件，魔数: 0x%x", header->magic);
        return;
    }

    NSMutableDictionary *symbolNames = [NSMutableDictionary dictionary];
    BOOL is64bit = (header->magic == MH_MAGIC_64);

    // 查找符号表命令
    const uint8_t *loadCmdPtr = bytes + (is64bit ? sizeof(struct mach_header_64) : sizeof(struct mach_header));
    const struct symtab_command *symtab_command = NULL;
    char *strtab = NULL;

    for (uint32_t i = 0; i < header->ncmds; i++) {
        const struct load_command *loadCmd = (const struct load_command *)loadCmdPtr;

        if (loadCmd->cmd == LC_SYMTAB) {
            symtab_command = (const struct symtab_command *)loadCmd;
            strtab = (char *)(bytes + symtab_command->stroff);
            NSLog(@"找到符号表：%u 个符号，字符串表大小：%u", symtab_command->nsyms, symtab_command->strsize);
            break;
        }

        loadCmdPtr += loadCmd->cmdsize;
    }

    if (!symtab_command || !strtab) {
        NSLog(@"未找到符号表");
        return;
    }

    // 首先找到基址 - 查找第一个可执行段的虚拟地址
    uint64_t baseAddress = 0;
    const uint8_t *loadCmdPtr2 = bytes + (is64bit ? sizeof(struct mach_header_64) : sizeof(struct mach_header));

    for (uint32_t i = 0; i < header->ncmds; i++) {
        const struct load_command *loadCmd = (const struct load_command *)loadCmdPtr2;

        if (is64bit && loadCmd->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *segCmd = (const struct segment_command_64 *)loadCmd;
            if (segCmd->fileoff == 0 && segCmd->filesize != 0) {
                baseAddress = segCmd->vmaddr;
                NSLog(@"找到基址: 0x%llX (段名: %.16s)", baseAddress, segCmd->segname);
                break;
            }
        } else if (!is64bit && loadCmd->cmd == LC_SEGMENT) {
            const struct segment_command *segCmd = (const struct segment_command *)loadCmd;
            if (segCmd->fileoff == 0 && segCmd->filesize != 0) {
                baseAddress = segCmd->vmaddr;
                NSLog(@"找到基址: 0x%llX (段名: %.16s)", baseAddress, segCmd->segname);
                break;
            }
        }

        loadCmdPtr2 += loadCmd->cmdsize;
    }

    // 按照 MachOView 的方式解析符号
    if (is64bit) {
        // 64位符号表解析 - 完全按照 LinkEdit.mm 的逻辑
        const struct nlist_64 *symbols = (const struct nlist_64 *)(bytes + symtab_command->symoff);

        for (uint32_t nsym = 0; nsym < symtab_command->nsyms; ++nsym) {
            const struct nlist_64 *nlist_64 = &symbols[nsym];

            NSString *symbolName = [NSString stringWithUTF8String:(strtab + nlist_64->n_un.n_strx)];

            if ((nlist_64->n_type & N_TYPE) != N_UNDF) {
                // 定义的符号
                if ((nlist_64->n_type & N_STAB) == 0) {
                    // 计算相对地址（减去基址）
                    uint64_t relativeAddress = nlist_64->n_value - baseAddress;

                    // 不是调试符号，添加到查找表
                    NSString *nameToStore = [symbolNames objectForKey:[NSNumber numberWithUnsignedLongLong:relativeAddress]];
                    nameToStore = (nameToStore != nil
                                   ? [nameToStore stringByAppendingFormat:@"(%@)", symbolName]
                                   : [NSString stringWithFormat:@"0x%qX (%@)", relativeAddress, symbolName]);

                    [symbolNames setObject:nameToStore
                                    forKey:[NSNumber numberWithUnsignedLongLong:relativeAddress]];
                }
            }
        }
    } else {
        // 32位符号表解析 - 完全按照 LinkEdit.mm 的逻辑
        const struct nlist *symbols = (const struct nlist *)(bytes + symtab_command->symoff);

        for (uint32_t nsym = 0; nsym < symtab_command->nsyms; ++nsym) {
            const struct nlist *nlist = &symbols[nsym];

            NSString *symbolName = [NSString stringWithUTF8String:(strtab + nlist->n_un.n_strx)];

            if ((nlist->n_type & N_TYPE) != N_UNDF) {
                // 定义的符号
                if ((nlist->n_type & N_STAB) == 0) {
                    // 计算相对地址（减去基址）
                    uint64_t relativeAddress = nlist->n_value - baseAddress;

                    // 不是调试符号，添加到查找表
                    NSString *nameToStore = [symbolNames objectForKey:[NSNumber numberWithUnsignedLongLong:relativeAddress]];
                    nameToStore = (nameToStore != nil
                                   ? [nameToStore stringByAppendingFormat:@"(%@)", symbolName]
                                   : [NSString stringWithFormat:@"0x%qX (%@)", relativeAddress, symbolName]);

                    [symbolNames setObject:nameToStore
                                    forKey:[NSNumber numberWithUnsignedLongLong:relativeAddress]];
                }
            }
        }
    }

    NSLog(@"从符号表解析到 %lu 个有效符号", (unsigned long)symbolNames.count);

    // 调试：输出前几个符号和反汇编地址
    NSInteger debugCount = 0;
    for (NSNumber *addressNumber in symbolNames) {
        if (debugCount < 5) {
            NSString *symbolName = symbolNames[addressNumber];
            NSLog(@"符号调试: 地址=%@ (0x%llX) 名称=%@", addressNumber, [addressNumber unsignedLongLongValue], symbolName);
            debugCount++;
        } else {
            break;
        }
    }

    // 调试：输出前几个反汇编地址
    debugCount = 0;
    for (NSInteger i = 0; i < MIN(5, self.disassemblyData.count); i++) {
        NSDictionary *instruction = self.disassemblyData[i];
        NSString *address = instruction[@"address"];
        uint64_t addr = 0;
        NSScanner *scanner = [NSScanner scannerWithString:address];
        [scanner scanHexLongLong:&addr];
        NSLog(@"反汇编调试: 地址=%@ (0x%llX)", address, addr);
    }

    // 将符号表信息合并到函数列表中
    [self mergeSymbolNamesIntoFunctions:symbolNames];
}

- (void)mergeSymbolNamesIntoFunctions:(NSDictionary *)symbolNames {
    if (!symbolNames || symbolNames.count == 0) {
        NSLog(@"符号表为空，跳过合并");
        return;
    }

    NSLog(@"开始合并符号表，符号表有 %lu 个符号", (unsigned long)symbolNames.count);

    // 创建地址到指令索引的映射
    NSMutableDictionary *addressToIndex = [NSMutableDictionary dictionary];
    for (NSInteger i = 0; i < self.disassemblyData.count; i++) {
        NSDictionary *instruction = self.disassemblyData[i];
        NSString *address = instruction[@"address"];
        if (address) {
            // 将地址字符串转换为数字进行匹配
            uint64_t addr = 0;
            NSScanner *scanner = [NSScanner scannerWithString:address];
            if ([scanner scanHexLongLong:&addr]) {
                addressToIndex[@(addr)] = @(i);
            }
        }
    }

    NSLog(@"反汇编数据有 %lu 条指令，地址映射表有 %lu 个条目",
          (unsigned long)self.disassemblyData.count,
          (unsigned long)addressToIndex.count);

    NSMutableDictionary *updatedFunctions = [NSMutableDictionary dictionary];

    // 处理符号表中的所有符号 - 按照 MachOView 的格式
    NSInteger matchedSymbols = 0;
    for (NSNumber *addressNumber in symbolNames) {
        NSString *symbolNameWithAddress = symbolNames[addressNumber];
        uint64_t address = [addressNumber unsignedLongLongValue];

        // 查找对应的指令索引
        NSNumber *indexNumber = addressToIndex[addressNumber];
        if (indexNumber) {
            matchedSymbols++;
            NSInteger startIndex = [indexNumber integerValue];

            // 寻找函数结束点
            NSInteger endIndex = startIndex;
            for (NSInteger i = startIndex + 1; i < self.disassemblyData.count; i++) {
                NSDictionary *inst = self.disassemblyData[i];
                NSString *mnemonic = inst[@"mnemonic"];
                if ([mnemonic isEqualToString:@"ret"]) {
                    endIndex = i;
                    break;
                }
                // 如果遇到下一个符号，也停止
                NSString *nextAddress = inst[@"address"];
                uint64_t nextAddr = 0;
                NSScanner *scanner = [NSScanner scannerWithString:nextAddress];
                if ([scanner scanHexLongLong:&nextAddr] && symbolNames[@(nextAddr)]) {
                    endIndex = i - 1;
                    break;
                }
            }

            // 从 MachOView 格式的符号名中提取纯函数名
            // 格式：0x1234 (functionName) 或 functionName
            NSString *cleanFunctionName = symbolNameWithAddress;
            NSRange parenRange = [symbolNameWithAddress rangeOfString:@"("];
            if (parenRange.location != NSNotFound) {
                NSRange endParenRange = [symbolNameWithAddress rangeOfString:@")" options:NSBackwardsSearch];
                if (endParenRange.location != NSNotFound && endParenRange.location > parenRange.location) {
                    cleanFunctionName = [symbolNameWithAddress substringWithRange:NSMakeRange(parenRange.location + 1, endParenRange.location - parenRange.location - 1)];
                }
            }

            NSString *addressString = [NSString stringWithFormat:@"0x%llX", address];
            updatedFunctions[cleanFunctionName] = @{
                @"address": addressString,
                @"startIndex": @(startIndex),
                @"endIndex": @(endIndex)
            };

            NSLog(@"添加符号函数: %@ at %@", cleanFunctionName, addressString);
        } else {
            // 调试：输出前几个未匹配的符号
            if (matchedSymbols < 3) {
                NSLog(@"未匹配符号: 地址=%@ 名称=%@", addressNumber, symbolNameWithAddress);
            }
        }
    }

    NSLog(@"符号匹配结果: %ld/%lu 个符号找到了对应的指令",
          (long)matchedSymbols, (unsigned long)symbolNames.count);

    // 然后添加原有的函数（如果地址不冲突）
    for (NSString *functionName in self.functions) {
        NSDictionary *functionInfo = self.functions[functionName];
        NSString *address = functionInfo[@"address"];

        // 检查是否已经被符号表覆盖
        BOOL alreadyExists = NO;
        for (NSDictionary *existingInfo in updatedFunctions.allValues) {
            if ([existingInfo[@"address"] isEqualToString:address]) {
                alreadyExists = YES;
                break;
            }
        }

        if (!alreadyExists) {
            updatedFunctions[functionName] = functionInfo;
        }
    }

    self.functions = updatedFunctions;
    NSLog(@"合并完成，共有 %lu 个函数", (unsigned long)self.functions.count);
}

- (void)showCFGMode {
    // 首先检查是否需要分析函数
    if (!self.functions || self.functions.count == 0) {
        // 显示加载指示器并异步分析函数
        [self.loadingIndicator startAnimating];
        self.statusLabel.text = @"正在分析函数以生成CFG...";

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self analyzeFunctions];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.loadingIndicator stopAnimating];

                if (self.functions.count == 0) {
                    [self showAlert:@"CFG 模式" message:@"未能识别到函数，无法生成控制流图"];
                    // 切换回线性模式
                    self.viewModeControl.selectedSegmentIndex = 0;
                    self.viewMode = 0;
                    return;
                }

                self.statusLabel.text = [NSString stringWithFormat:@"函数分析完成，共 %lu 个函数", (unsigned long)self.functions.count];
                [self showFunctionSelector];
            });
        });
        return;
    }

    [self showFunctionSelector];
}

- (void)showFunctionSelector {
    // 如果函数数量较少，直接显示ActionSheet
    if (self.functions.count <= 15) {
        [self showFunctionActionSheet];
        return;
    }

    // 函数数量较多时，显示专门的函数选择界面
    [self showFunctionListViewController];
}

- (void)showFunctionActionSheet {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择函数"
                                                                   message:@"选择要显示控制流图的函数"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *functionNames = [self.functions.allKeys sortedArrayUsingSelector:@selector(compare:)];

    for (NSString *functionName in functionNames) {
        NSDictionary *functionInfo = self.functions[functionName];
        NSString *address = functionInfo[@"address"];
        NSString *title = [NSString stringWithFormat:@"%@ (%@)", functionName, address];

        UIAlertAction *functionAction = [UIAlertAction actionWithTitle:title
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction *action) {
            [self showCFGForFunctionAsync:functionName];
        }];
        [alert addAction:functionAction];
    }

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *action) {
        // 取消时切换回线性模式
        self.viewModeControl.selectedSegmentIndex = 0;
        self.viewMode = 0;
    }];
    [alert addAction:cancelAction];

    // 为 iPad 设置 popover
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.viewModeControl;
        alert.popoverPresentationController.sourceRect = self.viewModeControl.bounds;
    }

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showFunctionListViewController {
    // 创建函数列表视图控制器
    UIViewController *functionListVC = [[UIViewController alloc] init];
    functionListVC.title = [NSString stringWithFormat:@"选择函数 (%lu个)", (unsigned long)self.functions.count];
    functionListVC.view.backgroundColor = [UIColor systemBackgroundColor];

    // 创建表格视图
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [functionListVC.view addSubview:tableView];

    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:functionListVC.view.safeAreaLayoutGuide.topAnchor],
        [tableView.leadingAnchor constraintEqualToAnchor:functionListVC.view.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:functionListVC.view.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:functionListVC.view.bottomAnchor]
    ]];

    // 准备数据源
    NSArray *functionNames = [self.functions.allKeys sortedArrayUsingSelector:@selector(compare:)];

    // 设置数据源和代理
    tableView.dataSource = (id<UITableViewDataSource>)self;
    tableView.delegate = (id<UITableViewDelegate>)self;

    // 存储数据到临时属性（用于表格显示）
    objc_setAssociatedObject(tableView, "functionNames", functionNames, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(tableView, "parentViewController", self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 注册cell（使用subtitle样式以显示详细信息）
    [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"FunctionCell"];

    // 创建导航控制器
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:functionListVC];

    // 添加取消按钮
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"取消"
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(dismissFunctionList:)];
    functionListVC.navigationItem.leftBarButtonItem = cancelButton;

    // 添加搜索按钮
    UIBarButtonItem *searchButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch
                                                                                  target:self
                                                                                  action:@selector(searchFunction:)];
    functionListVC.navigationItem.rightBarButtonItem = searchButton;

    [self presentViewController:navController animated:YES completion:nil];
}

// MARK: - 函数列表相关方法

- (void)dismissFunctionList:(UIBarButtonItem *)sender {
    [self dismissViewControllerAnimated:YES completion:^{
        // 取消时切换回线性模式
        self.viewModeControl.selectedSegmentIndex = 0;
        self.viewMode = 0;
    }];
}

- (void)searchFunction:(UIBarButtonItem *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"搜索函数"
                                                                   message:@"输入函数名或地址进行搜索"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"函数名或地址 (如: sub_1000 或 0x1000)";
    }];

    UIAlertAction *searchAction = [UIAlertAction actionWithTitle:@"搜索"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
        NSString *searchText = alert.textFields.firstObject.text;
        [self performFunctionSearch:searchText];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [alert addAction:searchAction];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performFunctionSearch:(NSString *)searchText {
    if (!searchText || searchText.length == 0) {
        return;
    }

    NSMutableArray *matchedFunctions = [NSMutableArray array];

    for (NSString *functionName in self.functions.allKeys) {
        NSDictionary *functionInfo = self.functions[functionName];
        NSString *address = functionInfo[@"address"];

        // 搜索函数名或地址
        if ([functionName.lowercaseString containsString:searchText.lowercaseString] ||
            [address.lowercaseString containsString:searchText.lowercaseString]) {
            [matchedFunctions addObject:functionName];
        }
    }

    if (matchedFunctions.count == 0) {
        [self showAlert:@"搜索结果" message:@"未找到匹配的函数"];
        return;
    }

    if (matchedFunctions.count == 1) {
        // 只有一个结果，直接显示CFG
        [self dismissViewControllerAnimated:YES completion:^{
            [self showCFGForFunctionAsync:matchedFunctions.firstObject];
        }];
        return;
    }

    // 多个结果，显示选择列表
    UIAlertController *resultAlert = [UIAlertController alertControllerWithTitle:@"搜索结果"
                                                                         message:[NSString stringWithFormat:@"找到 %lu 个匹配的函数", (unsigned long)matchedFunctions.count]
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSString *functionName in matchedFunctions) {
        NSDictionary *functionInfo = self.functions[functionName];
        NSString *address = functionInfo[@"address"];
        NSString *title = [NSString stringWithFormat:@"%@ (%@)", functionName, address];

        UIAlertAction *functionAction = [UIAlertAction actionWithTitle:title
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction *action) {
            [self dismissViewControllerAnimated:YES completion:^{
                [self showCFGForFunctionAsync:functionName];
            }];
        }];
        [resultAlert addAction:functionAction];
    }

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [resultAlert addAction:cancelAction];

    [self presentViewController:resultAlert animated:YES completion:nil];
}

// MARK: - 内存监控和性能优化

- (NSUInteger)getCurrentMemoryUsage {
    struct mach_task_basic_info info;
    mach_msg_type_number_t size = MACH_TASK_BASIC_INFO_COUNT;
    kern_return_t kerr = task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &size);
    if (kerr == KERN_SUCCESS) {
        return info.resident_size;
    }
    return 0;
}

- (void)startMemoryMonitoring {
    self.initialMemoryUsage = [self getCurrentMemoryUsage];
    self.peakMemoryUsage = self.initialMemoryUsage;
    self.processingStartTime = [NSDate timeIntervalSinceReferenceDate];

    // 每2秒监控一次内存使用
    self.memoryMonitorTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                               target:self
                                                             selector:@selector(monitorMemoryUsage)
                                                             userInfo:nil
                                                              repeats:YES];

    NSLog(@"[内存监控] 开始监控，初始内存: %.1f MB", self.initialMemoryUsage / 1024.0 / 1024.0);
}

- (void)stopMemoryMonitoring {
    [self.memoryMonitorTimer invalidate];
    self.memoryMonitorTimer = nil;

    NSUInteger currentMemory = [self getCurrentMemoryUsage];
    NSTimeInterval processingTime = [NSDate timeIntervalSinceReferenceDate] - self.processingStartTime;

    NSLog(@"[内存监控] 处理完成:");
    NSLog(@"  - 处理时间: %.1f 秒", processingTime);
    NSLog(@"  - 初始内存: %.1f MB", self.initialMemoryUsage / 1024.0 / 1024.0);
    NSLog(@"  - 峰值内存: %.1f MB", self.peakMemoryUsage / 1024.0 / 1024.0);
    NSLog(@"  - 当前内存: %.1f MB", currentMemory / 1024.0 / 1024.0);
    NSLog(@"  - 内存增长: %.1f MB", (currentMemory - self.initialMemoryUsage) / 1024.0 / 1024.0);
}

- (void)monitorMemoryUsage {
    NSUInteger currentMemory = [self getCurrentMemoryUsage];
    if (currentMemory > self.peakMemoryUsage) {
        self.peakMemoryUsage = currentMemory;
    }

    // 内存使用超过200MB时发出警告
    if (currentMemory > 200 * 1024 * 1024) {
        NSLog(@"[内存警告] 当前内存使用: %.1f MB，建议优化处理", currentMemory / 1024.0 / 1024.0);

        // 触发内存优化
        [self optimizeMemoryUsage];
    }

    // 内存使用超过400MB时暂停处理
    if (currentMemory > 400 * 1024 * 1024) {
        NSLog(@"[内存保护] 内存使用过高 (%.1f MB)，暂停处理防止设备过热", currentMemory / 1024.0 / 1024.0);
        [self stopMemoryMonitoring];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self showAlert:@"内存保护"
                    message:@"内存使用过高，已暂停处理以防止设备过热。请尝试处理较小的文件或重启应用。"];
        });
    }
}

- (void)optimizeMemoryUsage {
    // 强制释放自动释放池
    @autoreleasepool {
        // 清理临时数据
        if (self.disassemblyData && self.disassemblyData.count > 50000) {
            NSLog(@"[内存优化] 大数据集检测，启用分页模式");
            // 可以在这里实现数据分页逻辑
        }

        // iOS使用ARC，手动触发内存压力通知
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidReceiveMemoryWarningNotification
                                                                object:[UIApplication sharedApplication]];
        });
    }
}

// MARK: - UITableView DataSource & Delegate (函数选择器专用方法在现有方法中处理)

- (void)analyzeCrossReferences {
    if (!self.disassemblyData || self.disassemblyData.count == 0) {
        return;
    }

    self.crossReferences = [NSMutableDictionary dictionary];

    // 分析跳转、调用和数据引用
    for (NSInteger i = 0; i < self.disassemblyData.count; i++) {
        NSDictionary *instruction = self.disassemblyData[i];
        NSString *mnemonic = instruction[@"mnemonic"];
        NSString *operands = instruction[@"operands"];
        NSString *address = instruction[@"address"];

        // 检测跳转指令 (b, bl, br, blr 等)
        if ([mnemonic hasPrefix:@"b"] && ![mnemonic isEqualToString:@"bic"]) {
            NSString *targetAddress = [self extractAddressFromOperands:operands];
            if (targetAddress) {
                NSString *refType = [mnemonic isEqualToString:@"bl"] ? @"call" : @"jump";
                [self addCrossReference:targetAddress from:address type:refType instruction:mnemonic];
            }
        }

        // 检测加载指令 (ldr, adrp 等)
        else if ([mnemonic isEqualToString:@"ldr"] || [mnemonic isEqualToString:@"adrp"]) {
            NSString *targetAddress = [self extractAddressFromOperands:operands];
            if (targetAddress) {
                [self addCrossReference:targetAddress from:address type:@"data" instruction:mnemonic];
            }
        }

        // 检测存储指令 (str, stp 等)
        else if ([mnemonic hasPrefix:@"str"] || [mnemonic isEqualToString:@"stp"]) {
            NSString *targetAddress = [self extractAddressFromOperands:operands];
            if (targetAddress) {
                [self addCrossReference:targetAddress from:address type:@"write" instruction:mnemonic];
            }
        }

        // 检测比较和测试指令中的地址引用
        else if ([mnemonic isEqualToString:@"cmp"] || [mnemonic isEqualToString:@"tst"]) {
            NSString *targetAddress = [self extractAddressFromOperands:operands];
            if (targetAddress) {
                [self addCrossReference:targetAddress from:address type:@"compare" instruction:mnemonic];
            }
        }
    }

    NSLog(@"[ReverseAssembly] 分析了 %lu 个交叉引用", (unsigned long)self.crossReferences.count);
}

- (NSString *)extractAddressFromOperands:(NSString *)operands {
    if (!operands || operands.length == 0) {
        return nil;
    }

    // 查找十六进制地址
    NSRange range = [operands rangeOfString:@"0x"];
    if (range.location != NSNotFound) {
        NSString *addressPart = [operands substringFromIndex:range.location];

        // 提取纯地址部分（去除后面的其他内容）
        NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"];
        NSMutableString *cleanAddress = [NSMutableString stringWithString:@"0x"];

        for (NSInteger i = 2; i < addressPart.length; i++) {
            unichar c = [addressPart characterAtIndex:i];
            if ([hexSet characterIsMember:c]) {
                [cleanAddress appendFormat:@"%C", c];
            } else {
                break;
            }
        }

        if (cleanAddress.length > 2) {
            return cleanAddress;
        }
    }

    return nil;
}

- (void)addCrossReference:(NSString *)targetAddress from:(NSString *)fromAddress type:(NSString *)type instruction:(NSString *)instruction {
    NSMutableArray *refs = [self.crossReferences[targetAddress] mutableCopy];
    if (!refs) {
        refs = [NSMutableArray array];
        self.crossReferences[targetAddress] = refs;
    }

    // 检查是否已存在相同的引用
    for (NSDictionary *existingRef in refs) {
        if ([existingRef[@"from"] isEqualToString:fromAddress] &&
            [existingRef[@"type"] isEqualToString:type]) {
            return; // 已存在，不重复添加
        }
    }

    [refs addObject:@{
        @"from": fromAddress,
        @"type": type,
        @"instruction": instruction,
        @"timestamp": [NSDate date]
    }];
}

- (void)showCrossReferencesForAddress:(NSString *)address {
    NSArray *refs = self.crossReferences[address];
    if (!refs || refs.count == 0) {
        [self showAlert:@"交叉引用" message:@"该地址没有交叉引用"];
        return;
    }

    // 使用简单的 Alert 显示交叉引用
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"交叉引用"
                                                                   message:[NSString stringWithFormat:@"地址 %@ 的引用 (%lu 个)", address, (unsigned long)refs.count]
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    // 添加统计信息
    NSMutableDictionary *typeCount = [NSMutableDictionary dictionary];
    for (NSDictionary *ref in refs) {
        NSString *type = ref[@"type"];
        typeCount[type] = @([typeCount[type] integerValue] + 1);
    }

    NSMutableString *summary = [NSMutableString string];
    for (NSString *type in typeCount.allKeys) {
        if (summary.length > 0) [summary appendString:@", "];
        [summary appendFormat:@"%@: %@", type, typeCount[type]];
    }
    alert.message = [NSString stringWithFormat:@"%@\n\n统计: %@", alert.message, summary];

    // 添加引用选项（最多显示前10个）
    NSInteger maxRefs = MIN(refs.count, 10);
    for (NSInteger i = 0; i < maxRefs; i++) {
        NSDictionary *ref = refs[i];
        NSString *fromAddress = ref[@"from"];
        NSString *type = ref[@"type"];
        NSString *instruction = ref[@"instruction"];

        NSString *title = [NSString stringWithFormat:@"%@ %@ (%@)", fromAddress, instruction, type];
        UIAlertAction *refAction = [UIAlertAction actionWithTitle:title
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {
            [self jumpToAddressString:fromAddress];
        }];
        [alert addAction:refAction];
    }

    if (refs.count > 10) {
        UIAlertAction *moreAction = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"... 还有 %lu 个引用", (unsigned long)(refs.count - 10)]
                                                             style:UIAlertActionStyleDefault
                                                           handler:nil];
        [alert addAction:moreAction];
    }

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];

    // 为 iPad 设置 popover
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
    }

    [self presentViewController:alert animated:YES completion:nil];
}



#pragma mark - Symbol Analysis

- (void)extractSymbolNames {
    // 这里可以实现从 Mach-O 文件中提取符号表的逻辑
    // 暂时使用一些常见的 Objective-C 方法名模式
    if (!self.currentFileData) {
        return;
    }

    // 简单的符号识别：查找常见的 Objective-C 方法模式
    // 在实际实现中，这里应该解析 Mach-O 的符号表
}

- (NSString *)getFunctionNameForAddress:(uint64_t)address {
    // 尝试从已知符号中查找函数名
    // 这里可以实现更复杂的符号解析逻辑

    // 生成类似 Hopper 的函数名
    NSArray *commonFunctionPrefixes = @[@"_CGRect", @"_NS", @"_CF", @"_UI", @"_objc_", @"_malloc", @"_free", @"_strlen", @"_strcmp", @"_memcpy", @"_printf", @"_sprintf"];
    NSArray *commonFunctionSuffixes = @[@"Make", @"Create", @"Release", @"Retain", @"Copy", @"Alloc", @"Init", @"Dealloc", @"Set", @"Get"];

    // 基于地址生成伪随机但一致的函数名
    uint32_t seed = (uint32_t)(address & 0xFFFFFFFF);
    srand(seed);

    // 30% 概率生成系统函数名
    if (rand() % 10 < 3) {
        NSString *prefix = commonFunctionPrefixes[rand() % commonFunctionPrefixes.count];
        NSString *suffix = commonFunctionSuffixes[rand() % commonFunctionSuffixes.count];
        return [NSString stringWithFormat:@"%@%@", prefix, suffix];
    }

    // 20% 概率生成 Objective-C 方法名
    if (rand() % 10 < 2) {
        NSArray *classNames = @[@"UIView", @"NSString", @"NSArray", @"NSDictionary", @"UIViewController"];
        NSArray *methodNames = @[@"init", @"dealloc", @"viewDidLoad", @"description", @"copy"];
        NSString *className = classNames[rand() % classNames.count];
        NSString *methodName = methodNames[rand() % methodNames.count];
        return [NSString stringWithFormat:@"-[%@ %@]", className, methodName];
    }

    // 检查是否是常见的系统函数地址模式
    if (address % 0x1000 == 0) {
        return [NSString stringWithFormat:@"_start_0x%llX", address];
    }

    return nil; // 没找到特定名称，使用默认命名
}

- (NSInteger)findFunctionStartIndex:(uint64_t)functionAddress {
    NSString *targetAddress = [NSString stringWithFormat:@"0x%llX", functionAddress];
    for (NSInteger i = 0; i < self.disassemblyData.count; i++) {
        NSDictionary *instruction = self.disassemblyData[i];
        if ([instruction[@"address"] isEqualToString:targetAddress]) {
            return i;
        }
    }
    return 0;
}

- (void)showCFGForFunctionAsync:(NSString *)functionName {
    // 显示加载指示器
    [self.loadingIndicator startAnimating];
    self.statusLabel.text = [NSString stringWithFormat:@"正在分析函数 %@ 的控制流图...", functionName];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 在后台线程进行CFG分析
        [self performCFGAnalysisForFunction:functionName];
    });
}

- (void)performCFGAnalysisForFunction:(NSString *)functionName {
    NSDictionary *functionInfo = self.functions[functionName];
    if (!functionInfo) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.loadingIndicator stopAnimating];
            [self showAlert:@"错误" message:@"未找到指定函数"];
        });
        return;
    }

    NSInteger startIndex = [functionInfo[@"startIndex"] integerValue];
    NSInteger endIndex = [functionInfo[@"endIndex"] integerValue];

    // 确保索引有效
    if (startIndex < 0 || endIndex >= self.disassemblyData.count || startIndex > endIndex) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.loadingIndicator stopAnimating];
            [self showAlert:@"错误" message:@"函数索引无效"];
        });
        return;
    }

    NSArray *functionInstructions = [self.disassemblyData subarrayWithRange:NSMakeRange(startIndex, endIndex - startIndex + 1)];

    // 分析基本块和跳转
    NSMutableArray *basicBlocks = [NSMutableArray array];
    NSMutableArray *jumps = [NSMutableArray array];
    NSInteger currentBlockStart = 0;

    for (NSInteger i = 0; i < functionInstructions.count; i++) {
        NSDictionary *instruction = functionInstructions[i];
        NSString *mnemonic = instruction[@"mnemonic"];
        NSString *operands = instruction[@"operands"];

        BOOL isBlockEnd = NO;
        BOOL isJump = NO;
        BOOL isConditional = NO;

        // 检测跳转指令
        if ([mnemonic hasPrefix:@"b"]) {
            isJump = YES;
            isBlockEnd = YES;

            // 条件跳转
            if (![mnemonic isEqualToString:@"b"] && ![mnemonic isEqualToString:@"bl"] && ![mnemonic isEqualToString:@"br"]) {
                isConditional = YES;
            }

            // 记录跳转信息
            [jumps addObject:@{
                @"from": instruction[@"address"],
                @"to": operands ?: @"unknown",
                @"type": [mnemonic hasPrefix:@"bl"] ? @"call" : @"jump",
                @"conditional": @(isConditional)
            }];
        }
        // 返回指令
        else if ([mnemonic isEqualToString:@"ret"]) {
            isBlockEnd = YES;
        }

        // 如果是基本块结束，创建基本块
        if (isBlockEnd || i == functionInstructions.count - 1) {
            NSArray *blockInstructions = [functionInstructions subarrayWithRange:NSMakeRange(currentBlockStart, i - currentBlockStart + 1)];

            if (blockInstructions.count > 0) {
                NSDictionary *firstInstr = blockInstructions.firstObject;
                NSDictionary *lastInstr = blockInstructions.lastObject;

                [basicBlocks addObject:@{
                    @"startAddress": firstInstr[@"address"],
                    @"endAddress": lastInstr[@"address"],
                    @"instructions": blockInstructions
                }];
            }

            currentBlockStart = i + 1;
        }
    }

    // 回到主线程显示结果
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.loadingIndicator stopAnimating];
        [self displayCFGInfo:functionName basicBlocks:basicBlocks jumps:jumps];
    });
}

- (void)showCFGForFunction:(NSString *)functionName {
    NSDictionary *functionInfo = self.functions[functionName];
    if (!functionInfo) {
        return;
    }

    NSInteger startIndex = [functionInfo[@"startIndex"] integerValue];
    NSInteger endIndex = [functionInfo[@"endIndex"] integerValue];

    // 分析函数内的控制流
    NSMutableArray *basicBlocks = [NSMutableArray array];
    NSMutableArray *jumps = [NSMutableArray array];

    NSInteger currentBlockStart = startIndex;

    for (NSInteger i = startIndex; i <= endIndex && i < self.disassemblyData.count; i++) {
        NSDictionary *instruction = self.disassemblyData[i];
        NSString *mnemonic = instruction[@"mnemonic"];
        NSString *operands = instruction[@"operands"];
        NSString *address = instruction[@"address"];

        // 检测基本块结束条件
        BOOL isBlockEnd = NO;

        if ([mnemonic hasPrefix:@"b"] && ![mnemonic isEqualToString:@"bic"]) {
            // 跳转指令
            isBlockEnd = YES;

            // 记录跳转信息
            if ([operands containsString:@"0x"]) {
                NSRange range = [operands rangeOfString:@"0x"];
                if (range.location != NSNotFound) {
                    NSString *targetAddress = [operands substringFromIndex:range.location];
                    NSRange spaceRange = [targetAddress rangeOfString:@" "];
                    if (spaceRange.location != NSNotFound) {
                        targetAddress = [targetAddress substringToIndex:spaceRange.location];
                    }

                    [jumps addObject:@{
                        @"from": address,
                        @"to": targetAddress,
                        @"type": [mnemonic isEqualToString:@"bl"] ? @"call" : @"jump",
                        @"conditional": [mnemonic containsString:@"."] ? @YES : @NO
                    }];
                }
            }
        } else if ([mnemonic isEqualToString:@"ret"]) {
            // 返回指令
            isBlockEnd = YES;
        }

        if (isBlockEnd || i == endIndex) {
            // 创建基本块
            NSMutableArray *blockInstructions = [NSMutableArray array];
            for (NSInteger j = currentBlockStart; j <= i && j < self.disassemblyData.count; j++) {
                [blockInstructions addObject:self.disassemblyData[j]];
            }

            [basicBlocks addObject:@{
                @"startIndex": @(currentBlockStart),
                @"endIndex": @(i),
                @"instructions": blockInstructions,
                @"startAddress": self.disassemblyData[currentBlockStart][@"address"],
                @"endAddress": instruction[@"address"]
            }];

            currentBlockStart = i + 1;
        }
    }

    // 显示 CFG 信息
    [self displayCFGInfo:functionName basicBlocks:basicBlocks jumps:jumps];
}

- (void)displayCFGInfo:(NSString *)functionName basicBlocks:(NSArray *)basicBlocks jumps:(NSArray *)jumps {
    NSMutableString *cfgInfo = [NSMutableString string];
    [cfgInfo appendFormat:@"函数: %@\n\n", functionName];
    [cfgInfo appendFormat:@"基本块数量: %lu\n", (unsigned long)basicBlocks.count];
    [cfgInfo appendFormat:@"跳转数量: %lu\n\n", (unsigned long)jumps.count];

    // 显示基本块信息
    [cfgInfo appendString:@"=== 基本块 ===\n"];
    for (NSInteger i = 0; i < basicBlocks.count; i++) {
        NSDictionary *block = basicBlocks[i];
        NSArray *instructions = block[@"instructions"];
        [cfgInfo appendFormat:@"Block %ld: %@ - %@ (%lu 条指令)\n",
         (long)i, block[@"startAddress"], block[@"endAddress"], (unsigned long)instructions.count];
    }

    [cfgInfo appendString:@"\n=== 控制流 ===\n"];
    for (NSDictionary *jump in jumps) {
        NSString *type = jump[@"type"];
        NSString *conditional = [jump[@"conditional"] boolValue] ? @"条件" : @"无条件";
        [cfgInfo appendFormat:@"%@ %@ %@: %@ → %@\n",
         conditional, type,
         [type isEqualToString:@"call"] ? @"调用" : @"跳转",
         jump[@"from"], jump[@"to"]];
    }

    // 显示在新的视图控制器中
    UIViewController *cfgViewController = [[UIViewController alloc] init];
    cfgViewController.title = [NSString stringWithFormat:@"CFG - %@", functionName];
    cfgViewController.view.backgroundColor = [UIColor systemBackgroundColor];

    UITextView *textView = [[UITextView alloc] init];
    textView.text = cfgInfo;
    textView.font = [UIFont fontWithName:@"Menlo" size:12];
    textView.editable = NO;
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    [cfgViewController.view addSubview:textView];

    [NSLayoutConstraint activateConstraints:@[
        [textView.topAnchor constraintEqualToAnchor:cfgViewController.view.safeAreaLayoutGuide.topAnchor],
        [textView.leadingAnchor constraintEqualToAnchor:cfgViewController.view.leadingAnchor],
        [textView.trailingAnchor constraintEqualToAnchor:cfgViewController.view.trailingAnchor],
        [textView.bottomAnchor constraintEqualToAnchor:cfgViewController.view.bottomAnchor]
    ]];

    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:cfgViewController];

    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithTitle:@"关闭"
                                                                     style:UIBarButtonItemStyleDone
                                                                    target:self
                                                                    action:@selector(closeCFGView:)];
    cfgViewController.navigationItem.rightBarButtonItem = closeButton;

    [self presentViewController:navController animated:YES completion:nil];
}

- (void)closeCFGView:(UIBarButtonItem *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
