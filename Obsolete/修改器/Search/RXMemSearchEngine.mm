//
//  RXMemSearchEngine.mm
//  Modifier
//
//  基于rxmemscan的高性能内存搜索引擎封装
//  Created by AI Assistant on 2025-07-22.
//

#import "RXMemSearchEngine.h"
#include "rx_mem_scan.h"
#include "lz4/lz4.h"
#include <string>
#include <mach/mach.h>
#include <mach/vm_map.h>

@implementation RXSearchResult
@end

@interface RXMemSearchEngine() {
    rx_mem_scan *_scanner;
    rx_search_value_type *_currentValueType;
    dispatch_queue_t _searchQueue;
    RXValueType _currentRXValueType;  // 存储当前的RX值类型
    search_result_t _lastResult;      // 存储最后一次搜索结果
}

@property (nonatomic, strong, readwrite) RXSearchResult *lastSearchResult;
@end

@implementation RXMemSearchEngine

+ (instancetype)sharedEngine {
    static RXMemSearchEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[RXMemSearchEngine alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _scanner = new rx_mem_scan();
        _currentValueType = nullptr;
        _currentRXValueType = RXValueTypeInt32;  // 默认为32位整数
        _searchQueue = dispatch_queue_create("com.modifier.rxsearch", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc {
    if (_scanner) {
        delete _scanner;
        _scanner = nullptr;
    }
    if (_currentValueType) {
        delete _currentValueType;
        _currentValueType = nullptr;
    }
}

#pragma mark - 基本操作

- (BOOL)attachToProcess:(pid_t)pid {
    if (!_scanner) return NO;
    
    boolean_t result = _scanner->attach(pid);
    return result;
}

- (void)reset {
    if (_scanner) {
        _scanner->reset();
    }
    
    // 清除最后一次搜索结果
    _lastSearchResult = nil;
    memset(&_lastResult, 0, sizeof(search_result_t));
}

- (void)freeMemory {
    if (_scanner) {
        _scanner->free_memory();
    }
}

- (BOOL)isIdle {
    return _scanner ? _scanner->is_idle() : YES;
}

- (pid_t)targetPid {
    return _scanner ? _scanner->target_pid() : 0;
}

- (void)setIncludeReadOnlyMemory:(BOOL)includeReadOnly {
    if (_scanner) {
        _scanner->set_include_readonly(includeReadOnly);
    }
}

#pragma mark - 内存权限获取

// 获取指定地址的内存权限
- (int)getMemoryProtectionForAddress:(vm_address_t)address {
    if (!_scanner) return 0;

    pid_t targetPid = _scanner->target_pid();
    if (targetPid <= 0) return 0;

    task_t task;
    kern_return_t kr = task_for_pid(mach_task_self(), targetPid, &task);
    if (kr != KERN_SUCCESS) {
        return 0;
    }

    vm_address_t region_address = address;
    vm_size_t region_size;
    vm_region_flavor_t flavor = VM_REGION_BASIC_INFO_64;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t info_count = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object_name;

    kr = vm_region_64(task, &region_address, &region_size, flavor,
                      (vm_region_info_t)&info, &info_count, &object_name);

    if (kr != KERN_SUCCESS) {
        return 0;
    }

    // 检查地址是否在这个区域内
    if (address >= region_address && address < region_address + region_size) {
        return info.protection;
    }

    return 0;
}

#pragma mark - 搜索操作

- (void)searchValue:(NSString *)value 
               type:(RXValueType)valueType 
         comparison:(RXCompareType)compareType 
           callback:(RXSearchCallback)callback {
    
    if (!_scanner || !value || !callback) {
        return;
    }
    
    dispatch_async(_searchQueue, ^{
        // 设置搜索值类型
        [self setValueType:valueType];
        
        // 转换搜索值
        void *searchVal = [self convertValue:value toType:valueType];
        if (!searchVal) {
            dispatch_async(dispatch_get_main_queue(), ^{
                RXSearchResult *emptyResult = [[RXSearchResult alloc] init];
                emptyResult.matchedCount = 0;
                emptyResult.timeUsed = 0;
                emptyResult.memoryUsed = 0;
                self.lastSearchResult = emptyResult;
                callback(emptyResult, @[]);
            });
            return;
        }
        
        // 执行搜索
        rx_compare_type rxCompareType = [self convertCompareType:compareType];
        search_result_t result = self->_scanner->search(searchVal, rxCompareType);
        
        // 保存最后一次搜索结果
        self->_lastResult = result;
        
        // 转换结果
        RXSearchResult *searchResult = [self convertSearchResult:result];
        self.lastSearchResult = searchResult;
        NSArray<MemModel *> *memModels = [self getMemoryModelsFromResult:result];
        
        // 释放搜索值内存
        free(searchVal);
        
        // 回调结果
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(searchResult, memModels);
        });
    });
}

- (void)searchString:(NSString *)string callback:(RXSearchCallback)callback {
    if (!_scanner || !string || !callback) {
        return;
    }
    
    dispatch_async(_searchQueue, ^{
        // 设置搜索值类型为字符串类型
        [self setValueType:RXValueTypeString];
        
        // 执行字符串搜索
        std::string stdString = [string UTF8String];
        
        // 调用rx_mem_scan的search_str方法
        self->_scanner->search_str(stdString);
        
        // 获取最后搜索结果
        search_result_t result = self->_scanner->last_search_result();
        
        // 保存最后一次搜索结果
        self->_lastResult = result;
        
        // 转换为ObjC对象
        RXSearchResult *searchResult = [self convertSearchResult:result];
        self.lastSearchResult = searchResult;
        
        // 获取内存模型
        NSArray<MemModel *> *memModels = [self getMemoryModelsFromResult:result];
        
        // 回调结果
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(searchResult, memModels);
        });
    });
}

