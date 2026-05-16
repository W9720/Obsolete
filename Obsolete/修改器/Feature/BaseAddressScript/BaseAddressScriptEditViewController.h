//
//  BaseAddressScriptEditViewController.h
//  基址脚本编辑界面
//

#import <UIKit/UIKit.h>
#import "BaseAddressScript.h"

NS_ASSUME_NONNULL_BEGIN

@interface BaseAddressScriptEditViewController : UIViewController

@property (nonatomic, strong) BaseAddressScript *script;

- (instancetype)initWithScript:(BaseAddressScript *)script;

@end

NS_ASSUME_NONNULL_END
