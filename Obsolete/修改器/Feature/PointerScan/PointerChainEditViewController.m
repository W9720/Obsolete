//
//  PointerChainEditViewController.m
//  指针链编辑界面实现
//

#import "PointerChainEditViewController.h"
#import "VMTypeHeader.h"

@interface PointerChainEditViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIBarButtonItem *saveButton;
@property (nonatomic, strong) UIBarButtonItem *addButton;
@property (nonatomic, strong) UIBarButtonItem *testButton;

@end

@implementation PointerChainEditViewController

- (instancetype)initWithPointerChain:(BaseAddressPointerChain *)chain {
    return [self initWithPointerChain:chain isEncrypted:NO];
}

- (instancetype)initWithPointerChain:(BaseAddressPointerChain *)chain isEncrypted:(BOOL)isEncrypted {
    self = [super init];
    if (self) {
        _pointerChain = chain;
        _isEncrypted = isEncrypted;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = self.pointerChain.name;
    
    [self setupNavigationBar];
    [self setupTableView];
}

- (void)setupNavigationBar {
    // 保存按钮
    self.saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                    target:self
                                                                    action:@selector(saveButtonTapped:)];
    
    // 添加节点按钮
    self.addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                   target:self
                                                                   action:@selector(addButtonTapped:)];
    
    // 测试按钮
    self.testButton = [[UIBarButtonItem alloc] initWithTitle:@"测试"
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(testButtonTapped:)];

    if (self.isEncrypted) {
        // 加密脚本只显示标题，不显示编辑按钮
        self.title = [NSString stringWithFormat:@"%@ 🔒", self.pointerChain.name];
        self.navigationItem.rightBarButtonItems = @[]; // 不显示任何按钮
    } else {
        // 普通脚本显示所有按钮
        self.navigationItem.rightBarButtonItems = @[self.saveButton, self.addButton, self.testButton];
    }
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:self.tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
}

#pragma mark - Actions

- (void)saveButtonTapped:(UIBarButtonItem *)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)addButtonTapped:(UIBarButtonItem *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"添加指针节点"
                                                                   message:@"选择节点类型"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    // 添加基址节点
    UIAlertAction *baseNodeAction = [UIAlertAction actionWithTitle:@"🏠 基址节点 (模块+偏移)"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
        [self showAddBaseNodeDialog];
    }];
    [alert addAction:baseNodeAction];

    // 添加偏移节点
    UIAlertAction *offsetNodeAction = [UIAlertAction actionWithTitle:@"➡️ 偏移节点 (指针偏移)"
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * _Nonnull action) {
        [self showAddOffsetNodeDialog];
    }];
    [alert addAction:offsetNodeAction];

    // 从指针链添加
    UIAlertAction *fromChainAction = [UIAlertAction actionWithTitle:@"🔗 从指针链添加"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * _Nonnull action) {
        [self showAddFromChainDialog];
    }];
    [alert addAction:fromChainAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];

    // iPad 支持
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.barButtonItem = sender;
    }

    [self presentViewController:alert animated:YES completion:nil];
}

// 添加基址节点
- (void)showAddBaseNodeDialog {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"添加基址节点"
                                                                   message:@"输入模块名和偏移量"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"模块名称 (如: wp2, UnityFramework)";
    }];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"偏移量 (如: DE0CF8, 0xDE0CF8)";
    }];

    UIAlertAction *addAction = [UIAlertAction actionWithTitle:@"添加"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
        NSString *moduleName = alert.textFields[0].text ?: @"";
        NSString *offsetStr = alert.textFields[1].text ?: @"0";

        if (moduleName.length == 0) {
            [self showAlert:@"错误" message:@"请输入模块名称"];
            return;
        }

        uintptr_t offset = [self parseHexString:offsetStr];

        BaseAddressPointerNode *node = [[BaseAddressPointerNode alloc] initWithModuleName:moduleName
                                                                               baseAddress:0
                                                                                    offset:offset];
        [self.pointerChain addNode:node];
        [self.tableView reloadData];
    }];
    [alert addAction:addAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:nil];
}

