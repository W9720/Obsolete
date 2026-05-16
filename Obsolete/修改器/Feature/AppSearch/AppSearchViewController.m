//
//  AppSearchViewController.m
//  修改器
//
//  Created by MacXK on 2025/8/6.
//

#import "AppSearchViewController.h"

// 自定义的OfferNames视图控制器
@interface OfferNamesViewController : UIViewController
@property (nonatomic, strong) NSMutableArray *offerNames;
@end

@implementation OfferNamesViewController

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    return action == @selector(copy:) || action == @selector(runScript:);
}

- (void)copy:(id)sender {
    // 这个方法会被重写
}

- (void)runScript:(id)sender {
    // 这个方法会被重写
}

@end

// 自定义的OfferName表格cell
@interface OfferNameTableViewCell : UITableViewCell
@property (nonatomic, strong) NSString *offerName;
@property (nonatomic, weak) AppSearchViewController *parentViewController;
@end

@implementation OfferNameTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // 移除长按手势，改为点击处理
    }
    return self;
}



@end

@interface AppSearchViewController ()

@property (nonatomic, strong) NSArray *countries;
@property (nonatomic, strong) NSArray *countryCodes;
@property (nonatomic, strong) NSURLSessionDataTask *searchTask;
@property (nonatomic, strong) dispatch_source_t searchTimer;

@end

@implementation AppSearchViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // 设置基本属性
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"应用搜索";

    // 初始化数据
    [self initializeData];

    // 直接显示主界面，去掉欢迎动画
    [self setupMainUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 确保导航栏可见
    self.navigationController.navigationBar.hidden = NO;
}

#pragma mark - 初始化数据

- (void)initializeData {
    self.countries = @[@"中国", @"美国", @"台湾", @"日本"];
    self.countryCodes = @[@"cn", @"us", @"tw", @"jp"];
    self.searchResults = [[NSMutableArray alloc] init];
    self.searchCache = [[NSMutableDictionary alloc] init];
    self.offerNames = [[NSMutableArray alloc] init];
}



#pragma mark - 主界面设置

- (void)setupMainUI {
    [self setupActivityIndicator];
    [self setupSegmentedControl];
    [self setupSearchBar];
    [self setupTableView];
    [self setupConstraints];
}

- (void)setupActivityIndicator {
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.activityIndicator.hidesWhenStopped = YES;
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.activityIndicator];
}

- (void)setupSegmentedControl {
    self.segmentedControl = [[UISegmentedControl alloc] init];
    self.segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    
    for (NSInteger i = 0; i < self.countries.count; i++) {
        [self.segmentedControl insertSegmentWithTitle:self.countries[i] atIndex:i animated:NO];
    }
    
    self.segmentedControl.selectedSegmentIndex = 0;
    [self.segmentedControl addTarget:self action:@selector(segmentedControlChanged:) forControlEvents:UIControlEventValueChanged];
    
    [self.view addSubview:self.segmentedControl];
}

- (void)setupSearchBar {
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.placeholder = @"请搜索应用";
    self.searchBar.showsCancelButton = NO;
    self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    self.searchBar.delegate = self;
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:self.searchBar];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:self.tableView];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // 分段控制器
        [self.segmentedControl.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10],
        [self.segmentedControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.segmentedControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.segmentedControl.heightAnchor constraintEqualToConstant:32],
        
        // 搜索栏
        [self.searchBar.topAnchor constraintEqualToAnchor:self.segmentedControl.bottomAnchor constant:10],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        
        // 表格视图
        [self.tableView.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        
        // 活动指示器
        [self.activityIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.activityIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

#pragma mark - 分段控制器事件

- (void)segmentedControlChanged:(UISegmentedControl *)sender {
    if (self.searchBar.text.length > 0) {
        NSString *countryCode = self.countryCodes[sender.selectedSegmentIndex];
        NSString *cacheKey = [NSString stringWithFormat:@"%@_%@", self.searchBar.text, countryCode];
        
        if (self.searchCache[cacheKey]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.searchResults = [self.searchCache[cacheKey] mutableCopy];
                [self.tableView reloadData];
                [self.activityIndicator stopAnimating];
                self.tableView.userInteractionEnabled = YES;
            });
            return;
        }
        
        [self searchBarSearchButtonClicked:self.searchBar];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.activityIndicator stopAnimating];
            self.tableView.userInteractionEnabled = YES;
        });
    }
}

