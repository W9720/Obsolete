#import "FeatureViewController.h"
#import "MemoryBrowser/MemoryBrowserViewController.h"
#import "FeatureCompare/FeatureCompareViewController.h"
#import "AssemblyCalculator/AssemblyCalculatorViewController.h"
#import "StaticAddress/StaticAddressViewController.h"
#import "PointerScan/PointerScanViewController.h"
#import "BaseAddressScript/BaseAddressScriptViewController.h"
#import "ReverseAssembly/ReverseAssemblyViewController.h"
#import "AppSearch/AppSearchViewController.h"
#import "PluginMaker/PluginMakerViewController.h"
#import "GameQRCode/GameQRCodeViewController.h"
#import "HappySummer/HappySummerViewController.h"
#import "ClassDump/ClassDumpViewController.h"
#import "AppDecryption/AppDecryptionViewController.h"


#import "../Process/ProcessManager.h"

@interface FeatureViewController ()

// 私有属性
@property (nonatomic, strong) NSArray *sectionTitles;
@property (nonatomic, strong) NSArray *basicFeatures;
@property (nonatomic, strong) NSArray *advancedFeatures;
@property (nonatomic, strong) NSArray *exclusiveFeatures;

@end

@implementation FeatureViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // 设置标题
    [self setupTitleLabel];
    
    // 设置表格
    [self setupTableView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 确保导航栏隐藏
    self.navigationController.navigationBar.hidden = YES;
}

#pragma mark - UI Setup

