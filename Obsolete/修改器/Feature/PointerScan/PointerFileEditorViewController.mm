//
//  PointerFileEditorViewController.mm
//  Modifier
//
//  Created by Augment Agent on 2024/12/25.
//

#import "PointerFileEditorViewController.h"

@interface PointerFileEditorViewController () <UITextViewDelegate, UISearchBarDelegate>

// UI 组件
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIToolbar *toolbar;
@property (nonatomic, strong) UISegmentedControl *filterControl;
@property (nonatomic, strong) UILabel *statusLabel;

// 数据
@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) NSString *originalContent;
@property (nonatomic, strong) NSMutableArray<NSString *> *pointerLines;
@property (nonatomic, strong) NSMutableArray<NSString *> *filteredLines;
@property (nonatomic, assign) BOOL isFiltered;

// 编辑状态
@property (nonatomic, assign) BOOL hasUnsavedChanges;

@end

@implementation PointerFileEditorViewController

- (instancetype)initWithFilePath:(NSString *)filePath {
    self = [super init];
    if (self) {
        self.filePath = filePath;
        self.isFiltered = NO;
        self.hasUnsavedChanges = NO;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupUI];
    [self loadFileContent];
    [self setupNavigationBar];
}

- (void)setupUI {
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // 搜索栏
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"搜索指针链...";
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.searchBar];
    
    // 过滤控制器
    NSArray *filterItems = @[@"全部", @"有效指针", @"无效指针", @"包含偏移"];
    self.filterControl = [[UISegmentedControl alloc] initWithItems:filterItems];
    self.filterControl.selectedSegmentIndex = 0;
    self.filterControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.filterControl addTarget:self action:@selector(filterChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.filterControl];
    
    // 文本编辑器
    self.textView = [[UITextView alloc] init];
    self.textView.delegate = self;
    self.textView.font = [UIFont fontWithName:@"Menlo" size:14]; // 等宽字体
    self.textView.backgroundColor = [UIColor systemBackgroundColor];
    self.textView.textColor = [UIColor labelColor];
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.layer.borderColor = [UIColor systemGray4Color].CGColor;
    self.textView.layer.borderWidth = 1.0;
    self.textView.layer.cornerRadius = 8.0;
    [self.view addSubview:self.textView];
    
    // 状态标签
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont systemFontOfSize:12];
    self.statusLabel.textColor = [UIColor secondaryLabelColor];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusLabel];
    
    // 工具栏
    [self setupToolbar];
    
    // 约束
    [self setupConstraints];
}

- (void)setupToolbar {
    self.toolbar = [[UIToolbar alloc] init];
    self.toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIBarButtonItem *undoButton = [[UIBarButtonItem alloc] initWithTitle:@"撤销" 
                                                                   style:UIBarButtonItemStylePlain 
                                                                  target:self 
                                                                  action:@selector(undoAction)];
    
    UIBarButtonItem *redoButton = [[UIBarButtonItem alloc] initWithTitle:@"重做" 
                                                                   style:UIBarButtonItemStylePlain 
                                                                  target:self 
                                                                  action:@selector(redoAction)];
    
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace 
                                                                               target:nil 
                                                                               action:nil];
    
    UIBarButtonItem *formatButton = [[UIBarButtonItem alloc] initWithTitle:@"格式化" 
                                                                     style:UIBarButtonItemStylePlain 
                                                                    target:self 
                                                                    action:@selector(formatText)];
    
    UIBarButtonItem *validateButton = [[UIBarButtonItem alloc] initWithTitle:@"验证" 
                                                                       style:UIBarButtonItemStylePlain 
                                                                      target:self 
                                                                      action:@selector(validatePointers)];
    
    self.toolbar.items = @[undoButton, redoButton, flexSpace, formatButton, validateButton];
    [self.view addSubview:self.toolbar];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // 搜索栏
        [self.searchBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        
        // 过滤控制器
        [self.filterControl.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor constant:8],
        [self.filterControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.filterControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        
        // 文本编辑器
        [self.textView.topAnchor constraintEqualToAnchor:self.filterControl.bottomAnchor constant:8],
        [self.textView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.textView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.textView.bottomAnchor constraintEqualToAnchor:self.toolbar.topAnchor constant:-8],
        
        // 工具栏
        [self.toolbar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.toolbar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.toolbar.bottomAnchor constraintEqualToAnchor:self.statusLabel.topAnchor],
        
        // 状态标签
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [self.statusLabel.heightAnchor constraintEqualToConstant:30]
    ]];
}

