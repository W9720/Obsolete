//
//  TheosProjectCreatorViewController.m
//  修改器
//
//  Created by AI Assistant on 2025-01-08.
//

#import "TheosProjectCreatorViewController.h"
#import "TheosProjectManager.h"

@interface TheosProjectCreatorViewController ()

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UITextField *projectNameField;
@property (nonatomic, strong) UITextField *packageNameField;
@property (nonatomic, strong) UITextField *authorField;
@property (nonatomic, strong) UITextField *descriptionField;
@property (nonatomic, strong) UITextField *targetBundleField;
@property (nonatomic, strong) UIButton *createButton;

@end

@implementation TheosProjectCreatorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self setupUI];
    
    // 监听键盘通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupUI {
    // 创建滚动视图
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsVerticalScrollIndicator = YES;
    [self.view addSubview:self.scrollView];
    
    // 创建内容视图
    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];
    
    // 设置滚动视图约束
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    
    // 设置内容视图约束
    [NSLayoutConstraint activateConstraints:@[
        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor]
    ]];
    
    [self setupFormFields];
}

- (void)setupFormFields {
    CGFloat padding = 20.0;
    CGFloat fieldHeight = 44.0;
    CGFloat spacing = 16.0;
    
    // 标题标签
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"创建 Theos 项目";
    titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:titleLabel];
    
    // 项目名称
    UILabel *projectNameLabel = [self createLabelWithText:@"项目名称"];
    [self.contentView addSubview:projectNameLabel];
    
    self.projectNameField = [self createTextFieldWithPlaceholder:@"例如: MyTweak"];
    [self.contentView addSubview:self.projectNameField];
    
    // 包名
    UILabel *packageNameLabel = [self createLabelWithText:@"包名"];
    [self.contentView addSubview:packageNameLabel];
    
    self.packageNameField = [self createTextFieldWithPlaceholder:@"例如: com.yourname.mytweak"];
    [self.contentView addSubview:self.packageNameField];
    
    // 作者
    UILabel *authorLabel = [self createLabelWithText:@"作者"];
    [self.contentView addSubview:authorLabel];
    
    self.authorField = [self createTextFieldWithPlaceholder:@"例如: Your Name"];
    [self.contentView addSubview:self.authorField];
    
    // 描述
    UILabel *descriptionLabel = [self createLabelWithText:@"描述"];
    [self.contentView addSubview:descriptionLabel];
    
    self.descriptionField = [self createTextFieldWithPlaceholder:@"例如: An awesome MobileSubstrate tweak!"];
    [self.contentView addSubview:self.descriptionField];
    
    // 目标Bundle
    UILabel *targetBundleLabel = [self createLabelWithText:@"目标应用Bundle ID"];
    [self.contentView addSubview:targetBundleLabel];
    
    self.targetBundleField = [self createTextFieldWithPlaceholder:@"例如: com.apple.springboard"];
    [self.contentView addSubview:self.targetBundleField];
    
    // 创建按钮
    self.createButton = [[UIButton alloc] init];
    self.createButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.createButton setTitle:@"创建项目" forState:UIControlStateNormal];
    [self.createButton setBackgroundColor:[UIColor systemBlueColor]];
    self.createButton.layer.cornerRadius = 8.0;
    [self.createButton addTarget:self action:@selector(createTheosProject:) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.createButton];
    
    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        // 标题
        [titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:padding],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:padding],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
        
        // 项目名称
        [projectNameLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:spacing * 2],
        [projectNameLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:padding],
        [projectNameLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
        
        [self.projectNameField.topAnchor constraintEqualToAnchor:projectNameLabel.bottomAnchor constant:8],
        [self.projectNameField.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:padding],
        [self.projectNameField.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
        [self.projectNameField.heightAnchor constraintEqualToConstant:fieldHeight],
        
        // 包名
        [packageNameLabel.topAnchor constraintEqualToAnchor:self.projectNameField.bottomAnchor constant:spacing],
        [packageNameLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:padding],
        [packageNameLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
        
        [self.packageNameField.topAnchor constraintEqualToAnchor:packageNameLabel.bottomAnchor constant:8],
        [self.packageNameField.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:padding],
        [self.packageNameField.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
        [self.packageNameField.heightAnchor constraintEqualToConstant:fieldHeight],
        
        // 作者
        [authorLabel.topAnchor constraintEqualToAnchor:self.packageNameField.bottomAnchor constant:spacing],
        [authorLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:padding],
        [authorLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
        
        [self.authorField.topAnchor constraintEqualToAnchor:authorLabel.bottomAnchor constant:8],
        [self.authorField.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:padding],
        [self.authorField.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
        [self.authorField.heightAnchor constraintEqualToConstant:fieldHeight],
        
        // 描述
        [descriptionLabel.topAnchor constraintEqualToAnchor:self.authorField.bottomAnchor constant:spacing],
        [descriptionLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:padding],
        [descriptionLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
        
        [self.descriptionField.topAnchor constraintEqualToAnchor:descriptionLabel.bottomAnchor constant:8],
        [self.descriptionField.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:padding],
        [self.descriptionField.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
        [self.descriptionField.heightAnchor constraintEqualToConstant:fieldHeight],
        
        // 目标Bundle
        [targetBundleLabel.topAnchor constraintEqualToAnchor:self.descriptionField.bottomAnchor constant:spacing],
        [targetBundleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:padding],
        [targetBundleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
        
        [self.targetBundleField.topAnchor constraintEqualToAnchor:targetBundleLabel.bottomAnchor constant:8],
        [self.targetBundleField.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:padding],
        [self.targetBundleField.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
        [self.targetBundleField.heightAnchor constraintEqualToConstant:fieldHeight],
        
        // 创建按钮
        [self.createButton.topAnchor constraintEqualToAnchor:self.targetBundleField.bottomAnchor constant:spacing * 2],
        [self.createButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:padding],
        [self.createButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
        [self.createButton.heightAnchor constraintEqualToConstant:50],
        [self.createButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-padding]
    ]];
}

- (UILabel *)createLabelWithText:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    label.textColor = [UIColor labelColor];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

- (UITextField *)createTextFieldWithPlaceholder:(NSString *)placeholder {
    UITextField *textField = [[UITextField alloc] init];
    textField.placeholder = placeholder;
    textField.borderStyle = UITextBorderStyleRoundedRect;
    textField.font = [UIFont systemFontOfSize:16];
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.returnKeyType = UIReturnKeyNext;
    textField.delegate = (id<UITextFieldDelegate>)self;
    return textField;
}

#pragma mark - Actions

- (void)createTheosProject:(id)sender {
    // 验证输入
    if (self.projectNameField.text.length == 0) {
        [self showAlertWithTitle:@"错误" message:@"请输入项目名称"];
        return;
    }

    if (self.packageNameField.text.length == 0) {
        [self showAlertWithTitle:@"错误" message:@"请输入包名"];
        return;
    }

    if (self.targetBundleField.text.length == 0) {
        [self showAlertWithTitle:@"错误" message:@"请输入目标应用Bundle ID"];
        return;
    }

    // 创建项目配置
    NSDictionary *projectConfig = @{
        @"projectName": self.projectNameField.text,
        @"packageName": self.packageNameField.text,
        @"author": self.authorField.text.length > 0 ? self.authorField.text : @"Unknown",
        @"description": self.descriptionField.text.length > 0 ? self.descriptionField.text : @"An awesome MobileSubstrate tweak!",
        @"targetBundle": self.targetBundleField.text
    };

    // 显示加载指示器
    self.createButton.enabled = NO;
    [self.createButton setTitle:@"创建中..." forState:UIControlStateNormal];

    // 异步创建项目
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        BOOL success = [[TheosProjectManager sharedManager] createProjectWithConfig:projectConfig error:&error];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.createButton.enabled = YES;
            [self.createButton setTitle:@"创建项目" forState:UIControlStateNormal];

            if (success) {
                [self showAlertWithTitle:@"成功" message:@"Theos项目创建成功！"];
                [self clearFields];

                // 发送通知刷新文件列表
                [[NSNotificationCenter defaultCenter] postNotificationName:@"PluginMakerProjectCreated" object:nil];
            } else {
                NSString *errorMessage = error ? error.localizedDescription : @"创建项目失败";
                [self showAlertWithTitle:@"错误" message:errorMessage];
            }
        });
    });
}

- (void)clearFields {
    self.projectNameField.text = @"";
    self.packageNameField.text = @"";
    self.authorField.text = @"";
    self.descriptionField.text = @"";
    self.targetBundleField.text = @"";
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Keyboard Handling

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    CGRect keyboardFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat keyboardHeight = keyboardFrame.size.height;

    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0, 0, keyboardHeight, 0);
    self.scrollView.contentInset = contentInsets;
    self.scrollView.scrollIndicatorInsets = contentInsets;
}

- (void)keyboardWillHide:(NSNotification *)notification {
    self.scrollView.contentInset = UIEdgeInsetsZero;
    self.scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.projectNameField) {
        [self.packageNameField becomeFirstResponder];
    } else if (textField == self.packageNameField) {
        [self.authorField becomeFirstResponder];
    } else if (textField == self.authorField) {
        [self.descriptionField becomeFirstResponder];
    } else if (textField == self.descriptionField) {
        [self.targetBundleField becomeFirstResponder];
    } else if (textField == self.targetBundleField) {
        [textField resignFirstResponder];
        [self createTheosProject:nil];
    }
    return YES;
}

@end
