//
//  BaseAddressScript.m
//  基址脚本数据模型实现
//

#import "BaseAddressScript.h"
#import "VMTool.h"
#import "ProcessManager.h"
#import "PointerScanManager.h"
#include "mem.h"

@implementation BaseAddressPointerNode

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithModuleName:(NSString *)moduleName 
                        baseAddress:(uintptr_t)baseAddress 
                             offset:(NSInteger)offset {
    self = [super init];
    if (self) {
        _moduleName = [moduleName copy];
        _baseAddress = baseAddress;
        _offset = offset;
        _isValid = YES;
        _nodeDescription = [NSString stringWithFormat:@"%@+0x%lX", moduleName, (long)offset];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.moduleName forKey:@"moduleName"];
    [coder encodeInteger:self.baseAddress forKey:@"baseAddress"];
    [coder encodeInteger:self.offset forKey:@"offset"];
    [coder encodeObject:self.nodeDescription forKey:@"nodeDescription"];
    [coder encodeBool:self.isValid forKey:@"isValid"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _moduleName = [coder decodeObjectOfClass:[NSString class] forKey:@"moduleName"];
        _baseAddress = [coder decodeIntegerForKey:@"baseAddress"];
        _offset = [coder decodeIntegerForKey:@"offset"];
        _nodeDescription = [coder decodeObjectOfClass:[NSString class] forKey:@"nodeDescription"];
        _isValid = [coder decodeBoolForKey:@"isValid"];
    }
    return self;
}

// 获取显示用的模块名（加密脚本显示乱码）
- (NSString *)displayModuleName:(BOOL)isEncrypted {
    if (!isEncrypted) {
        return self.moduleName;
    }

    // 生成固定长度的乱码
    NSString *scrambled = @"";
    for (int i = 0; i < self.moduleName.length; i++) {
        unichar randomChar = 0x2588 + (i % 10); // 使用Unicode块字符
        scrambled = [scrambled stringByAppendingString:[NSString stringWithCharacters:&randomChar length:1]];
    }
    return scrambled;
}

// 获取显示用的偏移量（加密脚本显示乱码）
- (NSString *)displayOffset:(BOOL)isEncrypted {
    if (!isEncrypted) {
        return [NSString stringWithFormat:@"0x%lX", (unsigned long)self.offset];
    }

    // 生成乱码偏移量
    return @"0x████████";
}

@end

@implementation BaseAddressPointerChain

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithName:(NSString *)name valueType:(VMMemValueType)valueType {
    self = [super init];
    if (self) {
        _name = [name copy];
        _valueType = valueType;
        _nodes = [[NSMutableArray alloc] init];
        _isValid = NO;
        _lastValidated = [NSDate date];
    }
    return self;
}

- (void)addNode:(BaseAddressPointerNode *)node {
    [self.nodes addObject:node];
}

- (void)removeNodeAtIndex:(NSInteger)index {
    if (index >= 0 && index < self.nodes.count) {
        [self.nodes removeObjectAtIndex:index];
    }
}

