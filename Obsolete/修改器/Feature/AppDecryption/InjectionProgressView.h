//
//  InjectionProgressView.h
//  Obsolete
//
//  Created by Assistant on 2024/01/16.
//  自定义注入进度弹窗视图
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class InjectionProgressView;

@protocol InjectionProgressViewDelegate <NSObject>
- (void)injectionProgressViewDidCancel:(InjectionProgressView *)progressView;
@end

@interface InjectionProgressView : UIView

@property (nonatomic, weak) id<InjectionProgressViewDelegate> delegate;

- (void)showInView:(UIView *)parentView;
- (void)dismiss;
- (void)updateProgress:(float)progress status:(NSString *)status;

@end

NS_ASSUME_NONNULL_END
