//
//  BitSlicerStringSearcher.m
//  Modifier
//
//  Created by AI Assistant on 2023-07-23.
//

#import "BitSlicerStringSearcher.h"
#import "ProcessManager.h"
#import <mach/mach.h>

// 定义内存区域结构
@interface MemoryRegion : NSObject
@property (nonatomic, assign) vm_address_t address;
@property (nonatomic, assign) vm_size_t size;
@property (nonatomic, assign) vm_prot_t protection;
@end

@implementation MemoryRegion
@end

@interface BitSlicerStringSearcher ()

@property (nonatomic, assign) pid_t targetPid;
@property (nonatomic, strong) NSMutableArray<MemModel *> *lastSearchResults;
@property (nonatomic, assign) mach_port_t task;
@property (nonatomic, assign) BOOL isAttached;

@end

@implementation BitSlicerStringSearcher

+ (instancetype)sharedInstance {
    static BitSlicerStringSearcher *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _lastSearchResults = [NSMutableArray array];
        _isAttached = NO;
    }
    return self;
}

- (BOOL)attachToProcess:(pid_t)pid {
    if (_isAttached && _targetPid == pid) {
        return YES; // 已经附加到相同进程
    }
    
    // 清理之前的任务
    if (_isAttached) {
        [self detachFromProcess];
    }
    
    kern_return_t kr = task_for_pid(mach_task_self(), pid, &_task);
    if (kr != KERN_SUCCESS) {
        return NO;
    }
    
    _targetPid = pid;
    _isAttached = YES;
    [self reset];
    return YES;
}

- (void)detachFromProcess {
    if (_isAttached) {
        mach_port_deallocate(mach_task_self(), _task);
        _isAttached = NO;
    }
}

- (pid_t)currentPid {
    return _targetPid;
}

- (void)reset {
    [_lastSearchResults removeAllObjects];
}

#pragma mark - 内存区域枚举

- (NSArray<MemoryRegion *> *)enumerateMemoryRegions {
    if (!_isAttached) {
        return @[];
    }
    
    NSMutableArray<MemoryRegion *> *regions = [NSMutableArray array];
    
    mach_vm_address_t address = 0;
    mach_vm_size_t size = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t objectName = MACH_PORT_NULL;
    
    while (1) {
                kern_return_t kr = vm_region_64(_task, &address, &size, VM_REGION_BASIC_INFO_64, 
                                    (vm_region_info_t)&info, &infoCount, &objectName);
        
        if (kr != KERN_SUCCESS) {
            break;
        }
        
        // 检查区域权限
        BOOL is_readable = (info.protection & VM_PROT_READ);
        BOOL is_writable = (info.protection & VM_PROT_WRITE);
        BOOL is_executable = (info.protection & VM_PROT_EXECUTE);

        if (is_readable) {
            // 检查是否启用了只读搜索模式
            BOOL includeReadOnly = [[NSUserDefaults standardUserDefaults] boolForKey:@"IncludeReadOnlySearch"];

            BOOL shouldInclude = NO;
            if (includeReadOnly) {
                // 完整模式：搜索所有可读区域，但跳过大型纯执行区域
                if (is_executable && !is_writable && size > 1024 * 1024) {
                    shouldInclude = NO; // 跳过大型纯执行区域
                } else {
                    shouldInclude = YES; // 包含所有其他可读区域
                }
            } else {
                // 快速模式：只搜索可写区域
                shouldInclude = is_writable;
            }

            if (shouldInclude) {
                MemoryRegion *region = [[MemoryRegion alloc] init];
                region.address = address;
                region.size = size;
                region.protection = info.protection;
                [regions addObject:region];
            }
        }
        
        address += size;
    }
    
    return regions;
}

#pragma mark - 字符串搜索

