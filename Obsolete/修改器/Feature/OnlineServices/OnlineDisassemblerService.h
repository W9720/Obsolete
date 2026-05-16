#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OnlineDisassemblerService : NSObject

- (void)disassembleBytes:(NSString *)bytes completion:(void (^)(NSString * _Nullable result, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
