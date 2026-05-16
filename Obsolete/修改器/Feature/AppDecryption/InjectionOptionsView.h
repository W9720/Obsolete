//
//  InjectionOptionsView.h
//  Obsolete
//
//  Created by Assistant on 2024/01/16.
//  自定义注入选项弹窗视图
//

#import <UIKit/UIKit.h>
#import "DylibInjector.h"

NS_ASSUME_NONNULL_BEGIN

@class InjectionOptionsView;

@protocol InjectionOptionsViewDelegate <NSObject>
- (void)injectionOptionsView:(InjectionOptionsView *)optionsView 
           didConfirmWithType:(DylibInjectType)injectType 
            frameworkLocation:(FrameworkLocationType)frameworkLocation;
- (void)injectionOptionsViewDidCancel:(InjectionOptionsView *)optionsView;
@end

@interface InjectionOptionsView : UIView

@property (nonatomic, weak) id<InjectionOptionsViewDelegate> delegate;

- (instancetype)initWithFileName:(NSString *)fileName dylibName:(NSString *)dylibName;
- (void)showInView:(UIView *)parentView;
- (void)dismiss;

@end

NS_ASSUME_NONNULL_END