- (void)firstFuzzySearchWithType:(RXValueType)valueType callback:(RXSearchCallback)callback {
    if (!_scanner || !callback) {
        return;
    }
    
    dispatch_async(_searchQueue, ^{
        // 设置搜索值类型
        [self setValueType:valueType];
        
        search_result_t result = self->_scanner->first_fuzzy_search();
        // 保存最后一次搜索结果
        self->_lastResult = result;
        RXSearchResult *searchResult = [self convertSearchResult:result];
        self.lastSearchResult = searchResult;
        NSArray<MemModel *> *memModels = [self getMemoryModelsFromResult:result];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(searchResult, memModels);
        });
    });
}

- (void)fuzzySearchWithComparison:(RXCompareType)compareType callback:(RXSearchCallback)callback {
    if (!_scanner || !callback) {
        return;
    }
    
    dispatch_async(_searchQueue, ^{
        rx_compare_type rxCompareType = [self convertCompareType:compareType];
        search_result_t result = self->_scanner->fuzzy_search(rxCompareType);
        // 保存最后一次搜索结果
        self->_lastResult = result;
        RXSearchResult *searchResult = [self convertSearchResult:result];
        self.lastSearchResult = searchResult;
        NSArray<MemModel *> *memModels = [self getMemoryModelsFromResult:result];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(searchResult, memModels);
        });
    });
}

#pragma mark - 分页获取结果

- (void)getMemoryPageAtIndex:(NSUInteger)pageIndex 
                    pageSize:(NSUInteger)pageSize 
                    callback:(RXMemoryPageCallback)callback {
    
    if (!_scanner || !callback) return;
    
    dispatch_async(_searchQueue, ^{
        // 这里需要实现分页逻辑
        // 由于rxmemscan的分页接口比较复杂，先返回空数组
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(@[]);
        });
    });
}

- (void)getMatchedPageAtIndex:(NSUInteger)pageIndex 
                     pageSize:(NSUInteger)pageSize 
                     callback:(RXMemoryPageCallback)callback {
    
    if (!_scanner || !callback) return;
    
    dispatch_async(_searchQueue, ^{
        // 这里需要实现分页逻辑
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(@[]);
        });
    });
}

#pragma mark - 内存操作

- (BOOL)writeValue:(NSString *)value toAddress:(NSString *)address type:(RXValueType)valueType {
    if (!_scanner || !value || !address) return NO;
    
    // 转换地址
    vm_address_t addr = strtoull([address UTF8String], NULL, 16);
    
    // 转换值
    void *val = [self convertValue:value toType:valueType];
    if (!val) return NO;
    
    kern_return_t result = _scanner->write_val(addr, val);
    free(val);
    
    return (result == KERN_SUCCESS);
}

- (RXSearchResult *)lastSearchResult {
    if (!_lastSearchResult) {
        if (_scanner) {
            search_result_t result = _scanner->last_search_result();
            _lastResult = result;
            _lastSearchResult = [self convertSearchResult:result];
        }
    }
    return _lastSearchResult;
}

#pragma mark - 工具方法

