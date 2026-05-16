//
//  BaseAddressScript.h
//  基址脚本数据模型
//

#import <Foundation/Foundation.h>
#import "VMTypeHeader.h"

NS_ASSUME_NONNULL_BEGIN

// 脚本类型枚举
typedef NS_ENUM(NSInteger, BaseAddressScriptType) {
    BaseAddressScriptTypePointerChain,  // 指针链脚本
    BaseAddressScriptTypeStaticOffset,  // 静态偏移脚本
    BaseAddressScriptTypeDynamicBase,   // 动态基址脚本
    BaseAddressScriptTypeCustom         // 自定义脚本
};

// 脚本状态枚举
typedef NS_ENUM(NSInteger, BaseAddressScriptStatus) {
    BaseAddressScriptStatusActive,      // 激活状态
    BaseAddressScriptStatusInactive,    // 未激活状态
    BaseAddressScriptStatusError        // 错误状态
};

// 基址脚本指针链节点
@interface BaseAddressPointerNode : NSObject <NSCoding, NSSecureCoding>

@property (nonatomic, copy) NSString *moduleName;      // 模块名称
@property (nonatomic, assign) uintptr_t baseAddress;   // 基址
@property (nonatomic, assign) NSInteger offset;        // 偏移量
@property (nonatomic, copy) NSString *nodeDescription;     // 描述
@property (nonatomic, assign) BOOL isValid;            // 是否有效

- (instancetype)initWithModuleName:(NSString *)moduleName
                        baseAddress:(uintptr_t)baseAddress
                             offset:(NSInteger)offset;

// 获取显示用的模块名（加密脚本显示乱码）
- (NSString *)displayModuleName:(BOOL)isEncrypted;
// 获取显示用的偏移量（加密脚本显示乱码）
- (NSString *)displayOffset:(BOOL)isEncrypted;

@end

// 基址脚本指针链
@interface BaseAddressPointerChain : NSObject <NSCoding, NSSecureCoding>

@property (nonatomic, copy) NSString *name;                    // 指针链名称
@property (nonatomic, strong) NSMutableArray<BaseAddressPointerNode *> *nodes;  // 指针链节点
@property (nonatomic, assign) VMMemValueType valueType;        // 值类型
@property (nonatomic, copy) NSString *expectedValue;           // 期望值
@property (nonatomic, copy) NSString *currentValue;            // 当前值
@property (nonatomic, assign) BOOL isValid;                    // 是否有效
@property (nonatomic, strong) NSDate *lastValidated;           // 最后验证时间

- (instancetype)initWithName:(NSString *)name valueType:(VMMemValueType)valueType;
- (void)addNode:(BaseAddressPointerNode *)node;
- (void)removeNodeAtIndex:(NSInteger)index;
- (uintptr_t)calculateFinalAddress;
- (BOOL)validateChain;
- (NSString *)generateCode;

// 获取显示用的期望值（加密脚本显示乱码）
- (NSString *)displayExpectedValue:(BOOL)isEncrypted;

@end

// 基址脚本
@interface BaseAddressScript : NSObject <NSCoding, NSSecureCoding>

@property (nonatomic, copy) NSString *scriptId;                // 脚本ID
@property (nonatomic, copy) NSString *name;                    // 脚本名称
@property (nonatomic, copy) NSString *scriptDescription;       // 脚本描述
@property (nonatomic, assign) BaseAddressScriptType type;      // 脚本类型
@property (nonatomic, assign) BaseAddressScriptStatus status;  // 脚本状态
@property (nonatomic, copy) NSString *category;                // 分类
@property (nonatomic, copy) NSString *targetProcess;           // 目标进程
@property (nonatomic, strong) NSDate *createdDate;             // 创建时间
@property (nonatomic, strong) NSDate *modifiedDate;            // 修改时间
@property (nonatomic, copy) NSString *author;                  // 作者
@property (nonatomic, copy) NSString *version;                 // 版本

// 指针链相关
@property (nonatomic, strong) NSMutableArray<BaseAddressPointerChain *> *pointerChains;

// 自定义代码
@property (nonatomic, copy) NSString *customCode;              // 自定义代码

// 执行相关
@property (nonatomic, assign) BOOL autoExecute;                // 自动执行
@property (nonatomic, assign) NSTimeInterval executeInterval;  // 执行间隔

// 加密标识
@property (nonatomic, assign) BOOL isEncrypted;                // 是否为加密脚本

- (instancetype)initWithName:(NSString *)name type:(BaseAddressScriptType)type;
- (void)addPointerChain:(BaseAddressPointerChain *)chain;
- (void)removePointerChainAtIndex:(NSInteger)index;
- (BOOL)executeScript;
- (BOOL)validateScript;
- (NSString *)exportToString;
- (NSString *)exportToStringWithEncryption:(BOOL)encrypted password:(NSString *)password;
- (BOOL)importFromString:(NSString *)scriptString;
- (BOOL)importFromString:(NSString *)scriptString withPassword:(NSString *)password;

@end

NS_ASSUME_NONNULL_END
