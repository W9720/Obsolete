//
//  CodeEditorViewController.m
//  修改器
//
//  Created by AI Assistant on 2025-01-08.
//

#import "CodeEditorViewController.h"
#import "PluginFileManager.h"
#import "CodeTemplateManager.h"
#import <objc/runtime.h>

@interface CodeEditorViewController () <UITextViewDelegate>

@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UIToolbar *toolbar;
@property (nonatomic, strong) NSString *originalContent;
@property (nonatomic, assign) BOOL hasUnsavedChanges;

@end

@implementation CodeEditorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self setupNavigationBar];
    [self setupUI];
    [self loadFileContent];
}

- (void)setupNavigationBar {
    self.title = [self.filePath lastPathComponent];
    
    // 左侧关闭按钮
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithTitle:@"关闭"
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(closeEditor)];
    self.navigationItem.leftBarButtonItem = closeButton;
    
    // 右侧保存按钮
    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithTitle:@"保存"
                                                                   style:UIBarButtonItemStyleDone
                                                                  target:self
                                                                  action:@selector(saveFile)];
    self.navigationItem.rightBarButtonItem = saveButton;
}

- (void)setupUI {
    // 创建文本视图
    self.textView = [[UITextView alloc] init];
    self.textView.delegate = self;
    self.textView.font = [UIFont fontWithName:@"Menlo" size:14] ?: [UIFont systemFontOfSize:14];
    self.textView.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.15 alpha:1.0];
    self.textView.textColor = [UIColor whiteColor];
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.autocorrectionType = UITextAutocorrectionTypeNo;
    self.textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.textView.smartQuotesType = UITextSmartQuotesTypeNo;
    self.textView.smartDashesType = UITextSmartDashesTypeNo;
    [self.view addSubview:self.textView];
    
    // 创建工具栏
    [self setupToolbar];
    
    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        [self.textView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.textView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.textView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.textView.bottomAnchor constraintEqualToAnchor:self.toolbar.topAnchor],
        
        [self.toolbar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.toolbar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.toolbar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [self.toolbar.heightAnchor constraintEqualToConstant:44]
    ]];
}

- (void)setupToolbar {
    self.toolbar = [[UIToolbar alloc] init];
    self.toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.toolbar];
    
    // 创建工具栏按钮
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    // 检查文件扩展名，只为.xm文件添加预设代码块按钮
    NSString *fileExtension = [self.filePath.pathExtension lowercaseString];
    if ([fileExtension isEqualToString:@"xm"] || [fileExtension isEqualToString:@"mm"]) {
        UIBarButtonItem *templateButton = [[UIBarButtonItem alloc] initWithTitle:@"代码模板"
                                                                           style:UIBarButtonItemStylePlain
                                                                          target:self
                                                                          action:@selector(showCodeTemplates)];
        templateButton.tintColor = [UIColor systemBlueColor];
        
        self.toolbar.items = @[templateButton, flexibleSpace];
    } else {
        self.toolbar.items = @[flexibleSpace];
    }
}

- (void)loadFileContent {
    if (!self.filePath) return;
    
    NSError *error;
    NSString *content = [[PluginFileManager sharedManager] readFileAtPath:self.filePath error:&error];
    
    if (error) {
        [self showAlertWithTitle:@"读取失败" message:error.localizedDescription];
        return;
    }
    
    self.originalContent = content ?: @"";
    self.textView.text = self.originalContent;
    self.hasUnsavedChanges = NO;
    
    // 应用语法高亮
    [self applySyntaxHighlighting];
}

- (void)saveFile {
    if (!self.filePath || !self.hasUnsavedChanges) return;
    
    NSError *error;
    BOOL success = [[PluginFileManager sharedManager] writeContent:self.textView.text 
                                                            toFile:self.filePath 
                                                             error:&error];
    
    if (success) {
        self.originalContent = self.textView.text;
        self.hasUnsavedChanges = NO;
        [self showAlertWithTitle:@"保存成功" message:@"文件已保存"];
    } else {
        [self showAlertWithTitle:@"保存失败" message:error.localizedDescription];
    }
}

