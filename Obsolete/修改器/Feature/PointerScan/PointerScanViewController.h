//
//  PointerScanViewController.h
//  指针扫描界面控制器
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PointerScanViewController : UIViewController

// 使用目标地址初始化
- (instancetype)initWithTargetAddress:(NSString *)targetAddress;

@end

NS_ASSUME_NONNULL_END