- (void)setupNavigationBar {
    self.title = [self.filePath.lastPathComponent stringByDeletingPathExtension];
    
    // 保存按钮
    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithTitle:@"保存" 
                                                                   style:UIBarButtonItemStyleDone 
                                                                  target:self 
                                                                  action:@selector(saveFile)];
    
    // 取消按钮
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"取消" 
                                                                     style:UIBarButtonItemStylePlain 
                                                                    target:self 
                                                                    action:@selector(cancelEdit)];
    
    self.navigationItem.rightBarButtonItem = saveButton;
    self.navigationItem.leftBarButtonItem = cancelButton;
}

- (void)loadFileContent {
    NSError *error;
    self.originalContent = [NSString stringWithContentsOfFile:self.filePath 
                                                      encoding:NSUTF8StringEncoding 
                                                         error:&error];
    
    if (error) {
        [self showAlert:@"错误" message:[NSString stringWithFormat:@"读取文件失败: %@", error.localizedDescription]];
        return;
    }
    
    [self parsePointerLines];
    [self updateTextView];
    [self updateStatusLabel];
}

#pragma mark - 数据处理

- (void)parsePointerLines {
    self.pointerLines = [NSMutableArray array];
    NSArray *lines = [self.originalContent componentsSeparatedByString:@"\n"];

    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        // 跳过空行、头部信息和数值行
        if (trimmedLine.length == 0 ||
            [trimmedLine hasPrefix:@"Obsolete修改器"] ||
            [trimmedLine hasPrefix:@"共"] ||
            [trimmedLine hasPrefix:@"   ("]) {
            continue;
        }

        // 只保留指针链行
        if ([trimmedLine rangeOfString:@". "].location != NSNotFound) {
            [self.pointerLines addObject:trimmedLine];
        }
    }

    self.filteredLines = [self.pointerLines mutableCopy];
}

- (void)updateTextView {
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] init];

    NSArray *linesToShow = self.isFiltered ? self.filteredLines : self.pointerLines;

    for (NSInteger i = 0; i < linesToShow.count; i++) {
        NSString *line = linesToShow[i];
        NSAttributedString *highlightedLine = [self highlightPointerChain:line lineNumber:i + 1];
        [attributedText appendAttributedString:highlightedLine];

        if (i < linesToShow.count - 1) {
            [attributedText appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
        }
    }

    self.textView.attributedText = attributedText;
}

- (NSAttributedString *)highlightPointerChain:(NSString *)line lineNumber:(NSInteger)lineNumber {
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:line];

    // 基础字体和颜色
    [attributedString addAttribute:NSFontAttributeName
                             value:[UIFont fontWithName:@"Menlo" size:14]
                             range:NSMakeRange(0, line.length)];

    [attributedString addAttribute:NSForegroundColorAttributeName
                             value:[UIColor labelColor]
                             range:NSMakeRange(0, line.length)];

    // 高亮序号
    NSRange numberRange = [line rangeOfString:@"\\d+\\." options:NSRegularExpressionSearch];
    if (numberRange.location != NSNotFound) {
        [attributedString addAttribute:NSForegroundColorAttributeName
                                 value:[UIColor systemBlueColor]
                                 range:numberRange];
        [attributedString addAttribute:NSFontAttributeName
                                 value:[UIFont boldSystemFontOfSize:14]
                                 range:numberRange];
    }

    // 高亮基址 (wp2, wp3等)
    NSRegularExpression *baseRegex = [NSRegularExpression regularExpressionWithPattern:@"\\bwp\\d+\\b"
                                                                               options:0
                                                                                 error:nil];
    [baseRegex enumerateMatchesInString:line
                                options:0
                                  range:NSMakeRange(0, line.length)
                             usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
        [attributedString addAttribute:NSForegroundColorAttributeName
                                 value:[UIColor systemGreenColor]
                                 range:match.range];
        [attributedString addAttribute:NSFontAttributeName
                                 value:[UIFont boldSystemFontOfSize:14]
                                 range:match.range];
    }];

    // 高亮偏移量 (0x开头的十六进制)
    NSRegularExpression *offsetRegex = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9A-Fa-f]+"
                                                                                 options:0
                                                                                   error:nil];
    [offsetRegex enumerateMatchesInString:line
                                  options:0
                                    range:NSMakeRange(0, line.length)
                               usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
        [attributedString addAttribute:NSForegroundColorAttributeName
                                 value:[UIColor systemOrangeColor]
                                 range:match.range];
    }];

    // 高亮操作符 (+, -)
    NSRegularExpression *operatorRegex = [NSRegularExpression regularExpressionWithPattern:@"[+\\-]"
                                                                                   options:0
                                                                                     error:nil];
    [operatorRegex enumerateMatchesInString:line
                                    options:0
                                      range:NSMakeRange(0, line.length)
                                 usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
        [attributedString addAttribute:NSForegroundColorAttributeName
                                 value:[UIColor systemPurpleColor]
                                 range:match.range];
        [attributedString addAttribute:NSFontAttributeName
                                 value:[UIFont boldSystemFontOfSize:14]
                                 range:match.range];
    }];

    return attributedString;
}