- (void)setupTitleLabel {
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"功能";
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
    
    // 设置代理和数据源
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:self.tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:5],
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

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4; // 基础功能、娱乐功能、高级功能和专属功能四个部分
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: // 娱乐功能
            return 1; // 快乐一夏功能
        case 1: // 基础功能
            return 6; // 移除IPATool功能
        case 2: // 高级功能
            return 4;
        case 3: // 专属功能
            return 5; // 逆向汇编、插件制作、拦截助手、Dump、Hook
        default:
            return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return @"娱乐功能";
        case 1:
            return @"基础功能";
        case 2:
            return @"高级功能";
        case 3:
            return @"专属功能";
        default:
            return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"FeatureCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    // 配置单元格
    if (indexPath.section == 0) { // 娱乐功能
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"快乐一夏";
                cell.detailTextLabel.text = @"精彩视频内容，带给你快乐时光";
                cell.imageView.image = [UIImage systemImageNamed:@"sun.max.fill"];
                break;
        }
    } else if (indexPath.section == 1) { // 基础功能
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"内存浏览";
                cell.detailTextLabel.text = @"浏览和查看进程内存区域";
                cell.imageView.image = [UIImage systemImageNamed:@"memorychip"];
                break;
            case 1:
                cell.textLabel.text = @"特征对比";
                cell.detailTextLabel.text = @"比较内存特征值进行精确定位";
                cell.imageView.image = [UIImage systemImageNamed:@"square.and.line.vertical.and.square"];
                break;
            case 2:
                cell.textLabel.text = @"汇编计算";
                cell.detailTextLabel.text = @"分析和计算汇编指令的偏移量";
                cell.imageView.image = [UIImage systemImageNamed:@"function"];
                break;
            case 3:
                cell.textLabel.text = @"静态地址";
                cell.detailTextLabel.text = @"计算IDA/Hopper中的静态地址偏移";
                cell.imageView.image = [UIImage systemImageNamed:@"location"];
                break;
            case 4:
                cell.textLabel.text = @"应用搜索";
                cell.detailTextLabel.text = @"搜索App Store应用并提取offerName";
                cell.imageView.image = [UIImage systemImageNamed:@"magnifyingglass"];
                break;
            case 5:
                cell.textLabel.text = @"游戏扫码";
                cell.detailTextLabel.text = @"扫码登录游戏，快速进入游戏世界";
                cell.imageView.image = [UIImage systemImageNamed:@"qrcode"];
                break;


        }
    } else if (indexPath.section == 2) { // 高级功能
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"指针扫描";
                cell.detailTextLabel.text = @"扫描和分析内存指针链";
                cell.imageView.image = [UIImage systemImageNamed:@"arrow.triangle.branch"];
                break;
            case 1:
                cell.textLabel.text = @"指针脚本";
                cell.detailTextLabel.text = @"管理动态基址和偏移量";
                cell.imageView.image = [UIImage systemImageNamed:@"chart.bar"];
                break;
            case 2:
                cell.textLabel.text = @"内存脚本";
                cell.detailTextLabel.text = @"自动化内存操作和批量修改";
                cell.imageView.image = [UIImage systemImageNamed:@"terminal.fill"];
                break;
            case 3:
                cell.textLabel.text = @"应用解密";
                cell.detailTextLabel.text = @"解密App Store应用并生成IPA文件";
                cell.imageView.image = [UIImage systemImageNamed:@"lock.open"];
                break;
        }
    } else if (indexPath.section == 3) { // 专属功能
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"逆向汇编";
                cell.detailTextLabel.text = @"将二进制代码转换为汇编指令";
                cell.imageView.image = [UIImage systemImageNamed:@"cpu"];
                break;
            case 1:
                cell.textLabel.text = @"插件制作";
                cell.detailTextLabel.text = @"创建和管理Theos插件项目";
                cell.imageView.image = [UIImage systemImageNamed:@"hammer.fill"];
                break;
            case 2:
                cell.textLabel.text = @"拦截助手";
                cell.detailTextLabel.text = @"拦截和分析网络请求与API调用";
                cell.imageView.image = [UIImage systemImageNamed:@"network"];
                break;
            case 3:
                cell.textLabel.text = @"Dump";
                cell.detailTextLabel.text = @"导出内存数据和应用资源";
                cell.imageView.image = [UIImage systemImageNamed:@"square.and.arrow.down"];
                break;
            case 4:
                cell.textLabel.text = @"Hook";
                cell.detailTextLabel.text = @"动态修改和替换程序函数";
                cell.imageView.image = [UIImage systemImageNamed:@"link"];
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

#pragma mark - UITableViewDelegate

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
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 40.0;  // 设置section header高度为40点
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 10.0;  // 添加一个小的footer高度，增加section之间的间距
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *headerView = [[UIView alloc] init];
    headerView.backgroundColor = [UIColor clearColor];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    
    if (@available(iOS 13.0, *)) {
        titleLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        titleLabel.textColor = [UIColor darkGrayColor];
    }
    
    switch (section) {
        case 0:
            titleLabel.text = @"娱乐功能";
            break;
        case 1:
            titleLabel.text = @"基础功能";
            break;
        case 2:
            titleLabel.text = @"高级功能";
            break;
        case 3:
            titleLabel.text = @"专属功能";
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // 处理功能选择
    NSString *featureName = @"";
    BOOL shouldShowFeature = NO;

    if (indexPath.section == 0) { // 娱乐功能
        switch (indexPath.row) {
            case 0:
                featureName = @"快乐一夏";
                shouldShowFeature = YES; // 快乐一夏功能已实现
                break;
        }
    } else if (indexPath.section == 1) { // 基础功能
        switch (indexPath.row) {
            case 0:
                featureName = @"内存浏览";
                shouldShowFeature = YES; // 内存浏览功能已实现
                break;
            case 1:
                featureName = @"特征对比";
                shouldShowFeature = YES; // 特征对比功能已实现
                break;
            case 2:
                featureName = @"汇编计算";
                shouldShowFeature = YES; // 汇编计算功能已实现
                break;
            case 3:
                featureName = @"静态地址";
                shouldShowFeature = YES; // 静态地址功能已实现
                break;
            case 4:
                featureName = @"应用搜索";
                shouldShowFeature = YES; // 应用搜索功能已实现
                break;
            case 5:
                featureName = @"游戏扫码";
                shouldShowFeature = YES; // 游戏扫码功能已实现
                break;
            case 6:
                featureName = @"IPATool";
                shouldShowFeature = YES; // IPATool功能已实现
                break;

        }
    } else if (indexPath.section == 2) { // 高级功能
        switch (indexPath.row) {
            case 0:
                featureName = @"指针扫描";
                shouldShowFeature = YES; // 指针扫描功能已实现
                break;
            case 1:
                featureName = @"指针脚本";
                shouldShowFeature = YES; // 指针脚本功能已实现
                break;
            case 2:
                featureName = @"内存脚本";
                break;
            case 3:
                featureName = @"应用解密";
                shouldShowFeature = YES; // 应用解密功能已实现
                break;
        }
    } else if (indexPath.section == 3) { // 专属功能
        switch (indexPath.row) {
            case 0:
                featureName = @"逆向汇编";
                shouldShowFeature = YES; // 逆向汇编功能已实现
                break;
            case 1:
                featureName = @"插件制作";
                shouldShowFeature = YES; // 插件制作功能已实现
                break;
            case 2:
                featureName = @"拦截助手";
                break;
            case 3:
                featureName = @"Dump";
                shouldShowFeature = YES; // Dump功能已实现
                break;
            case 4:
                featureName = @"Hook";
                shouldShowFeature = YES; // Hook功能已实现
                break;
        }
    }
    
    // 处理特定功能
    if (shouldShowFeature) {
        if ([featureName isEqualToString:@"快乐一夏"]) {
            // 打开快乐一夏界面
            HappySummerViewController *happySummerVC = [[HappySummerViewController alloc] init];

            // 确保导航栏可见
            self.navigationController.navigationBar.hidden = NO;

            // 使用导航控制器推入新界面
            [self.navigationController pushViewController:happySummerVC animated:YES];
            return;
        } else if ([featureName isEqualToString:@"内存浏览"]) {
            // 打开内存浏览界面
            MemoryBrowserViewController *memoryVC = [[MemoryBrowserViewController alloc] initWithAddress:nil];

            // 确保导航栏可见
            self.navigationController.navigationBar.hidden = NO;

            // 使用导航控制器推入新界面
            [self.navigationController pushViewController:memoryVC animated:YES];
            return;
        } else if ([featureName isEqualToString:@"特征对比"]) {
            // 打开特征对比界面
            FeatureCompareViewController *compareVC = [[FeatureCompareViewController alloc]
                                                      initWithAddresses:@[]
                                                      valueType:VMMemValueTypeSignedInt];

            // 确保导航栏可见
            self.navigationController.navigationBar.hidden = NO;

            // 使用导航控制器推入新界面
            [self.navigationController pushViewController:compareVC animated:YES];
            return;
        } else if ([featureName isEqualToString:@"汇编计算"]) {
            // 打开汇编计算界面
            AssemblyCalculatorViewController *assemblyVC = [[AssemblyCalculatorViewController alloc] init];

            // 确保导航栏可见
            self.navigationController.navigationBar.hidden = NO;

            // 使用导航控制器推入新界面
            [self.navigationController pushViewController:assemblyVC animated:YES];
            return;
        } else if ([featureName isEqualToString:@"静态地址"]) {
            // 打开静态地址计算界面
            StaticAddressViewController *staticAddressVC = [[StaticAddressViewController alloc] init];

            // 确保导航栏可见
            self.navigationController.navigationBar.hidden = NO;

            // 使用导航控制器推入新界面
            [self.navigationController pushViewController:staticAddressVC animated:YES];
            return;
        } else if ([featureName isEqualToString:@"应用搜索"]) {
            // 打开应用搜索界面
            AppSearchViewController *appSearchVC = [[AppSearchViewController alloc] init];

            // 确保导航栏可见
            self.navigationController.navigationBar.hidden = NO;

            // 使用导航控制器推入新界面
            [self.navigationController pushViewController:appSearchVC animated:YES];
            return;
        } else if ([featureName isEqualToString:@"游戏扫码"]) {
            // 打开游戏扫码界面
            GameQRCodeViewController *gameQRCodeVC = [[GameQRCodeViewController alloc] init];

            // 确保导航栏可见
            self.navigationController.navigationBar.hidden = NO;

            // 使用导航控制器推入新界面
            [self.navigationController pushViewController:gameQRCodeVC animated:YES];
            return;

        } else if ([featureName isEqualToString:@"指针扫描"]) {
            // 打开指针扫描界面
            PointerScanViewController *pointerScanVC = [[PointerScanViewController alloc] initWithTargetAddress:@""];

            // 确保导航栏可见
            self.navigationController.navigationBar.hidden = NO;

            // 使用导航控制器推入新界面
            [self.navigationController pushViewController:pointerScanVC animated:YES];
            return;
        } else if ([featureName isEqualToString:@"指针脚本"]) {
            // 打开指针脚本界面
            BaseAddressScriptViewController *scriptVC = [[BaseAddressScriptViewController alloc] init];

            // 确保导航栏可见
            self.navigationController.navigationBar.hidden = NO;

            // 使用导航控制器推入新界面
            [self.navigationController pushViewController:scriptVC animated:YES];
            return;

        } else if ([featureName isEqualToString:@"应用解密"]) {
            // 打开应用解密界面
            AppDecryptionViewController *appDecryptionVC = [[AppDecryptionViewController alloc] init];

            // 确保导航栏可见
            self.navigationController.navigationBar.hidden = NO;

            // 使用导航控制器推入新界面
            [self.navigationController pushViewController:appDecryptionVC animated:YES];
            return;
        } else if ([featureName isEqualToString:@"逆向汇编"]) {
            // 打开逆向汇编界面
            ReverseAssemblyViewController *reverseAssemblyVC = [[ReverseAssemblyViewController alloc] init];

            // 确保导航栏可见
            self.navigationController.navigationBar.hidden = NO;

            // 使用导航控制器推入新界面
            [self.navigationController pushViewController:reverseAssemblyVC animated:YES];
            return;
        } else if ([featureName isEqualToString:@"插件制作"]) {
            // 打开插件制作界面
            PluginMakerViewController *pluginMakerVC = [[PluginMakerViewController alloc] init];

            // 确保导航栏可见
            self.navigationController.navigationBar.hidden = NO;

            // 使用导航控制器推入新界面
            [self.navigationController pushViewController:pluginMakerVC animated:YES];
            return;
        } else if ([featureName isEqualToString:@"Dump"]) {
            // 打开ClassDump界面
            ClassDumpViewController *classDumpVC = [[ClassDumpViewController alloc] init];

            // 确保导航栏可见
            self.navigationController.navigationBar.hidden = NO;

            // 使用导航控制器推入新界面
            [self.navigationController pushViewController:classDumpVC animated:YES];
            return;
        } else if ([featureName isEqualToString:@"Hook"]) {
            // 测试Frida功能
            [self testFridaFunctionality];
            return;
        }
    }
    
    // 显示功能尚未实现的提示
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"功能开发中"
                                                                   message:[NSString stringWithFormat:@"%@功能正在开发中，敬请期待！", featureName]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0; // 增加单元格高度从40到50
}



#pragma mark - Frida测试功能
- (void)testFridaFunctionality {
    // 显示功能尚未实现的提示
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Hook功能"
                                                                   message:@"Hook功能正在开发中，敬请期待！"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];

    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

@end 