- (NSString *)valueTypeToString:(RXValueType)type {
    switch (type) {
        case RXValueTypeInt8: return @"Int8";
        case RXValueTypeInt16: return @"Int16";
        case RXValueTypeInt32: return @"Int32";
        case RXValueTypeInt64: return @"Int64";
        case RXValueTypeUInt8: return @"UInt8";
        case RXValueTypeUInt16: return @"UInt16";
        case RXValueTypeUInt32: return @"UInt32";
        case RXValueTypeUInt64: return @"UInt64";
        case RXValueTypeFloat: return @"Float";
        case RXValueTypeDouble: return @"Double";
        case RXValueTypeString: return @"String";
        default: return @"Unknown";
    }
}

- (NSString *)compareTypeToString:(RXCompareType)type {
    switch (type) {
        case RXCompareTypeEqual: return @"等于";
        case RXCompareTypeNotEqual: return @"不等于";
        case RXCompareTypeGreater: return @"大于";
        case RXCompareTypeLess: return @"小于";
        case RXCompareTypeGreaterEqual: return @"大于等于";
        case RXCompareTypeLessEqual: return @"小于等于";
        case RXCompareTypeChanged: return @"已改变";
        case RXCompareTypeUnchanged: return @"未改变";
        case RXCompareTypeIncreased: return @"增加了";
        case RXCompareTypeDecreased: return @"减少了";
        case RXCompareTypeIncreasedBy: return @"增加了指定值";
        case RXCompareTypeDecreasedBy: return @"减少了指定值";
        default: return @"未知";
    }
}

#pragma mark - 私有方法

- (void)setValueType:(RXValueType)valueType {
    // 检查类型是否发生变化，只有变化时才设置新类型
    if (_currentRXValueType == valueType && _currentValueType != nullptr) {
        return;
    }

    if (_currentValueType) {
        delete _currentValueType;
        _currentValueType = nullptr;
    }

    // 保存当前的RX值类型
    _currentRXValueType = valueType;

    switch (valueType) {
        case RXValueTypeInt8:
            _currentValueType = new rx_search_typed_value_type<int8_t>();
            break;
        case RXValueTypeInt16:
            _currentValueType = new rx_search_typed_value_type<int16_t>();
            break;
        case RXValueTypeInt32:
            _currentValueType = new rx_search_typed_value_type<int32_t>();
            break;
        case RXValueTypeInt64:
            _currentValueType = new rx_search_typed_value_type<int64_t>();
            break;
        case RXValueTypeUInt8:
            _currentValueType = new rx_search_typed_value_type<uint8_t>();
            break;
        case RXValueTypeUInt16:
            _currentValueType = new rx_search_typed_value_type<uint16_t>();
            break;
        case RXValueTypeUInt32:
            _currentValueType = new rx_search_typed_value_type<uint32_t>();
            break;
        case RXValueTypeUInt64:
            _currentValueType = new rx_search_typed_value_type<uint64_t>();
            break;
        case RXValueTypeFloat:
            _currentValueType = new rx_search_typed_value_type<float>();
            break;
        case RXValueTypeDouble:
            _currentValueType = new rx_search_typed_value_type<double>();
            break;
        default:
            _currentValueType = new rx_search_typed_value_type<int32_t>();
            break;
    }

    if (_scanner && _currentValueType) {
        _scanner->set_search_value_type(_currentValueType);
    }
}

- (void *)convertValue:(NSString *)value toType:(RXValueType)valueType {
    if (!value) return nullptr;

    const char *cStr = [value UTF8String];
    void *result = nullptr;

    switch (valueType) {
        case RXValueTypeInt8: {
            int8_t *val = (int8_t *)malloc(sizeof(int8_t));
            *val = (int8_t)atoi(cStr);
            result = val;
            break;
        }
        case RXValueTypeInt16: {
            int16_t *val = (int16_t *)malloc(sizeof(int16_t));
            *val = (int16_t)atoi(cStr);
            result = val;
            break;
        }
        case RXValueTypeInt32: {
            int32_t *val = (int32_t *)malloc(sizeof(int32_t));
            *val = (int32_t)atoi(cStr);
            result = val;
            break;
        }
        case RXValueTypeInt64: {
            int64_t *val = (int64_t *)malloc(sizeof(int64_t));
            *val = (int64_t)atoll(cStr);
            result = val;
            break;
        }
        case RXValueTypeUInt8: {
            uint8_t *val = (uint8_t *)malloc(sizeof(uint8_t));
            *val = (uint8_t)atoi(cStr);
            result = val;
            break;
        }
        case RXValueTypeUInt16: {
            uint16_t *val = (uint16_t *)malloc(sizeof(uint16_t));
            *val = (uint16_t)atoi(cStr);
            result = val;
            break;
        }
        case RXValueTypeUInt32: {
            uint32_t *val = (uint32_t *)malloc(sizeof(uint32_t));
            *val = (uint32_t)atoll(cStr);
            result = val;
            break;
        }
        case RXValueTypeUInt64: {
            uint64_t *val = (uint64_t *)malloc(sizeof(uint64_t));
            *val = (uint64_t)strtoull(cStr, NULL, 10);
            result = val;
            break;
        }
        case RXValueTypeFloat: {
            float *val = (float *)malloc(sizeof(float));
            *val = atof(cStr);
            result = val;
            break;
        }
        case RXValueTypeDouble: {
            double *val = (double *)malloc(sizeof(double));
            *val = atof(cStr);
            result = val;
            break;
        }
        default:
            break;
    }

    return result;
}

