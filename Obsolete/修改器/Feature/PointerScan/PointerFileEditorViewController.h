//
//  PointerFileEditorViewController.h
//  Modifier
//
//  Created by Augment Agent on 2024/12/25.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol PointerFileEditorDelegate <NSObject>
- (void)pointerFileDidSave:(NSString *)filePath;
@end

@interface PointerFileEditorViewController : UIViewController

@property (nonatomic, weak) id<PointerFileEditorDelegate> delegate;

// 初始化方法
- (instancetype)initWithFilePath:(NSString *)filePath;

@end

NS_ASSUME_NONNULL_END
