//
//  ClassDumpFileContentViewController.m
//  Modifier
//
//  Created by AI Assistant on 2024/8/13.
//

#import "ClassDumpFileContentViewController.h"

@interface ClassDumpFileContentViewController ()

@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) NSString *filePath;

@end

@implementation ClassDumpFileContentViewController

- (instancetype)initWithFilePath:(NSString *)filePath {
    self = [super init];
    if (self) {
        _filePath = filePath;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = [self.filePath lastPathComponent];

    // 设置导航栏
    [self setupNavigationBar];

    // 设置文本视图
    [self setupTextView];

    // 加载文件内容
    [self loadFileContent];
}

#pragma mark - Setup Methods

- (void)setupNavigationBar {
    NSMutableArray *rightBarButtonItems = [NSMutableArray array];

    // 添加分享按钮
    UIBarButtonItem *shareButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                                 target:self
                                                                                 action:@selector(shareFile)];
    [rightBarButtonItems addObject:shareButton];

    // 只对.h文件添加Hook按钮
    NSString *fileExtension = [self.filePath.pathExtension lowercaseString];
    if ([fileExtension isEqualToString:@"h"]) {
        UIBarButtonItem *hookButton = [[UIBarButtonItem alloc] initWithTitle:@"Hook"
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:self
                                                                      action:@selector(generateHookFile)];
        hookButton.tintColor = [UIColor systemOrangeColor];
        [rightBarButtonItems addObject:hookButton];
    }

    self.navigationItem.rightBarButtonItems = rightBarButtonItems;
}

- (void)setupTextView {
    self.textView = [[UITextView alloc] init];
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.editable = NO;
    self.textView.font = [UIFont fontWithName:@"Menlo" size:14]; // 使用等宽字体
    self.textView.backgroundColor = [UIColor systemBackgroundColor];
    [self.view addSubview:self.textView];

    [NSLayoutConstraint activateConstraints:@[
        [self.textView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.textView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10],
        [self.textView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-10],
        [self.textView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
}

#pragma mark - File Operations

- (void)loadFileContent {
    NSError *error;
    NSString *content = [NSString stringWithContentsOfFile:self.filePath
                                                   encoding:NSUTF8StringEncoding
                                                      error:&error];

    if (error) {
        self.textView.text = [NSString stringWithFormat:@"无法读取文件内容:\n%@", error.localizedDescription];
        return;
    }

    if (content.length == 0) {
        self.textView.text = @"文件为空";
        return;
    }

    // 如果文件太大，只显示前面部分
    if (content.length > 100000) { // 100KB
        content = [content substringToIndex:100000];
        content = [content stringByAppendingString:@"\n\n... (文件太大，只显示前100KB内容)"];
    }

    self.textView.text = content;

    // 应用语法高亮
    [self applySyntaxHighlighting];
}

- (void)shareFile {
    NSURL *fileURL = [NSURL fileURLWithPath:self.filePath];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL]
                                                                             applicationActivities:nil];

    // iPad适配
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    }

    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)generateHookFile {
    NSString *headerContent = self.textView.text;
    if (headerContent.length == 0) {
        [self showAlertWithTitle:@"错误" message:@"头文件内容为空"];
        return;
    }

    // 解析头文件，提取类名和方法
    NSString *hookContent = [self generateHookContentFromHeader:headerContent];

    // 创建Hook文件名
    NSString *originalFileName = [[self.filePath lastPathComponent] stringByDeletingPathExtension];
    NSString *hookFileName = [NSString stringWithFormat:@"%@_Hook.xm", originalFileName];

    // 将Hook文件生成在当前头文件所在的目录（即dump文件夹内）
    NSString *currentDirectory = [self.filePath stringByDeletingLastPathComponent];
    NSString *hookFilePath = [currentDirectory stringByAppendingPathComponent:hookFileName];

    // 写入Hook文件
    NSError *error;
    BOOL success = [hookContent writeToFile:hookFilePath
                                 atomically:YES
                                   encoding:NSUTF8StringEncoding
                                      error:&error];

    if (success) {
        [self showAlertWithTitle:@"成功"
                         message:[NSString stringWithFormat:@"Hook文件已生成：\n%@", hookFilePath]];

        // 通知delegate刷新文件列表
        if ([self.delegate respondsToSelector:@selector(fileContentViewController:didGenerateHookFile:)]) {
            [self.delegate fileContentViewController:self didGenerateHookFile:hookFilePath];
        }
    } else {
        [self showAlertWithTitle:@"失败"
                         message:[NSString stringWithFormat:@"生成Hook文件失败：\n%@", error.localizedDescription]];
    }
}

