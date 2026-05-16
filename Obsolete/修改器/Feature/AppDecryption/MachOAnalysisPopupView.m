//
//  MachOAnalysisPopupView.m
//  Obsolete
//
//  Created by Assistant on 2024/01/16.
//

#import "MachOAnalysisPopupView.h"

@interface MachOAnalysisPopupView () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *footerView;
@property (nonatomic, strong) NSArray *dependencies;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, assign) long long fileSize;
@property (nonatomic, weak) UIViewController *parentController;

@end

@implementation MachOAnalysisPopupView

+ (void)showWithFileName:(NSString *)fileName
                fileSize:(long long)fileSize
            dependencies:(NSArray *)dependencies
          fromController:(UIViewController *)controller {
    
    MachOAnalysisPopupView *popup = [[MachOAnalysisPopupView alloc] initWithFrame:controller.view.bounds];
    popup.fileName = fileName;
    popup.fileSize = fileSize;
    popup.dependencies = dependencies;
    popup.parentController = controller;
    
    [popup setupUI];
    [controller.view addSubview:popup];
    [popup showWithAnimation];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.0];
    }
    return self;
}

- (void)setupUI {
    [self setupContainerView];
    [self setupHeaderView];
    [self setupTableView];
    [self setupFooterView];
    [self setupConstraints];
}

- (void)setupContainerView {
    self.containerView = [[UIView alloc] init];
    self.containerView.backgroundColor = [UIColor systemBackgroundColor];
    self.containerView.layer.cornerRadius = 16;
    self.containerView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.containerView.layer.shadowOffset = CGSizeMake(0, 8);
    self.containerView.layer.shadowRadius = 24;
    self.containerView.layer.shadowOpacity = 0.15;
    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 初始变换用于动画
    self.containerView.transform = CGAffineTransformMakeScale(0.8, 0.8);
    self.containerView.alpha = 0.0;
    
    [self addSubview:self.containerView];
}

