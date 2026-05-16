//
//  BaseAddressScriptViewController.m
//  基址脚本管理器实现
//

#import "BaseAddressScriptViewController.h"
#import "BaseAddressScriptManager.h"
#import "BaseAddressScriptEditViewController.h"
#import "ProcessManager.h"

@interface BaseAddressScriptViewController ()

@property (nonatomic, strong) BaseAddressScriptManager *scriptManager;
@property (nonatomic, strong) NSArray<BaseAddressScript *> *currentScripts;
@property (nonatomic, copy) NSString *currentCategory;

@end

@implementation BaseAddressScriptViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"指针脚本";
    
    // 初始化管理器
    self.scriptManager = [BaseAddressScriptManager sharedManager];
    self.currentCategory = @"默认";
    
    // 设置UI
    [self setupNavigationBar];
    [self setupCategoryControl];
    [self setupTableView];
    
    // 加载数据
    [self loadScriptsForCurrentCategory];
    
    // 注册通知
    [self registerNotifications];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 确保导航栏可见
    self.navigationController.navigationBar.hidden = NO;
    
    // 刷新数据
    [self loadScriptsForCurrentCategory];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UI Setup

- (void)setupNavigationBar {
    // 添加按钮
    self.addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                   target:self
                                                                   action:@selector(addButtonTapped:)];
    
    // 更多按钮
    self.moreButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"]
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(moreButtonTapped:)];
    
    self.navigationItem.rightBarButtonItems = @[self.addButton, self.moreButton];
}

- (void)setupCategoryControl {
    // 创建分类选择控件
    NSArray *categories = self.scriptManager.categories;
    self.categorySegmentControl = [[UISegmentedControl alloc] initWithItems:categories];
    self.categorySegmentControl.selectedSegmentIndex = 0;
    self.categorySegmentControl.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.categorySegmentControl addTarget:self
                                    action:@selector(categoryChanged:)
                          forControlEvents:UIControlEventValueChanged];
    
    [self.view addSubview:self.categorySegmentControl];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.categorySegmentControl.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10],
        [self.categorySegmentControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.categorySegmentControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.categorySegmentControl.heightAnchor constraintEqualToConstant:32]
    ]];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 注册单元格
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ScriptCell"];
    
    [self.view addSubview:self.tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.categorySegmentControl.bottomAnchor constant:10],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
}

#pragma mark - Data Loading

- (void)loadScriptsForCurrentCategory {
    self.currentScripts = [self.scriptManager scriptsInCategory:self.currentCategory];
    [self.tableView reloadData];
}

- (void)updateCategoryControl {
    // 重新创建分类控件
    [self.categorySegmentControl removeFromSuperview];
    [self setupCategoryControl];
}

- (void)updateCategorySegmentControl {
    [self updateCategoryControl];
}

#pragma mark - Actions

- (void)addButtonTapped:(UIBarButtonItem *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"创建指针链脚本"
                                                                   message:@"选择创建方式"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    // 快速创建
    UIAlertAction *quickAction = [UIAlertAction actionWithTitle:@"🚀 快速创建"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * _Nonnull action) {
        [self showQuickCreateDialog];
    }];
    [alert addAction:quickAction];

    // 从指针链创建
    UIAlertAction *fromPointerAction = [UIAlertAction actionWithTitle:@"🔗 从指针链创建"
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * _Nonnull action) {
        [self showCreateFromPointerChainDialog];
    }];
    [alert addAction:fromPointerAction];

    // 取消
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];

    // iPad 支持
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.barButtonItem = sender;
    }

    [self presentViewController:alert animated:YES completion:^{}];
}

// 快速创建脚本
- (void)showQuickCreateDialog {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"快速创建脚本"
                                                                   message:@"输入脚本名称即可快速创建"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"脚本名称 (如: 血量修改)";
    }];

    UIAlertAction *createAction = [UIAlertAction actionWithTitle:@"创建"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
        NSString *scriptName = alert.textFields.firstObject.text;
        if (scriptName.length > 0) {
            [self quickCreateScriptWithName:scriptName];
        }
    }];
    [alert addAction:createAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * _Nonnull action) {}];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:^{}];
}

// 从指针链创建脚本
- (void)showCreateFromPointerChainDialog {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"从指针链创建脚本"
                                                                   message:@"粘贴指针扫描结果的指针链"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"脚本名称";
    }];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"指针链 (如: wp2+0xF0D2B0+0x228+0x348)";
        // 尝试从剪贴板获取内容
        NSString *clipboardText = UIPasteboard.generalPasteboard.string;
        if (clipboardText && [self isValidPointerChain:clipboardText]) {
            textField.text = clipboardText;
        }
    }];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"期望值 (如: 999)";
    }];

    UIAlertAction *createAction = [UIAlertAction actionWithTitle:@"创建"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
        NSString *scriptName = alert.textFields[0].text;
        NSString *pointerChain = alert.textFields[1].text;
        NSString *expectedValue = alert.textFields[2].text;

        if (scriptName.length > 0 && pointerChain.length > 0) {
            [self createScriptFromPointerChain:pointerChain name:scriptName expectedValue:expectedValue];
        }
    }];
    [alert addAction:createAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * _Nonnull action) {}];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:^{}];
}

