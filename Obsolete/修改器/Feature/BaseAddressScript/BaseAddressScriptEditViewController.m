//
//  BaseAddressScriptEditViewController.m
//  基址脚本编辑界面实现
//

#import "BaseAddressScriptEditViewController.h"
#import "BaseAddressScriptManager.h"
#import "PointerChainEditViewController.h"
#import "VMTypeHeader.h"

@interface BaseAddressScriptEditViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIBarButtonItem *saveButton;
@property (nonatomic, strong) UIBarButtonItem *addButton;

@end

@implementation BaseAddressScriptEditViewController

- (instancetype)initWithScript:(BaseAddressScript *)script {
    self = [super init];
    if (self) {
        _script = script;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = self.script.name;
    
    [self setupNavigationBar];
    [self setupTableView];
}

- (void)setupNavigationBar {
    // 保存按钮
    self.saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                    target:self
                                                                    action:@selector(saveButtonTapped:)];
    
    // 添加指针链按钮
    self.addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                   target:self
                                                                   action:@selector(addButtonTapped:)];
    
    self.navigationItem.rightBarButtonItems = @[self.saveButton, self.addButton];
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
    [[BaseAddressScriptManager sharedManager] updateScript:self.script];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"保存成功"
                                                                   message:@"脚本已保存"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    [alert addAction:okAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)addButtonTapped:(UIBarButtonItem *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"添加指针链"
                                                                   message:@"请输入指针链名称"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"指针链名称";
    }];
    
    UIAlertAction *addAction = [UIAlertAction actionWithTitle:@"添加"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
        UITextField *textField = alert.textFields.firstObject;
        NSString *chainName = textField.text;
        
        if (chainName.length > 0) {
            BaseAddressPointerChain *chain = [[BaseAddressPointerChain alloc] initWithName:chainName 
                                                                                  valueType:VMMemValueTypeSignedInt];
            [self.script addPointerChain:chain];
            [self.tableView reloadData];
        }
    }];
    [alert addAction:addAction];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

