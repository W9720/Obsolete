#import <UIKit/UIKit.h>
#import "VMTypeHeader.h"

@interface MemoryBrowserViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITextField *addressTextField;
@property (nonatomic, strong) UISegmentedControl *dataTypeSegment;
@property (nonatomic, strong) NSString *baseAddress;
@property (nonatomic, strong) NSString *searchedAddress; // 当前搜索的地址，用于高亮显示
@property (nonatomic, strong) NSMutableArray *memoryData;
@property (nonatomic, assign) VMMemValueType currentValueType;

// 选择模式相关属性
@property (nonatomic, assign) BOOL isSelectionMode;
@property (nonatomic, strong) NSMutableArray *selectedAddresses;
@property (nonatomic, strong) UIBarButtonItem *selectButton;
@property (nonatomic, strong) UIBarButtonItem *calculateButton;
@property (nonatomic, strong) UIBarButtonItem *cancelButton;

// 初始化方法
- (instancetype)initWithAddress:(NSString *)address;

// 从搜索结果初始化
- (instancetype)initWithAddress:(NSString *)address valueType:(VMMemValueType)valueType;

// 读取内存数据
- (void)loadMemoryDataFromAddress:(NSString *)address withValueType:(VMMemValueType)valueType;

// 修改内存值
- (void)modifyMemoryValue:(NSString *)newValue atAddress:(NSString *)address withValueType:(VMMemValueType)valueType;

// 选择模式相关方法
- (void)toggleSelectionMode;
- (void)cancelSelectionMode;
- (void)calculateOffsetsBetweenSelectedAddresses;

@end 
