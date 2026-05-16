#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AssemblerErrorType) {
    AssemblerErrorTypeNetwork,
    AssemblerErrorTypeParsing,
    AssemblerErrorTypeInvalidResponse
};

@interface AssemblerError : NSError
+ (instancetype)errorWithType:(AssemblerErrorType)type message:(NSString *)message;
@end

@interface OnlineAssemblerService : NSObject

@property (nonatomic, strong, readonly, nullable) NSString *lastHtmlResponse;

- (void)assembleCode:(NSString *)code completion:(void (^)(NSString * _Nullable result, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