#pragma mark - UISearchBarDelegate

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    [searchBar setShowsCancelButton:NO animated:YES];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.searchResults removeAllObjects];
        [self.tableView reloadData];
        [self.activityIndicator stopAnimating];
    });
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    // 取消之前的搜索任务
    [self.searchTask cancel];

    // 取消之前的定时器
    if (self.searchTimer) {
        dispatch_source_cancel(self.searchTimer);
        self.searchTimer = nil;
    }

    if (searchText.length == 0) {
        [self.searchResults removeAllObjects];
        [self.tableView reloadData];
        return;
    }

    // 延迟搜索
    self.searchTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(self.searchTimer, dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 0);
    dispatch_source_set_event_handler(self.searchTimer, ^{
        [self searchBarSearchButtonClicked:searchBar];
        dispatch_source_cancel(self.searchTimer);
        self.searchTimer = nil;
    });
    dispatch_resume(self.searchTimer);
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];

    NSString *searchText = searchBar.text;
    if (searchText.length == 0) return;

    // 检查是否是App Store链接
    NSURL *url = [NSURL URLWithString:searchText];
    if (url && [url.host containsString:@"apps.apple.com"]) {
        NSString *pattern = @"/id(\\d+)";
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        NSTextCheckingResult *match = [regex firstMatchInString:url.path options:0 range:NSMakeRange(0, url.path.length)];

        if (match) {
            NSString *appId = [NSString stringWithFormat:@"id%@", [url.path substringWithRange:[match rangeAtIndex:1]]];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.searchBar.text = appId;
                [self performSearchWithTerm:appId];
            });
            return;
        }
    }

    [self performSearchWithTerm:searchText];
}