- (void)updateStatusLabel {
    NSInteger totalLines = self.pointerLines.count;
    NSInteger filteredLines = self.isFiltered ? self.filteredLines.count : totalLines;

    NSString *statusText;
    if (self.isFiltered) {
        statusText = [NSString stringWithFormat:@"显示 %ld / %ld 条指针链", (long)filteredLines, (long)totalLines];
    } else {
        statusText = [NSString stringWithFormat:@"共 %ld 条指针链", (long)totalLines];
    }

    if (self.hasUnsavedChanges) {
        statusText = [statusText stringByAppendingString:@" • 未保存"];
    }

    self.statusLabel.text = statusText;
}

#pragma mark - 过滤功能

- (void)filterChanged:(UISegmentedControl *)sender {
    NSInteger selectedIndex = sender.selectedSegmentIndex;

    switch (selectedIndex) {
        case 0: // 全部
            self.isFiltered = NO;
            self.filteredLines = [self.pointerLines mutableCopy];
            break;
        case 1: // 有效指针
            [self filterValidPointers];
            break;
        case 2: // 无效指针
            [self filterInvalidPointers];
            break;
        case 3: // 包含偏移
            [self filterPointersWithOffsets];
            break;
    }

    [self updateTextView];
    [self updateStatusLabel];
}

- (void)filterValidPointers {
    self.isFiltered = YES;
    self.filteredLines = [NSMutableArray array];

    for (NSString *line in self.pointerLines) {
        // 简单验证：包含基址和至少一个偏移
        if ([line containsString:@"wp"] && [line containsString:@"0x"]) {
            [self.filteredLines addObject:line];
        }
    }
}

- (void)filterInvalidPointers {
    self.isFiltered = YES;
    self.filteredLines = [NSMutableArray array];

    for (NSString *line in self.pointerLines) {
        // 简单验证：不包含基址或偏移
        if (![line containsString:@"wp"] || ![line containsString:@"0x"]) {
            [self.filteredLines addObject:line];
        }
    }
}

- (void)filterPointersWithOffsets {
    self.isFiltered = YES;
    self.filteredLines = [NSMutableArray array];

    for (NSString *line in self.pointerLines) {
        // 计算偏移数量
        NSInteger offsetCount = [[line componentsSeparatedByString:@"0x"] count] - 1;
        if (offsetCount > 1) { // 至少2个偏移
            [self.filteredLines addObject:line];
        }
    }
}

#pragma mark - 搜索功能

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        self.isFiltered = NO;
        self.filteredLines = [self.pointerLines mutableCopy];
    } else {
        [self performSearchWithText:searchText];
    }

    [self updateTextView];
    [self updateStatusLabel];
}

- (void)performSearchWithText:(NSString *)searchText {
    self.isFiltered = YES;
    self.filteredLines = [NSMutableArray array];

    NSString *lowercaseSearch = [searchText lowercaseString];

    for (NSString *line in self.pointerLines) {
        NSString *lowercaseLine = [line lowercaseString];
        if ([lowercaseLine containsString:lowercaseSearch]) {
            [self.filteredLines addObject:line];
        }
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - 文本编辑

- (void)textViewDidChange:(UITextView *)textView {
    self.hasUnsavedChanges = YES;
    [self updateStatusLabel];

    // 实时解析文本内容
    [self parseTextViewContent];
}

- (void)parseTextViewContent {
    NSString *currentText = self.textView.text;
    NSArray *lines = [currentText componentsSeparatedByString:@"\n"];

    self.pointerLines = [NSMutableArray array];

    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmedLine.length > 0) {
            [self.pointerLines addObject:trimmedLine];
        }
    }

    if (!self.isFiltered) {
        self.filteredLines = [self.pointerLines mutableCopy];
    }
}

#pragma mark - 工具栏操作

- (void)undoAction {
    [self.textView.undoManager undo];
}

- (void)redoAction {
    [self.textView.undoManager redo];
}