- (uintptr_t)calculateFinalAddress {
    if (self.nodes.count == 0) {
        return 0;
    }

    // 使用现有的指针扫描管理器来读取内存
    PointerScanManager *pointerManager = [PointerScanManager sharedManager];

    // 确保已经附加到当前进程
    NSString *pidString = [ProcessManager sharedManager].selectedProcessPID;
    if (!pidString) {
        NSLog(@"[BaseAddressScript] 未选择进程");
        return 0;
    }

    pid_t pid = [pidString intValue];
    NSError *error = nil;
    if (![pointerManager attachToProcess:pid error:&error]) {
        NSLog(@"[BaseAddressScript] 附加进程失败: %@", error.localizedDescription);
        return 0;
    }

    uintptr_t currentAddress = 0;

    for (NSInteger i = 0; i < self.nodes.count; i++) {
        BaseAddressPointerNode *node = self.nodes[i];

        if (i == 0) {
            // 第一个节点，需要解析模块基址
            uintptr_t moduleBaseAddress = 0;

            if (node.moduleName.length > 0) {
                // 获取模块基址
                NSError *moduleError = nil;
                NSArray<ModuleInfo *> *modules = [pointerManager getModuleList:&moduleError];
                if (moduleError) {
                    return 0;
                }

                for (ModuleInfo *module in modules) {
                    if ([module.name isEqualToString:node.moduleName]) {
                        moduleBaseAddress = module.startAddress;
                        break;
                    }
                }

                if (moduleBaseAddress == 0) {
                    return 0;
                }
            } else {
                moduleBaseAddress = node.baseAddress;
            }

            currentAddress = moduleBaseAddress + node.offset;
        } else {
            // 后续节点，使用指针扫描管理器读取当前地址的指针值
            // 使用与记录界面相同的读取策略：先尝试8字节，失败后尝试4字节
            NSError *readError = nil;
            NSData *data = [pointerManager readMemory:currentAddress size:8 error:&readError];
            uint64_t pointerValue = 0;

            if (data && data.length >= 8) {
                pointerValue = *(uint64_t *)data.bytes;
            } else {
                // 尝试4字节读取
                data = [pointerManager readMemory:currentAddress size:4 error:&readError];
                if (data && data.length >= 4) {
                    pointerValue = *(uint32_t *)data.bytes;
                } else {
                    return 0;
                }
            }

            // 解析偏移量（支持负偏移）
            int64_t offset = (int64_t)node.offset;
            currentAddress = pointerValue + offset;
        }
    }

    return currentAddress;
}

- (BOOL)validateChain {
    // 验证指针链的有效性
    uintptr_t finalAddress = [self calculateFinalAddress];

    if (finalAddress == 0) {
        self.isValid = NO;
        return NO;
    }

    // 使用指针扫描管理器读取最终地址的值
    PointerScanManager *pointerManager = [PointerScanManager sharedManager];

    // 根据值类型确定读取大小
    size_t valueSize = 0;
    switch (self.valueType) {
        case VMMemValueTypeSignedByte:
        case VMMemValueTypeUnsignedByte:
            valueSize = 1;
            break;
        case VMMemValueTypeSignedShort:
        case VMMemValueTypeUnsignedShort:
            valueSize = 2;
            break;
        case VMMemValueTypeSignedInt:
        case VMMemValueTypeUnsignedInt:
        case VMMemValueTypeFloat:
            valueSize = 4;
            break;
        case VMMemValueTypeSignedLong:
        case VMMemValueTypeUnsignedLong:
        case VMMemValueTypeDouble:
            valueSize = 8;
            break;
        default:
            valueSize = 4;
            break;
    }

    // 尝试读取值
    NSError *error = nil;
    NSData *data = [pointerManager readMemory:finalAddress size:valueSize error:&error];

    if (data && data.length >= valueSize) {
        // 读取成功，更新当前值
        self.currentValue = [[VMTool share] formatValueWithData:(void *)data.bytes type:self.valueType];
        self.isValid = YES;
        self.lastValidated = [NSDate date];

        NSLog(@"[BaseAddressScript] 指针链验证成功: %@ = %@", self.name, self.currentValue);
        return YES;
    } else {
        NSLog(@"[BaseAddressScript] 指针链验证失败: %@, 地址: 0x%lX, error: %@",
              self.name, (unsigned long)finalAddress, error.localizedDescription);
        self.isValid = NO;
        return NO;
    }
}