// 开关状态改变
- (void)enableSwitchChanged:(UISwitch *)sender {
    if (sender.isOn) {
        self.script.status = BaseAddressScriptStatusActive;
        NSLog(@"[BaseAddressScript] 脚本已启用: %@", self.script.name);
    } else {
        self.script.status = BaseAddressScriptStatusInactive;
        NSLog(@"[BaseAddressScript] 脚本已禁用: %@", self.script.name);
    }

    // 更新显示
    [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:4 inSection:0]]
                          withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2; // 基本信息 + 指针链
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: // 基本信息
            return 5; // 名称、描述、分类、目标进程、启用状态
        case 1: // 指针链
            return self.script.pointerChains.count;
        default:
            return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return @"基本信息";
        case 1:
            return @"指针链";
        default:
            return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"EditCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
    }
    
    if (indexPath.section == 0) {
        // 基本信息
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"名称";
                cell.detailTextLabel.text = self.script.name;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
            case 1:
                cell.textLabel.text = @"描述";
                cell.detailTextLabel.text = self.script.scriptDescription ?: @"无描述";
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
            case 2:
                cell.textLabel.text = @"分类";
                cell.detailTextLabel.text = self.script.category;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
            case 3:
                cell.textLabel.text = @"目标进程";
                cell.detailTextLabel.text = self.script.targetProcess ?: @"未设置";
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
            case 4:
                cell.textLabel.text = @"启用状态";
                cell.detailTextLabel.text = (self.script.status == BaseAddressScriptStatusActive) ? @"已启用" : @"已禁用";
                cell.accessoryType = UITableViewCellAccessoryNone;

                // 添加开关控件
                UISwitch *enableSwitch = [[UISwitch alloc] init];
                enableSwitch.on = (self.script.status == BaseAddressScriptStatusActive);
                [enableSwitch addTarget:self action:@selector(enableSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = enableSwitch;
                break;
        }
    } else if (indexPath.section == 1) {
        // 指针链
        BaseAddressPointerChain *chain = self.script.pointerChains[indexPath.row];

        if (self.script.isEncrypted) {
            // 加密脚本显示乱码
            cell.textLabel.text = @"████████";
            cell.detailTextLabel.text = @"🔒 已加密";
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.textColor = [UIColor grayColor];
            cell.detailTextLabel.textColor = [UIColor grayColor];
        } else {
            // 普通脚本正常显示
            cell.textLabel.text = chain.name;
            NSString *status = chain.isValid ? @"✅" : @"❌";
            NSString *nodeCount = [NSString stringWithFormat:@"%ld节点", (long)chain.nodes.count];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", status, nodeCount];
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
    if (self.script.isEncrypted) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法编辑"
                                                                       message:@"此脚本已加密，无法编辑内容"
                                                                preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                           style:UIAlertActionStyleDefault
                                                         handler:nil];
        [alert addAction:okAction];

        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    if (indexPath.section == 0 && indexPath.row != 4) { // 启用状态行不可点击
        [self editBasicInfoAtIndex:indexPath.row];
    } else if (indexPath.section == 1) {
        [self editPointerChainAtIndex:indexPath.row];
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) {
        // 加密脚本不允许编辑
        if (self.script.isEncrypted) {
            return;
        }

        BaseAddressPointerChain *chain = self.script.pointerChains[indexPath.row];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:chain.name
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        
        // 编辑
        UIAlertAction *editAction = [UIAlertAction actionWithTitle:@"编辑"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
            [self editPointerChainAtIndex:indexPath.row];
        }];
        [alert addAction:editAction];
        
        // 验证
        UIAlertAction *validateAction = [UIAlertAction actionWithTitle:@"验证"
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction * _Nonnull action) {
            [self validatePointerChainAtIndex:indexPath.row];
        }];
        [alert addAction:validateAction];
        
        // 删除
        UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"删除"
                                                               style:UIAlertActionStyleDestructive
                                                             handler:^(UIAlertAction * _Nonnull action) {
            [self deletePointerChainAtIndex:indexPath.row];
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
        
        [self presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark - Edit Methods

- (void)editBasicInfoAtIndex:(NSInteger)index {
    NSString *title = @"";
    NSString *message = @"";
    NSString *placeholder = @"";
    NSString *currentValue = @"";
    
    switch (index) {
        case 0:
            title = @"编辑名称";
            message = @"请输入脚本名称";
            placeholder = @"脚本名称";
            currentValue = self.script.name;
            break;
        case 1:
            title = @"编辑描述";
            message = @"请输入脚本描述";
            placeholder = @"脚本描述";
            currentValue = self.script.scriptDescription ?: @"";
            break;
        case 2:
            [self showCategorySelection];
            return;
        case 3:
            title = @"编辑目标进程";
            message = @"请输入目标进程名称";
            placeholder = @"进程名称";
            currentValue = self.script.targetProcess ?: @"";
            break;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = placeholder;
        textField.text = currentValue;
    }];
    
    UIAlertAction *saveAction = [UIAlertAction actionWithTitle:@"保存"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
        UITextField *textField = alert.textFields.firstObject;
        NSString *newValue = textField.text;
        
        switch (index) {
            case 0:
                self.script.name = newValue;
                self.title = newValue;
                break;
            case 1:
                self.script.scriptDescription = newValue;
                break;
            case 3:
                self.script.targetProcess = newValue;
                break;
        }
        
        [self.tableView reloadData];
    }];
    [alert addAction:saveAction];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showCategorySelection {
    NSArray *categories = [[BaseAddressScriptManager sharedManager] categories];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择分类"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (NSString *category in categories) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:category
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
            self.script.category = category;
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

- (void)editPointerChainAtIndex:(NSInteger)index {
    BaseAddressPointerChain *chain = self.script.pointerChains[index];
    PointerChainEditViewController *editVC = [[PointerChainEditViewController alloc] initWithPointerChain:chain isEncrypted:self.script.isEncrypted];

    // 确保导航栏可见
    self.navigationController.navigationBar.hidden = NO;

    // 使用导航控制器推入编辑界面
    [self.navigationController pushViewController:editVC animated:YES];
}

- (void)validatePointerChainAtIndex:(NSInteger)index {
    BaseAddressPointerChain *chain = self.script.pointerChains[index];
    BOOL isValid = [chain validateChain];
    
    NSString *message = isValid ? 
        [NSString stringWithFormat:@"指针链验证成功\n当前值: %@", chain.currentValue] :
        @"指针链验证失败";
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"验证结果"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    [alert addAction:okAction];
    
    [self presentViewController:alert animated:YES completion:nil];
    [self.tableView reloadData];
}

- (void)deletePointerChainAtIndex:(NSInteger)index {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"删除指针链"
                                                                   message:@"确定要删除这个指针链吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"删除"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self.script removePointerChainAtIndex:index];
        [self.tableView reloadData];
    }];
    [alert addAction:deleteAction];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end
