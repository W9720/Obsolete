//
//  PidModel.h
//  修改器
//
//  Created by AI Assistant on 2025-01-08.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PidModel : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *pid;
@property (nonatomic, copy) NSString *bundleIdentifier;
@property (nonatomic, assign) NSInteger pidValue; // 用于排序的数值型PID
@property (nonatomic, strong) UIImage *appIcon; // 应用真实图标
@end

NS_ASSUME_NONNULL_END