// 添加偏移节点
- (void)showAddOffsetNodeDialog {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"添加偏移节点"
                                                                   message:@"输入指针偏移量"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"偏移量 (如: FD8, 0xFD8, 18)";
    }];

    UIAlertAction *addAction = [UIAlertAction actionWithTitle:@"添加"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
        NSString *offsetStr = alert.textFields[0].text ?: @"0";
        uintptr_t offset = [self parseHexString:offsetStr];

        BaseAddressPointerNode *node = [[BaseAddressPointerNode alloc] initWithModuleName:@""
                                                                               baseAddress:0
                                                                                    offset:offset];
        [self.pointerChain addNode:node];
        [self.tableView reloadData];
    }];
    [alert addAction:addAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:nil];
}

// 从指针链批量添加
- (void)showAddFromChainDialog {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"从指针链添加"
                                                                   message:@"粘贴完整的指针链"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"指针链 (如: wp2+DE0CF8->FD8->FF4)";
        // 尝试从剪贴板获取内容
        NSString *clipboardText = UIPasteboard.generalPasteboard.string;
        if (clipboardText && [self isValidPointerChain:clipboardText]) {
            textField.text = clipboardText;
        }
    }];

    UIAlertAction *addAction = [UIAlertAction actionWithTitle:@"添加"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
        NSString *chainString = alert.textFields[0].text ?: @"";
        [self parseAndAddPointerChain:chainString];
    }];
    [alert addAction:addAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:nil];
}