// 快速创建脚本实现
- (void)quickCreateScriptWithName:(NSString *)name {
    BaseAddressScript *script = [[BaseAddressScript alloc] initWithName:name type:BaseAddressScriptTypePointerChain];
    script.scriptDescription = [NSString stringWithFormat:@"快速创建的指针链脚本: %@", name];
    script.category = self.currentCategory;
    script.targetProcess = [ProcessManager sharedManager].selectedProcessName ?: @"";

    // 添加一个示例指针链
    BaseAddressPointerChain *exampleChain = [[BaseAddressPointerChain alloc] initWithName:name valueType:VMMemValueTypeSignedInt];
    exampleChain.expectedValue = @"999";
    [script addPointerChain:exampleChain];

    // 添加到管理器
    [self.scriptManager addScript:script];

    // 刷新列表
    [self loadScriptsForCurrentCategory];

    // 直接进入编辑界面
    BaseAddressScriptEditViewController *editVC = [[BaseAddressScriptEditViewController alloc] initWithScript:script];
    [self.navigationController pushViewController:editVC animated:YES];
}

// 从指针链创建脚本实现
- (void)createScriptFromPointerChain:(NSString *)pointerChainString name:(NSString *)name expectedValue:(NSString *)expectedValue {
    BaseAddressScript *script = [[BaseAddressScript alloc] initWithName:name type:BaseAddressScriptTypePointerChain];
    script.scriptDescription = [NSString stringWithFormat:@"从指针链创建: %@", pointerChainString];
    script.category = self.currentCategory;
    script.targetProcess = [ProcessManager sharedManager].selectedProcessName ?: @"";

    // 解析指针链并创建指针链对象
    BaseAddressPointerChain *chain = [self parsePointerChainString:pointerChainString];
    if (chain) {
        chain.name = name;
        chain.expectedValue = expectedValue;
        chain.valueType = VMMemValueTypeSignedInt; // 默认为32位整数
        [script addPointerChain:chain];
    }

    // 添加到管理器
    [self.scriptManager addScript:script];

    // 刷新列表
    [self loadScriptsForCurrentCategory];

    // 显示成功提示
    NSString *message = chain ? @"脚本创建成功！" : @"脚本已创建，但指针链解析失败，请手动编辑。";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"创建完成"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *editAction = [UIAlertAction actionWithTitle:@"编辑脚本"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
        BaseAddressScriptEditViewController *editVC = [[BaseAddressScriptEditViewController alloc] initWithScript:script];
        [self.navigationController pushViewController:editVC animated:YES];
    }];
    [alert addAction:editAction];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {}];
    [alert addAction:okAction];

    [self presentViewController:alert animated:YES completion:^{}];
}

// 验证指针链格式
- (BOOL)isValidPointerChain:(NSString *)pointerChain {
    if (!pointerChain || pointerChain.length == 0) {
        return NO;
    }

    // 清理输入字符串，移除状态符号和多余空格
    NSString *cleanChain = [pointerChain stringByReplacingOccurrencesOfString:@"✅ " withString:@""];
    cleanChain = [cleanChain stringByReplacingOccurrencesOfString:@"❌ " withString:@""];
    cleanChain = [cleanChain stringByReplacingOccurrencesOfString:@" " withString:@""];

    // 只支持新格式：wp2+0xF0D2B0+0x228+0x348+0x38C
    NSRange plusRange = [cleanChain rangeOfString:@"+"];
    if (plusRange.location != NSNotFound) {
        NSArray *components = [cleanChain componentsSeparatedByString:@"+"];
        return components.count >= 2;
    }

    return NO;
}

// 解析指针链字符串
- (BaseAddressPointerChain *)parsePointerChainString:(NSString *)pointerChainString {
    if (![self isValidPointerChain:pointerChainString]) {
        return nil;
    }

    // 清理输入字符串，移除状态符号和多余空格
    NSString *cleanChain = [pointerChainString stringByReplacingOccurrencesOfString:@"✅ " withString:@""];
    cleanChain = [cleanChain stringByReplacingOccurrencesOfString:@"❌ " withString:@""];
    cleanChain = [cleanChain stringByReplacingOccurrencesOfString:@" " withString:@""];

    // 解析格式：wp2+0xF0D2B0+0x228+0x348+0x38C
    NSArray<NSString *> *components = [cleanChain componentsSeparatedByString:@"+"];

    if (components.count < 2) {
        return nil;
    }

    BaseAddressPointerChain *chain = [[BaseAddressPointerChain alloc] initWithName:@"解析的指针链"
                                                                         valueType:VMMemValueTypeSignedInt];

    // 第一个组件是模块名
    NSString *moduleName = components[0];

    // 第二个组件是基址偏移
    NSString *baseOffsetStr = components[1];
    uintptr_t baseOffset = [self parseHexString:baseOffsetStr];

    // 创建基址节点
    BaseAddressPointerNode *baseNode = [[BaseAddressPointerNode alloc] initWithModuleName:moduleName
                                                                               baseAddress:0
                                                                                    offset:baseOffset];
    [chain addNode:baseNode];

    // 解析后续偏移（从第3个组件开始）
    for (NSInteger i = 2; i < components.count; i++) {
        NSString *offsetStr = components[i];
        uintptr_t offset = [self parseHexString:offsetStr];

        BaseAddressPointerNode *offsetNode = [[BaseAddressPointerNode alloc] initWithModuleName:@""
                                                                                     baseAddress:0
                                                                                          offset:offset];
        [chain addNode:offsetNode];
    }

    return chain;
}

