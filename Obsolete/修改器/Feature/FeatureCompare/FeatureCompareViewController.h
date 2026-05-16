#import <UIKit/UIKit.h>
#import "VMTypeHeader.h"

@interface FeatureCompareViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *scanButton;
@property (nonatomic, strong) UIButton *compareButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UITextField *addressTextField;
@property (nonatomic, strong) UISegmentedControl *typeSegment;
@property (nonatomic, strong) UISegmentedControl *rangeSegment;
@property (nonatomic, strong) UILabel *rangeValueLabel;

// 扫描结果
@property (nonatomic, strong) NSArray *firstScanResults;
@property (nonatomic, strong) NSArray *secondScanResults;
@property (nonatomic, strong) NSMutableArray *featureResults;

// 扫描配置
@property (nonatomic, assign) NSInteger scanRange;
@property (nonatomic, assign) VMMemValueType valueType;

// 数据持久化
@property (nonatomic, strong) NSString *sessionId; // 会话ID，用于数据持久化

// 初始化方法
- (instancetype)initWithAddresses:(NSArray *)addresses valueType:(VMMemValueType)valueType;

// 数据管理方法
- (void)saveSessionData;
- (void)loadSessionData;
- (void)clearSessionData;
- (void)exportResults;

@end