- (rx_compare_type)convertCompareType:(RXCompareType)compareType {
    switch (compareType) {
        case RXCompareTypeEqual: return rx_compare_type_eq;
        case RXCompareTypeNotEqual: return rx_compare_type_ne;
        case RXCompareTypeGreater: return rx_compare_type_gt;
        case RXCompareTypeLess: return rx_compare_type_lt;
        case RXCompareTypeGreaterEqual: return rx_compare_type_gt; // rxmemscan只支持基本比较
        case RXCompareTypeLessEqual: return rx_compare_type_lt;    // rxmemscan只支持基本比较
        case RXCompareTypeChanged: return rx_compare_type_ne;      // 映射到不等于
        case RXCompareTypeUnchanged: return rx_compare_type_eq;    // 映射到等于
        case RXCompareTypeIncreased: return rx_compare_type_gt;    // 映射到大于
        case RXCompareTypeDecreased: return rx_compare_type_lt;    // 映射到小于
        case RXCompareTypeIncreasedBy: return rx_compare_type_gt;  // 映射到大于
        case RXCompareTypeDecreasedBy: return rx_compare_type_lt;  // 映射到小于
        default: return rx_compare_type_eq;
    }
}

- (RXSearchResult *)convertSearchResult:(search_result_t)result {
    RXSearchResult *searchResult = [[RXSearchResult alloc] init];
    searchResult.matchedCount = result.matched;
    searchResult.timeUsed = result.time_used;
    searchResult.memoryUsed = result.memory_used;
    return searchResult;
}

