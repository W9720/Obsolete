//
//  BaseAddressScriptViewController.h
//  基址脚本管理器
//

#import <UIKit/UIKit.h>
#import "BaseAddressScript.h"

NS_ASSUME_NONNULL_BEGIN

@interface BaseAddressScriptViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISegmentedControl *categorySegmentControl;
@property (nonatomic, strong) UIBarButtonItem *addButton;
@property (nonatomic, strong) UIBarButtonItem *moreButton;

// 临时作者信息（用于批量导出）
@property (nonatomic, strong, nullable) NSString *tempAuthorName;
@property (nonatomic, strong, nullable) NSString *tempAuthorDescription;

@end

NS_ASSUME_NONNULL_END