// 解析十六进制字符串（支持0x前缀和负数）
- (uintptr_t)parseHexString:(NSString *)hexStr {
    if (!hexStr || hexStr.length == 0) {
        return 0;
    }

    // 移除空格
    NSString *cleanStr = [hexStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

    // 检查是否为负数
    BOOL isNegative = [cleanStr hasPrefix:@"-"];
    if (isNegative) {
        cleanStr = [cleanStr substringFromIndex:1];
    }

    unsigned long long value = 0;
    NSScanner *scanner = [NSScanner scannerWithString:cleanStr];

    // 如果有0x前缀，NSScanner会自动处理
    if ([cleanStr hasPrefix:@"0x"] || [cleanStr hasPrefix:@"0X"]) {
        [scanner scanHexLongLong:&value];
    } else {
        // 没有0x前缀，直接按十六进制解析
        [scanner scanHexLongLong:&value];
    }

    // 处理负数
    if (isNegative) {
        return (uintptr_t)(-(long long)value);
    }

    return (uintptr_t)value;
}

- (void)moreButtonTapped:(UIBarButtonItem *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"更多操作"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    // 导入脚本
    UIAlertAction *importAction = [UIAlertAction actionWithTitle:@"导入脚本"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self showImportOptions];
    }];
    [alert addAction:importAction];
    
    // 导出所有脚本
    UIAlertAction *exportAllAction = [UIAlertAction actionWithTitle:@"导出所有脚本"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * _Nonnull action) {
        [self showExportOptions];
    }];
    [alert addAction:exportAllAction];
    
    // 管理分类
    UIAlertAction *manageCategoriesAction = [UIAlertAction actionWithTitle:@"管理分类"
                                                                     style:UIAlertActionStyleDefault
                                                                   handler:^(UIAlertAction * _Nonnull action) {
        [self showCategoryManagement];
    }];
    [alert addAction:manageCategoriesAction];
    
    // 清空所有脚本
    UIAlertAction *clearAllAction = [UIAlertAction actionWithTitle:@"清空所有脚本"
                                                             style:UIAlertActionStyleDestructive
                                                           handler:^(UIAlertAction * _Nonnull action) {
        [self confirmClearAllScripts];
    }];
    [alert addAction:clearAllAction];
    
    // 取消
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];
    
    // iPad 支持
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.barButtonItem = sender;
    }
    
    [self presentViewController:alert animated:YES completion:^{}];
}

- (void)categoryChanged:(UISegmentedControl *)sender {
    NSInteger selectedIndex = sender.selectedSegmentIndex;
    if (selectedIndex >= 0 && selectedIndex < self.scriptManager.categories.count) {
        self.currentCategory = self.scriptManager.categories[selectedIndex];
        [self loadScriptsForCurrentCategory];
    }
}

#pragma mark - Script Management

- (void)editScript:(BaseAddressScript *)script {
    BaseAddressScriptEditViewController *editVC = [[BaseAddressScriptEditViewController alloc] initWithScript:script];

    // 确保导航栏可见
    self.navigationController.navigationBar.hidden = NO;

    // 使用导航控制器推入编辑界面
    [self.navigationController pushViewController:editVC animated:YES];
}

- (void)executeScript:(BaseAddressScript *)script {
    BOOL success = [self.scriptManager executeScript:script];

    // 立即刷新界面以显示状态变化
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });

    NSString *message = success ? @"脚本执行成功" : @"脚本执行失败";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"执行结果"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {}];
    [alert addAction:okAction];

    [self presentViewController:alert animated:YES completion:^{}];
}

// 切换脚本执行状态
- (void)toggleScriptExecution:(BaseAddressScript *)script {
    if (script.status == BaseAddressScriptStatusActive) {
        // 如果脚本正在运行，停止它
        [self.scriptManager stopScript:script];

        // 显示停止提示
        [self showToast:@"脚本已停止"];
    } else {
        // 如果脚本未运行，启动它
        BOOL success = [self.scriptManager executeScript:script];

        // 显示启动结果
        NSString *message = success ? @"脚本已启动" : @"脚本启动失败";
        [self showToast:message];
    }

    // 立即刷新界面以显示状态变化
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

// 显示简洁的Toast提示
- (void)showToast:(NSString *)message {
    UIAlertController *toast = [UIAlertController alertControllerWithTitle:nil
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [self presentViewController:toast animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [toast dismissViewControllerAnimated:YES completion:nil];
        });
    }];
}

- (void)shareScript:(BaseAddressScript *)script {
    // 检查是否为加密脚本
    if (script.isEncrypted) {
        // 加密脚本只能加密分享
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"加密脚本分享"
                                                                       message:@"此脚本为加密脚本，只能进行加密分享"
                                                                preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *encryptedShareAction = [UIAlertAction actionWithTitle:@"🔐 加密分享"
                                                                       style:UIAlertActionStyleDefault
                                                                     handler:^(UIAlertAction * _Nonnull action) {
            [self showAuthorInfoDialog:script];
        }];
        [alert addAction:encryptedShareAction];

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                               style:UIAlertActionStyleCancel
                                                             handler:nil];
        [alert addAction:cancelAction];

        [self presentViewController:alert animated:YES completion:^{}];
        return;
    }

    // 普通脚本可以选择分享方式
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"分享脚本"
                                                                   message:@"选择分享方式"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    // 普通分享
    UIAlertAction *normalShareAction = [UIAlertAction actionWithTitle:@"📄 普通分享"
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * _Nonnull action) {
        [self shareScript:script encrypted:NO password:nil];
    }];
    [alert addAction:normalShareAction];

    // 加密分享
    UIAlertAction *encryptedShareAction = [UIAlertAction actionWithTitle:@"🔐 加密分享"
                                                                   style:UIAlertActionStyleDefault
                                                                 handler:^(UIAlertAction * _Nonnull action) {
        [self showAuthorInfoDialog:script];
    }];
    [alert addAction:encryptedShareAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];

    // iPad 支持
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
    }

    [self presentViewController:alert animated:YES completion:^{}];
}