- (void)setupHeaderView {
    self.headerView = [[UIView alloc] init];
    self.headerView.backgroundColor = [UIColor systemBlueColor];
    self.headerView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 文件图标
    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.image = [UIImage systemImageNamed:@"terminal.fill"];
    iconView.tintColor = [UIColor whiteColor];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 标题标签
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Mach-O 分析结果";
    titleLabel.font = [UIFont boldSystemFontOfSize:20];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 文件名标签
    UILabel *fileNameLabel = [[UILabel alloc] init];
    fileNameLabel.text = self.fileName;
    fileNameLabel.font = [UIFont systemFontOfSize:16];
    fileNameLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.9];
    fileNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 文件信息标签
    UILabel *infoLabel = [[UILabel alloc] init];
    infoLabel.text = [NSString stringWithFormat:@"大小: %@ • 类型: Mach-O", [self formatFileSize:self.fileSize]];
    infoLabel.font = [UIFont systemFontOfSize:14];
    infoLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
    infoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 关闭按钮
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [closeButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    closeButton.tintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [closeButton addTarget:self action:@selector(closeButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    [self.headerView addSubview:iconView];
    [self.headerView addSubview:titleLabel];
    [self.headerView addSubview:fileNameLabel];
    [self.headerView addSubview:infoLabel];
    [self.headerView addSubview:closeButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [iconView.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor constant:20],
        [iconView.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:32],
        [iconView.heightAnchor constraintEqualToConstant:32],
        
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:12],
        [titleLabel.topAnchor constraintEqualToAnchor:self.headerView.topAnchor constant:16],
        
        [fileNameLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [fileNameLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
        
        [infoLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [infoLabel.topAnchor constraintEqualToAnchor:fileNameLabel.bottomAnchor constant:2],
        [infoLabel.bottomAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:-16],
        
        [closeButton.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor constant:-16],
        [closeButton.topAnchor constraintEqualToAnchor:self.headerView.topAnchor constant:16],
        [closeButton.widthAnchor constraintEqualToConstant:28],
        [closeButton.heightAnchor constraintEqualToConstant:28],
        
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:closeButton.leadingAnchor constant:-12],
        [fileNameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:closeButton.leadingAnchor constant:-12],
        [infoLabel.trailingAnchor constraintLessThanOrEqualToAnchor:closeButton.leadingAnchor constant:-12]
    ]];
    
    [self.containerView addSubview:self.headerView];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [UIColor systemBackgroundColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.containerView addSubview:self.tableView];
}

- (void)setupFooterView {
    self.footerView = [[UIView alloc] init];
    self.footerView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.footerView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 统计标签
    UILabel *countLabel = [[UILabel alloc] init];
    if (self.dependencies.count > 0) {
        countLabel.text = [NSString stringWithFormat:@"共找到 %lu 个依赖库", (unsigned long)self.dependencies.count];
    } else {
        countLabel.text = @"未找到依赖库信息";
    }
    countLabel.font = [UIFont systemFontOfSize:14];
    countLabel.textColor = [UIColor secondaryLabelColor];
    countLabel.textAlignment = NSTextAlignmentCenter;
    countLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 复制按钮
    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [copyButton setTitle:@"复制" forState:UIControlStateNormal];
    [copyButton setImage:[UIImage systemImageNamed:@"doc.on.doc"] forState:UIControlStateNormal];
    copyButton.backgroundColor = [UIColor systemBlueColor];
    copyButton.tintColor = [UIColor whiteColor];
    copyButton.layer.cornerRadius = 8;
    copyButton.translatesAutoresizingMaskIntoConstraints = NO;
    [copyButton addTarget:self action:@selector(copyButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    // 确定按钮
    UIButton *okButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [okButton setTitle:@"确定" forState:UIControlStateNormal];
    okButton.backgroundColor = [UIColor systemGrayColor];
    okButton.tintColor = [UIColor whiteColor];
    okButton.layer.cornerRadius = 8;
    okButton.translatesAutoresizingMaskIntoConstraints = NO;
    [okButton addTarget:self action:@selector(closeButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    [self.footerView addSubview:countLabel];
    [self.footerView addSubview:copyButton];
    [self.footerView addSubview:okButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [countLabel.topAnchor constraintEqualToAnchor:self.footerView.topAnchor constant:12],
        [countLabel.leadingAnchor constraintEqualToAnchor:self.footerView.leadingAnchor constant:20],
        [countLabel.trailingAnchor constraintEqualToAnchor:self.footerView.trailingAnchor constant:-20],
        
        [copyButton.topAnchor constraintEqualToAnchor:countLabel.bottomAnchor constant:16],
        [copyButton.leadingAnchor constraintEqualToAnchor:self.footerView.leadingAnchor constant:20],
        [copyButton.heightAnchor constraintEqualToConstant:44],
        
        [okButton.topAnchor constraintEqualToAnchor:copyButton.topAnchor],
        [okButton.leadingAnchor constraintEqualToAnchor:copyButton.trailingAnchor constant:12],
        [okButton.trailingAnchor constraintEqualToAnchor:self.footerView.trailingAnchor constant:-20],
        [okButton.heightAnchor constraintEqualToConstant:44],
        [okButton.widthAnchor constraintEqualToAnchor:copyButton.widthAnchor],
        
        [okButton.bottomAnchor constraintEqualToAnchor:self.footerView.bottomAnchor constant:-20]
    ]];
    
    [self.containerView addSubview:self.footerView];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        [self.containerView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.containerView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.containerView.widthAnchor constraintEqualToConstant:340],
        [self.containerView.heightAnchor constraintEqualToConstant:500],
        
        [self.headerView.topAnchor constraintEqualToAnchor:self.containerView.topAnchor],
        [self.headerView.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor],
        [self.headerView.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor],
        
        [self.tableView.topAnchor constraintEqualToAnchor:self.headerView.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.footerView.topAnchor],
        
        [self.footerView.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor],
        [self.footerView.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor],
        [self.footerView.bottomAnchor constraintEqualToAnchor:self.containerView.bottomAnchor]
    ]];
    
    // 设置圆角
    self.headerView.layer.cornerRadius = 16;
    self.headerView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    
    self.footerView.layer.cornerRadius = 16;
    self.footerView.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
}

#pragma mark - Actions

- (void)closeButtonTapped {
    [self hideWithAnimation];
}

- (void)copyButtonTapped {
    NSMutableString *content = [NSMutableString string];
    [content appendFormat:@"文件: %@\n", self.fileName];
    [content appendFormat:@"大小: %@\n", [self formatFileSize:self.fileSize]];
    [content appendFormat:@"类型: Mach-O 可执行文件/库\n\n"];
    
    if (self.dependencies.count > 0) {
        [content appendString:@"依赖库信息:\n"];
        [content appendString:@"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"];
        
        for (NSDictionary *dep in self.dependencies) {
            NSString *type = dep[@"type"];
            NSString *name = dep[@"name"];
            NSString *version = dep[@"version"];
            
            [content appendFormat:@"%@\n", type];
            [content appendFormat:@"   %@\n", name];
            [content appendFormat:@"   版本: %@\n\n", version];
        }
        
        [content appendString:@"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"];
        [content appendFormat:@"共找到 %lu 个依赖库", (unsigned long)self.dependencies.count];
    } else {
        [content appendString:@"未找到依赖库信息"];
    }
    
    UIPasteboard.generalPasteboard.string = content;
    
    // 显示复制成功提示
    [self showCopySuccessHint];
}

- (void)showCopySuccessHint {
    UILabel *hintLabel = [[UILabel alloc] init];
    hintLabel.text = @"已复制到剪贴板";
    hintLabel.font = [UIFont systemFontOfSize:14];
    hintLabel.textColor = [UIColor whiteColor];
    hintLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    hintLabel.textAlignment = NSTextAlignmentCenter;
    hintLabel.layer.cornerRadius = 8;
    hintLabel.clipsToBounds = YES;
    hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    hintLabel.alpha = 0.0;
    
    [self addSubview:hintLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [hintLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [hintLabel.bottomAnchor constraintEqualToAnchor:self.containerView.topAnchor constant:-20],
        [hintLabel.widthAnchor constraintEqualToConstant:120],
        [hintLabel.heightAnchor constraintEqualToConstant:32]
    ]];
    
    [UIView animateWithDuration:0.3 animations:^{
        hintLabel.alpha = 1.0;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.3 delay:1.0 options:0 animations:^{
            hintLabel.alpha = 0.0;
        } completion:^(BOOL finished) {
            [hintLabel removeFromSuperview];
        }];
    }];
}

#pragma mark - Animation

- (void)showWithAnimation {
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:0 animations:^{
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        self.containerView.transform = CGAffineTransformIdentity;
        self.containerView.alpha = 1.0;
    } completion:nil];
}

- (void)hideWithAnimation {
    [UIView animateWithDuration:0.25 animations:^{
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.0];
        self.containerView.transform = CGAffineTransformMakeScale(0.8, 0.8);
        self.containerView.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dependencies.count > 0 ? self.dependencies.count : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"DependencyCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    if (self.dependencies.count == 0) {
        cell.textLabel.text = @"未找到依赖库";
        cell.detailTextLabel.text = @"该文件没有外部依赖库";
        cell.imageView.image = [UIImage systemImageNamed:@"info.circle"];
        cell.imageView.tintColor = [UIColor systemGrayColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        NSDictionary *dependency = self.dependencies[indexPath.row];
        NSString *type = dependency[@"type"];
        NSString *name = dependency[@"name"];
        NSString *version = dependency[@"version"];
        
        cell.textLabel.text = name;
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • 版本: %@", type, version];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        
        // 根据类型设置不同图标
        if ([type isEqualToString:@"LC_LOAD_WEAK_DYLIB"]) {
            cell.imageView.image = [UIImage systemImageNamed:@"exclamationmark.triangle.fill"];
            cell.imageView.tintColor = [UIColor systemOrangeColor];
        } else {
            cell.imageView.image = [UIImage systemImageNamed:@"gear.circle.fill"];
            cell.imageView.tintColor = [UIColor systemBlueColor];
        }
        
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    
    return cell;
}

#pragma mark - Helper Methods

- (NSString *)formatFileSize:(long long)size {
    if (size < 1024) {
        return [NSString stringWithFormat:@"%lld B", size];
    } else if (size < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f KB", size / 1024.0];
    } else if (size < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f MB", size / (1024.0 * 1024.0)];
    } else {
        return [NSString stringWithFormat:@"%.1f GB", size / (1024.0 * 1024.0 * 1024.0)];
    }
}

@end
