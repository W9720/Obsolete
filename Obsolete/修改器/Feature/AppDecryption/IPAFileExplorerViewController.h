//
//  IPAFileExplorerViewController.h
//  Obsolete
//
//  Created by Assistant on 2024/01/16.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface IPAFileExplorerViewController : UIViewController

- (instancetype)initWithRootPath:(NSString *)rootPath fileName:(NSString *)fileName;
- (BOOL)isExecutableOrDylib:(NSString *)filePath;

@end

NS_ASSUME_NONNULL_END