- (NSString *)generateCode {
    NSMutableString *code = [[NSMutableString alloc] init];
    [code appendFormat:@"// 指针链: %@\n", self.name];
    
    for (NSInteger i = 0; i < self.nodes.count; i++) {
        BaseAddressPointerNode *node = self.nodes[i];
        if (i == 0) {
            [code appendFormat:@"uintptr_t addr%ld = %@_base + 0x%lX;\n", 
             (long)i, node.moduleName, (long)node.offset];
        } else {
            [code appendFormat:@"uintptr_t addr%ld = *(uintptr_t*)addr%ld + 0x%lX;\n", 
             (long)i, (long)(i-1), (long)node.offset];
        }
    }
    
    [code appendFormat:@"// 最终地址: addr%ld\n", (long)(self.nodes.count - 1)];
    return code;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.name forKey:@"name"];
    [coder encodeObject:self.nodes forKey:@"nodes"];
    [coder encodeInteger:self.valueType forKey:@"valueType"];
    [coder encodeObject:self.expectedValue forKey:@"expectedValue"];
    [coder encodeObject:self.currentValue forKey:@"currentValue"];
    [coder encodeBool:self.isValid forKey:@"isValid"];
    [coder encodeObject:self.lastValidated forKey:@"lastValidated"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _name = [coder decodeObjectOfClass:[NSString class] forKey:@"name"];

        // 正确解码 NSMutableArray，指定允许的类
        NSSet *allowedClasses = [NSSet setWithObjects:[NSMutableArray class], [BaseAddressPointerNode class], nil];
        _nodes = [coder decodeObjectOfClasses:allowedClasses forKey:@"nodes"];
        if (!_nodes) {
            _nodes = [[NSMutableArray alloc] init];
        }

        _valueType = [coder decodeIntegerForKey:@"valueType"];
        _expectedValue = [coder decodeObjectOfClass:[NSString class] forKey:@"expectedValue"];
        _currentValue = [coder decodeObjectOfClass:[NSString class] forKey:@"currentValue"];
        _isValid = [coder decodeBoolForKey:@"isValid"];
        _lastValidated = [coder decodeObjectOfClass:[NSDate class] forKey:@"lastValidated"];
    }
    return self;
}

// 获取显示用的期望值（加密脚本显示乱码）
- (NSString *)displayExpectedValue:(BOOL)isEncrypted {
    if (!isEncrypted) {
        return self.expectedValue ?: @"";
    }

    // 生成乱码期望值
    NSString *original = self.expectedValue ?: @"0";
    NSString *scrambled = @"";
    for (int i = 0; i < original.length; i++) {
        scrambled = [scrambled stringByAppendingString:@"█"];
    }
    return scrambled;
}

@end

@implementation BaseAddressScript

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithName:(NSString *)name type:(BaseAddressScriptType)type {
    self = [super init];
    if (self) {
        _scriptId = [[NSUUID UUID] UUIDString];
        _name = [name copy];
        _type = type;
        _status = BaseAddressScriptStatusInactive;
        _category = @"默认";
        _createdDate = [NSDate date];
        _modifiedDate = [NSDate date];
        _author = @"用户";
        _version = @"1.0";
        _pointerChains = [[NSMutableArray alloc] init];
        _autoExecute = NO;
        _executeInterval = 1.0;
    }
    return self;
}

- (void)addPointerChain:(BaseAddressPointerChain *)chain {
    [self.pointerChains addObject:chain];
    self.modifiedDate = [NSDate date];
}

- (void)removePointerChainAtIndex:(NSInteger)index {
    if (index >= 0 && index < self.pointerChains.count) {
        [self.pointerChains removeObjectAtIndex:index];
        self.modifiedDate = [NSDate date];
    }
}

- (BOOL)executeScript {
    NSLog(@"[BaseAddressScript] 开始执行脚本: %@", self.name);

    // 检查是否有选中的进程
    if (![ProcessManager sharedManager].selectedProcessPID) {
        NSLog(@"[BaseAddressScript] 执行失败: 未选择进程");
        self.status = BaseAddressScriptStatusError;
        return NO;
    }

    // 设置当前进程
    NSString *pidString = [ProcessManager sharedManager].selectedProcessPID;
    [[VMTool share] setPid:[pidString intValue] name:[ProcessManager sharedManager].selectedProcessName];

    BOOL success = YES;
    NSInteger successCount = 0;
    NSInteger totalCount = 0;

    // 执行所有指针链
    for (BaseAddressPointerChain *chain in self.pointerChains) {
        totalCount++;

        // 验证指针链
        if (![chain validateChain]) {
            NSLog(@"[BaseAddressScript] 指针链验证失败: %@", chain.name);
            success = NO;
            continue;
        }

        // 如果有期望值，则写入内存
        if (chain.expectedValue && chain.expectedValue.length > 0) {
            if ([self writeValueToChain:chain]) {
                successCount++;
                NSLog(@"[BaseAddressScript] 成功写入值到指针链: %@", chain.name);
            } else {
                NSLog(@"[BaseAddressScript] 写入值失败: %@", chain.name);
                success = NO;
            }
        } else {
            // 只验证，不写入
            successCount++;
            NSLog(@"[BaseAddressScript] 指针链验证通过: %@", chain.name);
        }
    }

    // 执行自定义代码（如果有）
    if (self.customCode && self.customCode.length > 0) {
        // TODO: 实现自定义代码执行
        NSLog(@"[BaseAddressScript] 自定义代码执行功能待实现");
    }

    // 更新状态
    if (success && successCount == totalCount) {
        self.status = BaseAddressScriptStatusActive;
        NSLog(@"[BaseAddressScript] 脚本执行成功: %@ (%ld/%ld)", self.name, (long)successCount, (long)totalCount);
    } else {
        self.status = BaseAddressScriptStatusError;
        NSLog(@"[BaseAddressScript] 脚本执行部分失败: %@ (%ld/%ld)", self.name, (long)successCount, (long)totalCount);
    }

    return success;
}