- (void)closeEditor {
    if (self.hasUnsavedChanges) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"未保存的更改"
                                                                       message:@"您有未保存的更改，确定要关闭吗？"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"不保存" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            [self dismissViewControllerAnimated:YES completion:nil];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"保存并关闭" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self saveFile];
            [self dismissViewControllerAnimated:YES completion:nil];
        }]];
        
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)showCodeTemplates {
    // 创建预设代码块选择器视图
    UIViewController *presetVC = [[UIViewController alloc] init];
    presetVC.modalPresentationStyle = UIModalPresentationPageSheet;
    presetVC.view.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.15 alpha:1.0]; // 深色背景
    presetVC.title = @"预设代码块";

    // 添加导航栏
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:presetVC];
    navController.navigationBar.barTintColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.18 alpha:1.0];
    navController.navigationBar.tintColor = [UIColor systemBlueColor];

    // 添加关闭按钮
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                           target:self
                                                                           action:@selector(dismissPresetView:)];
    presetVC.navigationItem.leftBarButtonItem = closeButton;
    objc_setAssociatedObject(closeButton, "presetVC", navController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 创建滚动视图
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:presetVC.view.bounds];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scrollView.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.15 alpha:1.0];
    scrollView.contentInset = UIEdgeInsetsMake(40, 0, 0, 0);
    [presetVC.view addSubview:scrollView];

    // 添加标题标签
    UILabel *headerLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, presetVC.view.bounds.size.width - 40, 30)];
    headerLabel.text = @"选择要插入的代码模板";
    headerLabel.textColor = [UIColor whiteColor];
    headerLabel.font = [UIFont boldSystemFontOfSize:18.0];
    headerLabel.textAlignment = NSTextAlignmentCenter;
    [scrollView addSubview:headerLabel];

    [self setupPresetCardsInScrollView:scrollView headerLabel:headerLabel navController:navController];

    // 显示预设代码块选择器
    [self presentViewController:navController animated:YES completion:nil];
}



- (void)applySyntaxHighlighting {
    NSString *fileExtension = [self.filePath.pathExtension lowercaseString];
    if (![fileExtension isEqualToString:@"xm"] && ![fileExtension isEqualToString:@"mm"]) {
        return;
    }

    // 保存当前光标位置
    NSRange selectedRange = self.textView.selectedRange;

    NSString *text = self.textView.text;
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:text];

    // 设置基本文本属性
    [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:NSMakeRange(0, text.length)];
    [attributedString addAttribute:NSFontAttributeName value:self.textView.font range:NSMakeRange(0, text.length)];

    // 关键字高亮 - Objective-C 和 Logos 关键字
    // 定义不同类别的关键词及其颜色
    NSDictionary *keywordCategories = @{
        [UIColor systemPurpleColor]: @[@"@interface", @"@implementation", @"@end", @"@property", @"@synthesize", @"@dynamic",
                                       @"@protocol", @"@optional", @"@required", @"@class", @"@selector", @"@autoreleasepool"], // Objective-C 关键字
        [UIColor systemRedColor]: @[@"if", @"else", @"for", @"while", @"do", @"switch", @"case", @"default", @"break",
                                    @"continue", @"return", @"goto", @"typedef", @"enum", @"struct", @"union", @"const",
                                    @"static", @"extern", @"void", @"int", @"float", @"double", @"char", @"bool", @"id"], // C/C++ 基本类型和控制流
        [UIColor systemBlueColor]: @[@"NSString", @"NSArray", @"NSDictionary", @"NSObject", @"UIView", @"UIViewController"], // Foundation/UIKit 类
        [UIColor systemOrangeColor]: @[@"%hook", @"%end", @"%orig", @"%new", @"%ctor", @"%dtor", @"%group", @"%subclass", @"%property", @"%init", @"%c", @"%log"], // Logos 关键字
        [UIColor systemTealColor]: @[@"#import"] // 预处理指令
    };

    for (UIColor *color in keywordCategories) {
        NSArray *keywords = keywordCategories[color];
        for (NSString *keyword in keywords) {
            NSString *pattern;
            if ([keyword hasPrefix:@"%"] || [keyword isEqualToString:@"#import"]) {
                // 对于 Logos 关键字和 #import，使用更灵活的匹配模式
                pattern = [NSString stringWithFormat:@"%@", [NSRegularExpression escapedPatternForString:keyword]];
            } else {
                // 对于其他关键字，使用单词边界匹配
                pattern = [NSString stringWithFormat:@"\\b%@\\b", [NSRegularExpression escapedPatternForString:keyword]];
            }

            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
            NSArray *matches = [regex matchesInString:text options:0 range:NSMakeRange(0, text.length)];

            for (NSTextCheckingResult *match in matches) {
                [attributedString addAttribute:NSForegroundColorAttributeName value:color range:match.range];
            }
        }
    }

    // 字符串高亮
    NSRegularExpression *stringRegex = [NSRegularExpression regularExpressionWithPattern:@"\".*?\"" options:0 error:nil];
    NSArray *stringMatches = [stringRegex matchesInString:text options:0 range:NSMakeRange(0, text.length)];

    for (NSTextCheckingResult *match in stringMatches) {
        [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor systemGreenColor] range:match.range]; // 绿色字符串
    }

    // 注释高亮
    NSRegularExpression *commentRegex = [NSRegularExpression regularExpressionWithPattern:@"\/\/.*" options:0 error:nil];
    NSArray *commentMatches = [commentRegex matchesInString:text options:0 range:NSMakeRange(0, text.length)];

    for (NSTextCheckingResult *match in commentMatches) {
        [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithRed:0.4 green:0.4 blue:0.4 alpha:1.0] range:match.range]; // 灰色注释
    }

    // 数字高亮
    NSRegularExpression *numberRegex = [NSRegularExpression regularExpressionWithPattern:@"\\b\\d+\\b" options:0 error:nil];
    NSArray *numberMatches = [numberRegex matchesInString:text options:0 range:NSMakeRange(0, text.length)];

    for (NSTextCheckingResult *match in numberMatches) {
        [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor systemTealColor] range:match.range]; // 青色数字
    }

    // 方法名高亮 (简单的匹配)
    NSRegularExpression *methodRegex = [NSRegularExpression regularExpressionWithPattern:@"-\\s*\\(\\w+\\s*\\*?\\)\\s*\\w+\\s*:"
                                                                                  options:0
                                                                                    error:nil];
    NSArray *methodMatches = [methodRegex matchesInString:text options:0 range:NSMakeRange(0, text.length)];

    for (NSTextCheckingResult *match in methodMatches) {
        [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor systemIndigoColor] range:match.range]; // 紫色方法名
    }

    // 设置属性文本
    self.textView.attributedText = attributedString;

    // 恢复光标位置
    self.textView.selectedRange = selectedRange;
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    if (![textView.text isEqualToString:self.originalContent]) {
        self.hasUnsavedChanges = YES;
    }
    
    // 实时语法高亮（性能考虑，可以添加延迟）
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(applySyntaxHighlighting) object:nil];
    [self performSelector:@selector(applySyntaxHighlighting) withObject:nil afterDelay:0.5];
}