- (void)formatText {
    NSMutableString *formattedText = [NSMutableString string];

    for (NSInteger i = 0; i < self.pointerLines.count; i++) {
        NSString *line = self.pointerLines[i];

        // 移除现有序号
        NSRange dotRange = [line rangeOfString:@". "];
        if (dotRange.location != NSNotFound) {
            line = [line substringFromIndex:dotRange.location + dotRange.length];
        }

        // 添加新序号
        [formattedText appendFormat:@"%ld. %@", (long)(i + 1), line];

        if (i < self.pointerLines.count - 1) {
            [formattedText appendString:@"\n"];
        }
    }

    self.textView.text = formattedText;
    [self textViewDidChange:self.textView];
    [self updateTextView]; // 重新应用高亮

    [self showToast:@"格式化完成"];
}

- (void)validatePointers {
    NSMutableArray *invalidLines = [NSMutableArray array];

    for (NSInteger i = 0; i < self.pointerLines.count; i++) {
        NSString *line = self.pointerLines[i];

        // 基本验证规则
        BOOL hasBase = [line containsString:@"wp"];
        BOOL hasOffset = [line containsString:@"0x"];
        BOOL hasValidFormat = [line containsString:@"+"] || [line containsString:@"-"];

        if (!hasBase || !hasOffset || !hasValidFormat) {
            [invalidLines addObject:@(i + 1)];
        }
    }

    if (invalidLines.count == 0) {
        [self showAlert:@"验证结果" message:@"所有指针链格式正确！"];
    } else {
        NSString *invalidLinesStr = [[invalidLines valueForKey:@"stringValue"] componentsJoinedByString:@", "];
        NSString *message = [NSString stringWithFormat:@"发现 %lu 个格式错误的指针链：\n行号: %@",
                           (unsigned long)invalidLines.count, invalidLinesStr];
        [self showAlert:@"验证结果" message:message];
    }
}

#pragma mark - 保存和取消

- (void)saveFile {
    if (!self.hasUnsavedChanges) {
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    // 生成保存内容
    NSMutableString *saveContent = [NSMutableString string];

    // 添加头部信息
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"MM-dd HH:mm";
    NSString *timeString = [formatter stringFromDate:[NSDate date]];

    [saveContent appendFormat:@"Obsolete修改器 %@\n", timeString];
    [saveContent appendFormat:@"共%lu条指针链\n\n", (unsigned long)self.pointerLines.count];

    // 添加指针链
    for (NSInteger i = 0; i < self.pointerLines.count; i++) {
        NSString *line = self.pointerLines[i];

        // 确保有序号
        if (![line hasPrefix:[NSString stringWithFormat:@"%ld. ", (long)(i + 1)]]) {
            // 移除现有序号
            NSRange dotRange = [line rangeOfString:@". "];
            if (dotRange.location != NSNotFound) {
                line = [line substringFromIndex:dotRange.location + dotRange.length];
            }
            line = [NSString stringWithFormat:@"%ld. %@", (long)(i + 1), line];
        }

        [saveContent appendFormat:@"%@\n", line];
        [saveContent appendString:@"   (数值待更新)\n\n"];
    }

    // 写入文件
    NSError *error;
    BOOL success = [saveContent writeToFile:self.filePath
                                 atomically:YES
                                   encoding:NSUTF8StringEncoding
                                      error:&error];

    if (success) {
        self.hasUnsavedChanges = NO;
        [self updateStatusLabel];
        [self showToast:@"保存成功"];

        // 通知代理
        if ([self.delegate respondsToSelector:@selector(pointerFileDidSave:)]) {
            [self.delegate pointerFileDidSave:self.filePath];
        }

        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self showAlert:@"保存失败" message:error.localizedDescription];
    }
}

- (void)cancelEdit {
    if (self.hasUnsavedChanges) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"未保存的更改"
                                                                       message:@"您有未保存的更改，确定要退出吗？"
                                                                preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *discardAction = [UIAlertAction actionWithTitle:@"放弃更改"
                                                                style:UIAlertActionStyleDestructive
                                                              handler:^(UIAlertAction * _Nonnull action) {
            [self dismissViewControllerAnimated:YES completion:nil];
        }];

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"继续编辑"
                                                               style:UIAlertActionStyleCancel
                                                             handler:nil];

        [alert addAction:discardAction];
        [alert addAction:cancelAction];

        [self presentViewController:alert animated:YES completion:nil];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - 辅助方法

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

- (void)showToast:(NSString *)message {
    UIAlertController *toast = [UIAlertController alertControllerWithTitle:nil
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [self presentViewController:toast animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [toast dismissViewControllerAnimated:YES completion:nil];
        });
    }];
}

@end