// 写入值到指针链
- (BOOL)writeValueToChain:(BaseAddressPointerChain *)chain {
    uintptr_t finalAddress = [chain calculateFinalAddress];
    if (finalAddress == 0) {
        return NO;
    }

    // 获取当前进程的task用于写入
    mach_port_t task = [[VMTool share] getTask];
    if (task == 0) {
        return NO;
    }

    // 根据值类型转换期望值
    void *valueData = NULL;
    size_t valueSize = 0;

    switch (chain.valueType) {
        case VMMemValueTypeSignedByte: {
            int8_t value = (int8_t)[chain.expectedValue intValue];
            valueData = malloc(sizeof(int8_t));
            memcpy(valueData, &value, sizeof(int8_t));
            valueSize = sizeof(int8_t);
            break;
        }
        case VMMemValueTypeUnsignedByte: {
            uint8_t value = (uint8_t)[chain.expectedValue intValue];
            valueData = malloc(sizeof(uint8_t));
            memcpy(valueData, &value, sizeof(uint8_t));
            valueSize = sizeof(uint8_t);
            break;
        }
        case VMMemValueTypeSignedShort: {
            int16_t value = (int16_t)[chain.expectedValue intValue];
            valueData = malloc(sizeof(int16_t));
            memcpy(valueData, &value, sizeof(int16_t));
            valueSize = sizeof(int16_t);
            break;
        }
        case VMMemValueTypeUnsignedShort: {
            uint16_t value = (uint16_t)[chain.expectedValue intValue];
            valueData = malloc(sizeof(uint16_t));
            memcpy(valueData, &value, sizeof(uint16_t));
            valueSize = sizeof(uint16_t);
            break;
        }
        case VMMemValueTypeSignedInt: {
            int32_t value = (int32_t)[chain.expectedValue intValue];
            valueData = malloc(sizeof(int32_t));
            memcpy(valueData, &value, sizeof(int32_t));
            valueSize = sizeof(int32_t);
            break;
        }
        case VMMemValueTypeUnsignedInt: {
            uint32_t value = (uint32_t)[chain.expectedValue longLongValue];
            valueData = malloc(sizeof(uint32_t));
            memcpy(valueData, &value, sizeof(uint32_t));
            valueSize = sizeof(uint32_t);
            break;
        }
        case VMMemValueTypeSignedLong: {
            int64_t value = (int64_t)[chain.expectedValue longLongValue];
            valueData = malloc(sizeof(int64_t));
            memcpy(valueData, &value, sizeof(int64_t));
            valueSize = sizeof(int64_t);
            break;
        }
        case VMMemValueTypeUnsignedLong: {
            uint64_t value = (uint64_t)[chain.expectedValue longLongValue];
            valueData = malloc(sizeof(uint64_t));
            memcpy(valueData, &value, sizeof(uint64_t));
            valueSize = sizeof(uint64_t);
            break;
        }
        case VMMemValueTypeFloat: {
            float value = [chain.expectedValue floatValue];
            valueData = malloc(sizeof(float));
            memcpy(valueData, &value, sizeof(float));
            valueSize = sizeof(float);
            break;
        }
        case VMMemValueTypeDouble: {
            double value = [chain.expectedValue doubleValue];
            valueData = malloc(sizeof(double));
            memcpy(valueData, &value, sizeof(double));
            valueSize = sizeof(double);
            break;
        }
        default:
            return NO;
    }

    if (!valueData) {
        return NO;
    }

    // 写入内存
    int result = write_mem(task, finalAddress, valueData, (int)valueSize);
    free(valueData);

    if (result == 1) {
        NSLog(@"[BaseAddressScript] 成功写入值 %@ 到地址 0x%lX",
              chain.expectedValue, (unsigned long)finalAddress);
        return YES;
    } else {
        NSLog(@"[BaseAddressScript] 写入值失败: 地址 0x%lX, 值 %@",
              (unsigned long)finalAddress, chain.expectedValue);
        return NO;
    }
}