// 作者信息输入对话框
- (void)showAuthorInfoDialog:(BaseAddressScript *)script {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置作者信息"
                                                                   message:@"为加密分享设置作者信息和简介"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    // 作者名称输入框
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"作者名称（必填）";
        textField.text = @"";  // 默认为空，不填入现有作者信息
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];

    // 作者简介输入框
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"作者简介（选填）";
        textField.text = @"";  // 默认为空，不填入现有简介信息
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];

    // 确定按钮
    UIAlertAction *nextAction = [UIAlertAction actionWithTitle:@"下一步"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
        NSString *authorName = alert.textFields[0].text;
        NSString *authorDescription = alert.textFields[1].text;

        if (!authorName || authorName.length == 0) {
            [self showAlert:@"错误" message:@"请输入作者名称"];
            return;
        }

        // 保存作者信息到临时变量（不直接修改脚本）
        self.tempAuthorName = authorName;
        self.tempAuthorDescription = authorDescription;

        // 继续到密码设置
        [self showPasswordDialogForScript:script];
    }];
    [alert addAction:nextAction];

    // 取消按钮
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * _Nonnull action) {}];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:^{}];
}

// 单个脚本密码对话框
- (void)showPasswordDialogForScript:(BaseAddressScript *)script {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置验证码"
                                                                   message:@"为加密脚本设置验证码"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"输入验证码 (4-16位)";
        textField.secureTextEntry = YES;
    }];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"确认验证码";
        textField.secureTextEntry = YES;
    }];

    UIAlertAction *shareAction = [UIAlertAction actionWithTitle:@"分享"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * _Nonnull action) {
        NSString *password = alert.textFields[0].text;
        NSString *confirmPassword = alert.textFields[1].text;

        if (password.length < 4 || password.length > 16) {
            [self showAlert:@"错误" message:@"验证码长度必须在4-16位之间"];
            return;
        }

        if (![password isEqualToString:confirmPassword]) {
            [self showAlert:@"错误" message:@"两次输入的验证码不一致"];
            return;
        }

        [self shareScript:script encrypted:YES password:password];
    }];
    [alert addAction:shareAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * _Nonnull action) {}];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:^{}];
}

// 执行脚本分享
- (void)shareScript:(BaseAddressScript *)script encrypted:(BOOL)encrypted password:(NSString *)password {
    if (encrypted && self.tempAuthorName) {
        // 使用带作者信息的分享方法
        [self.scriptManager shareScript:script
                         fromController:self
                              encrypted:encrypted
                               password:password
                             authorName:self.tempAuthorName
                        authorDescription:self.tempAuthorDescription
                             completion:^(BOOL success) {
            // 清理临时作者信息
            self.tempAuthorName = nil;
            self.tempAuthorDescription = nil;

            if (!success) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showAlert:@"分享失败" message:@"无法分享脚本"];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showAlert:@"分享成功" message:@"加密脚本已分享，请将验证码告知接收方"];
                });
            }
        }];
    } else {
        // 普通分享
        [self.scriptManager shareScript:script
                         fromController:self
                              encrypted:encrypted
                               password:password
                             completion:^(BOOL success) {
            if (!success) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showAlert:@"分享失败" message:@"无法分享脚本"];
                });
            } else if (encrypted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showAlert:@"分享成功" message:@"加密脚本已分享，请将验证码告知接收方"];
                });
            }
        }];
    }
}

- (void)deleteScript:(BaseAddressScript *)script {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"删除脚本"
                                                                   message:[NSString stringWithFormat:@"确定要删除脚本 \"%@\" 吗？", script.name]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"删除"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self.scriptManager removeScript:script];
    }];
    [alert addAction:deleteAction];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * _Nonnull action) {}];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:^{}];
}

#pragma mark - Import/Export

- (void)showImportOptions {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"导入脚本"
                                                                   message:@"选择导入方式"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    // 从文件导入
    UIAlertAction *fromFileAction = [UIAlertAction actionWithTitle:@"📁 从文件导入"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
        [self showDocumentPicker];
    }];
    [alert addAction:fromFileAction];

    // 从剪贴板导入
    UIAlertAction *fromClipboardAction = [UIAlertAction actionWithTitle:@"📋 从剪贴板导入"
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * _Nonnull action) {
        [self importFromClipboard];
    }];
    [alert addAction:fromClipboardAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];

    // iPad 支持
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
    }

    [self presentViewController:alert animated:YES completion:^{}];
}

// 显示文档选择器
- (void)showDocumentPicker {
    UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc]
                                                     initWithDocumentTypes:@[@"public.text", @"public.data"]
                                                                    inMode:UIDocumentPickerModeImport];
    documentPicker.delegate = self;
    documentPicker.allowsMultipleSelection = NO;

    [self presentViewController:documentPicker animated:YES completion:^{}];
}

// 从剪贴板导入
- (void)importFromClipboard {
    NSString *clipboardText = UIPasteboard.generalPasteboard.string;
    if (!clipboardText || clipboardText.length == 0) {
        [self showAlert:@"错误" message:@"剪贴板为空"];
        return;
    }

    [self processImportedContent:clipboardText];
}

// 处理导入的内容
- (void)processImportedContent:(NSString *)content {
    // 检查是否为加密内容
    if ([content hasPrefix:@"ENCRYPTED_BAS_V1:"]) {
        [self showPasswordInputForEncryptedContent:content];
    } else {
        [self importScriptsFromContent:content];
    }
}

