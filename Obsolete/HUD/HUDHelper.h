//
//  HUDHelper.h
//  HUDApp
//
//  Created by 李良林 on 2024/2/2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

OBJC_EXTERN BOOL IsHUDEnabled(void);
OBJC_EXTERN void SetHUDEnabled(BOOL isEnabled);

#if DEBUG
OBJC_EXTERN void SimulateMemoryPressure(void);
#endif

NS_ASSUME_NONNULL_END
