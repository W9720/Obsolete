#import "AssemblyCalculatorViewController.h"
#import "OnlineAssemblerService.h"
#import "OnlineDisassemblerService.h"

@interface AssemblyCalculatorViewController ()
@property (nonatomic, assign) BOOL isFormatted;
@property (nonatomic, strong) OnlineAssemblerService *assemblerService;
@property (nonatomic, strong) OnlineDisassemblerService *disassemblerService;
@end

@implementation AssemblyCalculatorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"汇编计算器";

    // 初始化服务
    self.assemblerService = [[OnlineAssemblerService alloc] init];
    self.disassemblerService = [[OnlineDisassemblerService alloc] init];

    [self setupUI];
    [self setupConstraints];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = NO;
}

#pragma mark - UI Setup

- (void)setupUI {
    // 模式选择
    self.modeSegment = [[UISegmentedControl alloc] initWithItems:@[@"汇编转机器码", @"机器码转汇编"]];
    self.modeSegment.selectedSegmentIndex = 0;
    self.modeSegment.translatesAutoresizingMaskIntoConstraints = NO;
    [self.modeSegment addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.modeSegment];
    
    // 输入框
    self.inputTextView = [[UITextView alloc] init];
    self.inputTextView.layer.borderColor = [UIColor systemGray4Color].CGColor;
    self.inputTextView.layer.borderWidth = 1.5;
    self.inputTextView.layer.cornerRadius = 12.0;
    self.inputTextView.font = [UIFont fontWithName:@"Menlo" size:14];
    self.inputTextView.text = @"请输入汇编指令...";
    self.inputTextView.textColor = [UIColor lightGrayColor];
    self.inputTextView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.inputTextView.textContainerInset = UIEdgeInsetsMake(12, 8, 12, 8);
    self.inputTextView.delegate = self;
    self.inputTextView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.inputTextView];
    
    // 输出框
    self.outputTextView = [[UITextView alloc] init];
    self.outputTextView.layer.borderColor = [UIColor systemGray4Color].CGColor;
    self.outputTextView.layer.borderWidth = 1.5;
    self.outputTextView.layer.cornerRadius = 12.0;
    self.outputTextView.font = [UIFont fontWithName:@"Menlo" size:14];
    self.outputTextView.editable = NO;
    self.outputTextView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.outputTextView.textContainerInset = UIEdgeInsetsMake(12, 8, 12, 8);
    self.outputTextView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.outputTextView];
    
    // 转换按钮
    self.convertButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.convertButton setTitle:@"转换" forState:UIControlStateNormal];
    self.convertButton.backgroundColor = [UIColor systemBlueColor];
    [self.convertButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.convertButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.convertButton.layer.cornerRadius = 10;
    self.convertButton.layer.shadowColor = [UIColor blackColor].CGColor;
    self.convertButton.layer.shadowOffset = CGSizeMake(0, 2);
    self.convertButton.layer.shadowOpacity = 0.1;
    self.convertButton.layer.shadowRadius = 4;
    self.convertButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.convertButton addTarget:self action:@selector(convertButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.convertButton addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self.convertButton addTarget:self action:@selector(buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [self.view addSubview:self.convertButton];
    
    // 清除按钮
    self.clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.clearButton setTitle:@"清除" forState:UIControlStateNormal];
    self.clearButton.backgroundColor = [UIColor systemGray2Color];
    [self.clearButton setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    self.clearButton.titleLabel.font = [UIFont systemFontOfSize:16];
    self.clearButton.layer.cornerRadius = 10;
    self.clearButton.layer.borderWidth = 1;
    self.clearButton.layer.borderColor = [UIColor systemGray4Color].CGColor;
    self.clearButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.clearButton addTarget:self action:@selector(clearButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.clearButton addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self.clearButton addTarget:self action:@selector(buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [self.view addSubview:self.clearButton];
    
    // 复制按钮
    self.copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.copyButton setTitle:@"复制结果" forState:UIControlStateNormal];
    self.copyButton.backgroundColor = [UIColor systemGreenColor];
    [self.copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.copyButton.titleLabel.font = [UIFont systemFontOfSize:16];
    self.copyButton.layer.cornerRadius = 10;
    self.copyButton.layer.shadowColor = [UIColor blackColor].CGColor;
    self.copyButton.layer.shadowOffset = CGSizeMake(0, 2);
    self.copyButton.layer.shadowOpacity = 0.1;
    self.copyButton.layer.shadowRadius = 4;
    self.copyButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.copyButton addTarget:self action:@selector(copyButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.copyButton addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self.copyButton addTarget:self action:@selector(buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [self.view addSubview:self.copyButton];
    
    // 格式化开关
    self.formatLabel = [[UILabel alloc] init];
    self.formatLabel.text = @"紧凑模式";
    self.formatLabel.font = [UIFont systemFontOfSize:16];
    self.formatLabel.textColor = [UIColor secondaryLabelColor];
    self.formatLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.formatLabel];
    
    self.formatSwitch = [[UISwitch alloc] init];
    self.formatSwitch.on = NO;  // 默认关闭
    self.formatSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [self.formatSwitch addTarget:self action:@selector(formatSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.formatSwitch];

    // 状态标签
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"准备就绪";
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.textColor = [UIColor secondaryLabelColor];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusLabel];

    // 加载指示器
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.loadingIndicator];

    self.isFormatted = NO;  // 默认不格式化

    // 添加点击手势隐藏键盘
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard)];
    tapGesture.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tapGesture];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // 模式选择
        [self.modeSegment.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [self.modeSegment.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.modeSegment.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        // 输入框
        [self.inputTextView.topAnchor constraintEqualToAnchor:self.modeSegment.bottomAnchor constant:20],
        [self.inputTextView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.inputTextView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.inputTextView.heightAnchor constraintEqualToConstant:100],

        // 第一行按钮 - 转换和清除
        [self.convertButton.topAnchor constraintEqualToAnchor:self.inputTextView.bottomAnchor constant:15],
        [self.convertButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.convertButton.widthAnchor constraintEqualToConstant:100],
        [self.convertButton.heightAnchor constraintEqualToConstant:44],

        [self.clearButton.topAnchor constraintEqualToAnchor:self.inputTextView.bottomAnchor constant:15],
        [self.clearButton.leadingAnchor constraintEqualToAnchor:self.convertButton.trailingAnchor constant:15],
        [self.clearButton.widthAnchor constraintEqualToConstant:100],
        [self.clearButton.heightAnchor constraintEqualToConstant:44],

        // 第二行 - 复制按钮和格式化开关
        [self.copyButton.topAnchor constraintEqualToAnchor:self.convertButton.bottomAnchor constant:10],
        [self.copyButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.copyButton.widthAnchor constraintEqualToConstant:100],
        [self.copyButton.heightAnchor constraintEqualToConstant:44],

        // 格式化开关
        [self.formatLabel.centerYAnchor constraintEqualToAnchor:self.copyButton.centerYAnchor],
        [self.formatLabel.trailingAnchor constraintEqualToAnchor:self.formatSwitch.leadingAnchor constant:-10],

        [self.formatSwitch.centerYAnchor constraintEqualToAnchor:self.copyButton.centerYAnchor],
        [self.formatSwitch.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        // 输出框
        [self.outputTextView.topAnchor constraintEqualToAnchor:self.copyButton.bottomAnchor constant:15],
        [self.outputTextView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.outputTextView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        // 状态标签
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.outputTextView.bottomAnchor constant:15],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        // 加载指示器
        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingIndicator.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:10],

        // 让输出框填充剩余空间，但设置最小高度
        [self.outputTextView.heightAnchor constraintGreaterThanOrEqualToConstant:120],
        [self.outputTextView.bottomAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-80]
    ]];
}

#pragma mark - Actions

- (void)modeChanged:(UISegmentedControl *)sender {
    if (sender.selectedSegmentIndex == 0) {
        [self setPlaceholderText:@"请输入汇编指令..."];
        self.title = @"汇编计算器 - 汇编转机器码";
    } else {
        [self setPlaceholderText:@"请输入机器码..."];
        self.title = @"汇编计算器 - 机器码转汇编";
    }
    [self clearButtonTapped];
}

- (void)convertButtonTapped {
    // 隐藏键盘
    [self.inputTextView resignFirstResponder];

    // 检查是否显示placeholder或内容为空
    if ([self isShowingPlaceholder] || self.inputTextView.text.length == 0) {
        self.statusLabel.text = @"请输入内容";
        return;
    }

    NSString *input = [self.inputTextView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    [self.loadingIndicator startAnimating];
    self.convertButton.enabled = NO;
    self.statusLabel.text = @"转换中...";
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *result;
        
        if (self.modeSegment.selectedSegmentIndex == 0) {
            // 汇编转机器码
            result = [self assemblyToMachineCode:input];
        } else {
            // 机器码转汇编
            result = [self machineCodeToAssembly:input];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.loadingIndicator stopAnimating];
            self.convertButton.enabled = YES;
            
            if (result) {
                self.outputTextView.text = result;
                self.statusLabel.text = @"转换完成";
            } else {
                self.outputTextView.text = @"转换失败，请检查输入格式";
                self.statusLabel.text = @"转换失败";
            }
        });
    });
}