// 显示密码输入对话框
- (void)showPasswordInputForEncryptedContent:(NSString *)encryptedContent {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"输入验证码"
                                                                   message:@"此脚本已加密，请输入验证码"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"验证码";
        textField.secureTextEntry = YES;
    }];

    UIAlertAction *decryptAction = [UIAlertAction actionWithTitle:@"解密"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * _Nonnull action) {
        NSString *password = alert.textFields[0].text;
        NSString *decryptedContent = [self.scriptManager decryptString:encryptedContent withPassword:password];

        if (decryptedContent) {
            // 解密成功后，先显示作者信息，然后再导入
            [self showAuthorInfoBeforeImport:decryptedContent password:password];
        } else {
            [self showAlert:@"解密失败" message:@"验证码错误或文件已损坏"];
        }
    }];
    [alert addAction:decryptAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * _Nonnull action) {}];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:^{}];
}

// 显示作者信息后导入
- (void)showAuthorInfoBeforeImport:(NSString *)decryptedContent password:(NSString *)password {
    // 解析解密后的内容以获取作者信息
    NSError *error;
    NSData *jsonData = [decryptedContent dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];

    if (error || !jsonObject) {
        // 如果解析失败，直接导入
        [self importScriptsFromContentWithPassword:decryptedContent password:password];
        return;
    }

    // 提取作者信息 - 先检查外层（批量格式），再检查内层（单个脚本格式）
    NSString *authorName = jsonObject[@"authorName"];
    NSString *authorDescription = jsonObject[@"authorDescription"];

    // 如果外层没有作者信息，检查是否为单个脚本格式
    if ((!authorName || authorName.length == 0) && jsonObject[@"scriptId"]) {
        // 单个脚本格式，从脚本内部获取作者信息
        authorName = jsonObject[@"author"];
        authorDescription = jsonObject[@"description"];
    }

    // 如果仍然没有作者信息，直接导入
    if (!authorName || authorName.length == 0) {
        [self importScriptsFromContentWithPassword:decryptedContent password:password];
        return;
    }

    // 显示作者信息对话框
    NSString *message = [NSString stringWithFormat:@"作者：%@", authorName];
    if (authorDescription && authorDescription.length > 0) {
        message = [NSString stringWithFormat:@"作者：%@\n简介：%@", authorName, authorDescription];
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"脚本作者信息"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *importAction = [UIAlertAction actionWithTitle:@"导入脚本"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self importScriptsFromContentWithPassword:decryptedContent password:password];
    }];
    [alert addAction:importAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * _Nonnull action) {}];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:^{}];
}

// 从内容导入脚本
- (void)importScriptsFromContent:(NSString *)content {
    NSLog(@"[BaseAddressScript] 开始导入脚本内容");

    // 先尝试解析JSON来判断格式
    NSError *error;
    NSData *jsonData = [content dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];

    if (error || !jsonObject) {
        NSLog(@"[BaseAddressScript] JSON解析失败: %@", error.localizedDescription);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showAlert:@"导入失败" message:@"文件格式错误"];
        });
        return;
    }

    BOOL success = NO;

    // 检查是否为批量导出格式（包含scripts数组）
    if (jsonObject[@"scripts"]) {
        NSLog(@"[BaseAddressScript] 检测到批量脚本格式");
        success = [self.scriptManager importScriptsFromString:content];
    } else if (jsonObject[@"scriptId"]) {
        // 单个脚本格式，需要包装成批量格式
        NSLog(@"[BaseAddressScript] 检测到单个脚本格式，转换为批量格式");

        // 检查是否为加密脚本
        BOOL isEncrypted = [jsonObject[@"encrypted"] boolValue];

        NSDictionary *wrapperData = @{
            @"scripts": @[content],
            @"categories": @[],
            @"exportDate": [[NSDateFormatter new] stringFromDate:[NSDate date]],
            @"version": @"1.0",
            @"encrypted": isEncrypted ? @YES : @NO
        };

        NSData *wrapperJsonData = [NSJSONSerialization dataWithJSONObject:wrapperData
                                                                  options:NSJSONWritingPrettyPrinted
                                                                    error:&error];
        if (!error && wrapperJsonData) {
            NSString *wrapperString = [[NSString alloc] initWithData:wrapperJsonData encoding:NSUTF8StringEncoding];
            success = [self.scriptManager importScriptsFromString:wrapperString];
        }
    } else {
        NSLog(@"[BaseAddressScript] 未知的脚本格式");
    }

    if (success) {
        NSLog(@"[BaseAddressScript] 脚本导入成功，刷新界面");
        // 强制刷新界面
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadScriptsForCurrentCategory];
            [self.tableView reloadData];
            [self showAlert:@"导入成功" message:@"脚本已成功导入"];
        });
    } else {
        NSLog(@"[BaseAddressScript] 脚本导入失败");
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showAlert:@"导入失败" message:@"文件格式错误或内容无效"];
        });
    }
}

