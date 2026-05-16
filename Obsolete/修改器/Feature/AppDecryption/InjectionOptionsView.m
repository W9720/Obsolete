//
//  InjectionOptionsView.m
//  Obsolete
//
//  Created by Assistant on 2024/01/16.
//  自定义注入选项弹窗视图
//

#import "InjectionOptionsView.h"

@interface InjectionOptionsView ()

@property (nonatomic, strong) UIView *backgroundView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *fileInfoContainer;
@property (nonatomic, strong) UISegmentedControl *injectTypeControl;
@property (nonatomic, strong) UISegmentedControl *locationControl;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *dylibName;

@end

@implementation InjectionOptionsView

- (instancetype)initWithFileName:(NSString *)fileName dylibName:(NSString *)dylibName {
    self = [super init];
    if (self) {
        _fileName = fileName;
        _dylibName = dylibName;
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.frame = [UIScreen mainScreen].bounds;
    self.backgroundColor = [UIColor clearColor];
    
    // 背景遮罩
    self.backgroundView = [[UIView alloc] init];
    self.backgroundView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
    self.backgroundView.frame = self.bounds;
    [self addSubview:self.backgroundView];

    // 添加点击背景关闭手势
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped)];
    [self.backgroundView addGestureRecognizer:tapGesture];

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
            self.fileInfoContainer.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:1.0];
        } else {
            // 浅色模式
            self.contentView.backgroundColor = [UIColor systemBackgroundColor];
            self.contentView.layer.borderColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0].CGColor;
            self.fileInfoContainer.backgroundColor = [UIColor secondarySystemBackgroundColor];
        }
    }
}