- (void)clearButtonTapped {
    [self setPlaceholderText:self.modeSegment.selectedSegmentIndex == 0 ? @"请输入汇编指令..." : @"请输入机器码..."];
    self.outputTextView.text = @"";
    self.statusLabel.text = @"准备就绪";
}

- (void)copyButtonTapped {
    if (self.outputTextView.text.length > 0) {
        UIPasteboard.generalPasteboard.string = self.outputTextView.text;
        self.statusLabel.text = @"结果已复制到剪贴板";
    } else {
        self.statusLabel.text = @"没有可复制的内容";
    }
}

- (void)formatSwitchChanged:(UISwitch *)sender {
    self.isFormatted = sender.isOn;
    // 如果有输出内容且当前是汇编转机器码模式，重新格式化
    if (self.outputTextView.text.length > 0 && self.modeSegment.selectedSegmentIndex == 0) {
        // 只有在汇编转机器码模式下才需要重新转换以应用格式化
        [self convertButtonTapped];
    }
}

#pragma mark - Conversion Methods

- (NSString *)assemblyToMachineCode:(NSString *)assembly {
    __block NSString *result = nil;
    __block BOOL completed = NO;

    [self.assemblerService assembleCode:assembly completion:^(NSString * _Nullable machineCode, NSError * _Nullable error) {
        if (error) {
            result = [NSString stringWithFormat:@"转换失败: %@", error.localizedDescription];
        } else if (machineCode) {
            // 根据格式化开关处理机器码显示
            if (self.isFormatted) {
                // 紧凑模式：移除空格
                result = [machineCode stringByReplacingOccurrencesOfString:@" " withString:@""];
            } else {
                // 默认模式：保持空格
                result = machineCode;
            }
        } else {
            result = @"转换失败: 未知错误";
        }
        completed = YES;
    }];

    // 等待异步操作完成
    while (!completed) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }

    return result;
}

