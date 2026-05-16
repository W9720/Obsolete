//
//  PointerChainEditViewController.h
//  指针链编辑界面
//

#import <UIKit/UIKit.h>
#import "BaseAddressScript.h"

NS_ASSUME_NONNULL_BEGIN

@interface PointerChainEditViewController : UIViewController

@property (nonatomic, strong) BaseAddressPointerChain *pointerChain;
@property (nonatomic, assign) BOOL isEncrypted;  // 是否为加密脚本

- (instancetype)initWithPointerChain:(BaseAddressPointerChain *)chain;
- (instancetype)initWithPointerChain:(BaseAddressPointerChain *)chain isEncrypted:(BOOL)isEncrypted;

@end

NS_ASSUME_NONNULL_END