// 从内容导入脚本（带密码）
- (void)importScriptsFromContentWithPassword:(NSString *)content password:(NSString *)password {
    NSLog(@"[BaseAddressScript] 开始导入加密脚本内容");

    // 先尝试解析JSON来判断格式
    NSError *error;
    NSData *jsonData = [content dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];

    if (error || !jsonObject) {
        NSLog(@"[BaseAddressScript] JSON解析失败: %@", error.localizedDescription);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showAlert:@"导入失败" message:@"文件格式错误"];
        });
        return;
    }

    BOOL success = NO;

    // 检查是否为批量导出格式（包含scripts数组）
    if (jsonObject[@"scripts"]) {
        NSLog(@"[BaseAddressScript] 检测到批量脚本格式");
        success = [self.scriptManager importScriptsFromStringWithPassword:content password:password];
    } else if (jsonObject[@"scriptId"]) {
        // 单个脚本格式，需要包装成批量格式
        NSLog(@"[BaseAddressScript] 检测到单个脚本格式，转换为批量格式");

        // 通过密码导入的脚本强制标记为加密
        NSDictionary *wrapperData = @{
            @"scripts": @[content],
            @"categories": @[],
            @"exportDate": [[NSDateFormatter new] stringFromDate:[NSDate date]],
            @"version": @"1.0",
            @"encrypted": @YES  // 强制标记为加密
        };

        NSData *wrapperJsonData = [NSJSONSerialization dataWithJSONObject:wrapperData
                                                                  options:NSJSONWritingPrettyPrinted
                                                                    error:&error];
        if (!error && wrapperJsonData) {
            NSString *wrapperString = [[NSString alloc] initWithData:wrapperJsonData encoding:NSUTF8StringEncoding];
            success = [self.scriptManager importScriptsFromStringWithPassword:wrapperString password:password];
        }
    } else {
        NSLog(@"[BaseAddressScript] 未知的脚本格式");
    }

    if (success) {
        NSLog(@"[BaseAddressScript] 加密脚本导入成功，刷新界面");
        // 强制刷新界面
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadScriptsForCurrentCategory];
            [self.tableView reloadData];
            [self showAlert:@"导入成功" message:@"加密脚本已成功导入"];
        });
    } else {
        NSLog(@"[BaseAddressScript] 加密脚本导入失败");
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showAlert:@"导入失败" message:@"文件格式错误或密码错误"];
        });
    }
}

// 显示导出选项
- (void)showExportOptions {
    // 检查是否包含加密脚本
    BOOL hasEncryptedScript = NO;
    for (BaseAddressScript *script in self.scriptManager.scripts) {
        if (script.isEncrypted) {
            hasEncryptedScript = YES;
            break;
        }
    }

    if (hasEncryptedScript) {
        // 包含加密脚本，只能加密导出
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"包含加密脚本"
                                                                       message:@"检测到加密脚本，只能进行加密导出"
                                                                preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *encryptedExportAction = [UIAlertAction actionWithTitle:@"🔐 加密导出"
                                                                        style:UIAlertActionStyleDefault
                                                                      handler:^(UIAlertAction * _Nonnull action) {
            [self showBatchAuthorInfoDialog];
        }];
        [alert addAction:encryptedExportAction];

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                               style:UIAlertActionStyleCancel
                                                             handler:nil];
        [alert addAction:cancelAction];

        [self presentViewController:alert animated:YES completion:^{}];
        return;
    }

    // 普通脚本可以选择导出方式
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"导出脚本"
                                                                   message:@"选择导出方式"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    // 普通导出
    UIAlertAction *normalExportAction = [UIAlertAction actionWithTitle:@"📄 普通导出"
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction * _Nonnull action) {
        [self exportAllScripts:NO password:nil];
    }];
    [alert addAction:normalExportAction];

    // 加密导出
    UIAlertAction *encryptedExportAction = [UIAlertAction actionWithTitle:@"🔐 加密导出"
                                                                    style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction * _Nonnull action) {
        [self showBatchAuthorInfoDialog];
    }];
    [alert addAction:encryptedExportAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];

    // iPad 支持
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
    }

    [self presentViewController:alert animated:YES completion:^{}];
}

// 批量导出作者信息输入对话框
- (void)showBatchAuthorInfoDialog {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置作者信息"
                                                                   message:@"为批量加密导出设置作者信息"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    // 作者名称输入框
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"作者名称（必填）";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];

    // 作者简介输入框
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"作者简介（选填）";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];

    // 确定按钮
    UIAlertAction *nextAction = [UIAlertAction actionWithTitle:@"下一步"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
        NSString *authorName = alert.textFields[0].text;
        NSString *authorDescription = alert.textFields[1].text;

        if (!authorName || authorName.length == 0) {
            [self showAlert:@"错误" message:@"请输入作者名称"];
            return;
        }

        // 保存作者信息到临时变量
        self.tempAuthorName = authorName;
        self.tempAuthorDescription = authorDescription;

        // 继续到密码设置
        [self showPasswordDialog];
    }];
    [alert addAction:nextAction];

    // 取消按钮
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * _Nonnull action) {}];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:^{}];
}

// 显示密码设置对话框
- (void)showPasswordDialog {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置验证码"
                                                                   message:@"为加密脚本设置验证码"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"输入验证码 (4-16位)";
        textField.secureTextEntry = YES;
    }];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"确认验证码";
        textField.secureTextEntry = YES;
    }];

    UIAlertAction *exportAction = [UIAlertAction actionWithTitle:@"导出"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
        NSString *password = alert.textFields[0].text;
        NSString *confirmPassword = alert.textFields[1].text;

        if (password.length < 4 || password.length > 16) {
            [self showAlert:@"错误" message:@"验证码长度必须在4-16位之间"];
            return;
        }

        if (![password isEqualToString:confirmPassword]) {
            [self showAlert:@"错误" message:@"两次输入的验证码不一致"];
            return;
        }

        [self exportAllScripts:YES password:password];
    }];
    [alert addAction:exportAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * _Nonnull action) {}];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:^{}];
}

- (void)exportAllScripts:(BOOL)encrypted password:(NSString *)password {
    if (encrypted && self.tempAuthorName) {
        // 使用带作者信息的方法
        [self.scriptManager shareAllScripts:self
                                  encrypted:encrypted
                                   password:password ?: @""
                                 authorName:self.tempAuthorName ?: @""
                            authorDescription:self.tempAuthorDescription ?: @""
                                 completion:^(BOOL success) {
            // 清理临时作者信息
            self.tempAuthorName = nil;
            self.tempAuthorDescription = nil;

            [self handleExportResult:success encrypted:encrypted];
        }];
    } else {
        // 使用原有方法
        [self.scriptManager shareAllScripts:self
                                  encrypted:encrypted
                                   password:password ?: @""
                                 completion:^(BOOL success) {
            [self handleExportResult:success encrypted:encrypted];
        }];
    }
}