- (NSString *)machineCodeToAssembly:(NSString *)machineCode {
    __block NSString *result = nil;
    __block BOOL completed = NO;

    [self.disassemblerService disassembleBytes:machineCode completion:^(NSString * _Nullable assembly, NSError * _Nullable error) {
        if (error) {
            result = [NSString stringWithFormat:@"转换失败: %@", error.localizedDescription];
        } else if (assembly) {
            // 直接返回汇编代码结果
            result = assembly;
        } else {
            result = @"转换失败: 未知错误";
        }
        completed = YES;
    }];

    // 等待异步操作完成
    while (!completed) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }

    return result;
}

#pragma mark - UITextViewDelegate

- (void)textViewDidBeginEditing:(UITextView *)textView {
    if (textView == self.inputTextView && [self isShowingPlaceholder]) {
        textView.text = @"";
        textView.textColor = [UIColor labelColor];
    }
}

- (void)textViewDidEndEditing:(UITextView *)textView {
    if (textView == self.inputTextView && textView.text.length == 0) {
        [self setPlaceholderText:self.modeSegment.selectedSegmentIndex == 0 ? @"请输入汇编指令..." : @"请输入机器码..."];
    }
}

#pragma mark - Helper Methods

- (void)setPlaceholderText:(NSString *)placeholder {
    self.inputTextView.text = placeholder;
    self.inputTextView.textColor = [UIColor lightGrayColor];
}

- (BOOL)isShowingPlaceholder {
    NSString *currentPlaceholder = self.modeSegment.selectedSegmentIndex == 0 ? @"请输入汇编指令..." : @"请输入机器码...";
    return [self.inputTextView.text isEqualToString:currentPlaceholder] && [self.inputTextView.textColor isEqual:[UIColor lightGrayColor]];
}

- (void)buttonTouchDown:(UIButton *)button {
    [UIView animateWithDuration:0.1 animations:^{
        button.transform = CGAffineTransformMakeScale(0.95, 0.95);
        button.alpha = 0.8;
    }];
}

- (void)buttonTouchUp:(UIButton *)button {
    [UIView animateWithDuration:0.1 animations:^{
        button.transform = CGAffineTransformIdentity;
        button.alpha = 1.0;
    }];
}

- (void)hideKeyboard {
    [self.view endEditing:YES];
}

@end