- (NSArray<MemModel *> *)getMemoryModelsFromResult:(search_result_t)result {
    NSMutableArray<MemModel *> *memModels = [NSMutableArray array];

    if (!_scanner || result.matched == 0) {
        return [memModels copy];
    }

    // 限制初始结果为100条，后续通过增量加载获取更多
    uint32_t maxResults = MIN(100, result.matched);
    uint32_t pageSize = 100; // 每页100个结果
    uint32_t totalPages = (maxResults + pageSize - 1) / pageSize;
    
    // 获取搜索结果的地址和值
    for (uint32_t pageNo = 0; pageNo < totalPages; pageNo++) {
        
        // 获取匹配结果的页面
        rx_memory_page_pt page = _scanner->page_of_matched(pageNo, pageSize);
        if (!page) {
            continue;
        }
        
        if (!page->addresses) {
            continue;
        }
        
        if (!page->data) {
            continue;
        }

        // 获取地址列表和数据
        std::vector<vm_address_t> *addresses = page->addresses;
        uint8_t *data = page->data;
        
        // 确保搜索值类型已设置
        if (!_currentValueType) {
            // 如果是字符串搜索但未设置类型，创建一个字符串类型
            _currentValueType = new rx_search_typed_value_type<char>();
        }
        
        size_t valueSize = _currentValueType ? _currentValueType->size_of_value() : sizeof(uint32_t);

        // 遍历页面中的结果
        uint32_t itemsInPage = MIN((uint32_t)addresses->size(), MIN(pageSize, maxResults - pageNo * pageSize));

        for (uint32_t i = 0; i < itemsInPage; i++) {
            // 从rxmemscan的地址列表中获取地址
            vm_address_t address = (*addresses)[i];
            if (address == 0) {
                continue;
            }
            
            // 创建内存模型
            MemModel *memModel = [[MemModel alloc] init];
            memModel.address = [NSString stringWithFormat:@"0x%lX", (unsigned long)address];
            memModel.o_addr = address;

            // 获取内存权限
            memModel.protection = [self getMemoryProtectionForAddress:address];

            // 从rxmemscan的数据中获取对应的值
            if (i * valueSize < page->data_size) {
                uint8_t *valueData = data + (i * valueSize);
                
                // 特殊处理字符串类型
                if (_currentRXValueType == RXValueTypeString) {
                    // 完全模仿VM实现的字符串处理方式
                    char *data_ptr = (char *)valueData;
                    
                    // 首先确定字符串的长度 - 找到第一个非可打印字符或NULL
                    size_t str_len = 0;
                    size_t max_len = MIN(256, page->data_size - i * valueSize);
                    
                    // 检查是否是有效的UTF-8字符串
                    BOOL isValidString = YES;
                    while (str_len < max_len) {
                        char ch = data_ptr[str_len];
                        // 检查字符是否为NULL终止符或可打印ASCII字符
                        if (ch == 0) {
                            break; // 遇到NULL终止符，结束
                        }
                        
                        // 只接受可打印ASCII字符和基本控制字符
                        if (ch < 32 || ch > 126) {
                            // 允许一些常见控制字符如换行、制表符等
                            if (ch != '\n' && ch != '\r' && ch != '\t') {
                                // 如果是UTF-8多字节字符的开始，尝试验证
                                if ((ch & 0xE0) == 0xC0) { // 2字节UTF-8
                                    if (str_len + 1 >= max_len || (data_ptr[str_len+1] & 0xC0) != 0x80) {
                                        isValidString = NO;
                                        break;
                                    }
                                    str_len += 2; // 跳过这个2字节字符
                                    continue;
                                } else if ((ch & 0xF0) == 0xE0) { // 3字节UTF-8
                                    if (str_len + 2 >= max_len || 
                                        (data_ptr[str_len+1] & 0xC0) != 0x80 || 
                                        (data_ptr[str_len+2] & 0xC0) != 0x80) {
                                        isValidString = NO;
                                        break;
                                    }
                                    str_len += 3; // 跳过这个3字节字符
                                    continue;
                                } else {
                                    isValidString = NO;
                                    break;
                                }
                            }
                        }
                        str_len++;
                    }
                    
                    // 如果找到了有效字符串
                    if (isValidString && str_len > 0) {
                        // 创建一个有限长度的字符串
                        NSData *stringData = [NSData dataWithBytes:data_ptr length:str_len];
                        NSString *stringValue = [[NSString alloc] initWithData:stringData encoding:NSUTF8StringEncoding];
                        
                        // 如果UTF-8解码失败，尝试ASCII编码
                        if (!stringValue) {
                            stringValue = [[NSString alloc] initWithData:stringData encoding:NSASCIIStringEncoding];
                        }
                        
                        // 如果仍然失败，使用字符数组创建字符串
                        if (!stringValue) {
                            NSMutableString *mutableString = [NSMutableString string];
                            for (size_t j = 0; j < str_len; j++) {
                                char ch = data_ptr[j];
                                if (ch >= 32 && ch <= 126) {
                                    [mutableString appendFormat:@"%c", ch];
                                } else {
                                    [mutableString appendString:@"."];
                                }
                            }
                            stringValue = [mutableString copy];
                        }
                        
                        // 设置模型值
                        memModel.value = stringValue;
                    } else {
                        memModel.value = @"[空字符串]";
                    }
                    
                } else {
                    // 非字符串类型正常处理
                    memModel.value = [self formatValue:valueData withSize:valueSize];
                }
                
                memModel.type = [self getCurrentVMMemValueType];

                // 设置十六进制值
                NSMutableString *hexString = [NSMutableString string];
                for (size_t j = 0; j < valueSize; j++) {
                    [hexString appendFormat:@"%02X", valueData[j]];
                }
                memModel.value_16 = hexString;
                memModel.valueType = [self getCurrentVMMemValueType];
            } else {
                memModel.value = @"数据不足";
                memModel.type = [self getCurrentVMMemValueType];
            }

            [memModels addObject:memModel];
            
        }

        // 注意：rxmemscan会自动管理页面内存，不需要手动释放
    }

    return [memModels copy];
}