- (void)handleExportResult:(BOOL)success encrypted:(BOOL)encrypted {
    if (!success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"导出失败"
                                                                           message:@"无法导出脚本"
                                                                    preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * _Nonnull action) {}];
            [alert addAction:okAction];

            [self presentViewController:alert animated:YES completion:^{}];
        });
    } else if (encrypted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showAlert:@"导出成功" message:@"加密脚本已导出，请将验证码告知接收方"];
        });
    }
}

#pragma mark - Category Management



- (void)confirmClearAllScripts {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清空所有脚本"
                                                                   message:@"此操作将删除所有脚本，且无法恢复。确定要继续吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *clearAction = [UIAlertAction actionWithTitle:@"清空"
                                                          style:UIAlertActionStyleDestructive
                                                        handler:^(UIAlertAction * _Nonnull action) {
        [self.scriptManager clearAllScripts];
        // 立即刷新界面
        [self loadScriptsForCurrentCategory];
        [self.tableView reloadData];

        // 显示清空成功提示
        [self showAlert:@"清空完成" message:@"所有脚本已清空"];
    }];
    [alert addAction:clearAction];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * _Nonnull action) {}];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:^{}];
}

// 显示分类管理
- (void)showCategoryManagement {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"管理分类"
                                                                   message:@"选择操作"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    // 添加分类
    UIAlertAction *addCategoryAction = [UIAlertAction actionWithTitle:@"➕ 添加分类"
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * _Nonnull action) {
        [self showAddCategoryDialog];
    }];
    [alert addAction:addCategoryAction];

    // 重命名分类
    UIAlertAction *renameCategoryAction = [UIAlertAction actionWithTitle:@"✏️ 重命名分类"
                                                                   style:UIAlertActionStyleDefault
                                                                 handler:^(UIAlertAction * _Nonnull action) {
        [self showRenameCategoryDialog];
    }];
    [alert addAction:renameCategoryAction];

    // 删除分类
    UIAlertAction *deleteCategoryAction = [UIAlertAction actionWithTitle:@"🗑️ 删除分类"
                                                                   style:UIAlertActionStyleDestructive
                                                                 handler:^(UIAlertAction * _Nonnull action) {
        [self showDeleteCategoryDialog];
    }];
    [alert addAction:deleteCategoryAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];

    // iPad 支持
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
    }

    [self presentViewController:alert animated:YES completion:^{}];
}

// 显示添加分类对话框
- (void)showAddCategoryDialog {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"添加分类"
                                                                   message:@"输入新分类名称"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"分类名称";
    }];

    UIAlertAction *addAction = [UIAlertAction actionWithTitle:@"添加"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
        NSString *categoryName = alert.textFields[0].text;
        if (categoryName.length > 0) {
            [self.scriptManager addCategory:categoryName];
            [self updateCategorySegmentControl];
            [self showAlert:@"添加成功" message:[NSString stringWithFormat:@"分类 \"%@\" 已添加", categoryName]];
        } else {
            [self showAlert:@"错误" message:@"分类名称不能为空"];
        }
    }];
    [alert addAction:addAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * _Nonnull action) {}];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:^{}];
}

// 显示重命名分类对话框
- (void)showRenameCategoryDialog {
    NSArray *categories = self.scriptManager.categories;
    if (categories.count <= 1) {
        [self showAlert:@"提示" message:@"没有可重命名的分类"];
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重命名分类"
                                                                   message:@"选择要重命名的分类"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSString *category in categories) {
        if (![category isEqualToString:@"默认"]) { // 默认分类不能重命名
            UIAlertAction *categoryAction = [UIAlertAction actionWithTitle:category
                                                                     style:UIAlertActionStyleDefault
                                                                   handler:^(UIAlertAction * _Nonnull action) {
                [self showRenameCategoryInputDialog:category];
            }];
            [alert addAction:categoryAction];
        }
    }

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];

    // iPad 支持
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
    }

    [self presentViewController:alert animated:YES completion:^{}];
}

// 显示重命名输入对话框
- (void)showRenameCategoryInputDialog:(NSString *)oldName {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重命名分类"
                                                                   message:[NSString stringWithFormat:@"重命名分类 \"%@\"", oldName]
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"新分类名称";
        textField.text = oldName;
    }];

    UIAlertAction *renameAction = [UIAlertAction actionWithTitle:@"重命名"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
        NSString *newName = alert.textFields[0].text;
        if (newName.length > 0 && ![newName isEqualToString:oldName]) {
            [self.scriptManager renameCategory:oldName toName:newName];

            // 如果当前分类被重命名，更新当前分类
            if ([self.currentCategory isEqualToString:oldName]) {
                self.currentCategory = newName;
            }

            [self updateCategorySegmentControl];
            [self loadScriptsForCurrentCategory];
            [self showAlert:@"重命名成功" message:[NSString stringWithFormat:@"分类已重命名为 \"%@\"", newName]];
        } else {
            [self showAlert:@"错误" message:@"请输入有效的分类名称"];
        }
    }];
    [alert addAction:renameAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * _Nonnull action) {}];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:^{}];
}

