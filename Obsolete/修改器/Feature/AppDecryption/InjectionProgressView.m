//
//  InjectionProgressView.m
//  Obsolete
//
//  Created by Assistant on 2024/01/16.
//  自定义注入进度弹窗视图
//

#import "InjectionProgressView.h"

@interface InjectionProgressView ()

@property (nonatomic, strong) UIView *backgroundView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *progressContainer;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *percentLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

@end

@implementation InjectionProgressView

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.frame = [UIScreen mainScreen].bounds;
    self.backgroundColor = [UIColor clearColor];
    
    // 背景遮罩
    self.backgroundView = [[UIView alloc] init];
    self.backgroundView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    self.backgroundView.frame = self.bounds;
    [self addSubview:self.backgroundView];

    // 内容视图
    self.contentView = [[UIView alloc] init];

    // 根据当前界面风格设置背景色
    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            // 深色模式：使用更亮的背景色
            self.contentView.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0];
        } else {
            // 浅色模式：使用系统背景色
            self.contentView.backgroundColor = [UIColor systemBackgroundColor];
        }
    } else {
        self.contentView.backgroundColor = [UIColor whiteColor];
    }

    self.contentView.layer.cornerRadius = 16;
    self.contentView.layer.borderWidth = 1.0;

    // 根据界面风格设置边框色
    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            self.contentView.layer.borderColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0].CGColor;
        } else {
            self.contentView.layer.borderColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0].CGColor;
        }
    } else {
        self.contentView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    }

    // 阴影效果
    self.contentView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.contentView.layer.shadowOffset = CGSizeMake(0, 8);
    self.contentView.layer.shadowRadius = 20;
    self.contentView.layer.shadowOpacity = 0.3;
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.contentView];
    
    [self setupContentView];
    [self setupConstraints];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];

    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) {
            [self updateAppearanceForCurrentStyle];
        }
    }
}

- (void)updateAppearanceForCurrentStyle {
    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            // 深色模式
            self.contentView.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0];
            self.contentView.layer.borderColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0].CGColor;
            self.progressContainer.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:1.0];
        } else {
            // 浅色模式
            self.contentView.backgroundColor = [UIColor systemBackgroundColor];
            self.contentView.layer.borderColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0].CGColor;
            self.progressContainer.backgroundColor = [UIColor secondarySystemBackgroundColor];
        }
    }
}

- (void)setupContentView {
    // 标题
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"正在注入动态库";
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:titleLabel];
    
    // 活动指示器
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.activityIndicator startAnimating];
    [self.contentView addSubview:self.activityIndicator];
    
    // 进度条容器
    self.progressContainer = [[UIView alloc] init];

    // 根据界面风格设置进度容器背景色
    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            self.progressContainer.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:1.0];
        } else {
            self.progressContainer.backgroundColor = [UIColor secondarySystemBackgroundColor];
        }
    } else {
        self.progressContainer.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
    }

    self.progressContainer.layer.cornerRadius = 12;
    self.progressContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.progressContainer];
    
    // 进度条
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.progressTintColor = [UIColor systemBlueColor];
    self.progressView.trackTintColor = [UIColor systemGray5Color];
    self.progressView.layer.cornerRadius = 2;
    self.progressView.clipsToBounds = YES;
    self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.progressContainer addSubview:self.progressView];
    
    // 进度百分比标签
    self.percentLabel = [[UILabel alloc] init];
    self.percentLabel.text = @"0%";
    self.percentLabel.font = [UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightMedium];
    self.percentLabel.textAlignment = NSTextAlignmentCenter;
    self.percentLabel.textColor = [UIColor systemBlueColor];
    self.percentLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.progressContainer addSubview:self.percentLabel];
    
    // 状态标签
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"准备开始...";
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.textColor = [UIColor secondaryLabelColor];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.statusLabel];
    
    // 取消按钮
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    cancelButton.backgroundColor = [UIColor systemRedColor];
    [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    cancelButton.titleLabel.font = [UIFont systemFontOfSize:16];
    cancelButton.layer.cornerRadius = 8;
    cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [cancelButton addTarget:self action:@selector(cancelButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:cancelButton];
    
    // 进度容器约束
    [NSLayoutConstraint activateConstraints:@[
        [self.progressView.leadingAnchor constraintEqualToAnchor:self.progressContainer.leadingAnchor constant:16],
        [self.progressView.trailingAnchor constraintEqualToAnchor:self.progressContainer.trailingAnchor constant:-16],
        [self.progressView.topAnchor constraintEqualToAnchor:self.progressContainer.topAnchor constant:16],
        [self.progressView.heightAnchor constraintEqualToConstant:4],

        [self.percentLabel.topAnchor constraintEqualToAnchor:self.progressView.bottomAnchor constant:12],
        [self.percentLabel.centerXAnchor constraintEqualToAnchor:self.progressContainer.centerXAnchor],
        [self.percentLabel.bottomAnchor constraintEqualToAnchor:self.progressContainer.bottomAnchor constant:-16]
    ]];
    
    // 主要约束
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:24],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        
        [self.activityIndicator.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:20],
        [self.activityIndicator.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        
        [self.progressContainer.topAnchor constraintEqualToAnchor:self.activityIndicator.bottomAnchor constant:20],
        [self.progressContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.progressContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],

        [self.statusLabel.topAnchor constraintEqualToAnchor:self.progressContainer.bottomAnchor constant:20],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        
        [cancelButton.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:24],
        [cancelButton.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [cancelButton.widthAnchor constraintEqualToConstant:100],
        [cancelButton.heightAnchor constraintEqualToConstant:40],
        [cancelButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-24]
    ]];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        [self.contentView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.contentView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.contentView.widthAnchor constraintEqualToConstant:320]
    ]];
}

#pragma mark - Public Methods

- (void)showInView:(UIView *)parentView {
    [parentView addSubview:self];
    
    // 初始状态
    self.alpha = 0;
    self.contentView.transform = CGAffineTransformMakeScale(0.8, 0.8);
    
    // 动画显示
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.alpha = 1;
        self.contentView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)dismiss {
    [UIView animateWithDuration:0.25 animations:^{
        self.alpha = 0;
        self.contentView.transform = CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

- (void)updateProgress:(float)progress status:(NSString *)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.progressView setProgress:progress animated:YES];
        self.percentLabel.text = [NSString stringWithFormat:@"%.0f%%", progress * 100];
        self.statusLabel.text = status;
        
        // 当进度达到100%时，停止活动指示器
        if (progress >= 1.0) {
            [self.activityIndicator stopAnimating];
        }
    });
}

#pragma mark - Actions

- (void)cancelButtonTapped {
    if ([self.delegate respondsToSelector:@selector(injectionProgressViewDidCancel:)]) {
        [self.delegate injectionProgressViewDidCancel:self];
    }
}

@end