#pragma mark - 预设代码块相关方法

- (void)setupPresetCardsInScrollView:(UIScrollView *)scrollView headerLabel:(UILabel *)headerLabel navController:(UINavigationController *)navController {
    // 获取预设代码块数据
    CodeTemplateManager *templateManager = [CodeTemplateManager sharedManager];
    NSDictionary *presetCategories = [templateManager getAllTemplates];

    // 设置布局参数
    CGFloat padding = 12.0;
    CGFloat cardWidth = MIN(scrollView.bounds.size.width - (padding * 2), 400);
    CGFloat cardHeight = 80.0;
    CGFloat yOffset = headerLabel.frame.origin.y + headerLabel.frame.size.height + 15;

    // 遍历类别并创建卡片
    for (NSString *category in presetCategories) {
        // 添加类别标题
        UILabel *categoryLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, cardWidth, 30)];
        categoryLabel.text = category;
        categoryLabel.textColor = [UIColor whiteColor];
        categoryLabel.font = [UIFont boldSystemFontOfSize:16.0];
        [scrollView addSubview:categoryLabel];

        yOffset += categoryLabel.frame.size.height + 10;

        NSArray *presetBlocks = presetCategories[category];
        // 创建预设代码块卡片
        for (NSDictionary *preset in presetBlocks) {
            UIView *cardView = [self createPresetCardWithPreset:preset
                                                          frame:CGRectMake((scrollView.bounds.size.width - cardWidth) / 2, yOffset, cardWidth, cardHeight)
                                                  navController:navController];
            [scrollView addSubview:cardView];
            yOffset += cardHeight + padding;
        }
        yOffset += padding; // Add extra padding after each category
    }

    // 设置滚动视图内容大小
    scrollView.contentSize = CGSizeMake(scrollView.bounds.size.width, yOffset + padding);
}