- (NSString *)formatValue:(void *)valueBuffer withSize:(size_t)valueSize {
    if (!valueBuffer) return @"无效";

    // 根据当前设置的RX值类型格式化显示
    switch (_currentRXValueType) {
        case RXValueTypeInt8: {
            int8_t val = *(int8_t*)valueBuffer;
            return [NSString stringWithFormat:@"%d", val];
        }
        case RXValueTypeInt16: {
            int16_t val = *(int16_t*)valueBuffer;
            return [NSString stringWithFormat:@"%d", val];
        }
        case RXValueTypeInt32: {
            int32_t val = *(int32_t*)valueBuffer;
            return [NSString stringWithFormat:@"%d", val];
        }
        case RXValueTypeInt64: {
            int64_t val = *(int64_t*)valueBuffer;
            return [NSString stringWithFormat:@"%lld", val];
        }
        case RXValueTypeUInt8: {
            uint8_t val = *(uint8_t*)valueBuffer;
            return [NSString stringWithFormat:@"%u", val];
        }
        case RXValueTypeUInt16: {
            uint16_t val = *(uint16_t*)valueBuffer;
            return [NSString stringWithFormat:@"%u", val];
        }
        case RXValueTypeUInt32: {
            uint32_t val = *(uint32_t*)valueBuffer;
            return [NSString stringWithFormat:@"%u", val];
        }
        case RXValueTypeUInt64: {
            uint64_t val = *(uint64_t*)valueBuffer;
            return [NSString stringWithFormat:@"%llu", val];
        }
        case RXValueTypeFloat: {
            float val = *(float*)valueBuffer;
            // 使用固定格式确保浮点数正确显示，不使用科学计数法
            return [NSString stringWithFormat:@"%.7g", val];
        }
        case RXValueTypeDouble: {
            double val = *(double*)valueBuffer;
            // 使用固定格式确保浮点数正确显示，不使用科学计数法
            return [NSString stringWithFormat:@"%.15g", val];
        }
        case RXValueTypeString: {
            // 字符串类型的处理
            char *str = (char*)valueBuffer;
            NSString *result = [[NSString alloc] initWithBytes:str length:valueSize encoding:NSUTF8StringEncoding];
            return result ? result : @"[无效字符串]";
        }
        default: {
            // 默认以十六进制显示
            NSMutableString *hexString = [NSMutableString string];
            uint8_t *bytes = (uint8_t*)valueBuffer;
            for (size_t i = 0; i < valueSize && i < 8; i++) {
                [hexString appendFormat:@"%02X ", bytes[i]];
            }
            return hexString;
        }
    }
}

- (VMMemValueType)getCurrentVMMemValueType {
    if (!_currentValueType) return VMMemValueTypeSignedInt;

    size_t typeSize = _currentValueType->size_of_value();

    if (typeSize == sizeof(int8_t)) return VMMemValueTypeSignedByte;
    if (typeSize == sizeof(int16_t)) return VMMemValueTypeSignedShort;
    if (typeSize == sizeof(int32_t)) return VMMemValueTypeSignedInt;
    if (typeSize == sizeof(int64_t)) return VMMemValueTypeSignedLong;
    if (typeSize == sizeof(float)) return VMMemValueTypeFloat;
    if (typeSize == sizeof(double)) return VMMemValueTypeDouble;

    return VMMemValueTypeSignedInt; // 默认值
}

- (NSString *)getCurrentValueTypeString {
    VMMemValueType type = [self getCurrentVMMemValueType];

    switch (type) {
        case VMMemValueTypeSignedByte: return @"Int8";
        case VMMemValueTypeSignedShort: return @"Int16";
        case VMMemValueTypeSignedInt: return @"Int32";
        case VMMemValueTypeSignedLong: return @"Int64";
        case VMMemValueTypeFloat: return @"Float";
        case VMMemValueTypeDouble: return @"Double";
        case VMMemValueTypeStr: return @"String";
        default: return @"Unknown";
    }
}

- (NSString *)cleanRepeatingPatterns:(NSString *)input {
    // 检查是否包含重复模式，如httphttp...
    NSString *pattern = @"(http[^:]*:)\\1+";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    NSArray *matches = [regex matchesInString:input options:0 range:NSMakeRange(0, [input length])];
    
    if (matches.count > 0) {
        NSMutableString *result = [input mutableCopy];
        
        // 从后向前替换，避免范围变化问题
        for (NSInteger i = matches.count - 1; i >= 0; i--) {
            NSTextCheckingResult *match = matches[i];
            NSRange matchRange = [match range];
            
            // 提取第一个http部分
            NSString *httpPart = [input substringWithRange:[match rangeAtIndex:1]];
            
            // 替换整个重复序列为单个http部分
            [result replaceCharactersInRange:matchRange withString:httpPart];
        }
        
        return result;
    }
    
    // 检查是否包含URL，如果有，尝试提取完整URL
    NSRange httpRange = [input rangeOfString:@"http" options:NSCaseInsensitiveSearch];
    if (httpRange.location != NSNotFound) {
        NSString *urlString = [input substringFromIndex:httpRange.location];
        return urlString;
    }
    
    return input;
}