- (void)performSearchWithTerm:(NSString *)term {
    [self.activityIndicator startAnimating];
    self.tableView.userInteractionEnabled = NO;

    NSString *countryCode = self.countryCodes[self.segmentedControl.selectedSegmentIndex];
    NSString *cacheKey = [NSString stringWithFormat:@"%@_%@", term, countryCode];

    // 检查缓存
    if (self.searchCache[cacheKey]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.searchResults = [self.searchCache[cacheKey] mutableCopy];
            [self.tableView reloadData];
            [self.activityIndicator stopAnimating];
            self.tableView.userInteractionEnabled = YES;
        });
        return;
    }

    // URL编码
    NSString *encodedTerm = [term stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    if (!encodedTerm) return;

    NSString *urlString = [NSString stringWithFormat:@"https://itunes.apple.com/search?term=%@&entity=software&country=%@&limit=15", encodedTerm, countryCode];
    NSURL *requestURL = [NSURL URLWithString:urlString];
    if (!requestURL) return;

    NSURLRequest *request = [NSURLRequest requestWithURL:requestURL];

    self.searchTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.activityIndicator stopAnimating];
                self.tableView.userInteractionEnabled = YES;
            });
            return;
        }

        if (data) {
            NSError *jsonError;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];

            if (!jsonError && json[@"results"]) {
                NSArray *results = json[@"results"];
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.searchResults = [results mutableCopy];
                    self.searchCache[cacheKey] = results;
                    [self.tableView reloadData];
                    [self.activityIndicator stopAnimating];
                    self.tableView.userInteractionEnabled = YES;
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.activityIndicator stopAnimating];
                    self.tableView.userInteractionEnabled = YES;
                });
            }
        }
    }];

    [self.searchTask resume];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.tableView) {
        return self.searchResults.count;
    } else {
        return self.offerNames.count;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        static NSString *cellIdentifier = @"SearchResultCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];

            // 添加长按手势复制Bundle ID
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleAppCellLongPress:)];
            [cell addGestureRecognizer:longPress];
        }

        NSDictionary *app = self.searchResults[indexPath.row];
        cell.textLabel.text = app[@"trackName"];

        // 显示Bundle ID和版本信息
        NSString *bundleId = app[@"bundleId"] ?: @"未知";
        NSString *version = app[@"version"] ?: @"未知";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@ (v%@)", bundleId, app[@"primaryGenreName"] ?: @"", version];

        // 异步加载图标
        NSString *iconURL = app[@"artworkUrl60"];
        if (iconURL) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:iconURL]];
                if (imageData) {
                    UIImage *image = [UIImage imageWithData:imageData];
                    // 创建圆角图片
                    UIImage *roundedImage = [self createRoundedImage:image withRadius:8.0];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        UITableViewCell *updateCell = [tableView cellForRowAtIndexPath:indexPath];
                        if (updateCell) {
                            updateCell.imageView.image = roundedImage;
                            [updateCell setNeedsLayout];
                        }
                    });
                }
            });
        }

        return cell;
    } else {
        // offerNames表格 - 创建自定义cell
        static NSString *offerCellIdentifier = @"OfferCell";
        OfferNameTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:offerCellIdentifier];

        if (!cell) {
            cell = [[OfferNameTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:offerCellIdentifier];
            cell.parentViewController = self;
        }

        cell.textLabel.text = self.offerNames[indexPath.row];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.numberOfLines = 0;
        cell.offerName = self.offerNames[indexPath.row];

        return cell;
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (tableView == self.tableView) {
        NSDictionary *app = self.searchResults[indexPath.row];
        NSString *trackViewUrl = app[@"trackViewUrl"];

        if (trackViewUrl) {
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"id(\\d+)" options:0 error:nil];
            NSTextCheckingResult *match = [regex firstMatchInString:trackViewUrl options:0 range:NSMakeRange(0, trackViewUrl.length)];

            if (match) {
                NSString *appId = [trackViewUrl substringWithRange:[match rangeAtIndex:1]];
                NSString *countryCode = self.countryCodes[self.segmentedControl.selectedSegmentIndex];
                NSString *appName = app[@"trackName"] ?: @"";

                NSString *encodedAppName = [appName stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
                if (!encodedAppName) {
                    [self showErrorAlert:@"无法编码应用名称"];
                    return;
                }

                [self fetchOfferNamesForAppId:appId countryCode:countryCode appName:encodedAppName];
            }
        }
    } else if (tableView == self.offerNamesTableView) {
        // OfferName列表点击处理 - 显示复制和脚本选项
        NSString *offerName = self.offerNames[indexPath.row];
        [self showOfferNameActionSheet:offerName];
    }
}

- (void)fetchOfferNamesForAppId:(NSString *)appId countryCode:(NSString *)countryCode appName:(NSString *)appName {
    [self.activityIndicator startAnimating];

    NSString *urlString = [NSString stringWithFormat:@"https://apps.apple.com/%@/app/%@/id%@", countryCode, appName, appId];
    NSURL *url = [NSURL URLWithString:urlString];

    NSURLRequest *request = [NSURLRequest requestWithURL:url];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.activityIndicator stopAnimating];
        });

        if (error || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showErrorAlert:@"网络请求失败"];
            });
            return;
        }

        NSString *htmlString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!htmlString) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showErrorAlert:@"无法解析HTML内容"];
            });
            return;
        }

        // 提取offerName
        NSString *pattern = @"\\\\\"offerName\\\\\"\\s*:\\s*\\\\\"([^\\\\\"]+)\\\\\"";
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        NSArray *matches = [regex matchesInString:htmlString options:0 range:NSMakeRange(0, htmlString.length)];

        NSMutableArray *offerNames = [[NSMutableArray alloc] init];
        for (NSTextCheckingResult *match in matches) {
            NSString *offerName = [htmlString substringWithRange:[match rangeAtIndex:1]];
            [offerNames addObject:offerName];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (offerNames.count == 0) {
                [self showErrorAlert:[NSString stringWithFormat:@"未找到offerName\nHTML片段: %@", [htmlString substringToIndex:MIN(300, htmlString.length)]]];
            } else {
                [self showOfferNamesPopup:offerNames];
            }
        });
    }] resume];
}

