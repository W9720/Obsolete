//
//  AppSearchViewController.h
//  修改器
//
//  Created by MacXK on 2025/8/6.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AppSearchViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>

@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

// 数据属性
@property (nonatomic, strong) NSMutableArray *searchResults;
@property (nonatomic, strong) NSMutableDictionary *searchCache;
@property (nonatomic, strong) NSMutableArray *offerNames;

// 弹窗相关
@property (nonatomic, strong) UITableView *offerNamesTableView;
@property (nonatomic, strong) NSString *currentSelectedText;

@end

NS_ASSUME_NONNULL_END