// 增量加载更多搜索结果
- (NSArray<MemModel *> *)loadMoreResultsFromOffset:(uint32_t)offset count:(uint32_t)count {
    NSMutableArray<MemModel *> *memModels = [NSMutableArray array];
    
    if (!_scanner || !_lastSearchResult || offset >= _lastSearchResult.matchedCount) {
        return [memModels copy];
    }
    
    // 确保不超过实际匹配数量
    uint32_t actualCount = MIN(count, _lastSearchResult.matchedCount - offset);
    uint32_t pageSize = 100; // 每页100个结果
    
    // 计算起始页和结束页
    uint32_t startPage = offset / pageSize;
    uint32_t endPage = (offset + actualCount - 1) / pageSize;
    
    NSLog(@"[RX引擎] 增量加载 - 偏移量: %u, 数量: %u, 实际数量: %u, 起始页: %u, 结束页: %u", 
          offset, count, actualCount, startPage, endPage);
    
    // 遍历需要的页面
    for (uint32_t pageNo = startPage; pageNo <= endPage; pageNo++) {
        // 获取匹配结果的页面
        rx_memory_page_pt page = _scanner->page_of_matched(pageNo, pageSize);
        if (!page || !page->addresses || !page->data) {
            continue;
        }
        
        // 获取地址列表和数据
        std::vector<vm_address_t> *addresses = page->addresses;
        uint8_t *data = page->data;
        
        // 确保搜索值类型已设置
        if (!_currentValueType) {
            _currentValueType = new rx_search_typed_value_type<uint32_t>();
        }
        
        size_t valueSize = _currentValueType ? _currentValueType->size_of_value() : sizeof(uint32_t);
        
        // 计算当前页中的起始索引和结束索引
        uint32_t pageStartOffset = pageNo * pageSize;
        uint32_t pageStartIndex = (offset > pageStartOffset) ? (offset - pageStartOffset) : 0;
        
        // 修正计算逻辑，确保不会超出边界
        uint32_t itemsInPage = MIN((uint32_t)addresses->size(), pageSize);
        uint32_t pageEndIndex;
        
        if (pageNo == endPage) {
            // 最后一页的结束索引
            uint32_t remainingItems = offset + actualCount - pageStartOffset;
            pageEndIndex = MIN(pageStartIndex + remainingItems, itemsInPage);
        } else {
            // 中间页的结束索引
            pageEndIndex = itemsInPage;
        }
        
        NSLog(@"[RX引擎] 页面 %u - 起始索引: %u, 结束索引: %u", 
              pageNo, pageStartIndex, pageEndIndex);
        
        // 遍历当前页中的指定范围
        for (uint32_t i = pageStartIndex; i < pageEndIndex; i++) {
            // 从rxmemscan的地址列表中获取地址
            vm_address_t address = (*addresses)[i];
            if (address == 0) {
                continue;
            }
            
            // 创建内存模型
            MemModel *memModel = [[MemModel alloc] init];
            memModel.address = [NSString stringWithFormat:@"0x%lX", (unsigned long)address];
            memModel.o_addr = address;
            
            // 获取内存权限
            memModel.protection = [self getMemoryProtectionForAddress:address];
            
            // 从rxmemscan的数据中获取对应的值
            if (i * valueSize < page->data_size) {
                uint8_t *valueData = data + (i * valueSize);
                
                // 特殊处理字符串类型
                if (_currentRXValueType == RXValueTypeString) {
                    // 处理字符串类型的值（与getMemoryModelsFromResult方法相同）
                    char *data_ptr = (char *)valueData;
                    
                    // 首先确定字符串的长度 - 找到第一个非可打印字符或NULL
                    size_t str_len = 0;
                    size_t max_len = MIN(256, page->data_size - i * valueSize);
                    
                    // 检查是否是有效的UTF-8字符串
                    BOOL isValidString = YES;
                    while (str_len < max_len) {
                        char ch = data_ptr[str_len];
                        // 检查字符是否为NULL终止符或可打印ASCII字符
                        if (ch == 0) {
                            break; // 遇到NULL终止符，结束
                        }
                        
                        // 只接受可打印ASCII字符和基本控制字符
                        if (ch < 32 || ch > 126) {
                            // 允许一些常见控制字符如换行、制表符等
                            if (ch != '\n' && ch != '\r' && ch != '\t') {
                                // 如果是UTF-8多字节字符的开始，尝试验证
                                if ((ch & 0xE0) == 0xC0) { // 2字节UTF-8
                                    if (str_len + 1 >= max_len || (data_ptr[str_len+1] & 0xC0) != 0x80) {
                                        isValidString = NO;
                                        break;
                                    }
                                    str_len += 2; // 跳过这个2字节字符
                                    continue;
                                } else if ((ch & 0xF0) == 0xE0) { // 3字节UTF-8
                                    if (str_len + 2 >= max_len || 
                                        (data_ptr[str_len+1] & 0xC0) != 0x80 || 
                                        (data_ptr[str_len+2] & 0xC0) != 0x80) {
                                        isValidString = NO;
                                        break;
                                    }
                                    str_len += 3; // 跳过这个3字节字符
                                    continue;
                                } else if ((ch & 0xF8) == 0xF0) { // 4字节UTF-8
                                    if (str_len + 3 >= max_len || 
                                        (data_ptr[str_len+1] & 0xC0) != 0x80 || 
                                        (data_ptr[str_len+2] & 0xC0) != 0x80 || 
                                        (data_ptr[str_len+3] & 0xC0) != 0x80) {
                                        isValidString = NO;
                                        break;
                                    }
                                    str_len += 4; // 跳过这个4字节字符
                                    continue;
                                }
                                
                                isValidString = NO;
                                break;
                            }
                        }
                        str_len++;
                    }
                    
                    if (isValidString && str_len > 0) {
                        // 创建一个临时缓冲区来存储字符串，确保有足够空间添加NULL终止符
                        char *temp_str = (char *)malloc(str_len + 1);
                        if (temp_str) {
                            memcpy(temp_str, data_ptr, str_len);
                            temp_str[str_len] = '\0';
                            
                            // 设置值为找到的字符串
                            memModel.value = [NSString stringWithUTF8String:temp_str];
                            
                            // 释放临时缓冲区
                            free(temp_str);
                        }
                    } else {
                        // 如果不是有效的字符串，显示十六进制表示
                        memModel.value = @"[无效字符串]";
                    }
                } else {
                    // 处理数值类型的值（与getMemoryModelsFromResult方法相同）
                    switch (_currentRXValueType) {
                        case RXValueTypeInt8:
                            memModel.value = [NSString stringWithFormat:@"%d", *(int8_t *)valueData];
                            break;
                        case RXValueTypeInt16:
                            memModel.value = [NSString stringWithFormat:@"%d", *(int16_t *)valueData];
                            break;
                        case RXValueTypeInt32:
                            memModel.value = [NSString stringWithFormat:@"%d", *(int32_t *)valueData];
                            break;
                        case RXValueTypeInt64:
                            memModel.value = [NSString stringWithFormat:@"%lld", *(int64_t *)valueData];
                            break;
                        case RXValueTypeUInt8:
                            memModel.value = [NSString stringWithFormat:@"%u", *(uint8_t *)valueData];
                            break;
                        case RXValueTypeUInt16:
                            memModel.value = [NSString stringWithFormat:@"%u", *(uint16_t *)valueData];
                            break;
                        case RXValueTypeUInt32:
                            memModel.value = [NSString stringWithFormat:@"%u", *(uint32_t *)valueData];
                            break;
                        case RXValueTypeUInt64:
                            memModel.value = [NSString stringWithFormat:@"%llu", *(uint64_t *)valueData];
                            break;
                        case RXValueTypeFloat:
                            memModel.value = [NSString stringWithFormat:@"%f", *(float *)valueData];
                            break;
                        case RXValueTypeDouble:
                            memModel.value = [NSString stringWithFormat:@"%f", *(double *)valueData];
                            break;
                        default:
                            memModel.value = @"未知类型";
                            break;
                    }
                }
            }
            
            // 添加到结果数组
            [memModels addObject:memModel];
        }
    }
    
    NSLog(@"[RX引擎] 增量加载完成 - 加载了 %lu 条结果", (unsigned long)memModels.count);
    return [memModels copy];
}

@end