// 显示删除分类对话框
- (void)showDeleteCategoryDialog {
    NSArray *categories = self.scriptManager.categories;
    if (categories.count <= 1) {
        [self showAlert:@"提示" message:@"没有可删除的分类"];
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"删除分类"
                                                                   message:@"选择要删除的分类（脚本将移动到默认分类）"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSString *category in categories) {
        if (![category isEqualToString:@"默认"]) { // 默认分类不能删除
            UIAlertAction *categoryAction = [UIAlertAction actionWithTitle:category
                                                                     style:UIAlertActionStyleDestructive
                                                                   handler:^(UIAlertAction * _Nonnull action) {
                [self confirmDeleteCategory:category];
            }];
            [alert addAction:categoryAction];
        }
    }

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];

    // iPad 支持
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
    }

    [self presentViewController:alert animated:YES completion:^{}];
}

// 确认删除分类
- (void)confirmDeleteCategory:(NSString *)categoryName {
    NSInteger scriptCount = [self.scriptManager scriptsCountInCategory:categoryName];
    NSString *message;
    if (scriptCount > 0) {
        message = [NSString stringWithFormat:@"删除分类 \"%@\" 将把其中的 %ld 个脚本移动到默认分类。确定要继续吗？", categoryName, (long)scriptCount];
    } else {
        message = [NSString stringWithFormat:@"确定要删除分类 \"%@\" 吗？", categoryName];
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认删除"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"删除"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self.scriptManager removeCategory:categoryName];

        // 如果删除的是当前分类，切换到默认分类
        if ([self.currentCategory isEqualToString:categoryName]) {
            self.currentCategory = @"默认";
        }

        [self updateCategorySegmentControl];
        [self loadScriptsForCurrentCategory];
        [self showAlert:@"删除成功" message:[NSString stringWithFormat:@"分类 \"%@\" 已删除", categoryName]];
    }];
    [alert addAction:deleteAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * _Nonnull action) {}];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:^{}];
}

#pragma mark - Notifications

- (void)registerNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(scriptDidAdd:)
                                                 name:BaseAddressScriptDidAddNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(scriptDidRemove:)
                                                 name:BaseAddressScriptDidRemoveNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(scriptDidUpdate:)
                                                 name:BaseAddressScriptDidUpdateNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(scriptDidExecute:)
                                                 name:BaseAddressScriptDidExecuteNotification
                                               object:nil];
}

- (void)scriptDidAdd:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self loadScriptsForCurrentCategory];
    });
}

- (void)scriptDidRemove:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self loadScriptsForCurrentCategory];
    });
}

- (void)scriptDidUpdate:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self loadScriptsForCurrentCategory];
    });
}

- (void)scriptDidExecute:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.currentScripts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ScriptCell" forIndexPath:indexPath];
    
    BaseAddressScript *script = self.currentScripts[indexPath.row];
    
    cell.textLabel.text = script.name;

    // 根据运行状态设置详细文本和图标
    switch (script.status) {
        case BaseAddressScriptStatusActive:
            cell.detailTextLabel.text = @"🟢 运行中 - 点击停止";
            cell.imageView.image = [UIImage systemImageNamed:@"play.circle.fill"];
            cell.imageView.tintColor = [UIColor systemGreenColor];
            break;
        case BaseAddressScriptStatusInactive:
            cell.detailTextLabel.text = @"⚪ 已停止 - 点击启动";
            cell.imageView.image = [UIImage systemImageNamed:@"pause.circle"];
            cell.imageView.tintColor = [UIColor systemGrayColor];
            break;
        case BaseAddressScriptStatusError:
            cell.detailTextLabel.text = @"🔴 执行失败 - 点击重试";
            cell.imageView.image = [UIImage systemImageNamed:@"exclamationmark.circle.fill"];
            cell.imageView.tintColor = [UIColor systemRedColor];
            break;
    }
    
    cell.accessoryType = UITableViewCellAccessoryDetailButton;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    BaseAddressScript *script = self.currentScripts[indexPath.row];
    [self toggleScriptExecution:script];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    BaseAddressScript *script = self.currentScripts[indexPath.row];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:script.name
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    // 编辑
    UIAlertAction *editAction = [UIAlertAction actionWithTitle:@"编辑"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
        [self editScript:script];
    }];
    [alert addAction:editAction];
    
    // 分享
    UIAlertAction *shareAction = [UIAlertAction actionWithTitle:@"分享"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * _Nonnull action) {
        [self shareScript:script];
    }];
    [alert addAction:shareAction];
    
    // 删除
    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"删除"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self deleteScript:script];
    }];
    [alert addAction:deleteAction];
    
    // 取消
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];
    
    // iPad 支持
    if (alert.popoverPresentationController) {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        alert.popoverPresentationController.sourceView = cell;
        alert.popoverPresentationController.sourceRect = cell.bounds;
    }
    
    [self presentViewController:alert animated:YES completion:^{}];
}

// 显示提示
- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {}];
    [alert addAction:okAction];

    [self presentViewController:alert animated:YES completion:^{}];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count > 0) {
        NSURL *fileURL = urls.firstObject;
        NSError *error;
        NSString *content = [NSString stringWithContentsOfURL:fileURL encoding:NSUTF8StringEncoding error:&error];

        if (content) {
            NSLog(@"[BaseAddressScript] 从文件读取内容，长度: %lu", (unsigned long)content.length);
            [self processImportedContent:content];
        } else {
            NSLog(@"[BaseAddressScript] 文件读取失败: %@", error.localizedDescription);
            [self showAlert:@"读取失败" message:[NSString stringWithFormat:@"无法读取文件: %@", error.localizedDescription]];
        }
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    NSLog(@"[BaseAddressScript] 用户取消了文件选择");
}

@end