#pragma mark - 弹窗和辅助方法

- (void)showOfferNamesPopup:(NSArray *)offerNames {
    self.offerNames = [offerNames mutableCopy];

    // 创建一个简单的视图控制器来显示offerNames
    UIViewController *popupVC = [[UIViewController alloc] init];
    popupVC.view.backgroundColor = [UIColor systemBackgroundColor];
    popupVC.title = @"OfferName列表";

    // 创建表格视图
    self.offerNamesTableView = [[UITableView alloc] initWithFrame:popupVC.view.bounds style:UITableViewStylePlain];
    self.offerNamesTableView.delegate = self;
    self.offerNamesTableView.dataSource = self;
    self.offerNamesTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    [popupVC.view addSubview:self.offerNamesTableView];

    // 创建导航控制器
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:popupVC];

    // 添加关闭按钮
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithTitle:@"关闭"
                                                                    style:UIBarButtonItemStyleDone
                                                                   target:self
                                                                   action:@selector(closeOfferNamesPopup)];
    popupVC.navigationItem.rightBarButtonItem = closeButton;

    // 以模态方式呈现
    navController.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)closeOfferNamesPopup {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showOfferNameActionSheet:(NSString *)offerName {
    // 获取当前显示的视图控制器（OfferName弹窗）
    UIViewController *presentedVC = self.presentedViewController;
    if (!presentedVC) {
        NSLog(@"没有找到当前显示的视图控制器");
        return;
    }

    // 如果是导航控制器，获取顶部视图控制器
    UIViewController *targetVC = presentedVC;
    if ([presentedVC isKindOfClass:[UINavigationController class]]) {
        targetVC = [(UINavigationController *)presentedVC topViewController];
    }

    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:offerName
                                                                         message:@"选择操作"
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"复制"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
                                                           UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                                                           pasteboard.string = offerName;

                                                           UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制"
                                                                                                                          message:offerName
                                                                                                                   preferredStyle:UIAlertControllerStyleAlert];
                                                           UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
                                                           [alert addAction:okAction];
                                                           [targetVC presentViewController:alert animated:YES completion:nil];
                                                       }];

    UIAlertAction *scriptAction = [UIAlertAction actionWithTitle:@"脚本"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
                                                             [self generateScriptForOfferName:offerName fromViewController:targetVC];
                                                         }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [actionSheet addAction:copyAction];
    [actionSheet addAction:scriptAction];
    [actionSheet addAction:cancelAction];

    // iPad适配
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        actionSheet.popoverPresentationController.sourceView = targetVC.view;
        actionSheet.popoverPresentationController.sourceRect = CGRectMake(targetVC.view.bounds.size.width/2, targetVC.view.bounds.size.height/2, 1, 1);
    }

    [targetVC presentViewController:actionSheet animated:YES completion:nil];
}