- (NSString *)generateHookContentFromHeader:(NSString *)headerContent {
    NSMutableString *hookContent = [NSMutableString string];

    // 添加文件头注释
    [hookContent appendString:@"//\n"];
    [hookContent appendFormat:@"//  Auto-generated Hook file for %@\n", [self.filePath lastPathComponent]];
    [hookContent appendString:@"//  Generated by Obsolete ClassDump\n"];
    [hookContent appendString:@"//\n\n"];

    // 添加导入
    [hookContent appendString:@"#import <Foundation/Foundation.h>\n"];
    [hookContent appendString:@"#import <UIKit/UIKit.h>\n\n"];

    // 提取类名
    NSString *className = [self extractClassNameFromHeader:headerContent];
    if (className.length == 0) {
        className = @"UnknownClass";
    }

    [hookContent appendFormat:@"%%hook %@\n\n", className];

    // 提取并生成方法Hook
    NSArray *methods = [self extractMethodsFromHeader:headerContent];
    for (NSString *method in methods) {
        [hookContent appendFormat:@"%@\n", [self generateHookMethodFromSignature:method]];
        [hookContent appendString:@"\n"];
    }

    [hookContent appendString:@"%end\n\n"];

    // 添加构造函数
    [hookContent appendString:@"%ctor {\n"];
    [hookContent appendFormat:@"    NSLog(@\"Obsolete: %@ Hook loaded\");\n", className];
    [hookContent appendString:@"}\n"];

    return hookContent;
}

- (NSString *)extractClassNameFromHeader:(NSString *)headerContent {
    // 使用正则表达式提取@interface后的类名
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"@interface\\s+(\\w+)"
                                                                           options:0
                                                                             error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:headerContent
                                                    options:0
                                                      range:NSMakeRange(0, headerContent.length)];

    if (match && match.numberOfRanges > 1) {
        return [headerContent substringWithRange:[match rangeAtIndex:1]];
    }

    return @"";
}

- (NSArray *)extractMethodsFromHeader:(NSString *)headerContent {
    NSMutableArray *methods = [NSMutableArray array];

    // 提取实例方法 (以 - 开头)
    NSRegularExpression *instanceMethodRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\s*-\\s*\\([^)]+\\)\\s*[^;]+;"
                                                                                         options:NSRegularExpressionAnchorsMatchLines
                                                                                           error:nil];
    NSArray *instanceMatches = [instanceMethodRegex matchesInString:headerContent
                                                            options:0
                                                              range:NSMakeRange(0, headerContent.length)];

    for (NSTextCheckingResult *match in instanceMatches) {
        NSString *methodSignature = [headerContent substringWithRange:match.range];
        methodSignature = [methodSignature stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [methods addObject:methodSignature];
    }

    // 提取类方法 (以 + 开头)
    NSRegularExpression *classMethodRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\s*\\+\\s*\\([^)]+\\)\\s*[^;]+;"
                                                                                       options:NSRegularExpressionAnchorsMatchLines
                                                                                         error:nil];
    NSArray *classMatches = [classMethodRegex matchesInString:headerContent
                                                      options:0
                                                        range:NSMakeRange(0, headerContent.length)];

    for (NSTextCheckingResult *match in classMatches) {
        NSString *methodSignature = [headerContent substringWithRange:match.range];
        methodSignature = [methodSignature stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [methods addObject:methodSignature];
    }

    return methods;
}

