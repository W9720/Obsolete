//
//  RXMemSearchEngine.h
//  Modifier
//
//  基于rxmemscan的高性能内存搜索引擎封装
//  Created by AI Assistant on 2025-07-22.
//

#import <Foundation/Foundation.h>
#import "MemModel.h"

NS_ASSUME_NONNULL_BEGIN

// 搜索结果统计信息
@interface RXSearchResult : NSObject
@property (nonatomic, assign) NSUInteger matchedCount;      // 匹配数量
@property (nonatomic, assign) NSUInteger timeUsed;         // 搜索耗时(毫秒)
@property (nonatomic, assign) NSUInteger memoryUsed;       // 内存使用量(字节)
@end

// 搜索比较类型
typedef NS_ENUM(NSInteger, RXCompareType) {
    RXCompareTypeEqual = 0,         // 等于
    RXCompareTypeNotEqual,          // 不等于
    RXCompareTypeGreater,           // 大于
    RXCompareTypeLess,              // 小于
    RXCompareTypeGreaterEqual,      // 大于等于
    RXCompareTypeLessEqual,         // 小于等于
    RXCompareTypeChanged,           // 已改变
    RXCompareTypeUnchanged,         // 未改变
    RXCompareTypeIncreased,         // 增加了
    RXCompareTypeDecreased,         // 减少了
    RXCompareTypeIncreasedBy,       // 增加了指定值
    RXCompareTypeDecreasedBy        // 减少了指定值
};

// 搜索数据类型
typedef NS_ENUM(NSInteger, RXValueType) {
    RXValueTypeInt8 = 0,
    RXValueTypeInt16,
    RXValueTypeInt32,
    RXValueTypeInt64,
    RXValueTypeUInt8,
    RXValueTypeUInt16,
    RXValueTypeUInt32,
    RXValueTypeUInt64,
    RXValueTypeFloat,
    RXValueTypeDouble,
    RXValueTypeString
};

// 搜索回调
typedef void(^RXSearchCallback)(RXSearchResult *result, NSArray<MemModel *> *results);
typedef void(^RXMemoryPageCallback)(NSArray<MemModel *> *pageResults);

@interface RXMemSearchEngine : NSObject

// 最后一次搜索结果
@property (nonatomic, strong, readonly) RXSearchResult *lastSearchResult;

// 单例
+ (instancetype)sharedEngine;

// 基本操作
- (BOOL)attachToProcess:(pid_t)pid;
- (void)reset;
- (void)freeMemory;
- (BOOL)isIdle;
- (pid_t)targetPid;

// 搜索模式配置
- (void)setIncludeReadOnlyMemory:(BOOL)includeReadOnly;

// 搜索操作
- (void)searchValue:(NSString *)value 
               type:(RXValueType)valueType 
         comparison:(RXCompareType)compareType 
           callback:(RXSearchCallback)callback;

- (void)searchString:(NSString *)string 
            callback:(RXSearchCallback)callback;

- (void)firstFuzzySearchWithType:(RXValueType)valueType
                       callback:(RXSearchCallback)callback;

- (void)fuzzySearchWithComparison:(RXCompareType)compareType 
                         callback:(RXSearchCallback)callback;

// 分页获取结果
- (void)getMemoryPageAtIndex:(NSUInteger)pageIndex 
                    pageSize:(NSUInteger)pageSize 
                    callback:(RXMemoryPageCallback)callback;

- (void)getMatchedPageAtIndex:(NSUInteger)pageIndex 
                     pageSize:(NSUInteger)pageSize 
                     callback:(RXMemoryPageCallback)callback;

// 内存操作
- (BOOL)writeValue:(NSString *)value 
         toAddress:(NSString *)address 
              type:(RXValueType)valueType;

// 获取最后搜索结果统计
- (RXSearchResult *)lastSearchResult;

// 内存权限获取
- (int)getMemoryProtectionForAddress:(vm_address_t)address;

// 增量加载更多搜索结果
- (NSArray<MemModel *> *)loadMoreResultsFromOffset:(uint32_t)offset count:(uint32_t)count;

// 工具方法
- (NSString *)valueTypeToString:(RXValueType)type;
- (NSString *)compareTypeToString:(RXCompareType)type;

@end
NS_ASSUME_NONNULL_END