- (void)searchString:(NSString *)string 
     caseInsensitive:(BOOL)caseInsensitive 
              utf16:(BOOL)isUTF16 
           callback:(void (^)(NSInteger, NSArray<MemModel *> *, NSTimeInterval))callback {
    
    if (!_isAttached) {
        if (callback) {
            callback(0, @[], 0);
        }
        return;
    }
    
    NSDate *startTime = [NSDate date];
    
    // 清空上次的搜索结果
    [self.lastSearchResults removeAllObjects];
    
    // 获取内存区域
    NSArray<MemoryRegion *> *regions = [self enumerateMemoryRegions];
    
    // 准备搜索数据
    NSData *searchData;
    if (isUTF16) {
        // UTF-16编码
        searchData = [string dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
    } else {
        // UTF-8编码
        searchData = [string dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    // 如果是大小写不敏感搜索，转换为小写
    NSData *lowerSearchData;
    if (caseInsensitive) {
        NSString *lowerString = [string lowercaseString];
        if (isUTF16) {
            lowerSearchData = [lowerString dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
        } else {
            lowerSearchData = [lowerString dataUsingEncoding:NSUTF8StringEncoding];
        }
    }
    
    // 开始搜索
    for (NSUInteger i = 0; i < regions.count; i++) {
        MemoryRegion *region = regions[i];
        
        // 读取区域内存
        vm_size_t bytesRead = 0;
        void *buffer = malloc(region.size);
        
        kern_return_t kr = vm_read_overwrite(_task, region.address, region.size, 
                                           (vm_address_t)buffer, &bytesRead);
        
        if (kr != KERN_SUCCESS || bytesRead == 0) {
            free(buffer);
            continue;
        }
        
        // 搜索字符串
        NSUInteger searchLength = searchData.length;
        const void *searchBytes = searchData.bytes;
        const void *lowerSearchBytes = caseInsensitive ? lowerSearchData.bytes : NULL;
        
        for (NSUInteger offset = 0; offset <= bytesRead - searchLength; offset++) {
            BOOL found = NO;
            
            if (caseInsensitive) {
                // 大小写不敏感比较
                found = [self compareMemory:buffer + offset 
                               withPattern:lowerSearchBytes 
                                   length:searchLength 
                          caseInsensitive:YES];
            } else {
                // 大小写敏感比较
                found = memcmp(buffer + offset, searchBytes, searchLength) == 0;
            }
            
            if (found) {
                // 创建结果模型
                vm_address_t foundAddress = region.address + offset;
                NSString *addressString = [NSString stringWithFormat:@"0x%llx", (unsigned long long)foundAddress];

                NSString *value;

                // 检查模糊字符设置
                BOOL isFuzzyStringEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"FuzzyStringMode"];

                if (isFuzzyStringEnabled) {
                    // 模糊字符开启：读取更长的字符串（当前行为）
                    NSUInteger maxReadLength = MIN(256, bytesRead - offset);
                    NSData *valueData = [NSData dataWithBytes:buffer + offset length:maxReadLength];

                    if (isUTF16) {
                        value = [[NSString alloc] initWithData:valueData encoding:NSUTF16LittleEndianStringEncoding];
                    } else {
                        value = [[NSString alloc] initWithData:valueData encoding:NSUTF8StringEncoding];
                    }

                    // 如果无法解码或值为空，跳过
                    if (!value || value.length == 0) {
                        continue;
                    }

                    // 截断过长的字符串
                    if (value.length > 50) {
                        value = [value substringToIndex:50];
                    }
                } else {
                    // 模糊字符关闭：只显示精确匹配的搜索词
                    NSData *exactData = [NSData dataWithBytes:buffer + offset length:searchLength];

                    if (isUTF16) {
                        value = [[NSString alloc] initWithData:exactData encoding:NSUTF16LittleEndianStringEncoding];
                    } else {
                        value = [[NSString alloc] initWithData:exactData encoding:NSUTF8StringEncoding];
                    }

                    // 如果无法解码或值为空，跳过
                    if (!value || value.length == 0) {
                        continue;
                    }
                }
                
                // 创建内存模型
                MemModel *model = [[MemModel alloc] init];
                model.address = addressString;
                model.value = value;
                                 model.type = VMMemValueTypeStr; // 无论是UTF-8还是UTF-16，都使用VMMemValueTypeStr
                
                // 设置权限标志
                NSString *permissionStr = @"[";
                if (region.protection & VM_PROT_READ) permissionStr = [permissionStr stringByAppendingString:@"R"];
                else permissionStr = [permissionStr stringByAppendingString:@"-"];
                
                if (region.protection & VM_PROT_WRITE) permissionStr = [permissionStr stringByAppendingString:@"W"];
                else permissionStr = [permissionStr stringByAppendingString:@"-"];
                
                if (region.protection & VM_PROT_EXECUTE) permissionStr = [permissionStr stringByAppendingString:@"X"];
                else permissionStr = [permissionStr stringByAppendingString:@"-"];
                
                permissionStr = [permissionStr stringByAppendingString:@"]"];
                model.protection = region.protection; // 使用protection属性而不是permission
                
                [self.lastSearchResults addObject:model];
            }
        }
        
        free(buffer);
    }
    
    NSTimeInterval timeUsed = [[NSDate date] timeIntervalSinceDate:startTime];
    
    if (callback) {
        callback(self.lastSearchResults.count, [self.lastSearchResults copy], timeUsed);
    }
}

- (void)narrowSearchWithString:(NSString *)string 
               caseInsensitive:(BOOL)caseInsensitive 
                        utf16:(BOOL)isUTF16 
                     callback:(void (^)(NSInteger, NSArray<MemModel *> *, NSTimeInterval))callback {
    
    if (self.lastSearchResults.count == 0) {
        if (callback) {
            callback(0, @[], 0);
        }
        return;
    }
    
    NSDate *startTime = [NSDate date];
    NSMutableArray<MemModel *> *newResults = [NSMutableArray array];
    
    // 准备搜索数据
    NSData *searchData;
    if (isUTF16) {
        searchData = [string dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
    } else {
        searchData = [string dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    // 如果是大小写不敏感搜索，转换为小写
    NSData *lowerSearchData;
    if (caseInsensitive) {
        NSString *lowerString = [string lowercaseString];
        if (isUTF16) {
            lowerSearchData = [lowerString dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
        } else {
            lowerSearchData = [lowerString dataUsingEncoding:NSUTF8StringEncoding];
        }
    }
    
    // 遍历上次的搜索结果
    for (MemModel *model in self.lastSearchResults) {
        // 解析地址
        unsigned long long address;
        [[NSScanner scannerWithString:model.address] scanHexLongLong:&address];
        
        // 读取内存
        vm_size_t bytesRead = 0;
        NSUInteger readSize = isUTF16 ? 512 : 256; // UTF-16需要更多空间
        void *buffer = malloc(readSize);
        
        kern_return_t kr = vm_read_overwrite(_task, address, readSize, (vm_address_t)buffer, &bytesRead);
        
        if (kr != KERN_SUCCESS || bytesRead == 0) {
            free(buffer);
            continue;
        }
        
        // 搜索字符串
        NSUInteger searchLength = searchData.length;
        const void *searchBytes = searchData.bytes;
        const void *lowerSearchBytes = caseInsensitive ? lowerSearchData.bytes : NULL;
        
        BOOL found = NO;
        
        if (caseInsensitive) {
            found = [self compareMemory:buffer 
                           withPattern:lowerSearchBytes 
                               length:searchLength 
                      caseInsensitive:YES];
        } else {
            found = memcmp(buffer, searchBytes, searchLength) == 0;
        }
        
        if (found) {
            NSString *value;

            // 检查模糊字符设置
            BOOL isFuzzyStringEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"FuzzyStringMode"];

            if (isFuzzyStringEnabled) {
                // 模糊字符开启：读取更长的字符串（当前行为）
                NSUInteger maxReadLength = MIN(256, bytesRead);
                NSData *valueData = [NSData dataWithBytes:buffer length:maxReadLength];

                if (isUTF16) {
                    value = [[NSString alloc] initWithData:valueData encoding:NSUTF16LittleEndianStringEncoding];
                } else {
                    value = [[NSString alloc] initWithData:valueData encoding:NSUTF8StringEncoding];
                }

                // 如果无法解码或值为空，使用原值
                if (!value || value.length == 0) {
                    value = model.value;
                }

                // 截断过长的字符串
                if (value.length > 50) {
                    value = [value substringToIndex:50];
                }
            } else {
                // 模糊字符关闭：只显示精确匹配的搜索词
                NSUInteger searchLength = searchData.length;
                NSData *exactData = [NSData dataWithBytes:buffer length:MIN(searchLength, bytesRead)];

                if (isUTF16) {
                    value = [[NSString alloc] initWithData:exactData encoding:NSUTF16LittleEndianStringEncoding];
                } else {
                    value = [[NSString alloc] initWithData:exactData encoding:NSUTF8StringEncoding];
                }

                // 如果无法解码或值为空，使用原值
                if (!value || value.length == 0) {
                    value = model.value;
                }
            }
            
            // 更新值
            model.value = value;
            [newResults addObject:model];
        }
        
        free(buffer);
    }
    
    // 更新结果
    self.lastSearchResults = newResults;
    
    NSTimeInterval timeUsed = [[NSDate date] timeIntervalSinceDate:startTime];
    
    if (callback) {
        callback(self.lastSearchResults.count, [self.lastSearchResults copy], timeUsed);
    }
}

#pragma mark - 辅助方法

// 大小写不敏感内存比较
- (BOOL)compareMemory:(const void *)memory 
         withPattern:(const void *)pattern 
             length:(NSUInteger)length 
    caseInsensitive:(BOOL)caseInsensitive {
    
    if (!caseInsensitive) {
        return memcmp(memory, pattern, length) == 0;
    }
    
    const unsigned char *mem = memory;
    const unsigned char *pat = pattern;
    
    for (NSUInteger i = 0; i < length; i++) {
        unsigned char c1 = mem[i];
        unsigned char c2 = pat[i];
        
        // 转换为小写进行比较
        if (c1 >= 'A' && c1 <= 'Z') {
            c1 = c1 - 'A' + 'a';
        }
        
        if (c1 != c2) {
            return NO;
        }
    }
    
    return YES;
}

- (void)dealloc {
    [self detachFromProcess];
}

@end 