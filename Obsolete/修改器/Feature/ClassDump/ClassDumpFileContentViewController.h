//
//  ClassDumpFileContentViewController.h
//  Modifier
//
//  Created by AI Assistant on 2024/8/13.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ClassDumpFileContentViewController;

@protocol ClassDumpFileContentViewControllerDelegate <NSObject>
@optional
- (void)fileContentViewController:(ClassDumpFileContentViewController *)controller didGenerateHookFile:(NSString *)hookFilePath;
@end

@interface ClassDumpFileContentViewController : UIViewController

@property (nonatomic, weak) id<ClassDumpFileContentViewControllerDelegate> delegate;

- (instancetype)initWithFilePath:(NSString *)filePath;

@end

NS_ASSUME_NONNULL_END
