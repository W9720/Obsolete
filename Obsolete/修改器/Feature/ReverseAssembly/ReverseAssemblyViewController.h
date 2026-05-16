//
//  ReverseAssemblyViewController.h
//  Obsolete
//
//  Created by AI Assistant on 2025-01-08.
//

#import <UIKit/UIKit.h>
#import "../PointerScan/PointerScanManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface ReverseAssemblyViewController : UIViewController

// 文件选择相关（新功能）
@property (nonatomic, strong) NSString *selectedFilePath;

// 兼容性保留（已弃用）
@property (nonatomic, strong) ModuleInfo *selectedModule;
- (void)updateModuleButtonTitle;
- (void)loadDisassemblyForModule:(ModuleInfo *)module;

@end

NS_ASSUME_NONNULL_END