- (UIView *)createPresetCardWithPreset:(NSDictionary *)preset frame:(CGRect)frame navController:(UINavigationController *)navController {
    // 创建卡片容器
    UIView *cardView = [[UIView alloc] initWithFrame:frame];
    cardView.backgroundColor = [UIColor colorWithRed:0.18 green:0.18 blue:0.22 alpha:1.0];
    cardView.layer.cornerRadius = 16.0;
    cardView.layer.borderWidth = 1.0;
    cardView.layer.borderColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.3].CGColor;
    cardView.layer.shadowColor = [UIColor blackColor].CGColor;
    cardView.layer.shadowOffset = CGSizeMake(0, 4);
    cardView.layer.shadowOpacity = 0.2;
    cardView.layer.shadowRadius = 8.0;

    CGFloat padding = 12.0;
    CGFloat cardWidth = frame.size.width;
    CGFloat cardHeight = frame.size.height;

    // 添加图标背景
    UIView *iconBackground = [[UIView alloc] initWithFrame:CGRectMake(padding, padding, 40, 40)];
    iconBackground.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.2];
    iconBackground.layer.cornerRadius = 8.0;
    [cardView addSubview:iconBackground];

    // 添加图标
    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 24, 24)];
    iconView.center = iconBackground.center;
    if (@available(iOS 13.0, *)) {
        iconView.image = [UIImage systemImageNamed:@"hammer.fill"];
        iconView.tintColor = [UIColor systemBlueColor];
    }
    [cardView addSubview:iconView];

    // 添加标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding + 50, padding, cardWidth - padding * 2 - 50, 20)];
    titleLabel.text = preset[@"title"];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:16.0];
    [cardView addSubview:titleLabel];

    // 添加描述
    UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding + 50, padding + 25, cardWidth - padding * 2 - 50, 18)];
    descLabel.text = preset[@"description"];
    descLabel.textColor = [UIColor lightGrayColor];
    descLabel.font = [UIFont systemFontOfSize:12.0];
    [cardView addSubview:descLabel];

    // 添加插入按钮
    UIButton *insertButton = [UIButton buttonWithType:UIButtonTypeSystem];
    insertButton.frame = CGRectMake(cardWidth - 80 - padding, cardHeight - 30 - padding, 80, 30);
    insertButton.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.2];
    [insertButton setTitle:@"插入" forState:UIControlStateNormal];
    [insertButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    insertButton.titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
    insertButton.layer.cornerRadius = 8.0;
    [cardView addSubview:insertButton];

    // 添加点击手势到整个卡片
    UITapGestureRecognizer *cardTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(insertPresetCode:)];
    [cardView addGestureRecognizer:cardTapGesture];

    // 添加点击事件到按钮
    [insertButton addTarget:self action:@selector(insertPresetCodeFromButton:) forControlEvents:UIControlEventTouchUpInside];

    // 存储代码模板
    objc_setAssociatedObject(cardTapGesture, "code", preset[@"code"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cardTapGesture, "textView", self.textView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cardTapGesture, "presetVC", navController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    objc_setAssociatedObject(insertButton, "code", preset[@"code"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(insertButton, "textView", self.textView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(insertButton, "presetVC", navController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    return cardView;
}

- (void)insertPresetCode:(UITapGestureRecognizer *)gesture {
    NSString *code = objc_getAssociatedObject(gesture, "code");
    UITextView *textView = objc_getAssociatedObject(gesture, "textView");
    UIViewController *presetVC = objc_getAssociatedObject(gesture, "presetVC");

    [self insertCodeToTextView:textView code:code];
    [presetVC dismissViewControllerAnimated:YES completion:nil];
}

- (void)insertPresetCodeFromButton:(UIButton *)button {
    NSString *code = objc_getAssociatedObject(button, "code");
    UITextView *textView = objc_getAssociatedObject(button, "textView");
    UIViewController *presetVC = objc_getAssociatedObject(button, "presetVC");

    [self insertCodeToTextView:textView code:code];
    [presetVC dismissViewControllerAnimated:YES completion:nil];
}

- (void)insertCodeToTextView:(UITextView *)textView code:(NSString *)code {
    // 在当前光标位置插入代码模板
    NSRange selectedRange = textView.selectedRange;
    NSString *currentText = textView.text;
    NSString *newText = [currentText stringByReplacingCharactersInRange:selectedRange withString:code];

    textView.text = newText;

    // 更新光标位置
    textView.selectedRange = NSMakeRange(selectedRange.location + code.length, 0);

    // 应用语法高亮
    [self applySyntaxHighlighting];

    // 标记为已修改
    self.hasUnsavedChanges = YES;
}

- (void)dismissPresetView:(UIBarButtonItem *)sender {
    UIViewController *presetVC = objc_getAssociatedObject(sender, "presetVC");
    [presetVC dismissViewControllerAnimated:YES completion:nil];
}

@end