- (NSString *)generateHookMethodFromSignature:(NSString *)signature {
    // 移除末尾的分号
    NSString *cleanSignature = [signature stringByReplacingOccurrencesOfString:@";" withString:@""];

    NSMutableString *hookMethod = [NSMutableString string];
    [hookMethod appendFormat:@"%@ {\n", cleanSignature];
    [hookMethod appendString:@"    NSLog(@\"Obsolete: %s called\", __FUNCTION__);\n"];

    // 检查是否有返回值
    if (![signature containsString:@"(void)"]) {
        [hookMethod appendString:@"    id result = %orig;\n"];
        [hookMethod appendString:@"    NSLog(@\"Obsolete: %s result: %@\", __FUNCTION__, result);\n"];
        [hookMethod appendString:@"    return result;\n"];
    } else {
        [hookMethod appendString:@"    %orig;\n"];
    }

    [hookMethod appendString:@"}"];

    return hookMethod;
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Syntax Highlighting

- (void)applySyntaxHighlighting {
    NSString *fileExtension = [self.filePath.pathExtension lowercaseString];
    if (![fileExtension isEqualToString:@"h"] && ![fileExtension isEqualToString:@"xm"]) {
        return; // 对.h和.xm文件应用语法高亮
    }

    NSString *text = self.textView.text;
    if (text.length == 0) return;

    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:text];

    // 设置基本文本属性
    UIColor *textColor = [UIColor labelColor];
    [attributedString addAttribute:NSForegroundColorAttributeName value:textColor range:NSMakeRange(0, text.length)];
    [attributedString addAttribute:NSFontAttributeName value:self.textView.font range:NSMakeRange(0, text.length)];

    // 定义不同类别的关键词及其颜色
    NSMutableDictionary *keywordCategories = [@{
        [UIColor systemPurpleColor]: @[@"@interface", @"@implementation", @"@end", @"@property", @"@synthesize", @"@dynamic",
                                       @"@protocol", @"@optional", @"@required", @"@class", @"@selector"], // Objective-C 关键字
        [UIColor systemRedColor]: @[@"if", @"else", @"for", @"while", @"do", @"switch", @"case", @"default", @"break",
                                    @"continue", @"return", @"goto", @"typedef", @"enum", @"struct", @"union", @"const",
                                    @"static", @"extern", @"void", @"int", @"float", @"double", @"char", @"bool", @"id",
                                    @"BOOL", @"YES", @"NO", @"nil", @"NULL"], // C/C++ 基本类型和控制流
        [UIColor systemBlueColor]: @[@"NSString", @"NSArray", @"NSDictionary", @"NSObject", @"UIView", @"UIViewController",
                                     @"NSInteger", @"NSUInteger", @"CGFloat", @"CGRect", @"CGPoint", @"CGSize"], // Foundation/UIKit 类
        [UIColor systemTealColor]: @[@"#import", @"#include", @"#define", @"#ifdef", @"#ifndef", @"#endif", @"#pragma"] // 预处理指令
    } mutableCopy];

    // 如果是.xm文件，添加Logos关键字
    if ([fileExtension isEqualToString:@"xm"]) {
        keywordCategories[[UIColor systemOrangeColor]] = @[@"%hook", @"%end", @"%orig", @"%new", @"%ctor", @"%dtor",
                                                           @"%group", @"%subclass", @"%property", @"%init", @"%c", @"%log"];
    }

    for (UIColor *color in keywordCategories) {
        NSArray *keywords = keywordCategories[color];
        for (NSString *keyword in keywords) {
            NSString *pattern;
            if ([keyword hasPrefix:@"#"] || [keyword hasPrefix:@"@"]) {
                // 对于预处理指令和Objective-C关键字，使用更灵活的匹配模式
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
        [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor systemGreenColor] range:match.range];
    }

    // 注释高亮
    NSRegularExpression *commentRegex = [NSRegularExpression regularExpressionWithPattern:@"\/\/.*|\/\\*[\\s\\S]*?\\*\/" options:0 error:nil];
    NSArray *commentMatches = [commentRegex matchesInString:text options:0 range:NSMakeRange(0, text.length)];

    for (NSTextCheckingResult *match in commentMatches) {
        [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor systemGrayColor] range:match.range];
    }

    // 方法名高亮
    NSRegularExpression *methodRegex = [NSRegularExpression regularExpressionWithPattern:@"-\\s*\\([^)]+\\)\\s*\\w+\\s*:" options:0 error:nil];
    NSArray *methodMatches = [methodRegex matchesInString:text options:0 range:NSMakeRange(0, text.length)];

    for (NSTextCheckingResult *match in methodMatches) {
        [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor systemIndigoColor] range:match.range];
    }

    // 设置属性文本
    self.textView.attributedText = attributedString;
}

@end