- (BOOL)validateScript {
    // 验证脚本的有效性
    if (self.pointerChains.count == 0 && !self.customCode) {
        return NO;
    }
    
    for (BaseAddressPointerChain *chain in self.pointerChains) {
        if (![chain validateChain]) {
            return NO;
        }
    }
    
    return YES;
}

- (NSString *)exportToString {
    // 如果是加密脚本，返回错误信息而不是真实内容
    if (self.isEncrypted) {
        NSMutableDictionary *exportData = [[NSMutableDictionary alloc] init];

        exportData[@"scriptId"] = self.scriptId;
        exportData[@"name"] = self.name;
        exportData[@"description"] = @"🔒 此脚本已加密，无法查看详细内容";
        exportData[@"type"] = @(self.type);
        exportData[@"category"] = self.category;
        exportData[@"targetProcess"] = @"🔒 已加密";
        exportData[@"author"] = self.author;
        exportData[@"version"] = self.version;
        exportData[@"customCode"] = @"🔒 已加密";

        // 指针链显示为加密状态
        exportData[@"pointerChains"] = @[@"🔒 加密内容，无法查看"];
        exportData[@"encrypted"] = @YES;

        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:exportData
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:&error];

        if (error) {
            return nil;
        }

        return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }

    // 普通脚本正常导出
    NSMutableDictionary *exportData = [[NSMutableDictionary alloc] init];

    exportData[@"scriptId"] = self.scriptId;
    exportData[@"name"] = self.name;
    exportData[@"description"] = self.scriptDescription ?: @"";
    exportData[@"type"] = @(self.type);
    exportData[@"category"] = self.category;
    exportData[@"targetProcess"] = self.targetProcess ?: @"";
    exportData[@"author"] = self.author;
    exportData[@"version"] = self.version;
    exportData[@"customCode"] = self.customCode ?: @"";

    // 导出指针链
    NSMutableArray *chainsData = [[NSMutableArray alloc] init];
    for (BaseAddressPointerChain *chain in self.pointerChains) {
        NSData *chainData = [NSKeyedArchiver archivedDataWithRootObject:chain
                                                  requiringSecureCoding:YES
                                                                  error:nil];
        if (chainData) {
            [chainsData addObject:[chainData base64EncodedStringWithOptions:0]];
        }
    }
    exportData[@"pointerChains"] = chainsData;

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:exportData
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];

    if (error) {
        return nil;
    }

    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (NSString *)exportToStringWithEncryption:(BOOL)encrypted password:(NSString *)password {
    NSMutableDictionary *exportData = [[NSMutableDictionary alloc] init];

    exportData[@"scriptId"] = self.scriptId;
    exportData[@"name"] = self.name;
    exportData[@"description"] = self.scriptDescription ?: @"";
    exportData[@"type"] = @(self.type);
    exportData[@"category"] = self.category;
    exportData[@"targetProcess"] = self.targetProcess ?: @"";
    exportData[@"author"] = self.author;
    exportData[@"version"] = self.version;
    exportData[@"customCode"] = self.customCode ?: @"";

    // 导出指针链
    NSMutableArray *chainsData = [[NSMutableArray alloc] init];
    for (BaseAddressPointerChain *chain in self.pointerChains) {
        NSData *chainData = [NSKeyedArchiver archivedDataWithRootObject:chain
                                                  requiringSecureCoding:YES
                                                                  error:nil];
        if (chainData) {
            NSString *chainString = [chainData base64EncodedStringWithOptions:0];

            // 如果需要加密，对指针链数据进行加密
            if (encrypted && password.length > 0) {
                chainString = [self encryptPointerChainData:chainString withPassword:password];
            }

            [chainsData addObject:chainString];
        }
    }
    exportData[@"pointerChains"] = chainsData;

    // 添加加密标识（保持原有的加密状态或新的加密状态）
    if (encrypted || self.isEncrypted) {
        exportData[@"encrypted"] = @YES;
    }

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:exportData
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];

    if (error) {
        return nil;
    }

    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

