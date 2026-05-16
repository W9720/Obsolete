#import <UIKit/UIKit.h>

@interface AssemblyCalculatorViewController : UIViewController <UITextViewDelegate>

// UI组件
@property (nonatomic, strong) UISegmentedControl *modeSegment;
@property (nonatomic, strong) UITextView *inputTextView;
@property (nonatomic, strong) UITextView *outputTextView;
@property (nonatomic, strong) UIButton *convertButton;
@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong, getter=getCopyButton) UIButton *copyButton;
@property (nonatomic, strong) UISwitch *formatSwitch;
@property (nonatomic, strong) UILabel *formatLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

@end