- (void)generateScriptForOfferName:(NSString *)offerName fromViewController:(UIViewController *)viewController {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"生成脚本"
                                                                   message:@"请输入脚本信息"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    // 添加输入框
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"应用名称";
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"脚本功能";
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"软件版本";
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"脚本作者";
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"反馈地址";
    }];

    // 生成脚本按钮
    UIAlertAction *generateAction = [UIAlertAction actionWithTitle:@"生成脚本"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
                                                               NSString *appName = alert.textFields[0].text ?: @"";
                                                               NSString *scriptFunc = alert.textFields[1].text ?: @"";
                                                               NSString *version = alert.textFields[2].text ?: @"";
                                                               NSString *author = alert.textFields[3].text ?: @"";
                                                               NSString *feedback = alert.textFields[4].text ?: @"";

                                                               [self createScriptFileWithOfferName:offerName
                                                                                            appName:appName
                                                                                         scriptFunc:scriptFunc
                                                                                            version:version
                                                                                             author:author
                                                                                           feedback:feedback
                                                                                     fromViewController:viewController];
                                                           }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [alert addAction:generateAction];
    [alert addAction:cancelAction];

    [viewController presentViewController:alert animated:YES completion:nil];
}

- (void)createScriptFileWithOfferName:(NSString *)offerName
                              appName:(NSString *)appName
                           scriptFunc:(NSString *)scriptFunc
                              version:(NSString *)version
                               author:(NSString *)author
                             feedback:(NSString *)feedback
                       fromViewController:(UIViewController *)viewController {

    // 完整的脚本内容
    NSString *jsContent = [NSString stringWithFormat:@"/******************************\n\n应用名称：%@\n脚本功能：%@\n软件版本：%@\n脚本作者：%@\n软件作者：MacXK♨️\n反馈地址：%@\n使用声明：⚠️此脚本仅供学习与交流，请勿转载与贩卖!\n\n*******************************/\n\n[rewrite_local]\n\n^http[s]?:\\/\\/buy.itunes.apple.com/verifyReceipt url script-response-body https://raw.githubusercontent.com/89996462/Quantumult-X/main/ycdz/westkingnet.js\n\n[mitm] \n\nhostname = buy.itunes.apple.com\n\n*******************************/\n\nvar objc = JSON.parse($response.body);\nobjc.receipt.in_app = [{\n\"quantity\" : \"1\",\n\"purchase_date_ms\" : \"1234567890123\",\n\"expires_date\" : \"2099-12-31 23:59:59 Etc/GMT\",\n\"expires_date_pst\" : \"2099-12-31 23:59:59 America/Los_Angeles\",\n\"expires_date_ms\" : \"4102415999000\",\n\"web_order_line_item_id\" : \"1000000012345678\",\n\"is_trial_period\" : \"false\",\n\"item_id\" : \"1234567890\",\n\"unique_identifier\" : \"0000b012-45f6-7890-ab12-c34567890def\",\n\"original_transaction_id\" : \"1000000012345678\",\n\"expires_date_formatted\" : \"2099-12-31 23:59:59 Etc/GMT\",\n\"product_id\" : \"%@\",\n\"transaction_id\" : \"1000000012345678\",\n\"bvrs\" : \"1.0.0\",\n\"web_order_line_item_id\" : \"1000000012345678\",\n\"version_external_identifier\" : \"123456789\",\n\"bid\" : \"com.example.app\",\n\"unique_vendor_identifier\" : \"12345678-1234-1234-1234-123456789012\",\n\"original_purchase_date_pst\" : \"2023-01-01 00:00:00 America/Los_Angeles\",\n\"purchase_date_pst\" : \"2023-01-01 00:00:00 America/Los_Angeles\",\n\"original_purchase_date\" : \"2023-01-01 00:00:00 Etc/GMT\",\n\"purchase_date\" : \"2023-01-01 00:00:00 Etc/GMT\",\n\"original_purchase_date_ms\" : \"1672531200000\",\n\"is_in_intro_offer_period\" : \"false\"\n}];\n$done({body : JSON.stringify(objc)});", appName, scriptFunc, version, author, feedback, offerName];

    // 创建临时文件
    NSString *tempDir = NSTemporaryDirectory();
    NSString *fileName = [NSString stringWithFormat:@"%@.js", offerName];
    NSString *filePath = [tempDir stringByAppendingPathComponent:fileName];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];

    NSError *error;
    BOOL success = [jsContent writeToURL:fileURL
                              atomically:YES
                                encoding:NSUTF8StringEncoding
                                   error:&error];

    if (success) {
        NSLog(@"文件保存成功：%@", fileURL);

        // 使用分享功能导出文件
        UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL]
                                                                                 applicationActivities:nil];

        // iPad适配
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            activityVC.popoverPresentationController.sourceView = viewController.view;
            activityVC.popoverPresentationController.sourceRect = CGRectMake(viewController.view.bounds.size.width/2, viewController.view.bounds.size.height/2, 1, 1);
            activityVC.popoverPresentationController.permittedArrowDirections = 0;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [viewController presentViewController:activityVC animated:YES completion:^{
                NSLog(@"分享控制器已显示");
            }];
        });
    } else {
        NSLog(@"文件保存失败：%@", error.localizedDescription);

        UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"错误"
                                                                            message:[NSString stringWithFormat:@"文件保存失败：%@", error.localizedDescription]
                                                                     preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
        [errorAlert addAction:okAction];
        [viewController presentViewController:errorAlert animated:YES completion:nil];
    }
}