- (void)setupContentView {
    // 标题
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"动态库注入配置";
    titleLabel.font = [UIFont boldSystemFontOfSize:20];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:titleLabel];
    
    // 文件信息容器
    self.fileInfoContainer = [[UIView alloc] init];

    // 根据界面风格设置文件信息容器背景色
    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            self.fileInfoContainer.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:1.0];
        } else {
            self.fileInfoContainer.backgroundColor = [UIColor secondarySystemBackgroundColor];
        }
    } else {
        self.fileInfoContainer.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
    }

    self.fileInfoContainer.layer.cornerRadius = 8;
    self.fileInfoContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.fileInfoContainer];
    
    // 目标文件信息
    UILabel *fileInfoLabel = [[UILabel alloc] init];
    fileInfoLabel.text = [NSString stringWithFormat:@"📱 目标文件: %@", self.fileName];
    fileInfoLabel.font = [UIFont systemFontOfSize:14];
    fileInfoLabel.textColor = [UIColor labelColor];
    fileInfoLabel.numberOfLines = 0;
    fileInfoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.fileInfoContainer addSubview:fileInfoLabel];
    
    // 注入库信息
    UILabel *dylibInfoLabel = [[UILabel alloc] init];
    dylibInfoLabel.text = [NSString stringWithFormat:@"🔧 注入库: %@", self.dylibName];
    dylibInfoLabel.font = [UIFont systemFontOfSize:14];
    dylibInfoLabel.textColor = [UIColor labelColor];
    dylibInfoLabel.numberOfLines = 0;
    dylibInfoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.fileInfoContainer addSubview:dylibInfoLabel];
    
    // 注入类型标题
    UILabel *injectTypeLabel = [[UILabel alloc] init];
    injectTypeLabel.text = @"注入类型";
    injectTypeLabel.font = [UIFont boldSystemFontOfSize:16];
    injectTypeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:injectTypeLabel];
    
    // 注入类型选择
    self.injectTypeControl = [[UISegmentedControl alloc] initWithItems:@[@"强依赖", @"弱依赖"]];
    self.injectTypeControl.selectedSegmentIndex = 0;
    self.injectTypeControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.injectTypeControl];
    
    // 安装位置标题
    UILabel *locationLabel = [[UILabel alloc] init];
    locationLabel.text = @"安装位置";
    locationLabel.font = [UIFont boldSystemFontOfSize:16];
    locationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:locationLabel];
    
    // 安装位置选择
    self.locationControl = [[UISegmentedControl alloc] initWithItems:@[@"Frameworks目录", @"应用根目录"]];
    self.locationControl.selectedSegmentIndex = 0;
    self.locationControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.locationControl];
    
    // 说明文字
    UILabel *descLabel = [[UILabel alloc] init];
    descLabel.text = @"💡 提示：\n• 强依赖：应用启动时必须加载\n• 弱依赖：可选加载，失败不影响启动\n• Frameworks目录：推荐位置，符合iOS规范";
    descLabel.font = [UIFont systemFontOfSize:12];
    descLabel.textColor = [UIColor tertiaryLabelColor];
    descLabel.numberOfLines = 0;
    descLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:descLabel];
    
    // 按钮容器
    UIView *buttonContainer = [[UIView alloc] init];
    buttonContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:buttonContainer];
    
    // 确认按钮
    UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [confirmButton setTitle:@"开始注入" forState:UIControlStateNormal];
    confirmButton.backgroundColor = [UIColor systemBlueColor];
    [confirmButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    confirmButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    confirmButton.layer.cornerRadius = 8;
    confirmButton.translatesAutoresizingMaskIntoConstraints = NO;
    [confirmButton addTarget:self action:@selector(confirmButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [buttonContainer addSubview:confirmButton];
    
    // 取消按钮
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    cancelButton.backgroundColor = [UIColor systemGrayColor];
    [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    cancelButton.titleLabel.font = [UIFont systemFontOfSize:16];
    cancelButton.layer.cornerRadius = 8;
    cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [cancelButton addTarget:self action:@selector(cancelButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [buttonContainer addSubview:cancelButton];
    
    // 文件信息容器约束
    [NSLayoutConstraint activateConstraints:@[
        [fileInfoLabel.topAnchor constraintEqualToAnchor:self.fileInfoContainer.topAnchor constant:12],
        [fileInfoLabel.leadingAnchor constraintEqualToAnchor:self.fileInfoContainer.leadingAnchor constant:12],
        [fileInfoLabel.trailingAnchor constraintEqualToAnchor:self.fileInfoContainer.trailingAnchor constant:-12],

        [dylibInfoLabel.topAnchor constraintEqualToAnchor:fileInfoLabel.bottomAnchor constant:8],
        [dylibInfoLabel.leadingAnchor constraintEqualToAnchor:self.fileInfoContainer.leadingAnchor constant:12],
        [dylibInfoLabel.trailingAnchor constraintEqualToAnchor:self.fileInfoContainer.trailingAnchor constant:-12],
        [dylibInfoLabel.bottomAnchor constraintEqualToAnchor:self.fileInfoContainer.bottomAnchor constant:-12]
    ]];
    
    // 按钮容器约束
    [NSLayoutConstraint activateConstraints:@[
        [confirmButton.leadingAnchor constraintEqualToAnchor:buttonContainer.leadingAnchor],
        [confirmButton.topAnchor constraintEqualToAnchor:buttonContainer.topAnchor],
        [confirmButton.bottomAnchor constraintEqualToAnchor:buttonContainer.bottomAnchor],
        [confirmButton.heightAnchor constraintEqualToConstant:44],
        
        [cancelButton.trailingAnchor constraintEqualToAnchor:buttonContainer.trailingAnchor],
        [cancelButton.topAnchor constraintEqualToAnchor:buttonContainer.topAnchor],
        [cancelButton.bottomAnchor constraintEqualToAnchor:buttonContainer.bottomAnchor],
        [cancelButton.heightAnchor constraintEqualToConstant:44],
        [cancelButton.widthAnchor constraintEqualToConstant:80],
        
        [cancelButton.leadingAnchor constraintEqualToAnchor:confirmButton.trailingAnchor constant:12]
    ]];
    
    // 主要约束
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:24],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        
        [self.fileInfoContainer.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:20],
        [self.fileInfoContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.fileInfoContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],

        [injectTypeLabel.topAnchor constraintEqualToAnchor:self.fileInfoContainer.bottomAnchor constant:24],
        [injectTypeLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [injectTypeLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        
        [self.injectTypeControl.topAnchor constraintEqualToAnchor:injectTypeLabel.bottomAnchor constant:8],
        [self.injectTypeControl.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.injectTypeControl.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        
        [locationLabel.topAnchor constraintEqualToAnchor:self.injectTypeControl.bottomAnchor constant:20],
        [locationLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [locationLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        
        [self.locationControl.topAnchor constraintEqualToAnchor:locationLabel.bottomAnchor constant:8],
        [self.locationControl.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.locationControl.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        
        [descLabel.topAnchor constraintEqualToAnchor:self.locationControl.bottomAnchor constant:20],
        [descLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [descLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        
        [buttonContainer.topAnchor constraintEqualToAnchor:descLabel.bottomAnchor constant:24],
        [buttonContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [buttonContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [buttonContainer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-24]
    ]];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        [self.contentView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.contentView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.contentView.widthAnchor constraintEqualToConstant:350],
        [self.contentView.heightAnchor constraintLessThanOrEqualToConstant:500]
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

#pragma mark - Actions

- (void)backgroundTapped {
    [self cancelButtonTapped];
}

- (void)confirmButtonTapped {
    DylibInjectType injectType = (DylibInjectType)self.injectTypeControl.selectedSegmentIndex;
    FrameworkLocationType frameworkLocation = (FrameworkLocationType)self.locationControl.selectedSegmentIndex;
    
    if ([self.delegate respondsToSelector:@selector(injectionOptionsView:didConfirmWithType:frameworkLocation:)]) {
        [self.delegate injectionOptionsView:self didConfirmWithType:injectType frameworkLocation:frameworkLocation];
    }
}

- (void)cancelButtonTapped {
    if ([self.delegate respondsToSelector:@selector(injectionOptionsViewDidCancel:)]) {
        [self.delegate injectionOptionsViewDidCancel:self];
    }
}

@end
