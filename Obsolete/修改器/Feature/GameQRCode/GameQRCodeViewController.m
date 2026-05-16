#import "GameQRCodeViewController.h"

@interface GameQRCodeViewController () <WKNavigationDelegate>

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UILabel *statusLabel;

@end

@implementation GameQRCodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"游戏扫码";
    
    // 设置导航栏
    [self setupNavigationBar];
    
    // 设置UI
    [self setupUI];
    
    // 加载网页
    [self loadGameQRCodePage];
}

- (void)setupNavigationBar {
    // 添加关闭按钮
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] 
                                   initWithTitle:@"关闭" 
                                   style:UIBarButtonItemStylePlain 
                                   target:self 
                                   action:@selector(closeButtonTapped)];
    self.navigationItem.leftBarButtonItem = closeButton;
    
    // 添加刷新按钮
    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] 
                                     initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh 
                                     target:self 
                                     action:@selector(refreshButtonTapped)];
    self.navigationItem.rightBarButtonItem = refreshButton;
}

- (void)setupUI {
    // 创建WebView配置
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.allowsInlineMediaPlayback = YES;
    
    // 创建WebView
    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    self.webView.navigationDelegate = self;
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.webView];
    
    // 创建加载指示器
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.loadingIndicator];
    
    // 创建状态标签
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"正在加载游戏扫码页面...";
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont systemFontOfSize:16];
    self.statusLabel.textColor = [UIColor secondaryLabelColor];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusLabel];
    
    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        // WebView约束
        [self.webView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.webView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        
        // 加载指示器约束
        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-30],
        
        // 状态标签约束
        [self.statusLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.loadingIndicator.bottomAnchor constant:20],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20]
    ]];
}

- (void)loadGameQRCodePage {
    [self.loadingIndicator startAnimating];
    self.statusLabel.hidden = NO;
    
    NSString *urlString = @"https://apt.25mao.com/wxgame/";
    NSURL *url = [NSURL URLWithString:urlString];
    
    if (url) {
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [self.webView loadRequest:request];
    } else {
        [self showErrorWithMessage:@"无效的URL地址"];
    }
}

- (void)showErrorWithMessage:(NSString *)message {
    [self.loadingIndicator stopAnimating];
    self.statusLabel.text = [NSString stringWithFormat:@"加载失败: %@", message];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"加载失败"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *retryAction = [UIAlertAction actionWithTitle:@"重试"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * _Nonnull action) {
                                                            [self loadGameQRCodePage];
                                                        }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    
    [alert addAction:retryAction];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Button Actions

- (void)closeButtonTapped {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)refreshButtonTapped {
    [self loadGameQRCodePage];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    [self.loadingIndicator startAnimating];
    self.statusLabel.text = @"正在加载...";
    self.statusLabel.hidden = NO;
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self.loadingIndicator stopAnimating];
    self.statusLabel.hidden = YES;
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self.loadingIndicator stopAnimating];
    [self showErrorWithMessage:error.localizedDescription];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self.loadingIndicator stopAnimating];
    [self showErrorWithMessage:error.localizedDescription];
}

@end