// 解析并添加指针链
- (void)parseAndAddPointerChain:(NSString *)chainString {
    if (![self isValidPointerChain:chainString]) {
        [self showAlert:@"错误" message:@"无效的指针链格式"];
        return;
    }

    // 清空现有节点
    [self.pointerChain.nodes removeAllObjects];

    // 清理输入字符串，移除状态符号和多余空格
    NSString *cleanChain = [chainString stringByReplacingOccurrencesOfString:@"✅ " withString:@""];
    cleanChain = [cleanChain stringByReplacingOccurrencesOfString:@"❌ " withString:@""];
    cleanChain = [cleanChain stringByReplacingOccurrencesOfString:@" " withString:@""];

    // 解析格式：wp2+0xF0D2B0+0x228+0x348+0x38C
    NSArray<NSString *> *components = [cleanChain componentsSeparatedByString:@"+"];

    if (components.count < 2) {
        [self showAlert:@"错误" message:@"无效的指针链格式"];
        return;
    }

    // 第一个组件是模块名
    NSString *moduleName = components[0];

    // 第二个组件是基址偏移
    NSString *baseOffsetStr = components[1];
    uintptr_t baseOffset = [self parseHexString:baseOffsetStr];

    // 创建基址节点
    BaseAddressPointerNode *baseNode = [[BaseAddressPointerNode alloc] initWithModuleName:moduleName
                                                                               baseAddress:0
                                                                                    offset:baseOffset];
    [self.pointerChain addNode:baseNode];

    // 解析后续偏移（从第3个组件开始）
    for (NSInteger i = 2; i < components.count; i++) {
        NSString *offsetStr = components[i];
        uintptr_t offset = [self parseHexString:offsetStr];

        BaseAddressPointerNode *offsetNode = [[BaseAddressPointerNode alloc] initWithModuleName:@""
                                                                                     baseAddress:0
                                                                                          offset:offset];
        [self.pointerChain addNode:offsetNode];
    }

    [self.tableView reloadData];
    [self showAlert:@"成功" message:[NSString stringWithFormat:@"已添加 %ld 个节点", (long)self.pointerChain.nodes.count]];
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

- (void)testButtonTapped:(UIBarButtonItem *)sender {
    BOOL isValid = [self.pointerChain validateChain];
    
    NSString *title = isValid ? @"测试成功" : @"测试失败";
    NSString *message = isValid ? 
        [NSString stringWithFormat:@"指针链有效\n当前值: %@", self.pointerChain.currentValue] :
        @"指针链无效，请检查节点配置";
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    [alert addAction:okAction];
    
    [self presentViewController:alert animated:YES completion:nil];
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2; // 基本信息 + 节点列表
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: // 基本信息
            return 3; // 名称、值类型、期望值
        case 1: // 节点列表
            return self.pointerChain.nodes.count;
        default:
            return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return @"指针链信息";
        case 1:
            return [NSString stringWithFormat:@"指针节点 (%ld个)", (long)self.pointerChain.nodes.count];
        default:
            return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"PointerChainCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
    }
    
    if (indexPath.section == 0) {
        // 基本信息
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"名称";
                if (self.isEncrypted) {
                    cell.detailTextLabel.text = @"████████";
                } else {
                    cell.detailTextLabel.text = self.pointerChain.name;
                }
                cell.accessoryType = self.isEncrypted ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator;
                break;
            case 1:
                cell.textLabel.text = @"值类型";
                if (self.isEncrypted) {
                    cell.detailTextLabel.text = @"███";
                } else {
                    cell.detailTextLabel.text = [self valueTypeString:self.pointerChain.valueType];
                }
                cell.accessoryType = self.isEncrypted ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator;
                break;
            case 2:
                cell.textLabel.text = @"期望值";
                if (self.isEncrypted) {
                    cell.detailTextLabel.text = [self.pointerChain displayExpectedValue:YES];
                } else {
                    cell.detailTextLabel.text = self.pointerChain.expectedValue ?: @"未设置";
                }
                cell.accessoryType = self.isEncrypted ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator;
                break;
        }

        // 设置加密脚本的样式
        if (self.isEncrypted) {
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.textColor = [UIColor grayColor];
            cell.detailTextLabel.textColor = [UIColor grayColor];
        } else {
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            cell.textLabel.textColor = [UIColor labelColor];
            cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        }
    } else if (indexPath.section == 1) {
        // 节点列表
        BaseAddressPointerNode *node = self.pointerChain.nodes[indexPath.row];

        if (self.isEncrypted) {
            // 加密脚本显示乱码
            if (indexPath.row == 0) {
                cell.textLabel.text = @"基址: ████████";
                cell.detailTextLabel.text = @"████████+0x████████";
            } else {
                cell.textLabel.text = [NSString stringWithFormat:@"节点 %ld", (long)indexPath.row];
                cell.detailTextLabel.text = @"偏移: 0x████████";
            }
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.textColor = [UIColor grayColor];
            cell.detailTextLabel.textColor = [UIColor grayColor];
        } else {
            // 普通脚本正常显示
            if (indexPath.row == 0) {
                cell.textLabel.text = [NSString stringWithFormat:@"基址: %@", [node displayModuleName:NO]];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@+%@",
                                            [node displayModuleName:NO], [node displayOffset:NO]];
            } else {
                cell.textLabel.text = [NSString stringWithFormat:@"节点 %ld", (long)indexPath.row];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"偏移: %@", [node displayOffset:NO]];
            }
            cell.accessoryType = UITableViewCellAccessoryDetailButton;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            cell.textLabel.textColor = [UIColor labelColor];
            cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        }
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    // 加密脚本不允许编辑
    if (self.isEncrypted) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法编辑"
                                                                       message:@"此指针链已加密，无法编辑内容"
                                                                preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                           style:UIAlertActionStyleDefault
                                                         handler:nil];
        [alert addAction:okAction];

        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    if (indexPath.section == 0) {
        [self editBasicInfoAtIndex:indexPath.row];
    } else if (indexPath.section == 1) {
        [self editNodeAtIndex:indexPath.row];
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1 && !self.isEncrypted) {
        [self editNodeAtIndex:indexPath.row];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 1; // 只允许编辑节点
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete && indexPath.section == 1) {
        [self.pointerChain removeNodeAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

#pragma mark - Edit Methods

- (void)editBasicInfoAtIndex:(NSInteger)index {
    switch (index) {
        case 0:
            [self editName];
            break;
        case 1:
            [self editValueType];
            break;
        case 2:
            [self editExpectedValue];
            break;
    }
}

- (void)editName {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"编辑名称"
                                                                   message:@"请输入指针链名称"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"指针链名称";
        textField.text = self.pointerChain.name;
    }];
    
    UIAlertAction *saveAction = [UIAlertAction actionWithTitle:@"保存"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
        UITextField *textField = alert.textFields.firstObject;
        self.pointerChain.name = textField.text;
        self.title = textField.text;
        [self.tableView reloadData];
    }];
    [alert addAction:saveAction];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)editValueType {
    NSArray *types = @[@"I8", @"I16", @"I32", @"I64", @"F32", @"F64"];
    NSArray *typeValues = @[@(VMMemValueTypeSignedByte), @(VMMemValueTypeSignedShort), 
                           @(VMMemValueTypeSignedInt), @(VMMemValueTypeSignedLong),
                           @(VMMemValueTypeFloat), @(VMMemValueTypeDouble)];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择值类型"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (NSInteger i = 0; i < types.count; i++) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:types[i]
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
            self.pointerChain.valueType = [typeValues[i] integerValue];
            [self.tableView reloadData];
        }];
        [alert addAction:action];
    }
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];
    
    // iPad 支持
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, 
                                                                    self.view.bounds.size.height/2, 
                                                                    0, 0);
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)editExpectedValue {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"编辑期望值"
                                                                   message:@"请输入要写入的值"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"期望值";
        textField.text = self.pointerChain.expectedValue;
    }];
    
    UIAlertAction *saveAction = [UIAlertAction actionWithTitle:@"保存"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
        UITextField *textField = alert.textFields.firstObject;
        self.pointerChain.expectedValue = textField.text;
        [self.tableView reloadData];
    }];
    [alert addAction:saveAction];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)editNodeAtIndex:(NSInteger)index {
    if (index < 0 || index >= self.pointerChain.nodes.count) {
        return;
    }

    BaseAddressPointerNode *node = self.pointerChain.nodes[index];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"编辑节点"
                                                                   message:[NSString stringWithFormat:@"编辑节点 %ld", (long)(index + 1)]
                                                            preferredStyle:UIAlertControllerStyleAlert];

    if (index == 0) {
        // 基址节点
        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = @"模块名称";
            textField.text = node.moduleName;
        }];

        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = @"偏移量";
            textField.text = [NSString stringWithFormat:@"0x%lX", (unsigned long)node.offset];
        }];

        UIAlertAction *saveAction = [UIAlertAction actionWithTitle:@"保存"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
            NSString *moduleName = alert.textFields[0].text ?: @"";
            NSString *offsetStr = alert.textFields[1].text ?: @"0";

            if (moduleName.length == 0) {
                [self showAlert:@"错误" message:@"模块名称不能为空"];
                return;
            }

            uintptr_t offset = [self parseHexString:offsetStr];

            node.moduleName = moduleName;
            node.offset = offset;
            [self.tableView reloadData];
        }];
        [alert addAction:saveAction];
    } else {
        // 偏移节点
        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = @"偏移量";
            textField.text = [NSString stringWithFormat:@"0x%lX", (unsigned long)node.offset];
        }];

        UIAlertAction *saveAction = [UIAlertAction actionWithTitle:@"保存"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
            NSString *offsetStr = alert.textFields[0].text ?: @"0";
            uintptr_t offset = [self parseHexString:offsetStr];

            node.offset = offset;
            [self.tableView reloadData];
        }];
        [alert addAction:saveAction];
    }

    // 删除节点
    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"删除"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self.pointerChain removeNodeAtIndex:index];
        [self.tableView reloadData];
    }];
    [alert addAction:deleteAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:nil];
}

// 显示提示
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

#pragma mark - Helper Methods

- (NSString *)valueTypeString:(VMMemValueType)type {
    switch (type) {
        case VMMemValueTypeSignedByte: return @"I8";
        case VMMemValueTypeSignedShort: return @"I16";
        case VMMemValueTypeSignedInt: return @"I32";
        case VMMemValueTypeSignedLong: return @"I64";
        case VMMemValueTypeFloat: return @"F32";
        case VMMemValueTypeDouble: return @"F64";
        default: return @"未知";
    }
}

@end
