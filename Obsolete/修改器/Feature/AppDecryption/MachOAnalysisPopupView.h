//
//  MachOAnalysisPopupView.h
//  Obsolete
//
//  Created by Assistant on 2024/01/16.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MachOAnalysisPopupView : UIView

+ (void)showWithFileName:(NSString *)fileName
                fileSize:(long long)fileSize
            dependencies:(NSArray *)dependencies
          fromController:(UIViewController *)controller;

@end

NS_ASSUME_NONNULL_END