- (void)showErrorAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    [alert addAction:okAction];

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - 长按手势处理

- (void)handleAppCellLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;

    CGPoint point = [gesture locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:point];

    if (!indexPath || indexPath.row >= self.searchResults.count) return;

    NSDictionary *app = self.searchResults[indexPath.row];
    NSString *bundleId = app[@"bundleId"] ?: @"未知";
    NSString *appName = app[@"trackName"] ?: @"未知应用";

    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:appName
                                                                         message:@"选择操作"
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *copyBundleIdAction = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"复制Bundle ID (%@)", bundleId]
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction * _Nonnull action) {
                                                                   UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                                                                   pasteboard.string = bundleId;

                                                                   UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制Bundle ID"
                                                                                                                                  message:bundleId
                                                                                                                           preferredStyle:UIAlertControllerStyleAlert];
                                                                   UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
                                                                   [alert addAction:okAction];
                                                                   [self presentViewController:alert animated:YES completion:nil];
                                                               }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [actionSheet addAction:copyBundleIdAction];
    [actionSheet addAction:cancelAction];

    // iPad适配
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        actionSheet.popoverPresentationController.sourceView = cell;
        actionSheet.popoverPresentationController.sourceRect = cell.bounds;
    }

    [self presentViewController:actionSheet animated:YES completion:nil];
}





#pragma mark - 图片处理

- (UIImage *)createRoundedImage:(UIImage *)image withRadius:(CGFloat)radius {
    if (!image) return nil;

    // 创建更小的固定大小图片 (40x40) 并添加透明边距
    CGSize targetSize = CGSizeMake(50, 50); // 总尺寸包含边距
    CGSize imageSize = CGSizeMake(40, 40);  // 实际图片尺寸
    CGFloat margin = (targetSize.width - imageSize.width) / 2; // 边距

    CGRect imageRect = CGRectMake(margin, margin, imageSize.width, imageSize.height);

    UIGraphicsBeginImageContextWithOptions(targetSize, NO, [UIScreen mainScreen].scale);

    // 设置透明背景
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextClearRect(context, CGRectMake(0, 0, targetSize.width, targetSize.height));

    // 创建圆角路径并裁剪
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:imageRect cornerRadius:radius];
    [path addClip];

    // 绘制图片
    [image drawInRect:imageRect];
    UIImage *roundedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return roundedImage;
}

#pragma mark - 内存管理

- (void)dealloc {
    // 取消网络请求
    [self.searchTask cancel];

    // 取消定时器
    if (self.searchTimer) {
        dispatch_source_cancel(self.searchTimer);
        self.searchTimer = nil;
    }
}

@end