// 加密指针链数据
- (NSString *)encryptPointerChainData:(NSString *)data withPassword:(NSString *)password {
    if (!data || !password) return data;

    NSData *dataBytes = [data dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *encryptedData = [NSMutableData dataWithLength:dataBytes.length];

    const char *passwordBytes = [password UTF8String];
    NSUInteger passwordLength = strlen(passwordBytes);

    const uint8_t *inputBytes = dataBytes.bytes;
    uint8_t *outputBytes = encryptedData.mutableBytes;

    // 简单的XOR加密
    for (NSUInteger i = 0; i < dataBytes.length; i++) {
        outputBytes[i] = inputBytes[i] ^ passwordBytes[i % passwordLength];
    }

    return [encryptedData base64EncodedStringWithOptions:0];
}

- (BOOL)importFromString:(NSString *)scriptString {
    NSError *error;
    NSData *jsonData = [scriptString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *importData = [NSJSONSerialization JSONObjectWithData:jsonData 
                                                               options:0 
                                                                 error:&error];
    
    if (error || !importData) {
        return NO;
    }
    
    // 导入基本信息
    self.scriptId = importData[@"scriptId"] ?: [[NSUUID UUID] UUIDString];
    self.name = importData[@"name"] ?: @"未命名脚本";
    self.scriptDescription = importData[@"description"];
    self.type = [importData[@"type"] integerValue];
    self.category = importData[@"category"] ?: @"默认";
    self.targetProcess = importData[@"targetProcess"];
    self.author = importData[@"author"] ?: @"未知";
    self.version = importData[@"version"] ?: @"1.0";
    self.customCode = importData[@"customCode"];
    
    // 导入指针链
    [self.pointerChains removeAllObjects];
    NSArray *chainsData = importData[@"pointerChains"];
    for (NSString *chainDataString in chainsData) {
        NSData *chainData = [[NSData alloc] initWithBase64EncodedString:chainDataString options:0];
        if (chainData) {
            BaseAddressPointerChain *chain = [NSKeyedUnarchiver unarchivedObjectOfClass:[BaseAddressPointerChain class]
                                                                    fromData:chainData
                                                                       error:nil];
            if (chain) {
                [self.pointerChains addObject:chain];
            }
        }
    }
    
    self.modifiedDate = [NSDate date];
    return YES;
}

- (BOOL)importFromString:(NSString *)scriptString withPassword:(NSString *)password {
    if (!scriptString) return NO;

    NSError *error;
    NSData *jsonData = [scriptString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *importData = [NSJSONSerialization JSONObjectWithData:jsonData
                                                               options:0
                                                                 error:&error];

    if (error || !importData) {
        return NO;
    }

    // 检查是否为加密脚本
    BOOL isEncrypted = [importData[@"encrypted"] boolValue];

    // 导入基本信息
    self.scriptId = importData[@"scriptId"] ?: [[NSUUID UUID] UUIDString];
    self.name = importData[@"name"] ?: @"未命名脚本";
    self.scriptDescription = importData[@"description"];
    self.type = [importData[@"type"] integerValue];
    self.category = importData[@"category"] ?: @"默认";
    self.targetProcess = importData[@"targetProcess"];
    self.author = importData[@"author"] ?: @"未知";
    self.version = importData[@"version"] ?: @"1.0";
    self.customCode = importData[@"customCode"];

    // 标记加密状态 - 如果是通过密码导入的，强制标记为加密
    self.isEncrypted = YES;  // 通过密码导入的脚本必须保持加密状态

    // 导入指针链
    [self.pointerChains removeAllObjects];
    NSArray *chainsData = importData[@"pointerChains"];
    for (NSString *originalChainDataString in chainsData) {

        NSString *chainDataString = originalChainDataString;

        // 如果是加密脚本，需要解密指针链数据
        if (isEncrypted && password.length > 0) {
            chainDataString = [self decryptPointerChainData:chainDataString withPassword:password];
            if (!chainDataString) {
                NSLog(@"[BaseAddressScript] 指针链解密失败");
                continue;
            }
        }

        NSData *chainData = [[NSData alloc] initWithBase64EncodedString:chainDataString options:0];
        if (chainData) {
            BaseAddressPointerChain *chain = [NSKeyedUnarchiver unarchivedObjectOfClass:[BaseAddressPointerChain class]
                                                                    fromData:chainData
                                                                       error:nil];
            if (chain) {
                [self.pointerChains addObject:chain];
            }
        }
    }

    self.modifiedDate = [NSDate date];
    return YES;
}

// 解密指针链数据
- (NSString *)decryptPointerChainData:(NSString *)encryptedData withPassword:(NSString *)password {
    if (!encryptedData || !password) return nil;

    NSData *encryptedBytes = [[NSData alloc] initWithBase64EncodedString:encryptedData options:0];
    if (!encryptedBytes) return nil;

    NSMutableData *decryptedData = [NSMutableData dataWithLength:encryptedBytes.length];

    const char *passwordBytes = [password UTF8String];
    NSUInteger passwordLength = strlen(passwordBytes);

    const uint8_t *inputBytes = encryptedBytes.bytes;
    uint8_t *outputBytes = decryptedData.mutableBytes;

    // XOR解密
    for (NSUInteger i = 0; i < encryptedBytes.length; i++) {
        outputBytes[i] = inputBytes[i] ^ passwordBytes[i % passwordLength];
    }

    return [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.scriptId forKey:@"scriptId"];
    [coder encodeObject:self.name forKey:@"name"];
    [coder encodeObject:self.scriptDescription forKey:@"scriptDescription"];
    [coder encodeInteger:self.type forKey:@"type"];
    [coder encodeInteger:self.status forKey:@"status"];
    [coder encodeObject:self.category forKey:@"category"];
    [coder encodeObject:self.targetProcess forKey:@"targetProcess"];
    [coder encodeObject:self.createdDate forKey:@"createdDate"];
    [coder encodeObject:self.modifiedDate forKey:@"modifiedDate"];
    [coder encodeObject:self.author forKey:@"author"];
    [coder encodeObject:self.version forKey:@"version"];
    [coder encodeObject:self.pointerChains forKey:@"pointerChains"];
    [coder encodeObject:self.customCode forKey:@"customCode"];
    [coder encodeBool:self.autoExecute forKey:@"autoExecute"];
    [coder encodeDouble:self.executeInterval forKey:@"executeInterval"];
    [coder encodeBool:self.isEncrypted forKey:@"isEncrypted"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _scriptId = [coder decodeObjectOfClass:[NSString class] forKey:@"scriptId"];
        _name = [coder decodeObjectOfClass:[NSString class] forKey:@"name"];
        _scriptDescription = [coder decodeObjectOfClass:[NSString class] forKey:@"scriptDescription"];
        _type = [coder decodeIntegerForKey:@"type"];
        _status = [coder decodeIntegerForKey:@"status"];
        _category = [coder decodeObjectOfClass:[NSString class] forKey:@"category"];
        _targetProcess = [coder decodeObjectOfClass:[NSString class] forKey:@"targetProcess"];
        _createdDate = [coder decodeObjectOfClass:[NSDate class] forKey:@"createdDate"];
        _modifiedDate = [coder decodeObjectOfClass:[NSDate class] forKey:@"modifiedDate"];
        _author = [coder decodeObjectOfClass:[NSString class] forKey:@"author"];
        _version = [coder decodeObjectOfClass:[NSString class] forKey:@"version"];

        // 正确解码指针链数组
        NSSet *allowedClasses = [NSSet setWithObjects:[NSMutableArray class], [BaseAddressPointerChain class], nil];
        _pointerChains = [coder decodeObjectOfClasses:allowedClasses forKey:@"pointerChains"];
        if (!_pointerChains) {
            _pointerChains = [[NSMutableArray alloc] init];
        }

        _customCode = [coder decodeObjectOfClass:[NSString class] forKey:@"customCode"];
        _autoExecute = [coder decodeBoolForKey:@"autoExecute"];
        _executeInterval = [coder decodeDoubleForKey:@"executeInterval"];
        _isEncrypted = [coder decodeBoolForKey:@"isEncrypted"];
    }
    return self;
}

@end
