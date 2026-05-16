#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface SearchViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

// 搜索结果总数（用于增量加载）
@property (nonatomic, assign) NSUInteger totalResultCount;

// 数值搜索相关方法声明
- (void)handleValueSearch;
- (void)showCustomSearchMemoryView;
- (void)typeSegmentControlChanged:(UISegmentedControl *)sender;
- (void)searchButtonTapped:(UIButton *)sender;
- (void)cancelButtonTapped:(UIButton *)sender;
- (BOOL)validateInput:(NSString *)input forType:(NSString *)type;
- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message;

// 模糊搜索相关方法声明
- (void)showFuzzySearchOptions;
- (void)showFuzzyCompareOptions;
- (void)firstFuzzySearchButtonTapped:(UIButton *)sender;
- (void)fuzzyCompareSearchButtonTapped:(UIButton *)sender;

@end 
