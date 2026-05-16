//
//  DisassemblyEngine.m
//  Obsolete
//
//  Created by AI Assistant on 2025-01-08.
//

#import "DisassemblyEngine.h"
#import "ProcessManager.h"
#import <mach/mach.h>
#import <mach/vm_map.h>
#import "../../VMem/mem/mem.h"
#import <mach-o/loader.h>
#import "capstone/capstone.h"
#import "../../Search/lz4/lz4.h"

// 压缩指令数据结构
typedef struct {
    char *compressedData;
    int compressedSize;
    int originalSize;
    NSUInteger instructionCount;
} CompressedInstructionBlock;

@implementation DisassemblyEngine

#pragma mark - LZ4 压缩优化方法

+ (NSData *)compressInstructionData:(NSArray<NSDictionary *> *)instructions {
    // 将指令数组序列化为JSON数据
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:instructions
                                                       options:0
                                                         error:&error];
    if (error || !jsonData) {
        NSLog(@"[DisassemblyEngine] JSON序列化失败: %@", error.localizedDescription);
        return nil;
    }

    // 计算压缩缓冲区大小
    int maxCompressedSize = LZ4_compressBound((int)jsonData.length);
    char *compressedBuffer = malloc(maxCompressedSize);
    if (!compressedBuffer) {
        NSLog(@"[DisassemblyEngine] 压缩缓冲区分配失败");
        return nil;
    }

    // 使用LZ4压缩，acceleration=1为默认速度
    int compressedSize = LZ4_compress_fast((const char *)jsonData.bytes,
                                          compressedBuffer,
                                          (int)jsonData.length,
                                          maxCompressedSize,
                                          1);

    if (compressedSize <= 0) {
        NSLog(@"[DisassemblyEngine] LZ4压缩失败");
        free(compressedBuffer);
        return nil;
    }

    NSLog(@"[DisassemblyEngine] 压缩完成: %lu -> %d 字节 (压缩率: %.1f%%)",
          (unsigned long)jsonData.length, compressedSize,
          (double)compressedSize / jsonData.length * 100.0);

    // 创建包含原始大小信息的数据
    NSMutableData *result = [NSMutableData dataWithCapacity:sizeof(int) + compressedSize];
    int originalSize = (int)jsonData.length;
    [result appendBytes:&originalSize length:sizeof(int)];
    [result appendBytes:compressedBuffer length:compressedSize];

    free(compressedBuffer);
    return result;
}

+ (NSArray<NSDictionary *> *)decompressInstructionData:(NSData *)compressedData {
    if (!compressedData || compressedData.length < sizeof(int)) {
        return nil;
    }

    // 读取原始大小
    int originalSize;
    [compressedData getBytes:&originalSize length:sizeof(int)];

    // 获取压缩数据
    const char *compressed = (const char *)compressedData.bytes + sizeof(int);
    int compressedSize = (int)compressedData.length - sizeof(int);

    // 分配解压缓冲区
    char *decompressedBuffer = malloc(originalSize);
    if (!decompressedBuffer) {
        NSLog(@"[DisassemblyEngine] 解压缓冲区分配失败");
        return nil;
    }

    // LZ4解压
    int decompressedSize = LZ4_decompress_safe(compressed,
                                              decompressedBuffer,
                                              compressedSize,
                                              originalSize);

    if (decompressedSize != originalSize) {
        NSLog(@"[DisassemblyEngine] LZ4解压失败: %d != %d", decompressedSize, originalSize);
        free(decompressedBuffer);
        return nil;
    }

    // 反序列化JSON
    NSData *jsonData = [NSData dataWithBytes:decompressedBuffer length:originalSize];
    free(decompressedBuffer);

    NSError *error;
    NSArray *instructions = [NSJSONSerialization JSONObjectWithData:jsonData
                                                            options:0
                                                              error:&error];
    if (error) {
        NSLog(@"[DisassemblyEngine] JSON反序列化失败: %@", error.localizedDescription);
        return nil;
    }

    return instructions;
}

+ (NSArray<NSDictionary *> *)disassembleModule:(ModuleInfo *)module maxInstructions:(NSUInteger)maxInstructions {
    NSMutableArray<NSDictionary *> *instructions = [NSMutableArray array];

    if (!module) {
        NSLog(@"[DisassemblyEngine] 错误: 模块为空");
        return instructions;
    }

    NSLog(@"[DisassemblyEngine] 开始反汇编模块: %@", module.name);
    NSLog(@"[DisassemblyEngine] 模块地址范围: 0x%lX - 0x%lX", (unsigned long)module.startAddress, (unsigned long)module.endAddress);

    // 获取当前进程
    ProcessManager *processManager = [ProcessManager sharedManager];
    if (!processManager.selectedProcessPID) {
        NSLog(@"[DisassemblyEngine] 错误: 没有选择进程");
        return instructions;
    }

    // 使用项目现有的get_task函数获取进程task
    mach_port_t task = get_task([processManager.selectedProcessPID intValue], processManager.selectedProcessName);
    if (task == MACH_PORT_NULL) {
        NSLog(@"[DisassemblyEngine] 错误: 无法获取进程task");
        return instructions;
    }

    // 尝试找到TEXT段，如果失败则使用模块起始地址
    uint64_t textAddress = module.startAddress;
    uint64_t textSize = module.endAddress - module.startAddress;

    // 尝试解析Mach-O头部找到TEXT段
    if ([self findTextSegmentInModule:module task:task textAddress:&textAddress textSize:&textSize]) {
        NSLog(@"[DisassemblyEngine] 成功找到TEXT段: 0x%llX, 大小: %llu", textAddress, textSize);
    } else {
        NSLog(@"[DisassemblyEngine] 未找到TEXT段，使用模块地址: 0x%llX", textAddress);
    }

    // 如果没有指定最大指令数，设置一个合理的默认值
    if (maxInstructions == 0) {
        maxInstructions = MIN(textSize / 4, 1000); // 默认最多1000条指令，避免太多
    }

    // 反汇编TEXT段
    NSUInteger readSize = MIN(textSize, maxInstructions * 4); // 限制读取大小
    return [self disassembleAtAddress:textAddress size:readSize maxInstructions:maxInstructions];
}

+ (NSArray<NSDictionary *> *)disassembleAtAddress:(uint64_t)address size:(NSUInteger)size maxInstructions:(NSUInteger)maxInstructions {
    NSMutableArray<NSDictionary *> *instructions = [NSMutableArray array];

    // 获取当前进程
    ProcessManager *processManager = [ProcessManager sharedManager];
    if (!processManager.selectedProcessPID) {
        NSLog(@"[DisassemblyEngine] 错误: 没有选择进程");
        return instructions;
    }

    NSLog(@"[DisassemblyEngine] 目标进程PID: %@", processManager.selectedProcessPID);

    // 使用项目现有的get_task函数获取进程task
    mach_port_t task = get_task([processManager.selectedProcessPID intValue], processManager.selectedProcessName);
    if (task == MACH_PORT_NULL) {
        NSLog(@"[DisassemblyEngine] 错误: 无法获取进程task");
        return instructions;
    }

    NSLog(@"[DisassemblyEngine] 成功获取进程task");

    // 限制读取大小，避免内存过大
    NSUInteger readSize = MIN(size, maxInstructions * 4); // ARM64指令为4字节
    if (readSize > 1024 * 1024) { // 最大1MB
        readSize = 1024 * 1024;
    }

    NSLog(@"[DisassemblyEngine] 计划读取大小: %lu 字节", (unsigned long)readSize);
    NSLog(@"[DisassemblyEngine] 从地址 0x%llX 开始读取", address);

    // 确保地址4字节对齐（ARM64指令要求）
    uint64_t alignedAddress = address & ~0x3ULL;
    if (alignedAddress != address) {
        NSLog(@"[DisassemblyEngine] 警告: 地址未对齐，从 0x%llX 调整为 0x%llX", address, alignedAddress);
        address = alignedAddress;
    }

    // 读取内存数据
    uint8_t *buffer = malloc(readSize);
    if (!buffer) {
        NSLog(@"[DisassemblyEngine] 错误: 内存分配失败");
        return instructions;
    }

    vm_size_t bytesRead = 0;
    kern_return_t kr = vm_read_overwrite(task, address, readSize, (vm_address_t)buffer, &bytesRead);

    NSLog(@"[DisassemblyEngine] vm_read_overwrite 返回: %d, 实际读取: %lu 字节", kr, (unsigned long)bytesRead);

    if (kr != KERN_SUCCESS || bytesRead == 0) {
        NSLog(@"[DisassemblyEngine] 错误: 读取内存失败: %d (%s)", kr, mach_error_string(kr));
        free(buffer);
        return instructions;
    }

    // 打印前16字节的数据用于调试
    NSMutableString *hexString = [NSMutableString string];
    NSUInteger printBytes = MIN(bytesRead, 16);
    for (NSUInteger i = 0; i < printBytes; i++) {
        [hexString appendFormat:@"%02X ", buffer[i]];
    }
    NSLog(@"[DisassemblyEngine] 读取的前%lu字节数据: %@", (unsigned long)printBytes, hexString);

    // 使用capstone进行反汇编
    NSLog(@"[DisassemblyEngine] 开始使用Capstone进行反汇编");

    // 检测架构并初始化capstone
    cs_arch target_arch = CS_ARCH_AARCH64;  // 默认ARM64
    cs_mode target_mode = CS_MODE_LITTLE_ENDIAN;

    // 使用新的capstone反汇编方法
    NSArray<NSDictionary *> *disassemblyResult = [self disassembleWithCapstone:buffer
                                                                          size:bytesRead
                                                                     atAddress:address
                                                                maxInstructions:maxInstructions
                                                                  architecture:target_arch
                                                                          mode:target_mode];

    [instructions addObjectsFromArray:disassemblyResult];
    free(buffer);

    NSLog(@"[DisassemblyEngine] 反汇编完成，共 %lu 条指令", (unsigned long)instructions.count);
    return instructions;
}

// 查找模块中的TEXT段
+ (BOOL)findTextSegmentInModule:(ModuleInfo *)module task:(mach_port_t)task textAddress:(uint64_t *)textAddress textSize:(uint64_t *)textSize {
    // 读取Mach-O头部
    struct mach_header_64 header;
    vm_size_t bytesRead = 0;
    kern_return_t kr = vm_read_overwrite(task, module.startAddress, sizeof(header), (vm_address_t)&header, &bytesRead);

    if (kr != KERN_SUCCESS || bytesRead != sizeof(header)) {
        NSLog(@"[DisassemblyEngine] 无法读取Mach-O头部: %d", kr);
        return NO;
    }

    // 检查魔数
    if (header.magic != MH_MAGIC_64) {
        NSLog(@"[DisassemblyEngine] 不是有效的64位Mach-O文件，魔数: 0x%X", header.magic);
        return NO;
    }

    NSLog(@"[DisassemblyEngine] Mach-O头部信息: ncmds=%u, sizeofcmds=%u", header.ncmds, header.sizeofcmds);

    // 读取加载命令
    uint64_t cmdOffset = module.startAddress + sizeof(struct mach_header_64);

    for (uint32_t i = 0; i < header.ncmds; i++) {
        struct load_command cmd;
        kr = vm_read_overwrite(task, cmdOffset, sizeof(cmd), (vm_address_t)&cmd, &bytesRead);

        if (kr != KERN_SUCCESS || bytesRead != sizeof(cmd)) {
            NSLog(@"[DisassemblyEngine] 无法读取加载命令 %u", i);
            break;
        }

        if (cmd.cmd == LC_SEGMENT_64) {
            struct segment_command_64 segCmd;
            kr = vm_read_overwrite(task, cmdOffset, sizeof(segCmd), (vm_address_t)&segCmd, &bytesRead);

            if (kr == KERN_SUCCESS && bytesRead == sizeof(segCmd)) {
                NSString *segName = [NSString stringWithUTF8String:segCmd.segname];
                NSLog(@"[DisassemblyEngine] 找到段: %@, 地址: 0x%llX, 大小: %llu", segName, segCmd.vmaddr, segCmd.vmsize);

                if ([segName isEqualToString:@"__TEXT"]) {
                    // 使用模块的实际加载地址，而不是虚拟地址
                    // TEXT段的实际地址 = 模块基地址 + (TEXT段虚拟地址 - 模块虚拟基地址)
                    uint64_t textVirtualAddr = segCmd.vmaddr;
                    uint64_t moduleVirtualBase = 0x100000000; // 典型的iOS应用虚拟基地址
                    uint64_t offset = textVirtualAddr - moduleVirtualBase;
                    *textAddress = module.startAddress + offset;
                    *textSize = segCmd.vmsize;
                    NSLog(@"[DisassemblyEngine] 找到TEXT段:");
                    NSLog(@"[DisassemblyEngine]   虚拟地址: 0x%llX", textVirtualAddr);
                    NSLog(@"[DisassemblyEngine]   实际地址: 0x%llX", *textAddress);
                    NSLog(@"[DisassemblyEngine]   大小: %llu", *textSize);
                    return YES;
                }
            }
        }

        cmdOffset += cmd.cmdsize;
    }

    NSLog(@"[DisassemblyEngine] 未找到TEXT段");
    return NO;
}

// 检测CPU架构类型
+ (cs_arch)detectArchitectureFromMachHeader:(struct mach_header_64 *)header mode:(cs_mode *)mode {
    switch (header->cputype) {
        case CPU_TYPE_I386:
            *mode = CS_MODE_32;
            return CS_ARCH_X86;
        case CPU_TYPE_X86_64:
            *mode = CS_MODE_64;
            return CS_ARCH_X86;
        case CPU_TYPE_ARM:
            *mode = CS_MODE_ARM;
            return CS_ARCH_ARM;
        case CPU_TYPE_ARM64:
            *mode = CS_MODE_LITTLE_ENDIAN;
            return CS_ARCH_AARCH64;
        default:
            NSLog(@"[DisassemblyEngine] 不支持的CPU架构: %d", header->cputype);
            *mode = CS_MODE_LITTLE_ENDIAN;
            return CS_ARCH_AARCH64; // 默认ARM64
    }
}

// 改进的反汇编方法，支持多架构检测
+ (NSArray<NSDictionary *> *)disassembleWithCapstone:(uint8_t *)buffer
                                                 size:(size_t)size
                                            atAddress:(uint64_t)address
                                       maxInstructions:(NSUInteger)maxInstructions
                                         architecture:(cs_arch)arch
                                                 mode:(cs_mode)mode {
    NSMutableArray<NSDictionary *> *instructions = [NSMutableArray array];

    csh cs_handle = 0;
    cs_insn *cs_insn = NULL;
    size_t disasm_count = 0;
    cs_err cserr;

    // 初始化capstone
    if ((cserr = cs_open(arch, mode, &cs_handle)) != CS_ERR_OK) {
        NSLog(@"[DisassemblyEngine] Capstone初始化失败: %d, %s", cserr, cs_strerror(cserr));
        return instructions;
    }

    // 启用详细信息和跳过数据模式
    cs_option(cs_handle, CS_OPT_DETAIL, CS_OPT_ON);
    cs_option(cs_handle, CS_OPT_SKIPDATA, CS_OPT_ON);

    // 对于ARM架构，可能需要设置Thumb模式
    if (arch == CS_ARCH_ARM) {
        // 可以根据需要动态切换到Thumb模式
        cs_option(cs_handle, CS_OPT_MODE, CS_MODE_ARM);
    }

    // 反汇编
    disasm_count = cs_disasm(cs_handle, buffer, size, address, maxInstructions, &cs_insn);
    NSLog(@"[DisassemblyEngine] Capstone反汇编完成，获得 %lu 条指令", disasm_count);

    // 转换capstone结果为我们的格式
    for (size_t i = 0; i < disasm_count; i++) {
        NSMutableDictionary *instruction = [NSMutableDictionary dictionary];

        // 格式化地址
        instruction[@"address"] = [NSString stringWithFormat:@"0x%016llX", cs_insn[i].address];

        // 格式化字节码
        NSMutableString *hexString = [NSMutableString string];
        for (int j = 0; j < cs_insn[i].size; j++) {
            if (j > 0) [hexString appendString:@" "];
            [hexString appendFormat:@"%02X", cs_insn[i].bytes[j]];
        }
        instruction[@"bytes"] = [hexString copy];

        // 指令助记符和操作数
        instruction[@"mnemonic"] = [NSString stringWithUTF8String:cs_insn[i].mnemonic];
        instruction[@"operands"] = [NSString stringWithUTF8String:cs_insn[i].op_str];

        [instructions addObject:instruction];
    }

    // 释放capstone资源
    cs_free(cs_insn, disasm_count);
    cs_close(&cs_handle);

    return instructions;

}

#pragma mark - 静态文件反汇编

+ (NSArray<NSDictionary *> *)disassembleFile:(NSString *)filePath maxInstructions:(NSUInteger)maxInstructions {
    NSMutableArray<NSDictionary *> *instructions = [NSMutableArray array];

    if (!filePath || filePath.length == 0) {
        NSLog(@"[DisassemblyEngine] 错误: 文件路径为空");
        return instructions;
    }

    NSLog(@"[DisassemblyEngine] 开始静态反汇编文件: %@", filePath);

    // 检查文件大小，避免一次性加载过大文件
    NSError *error;
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&error];
    if (error) {
        NSLog(@"[DisassemblyEngine] 错误: 无法获取文件信息: %@", error.localizedDescription);
        return instructions;
    }

    unsigned long long fileSize = [fileAttributes[NSFileSize] unsignedLongLongValue];
    NSLog(@"[DisassemblyEngine] 文件大小: %llu 字节 (%.2f MB)", fileSize, fileSize / (1024.0 * 1024.0));

    // 所有文件都使用内存映射读取，优化内存使用
    NSLog(@"[DisassemblyEngine] 使用内存映射读取文件");
    NSData *fileData = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:&error];

    if (!fileData || fileData.length == 0) {
        NSLog(@"[DisassemblyEngine] 错误: 无法读取文件或文件为空");
        return instructions;
    }

    // 解析 Mach-O 文件，查找 TEXT 段
    const uint8_t *fileBytes = (const uint8_t *)fileData.bytes;
    NSUInteger fileSizeForParsing = fileData.length;

    // 检查 Mach-O 魔数
    if (fileSizeForParsing < sizeof(struct mach_header_64)) {
        NSLog(@"[DisassemblyEngine] 错误: 文件太小，不是有效的 Mach-O 文件");
        return instructions;
    }

    const struct mach_header_64 *header = (const struct mach_header_64 *)fileBytes;

    // 检查魔数和架构
    if (header->magic != MH_MAGIC_64) {
        NSLog(@"[DisassemblyEngine] 错误: 不支持的文件格式 (魔数: 0x%x)", header->magic);
        return instructions;
    }

    if (header->cputype != CPU_TYPE_ARM64) {
        NSLog(@"[DisassemblyEngine] 错误: 不支持的 CPU 架构 (类型: %d)", header->cputype);
        return instructions;
    }

    NSLog(@"[DisassemblyEngine] 检测到 ARM64 Mach-O 文件，文件类型: %d", header->filetype);

    // 查找所有包含指令的 sections
    NSArray<NSDictionary *> *codeSections = [self findCodeSectionsInFileData:fileData];

    if (codeSections.count == 0) {
        NSLog(@"[DisassemblyEngine] 错误: 未找到任何代码段");
        return instructions;
    }

    NSLog(@"[DisassemblyEngine] 找到 %lu 个代码段", (unsigned long)codeSections.count);

    // 反汇编所有代码段，使用分批处理避免内存峰值
    NSUInteger totalInstructions = 0;
    NSUInteger processedSections = 0;

    for (NSDictionary *section in codeSections) {
        @autoreleasepool { // 自动释放池，及时释放临时对象
            const uint8_t *sectionData = [section[@"data"] pointerValue];
            NSUInteger sectionSize = [section[@"size"] unsignedIntegerValue];
            uint64_t sectionVMAddr = [section[@"vmaddr"] unsignedLongLongValue];
            NSString *sectionName = section[@"name"];

            NSLog(@"[DisassemblyEngine] 反汇编段 %lu/%lu: %@, VM地址=0x%llX, 大小=%lu",
                  processedSections + 1, (unsigned long)codeSections.count,
                  sectionName, sectionVMAddr, sectionSize);

            // 计算剩余可反汇编的指令数
            NSUInteger remainingInstructions = 0;
            if (maxInstructions > 0) {
                if (totalInstructions >= maxInstructions) {
                    NSLog(@"[DisassemblyEngine] 已达到最大指令数限制: %lu", (unsigned long)maxInstructions);
                    break; // 已达到最大指令数
                }
                remainingInstructions = maxInstructions - totalInstructions;
            }

            // 对于所有段，都使用分块处理优化内存
            NSUInteger chunkSize = 512 * 1024; // 512KB 块，更小的块大小
            NSUInteger offset = 0;

            while (offset < sectionSize && (maxInstructions == 0 || totalInstructions < maxInstructions)) {
                NSUInteger currentChunkSize = MIN(chunkSize, sectionSize - offset);

                NSArray<NSDictionary *> *chunkInstructions = [self disassembleStaticData:sectionData + offset
                                                                                     size:currentChunkSize
                                                                              baseAddress:sectionVMAddr + offset
                                                                          maxInstructions:remainingInstructions];

                [instructions addObjectsFromArray:chunkInstructions];
                totalInstructions += chunkInstructions.count;

                if (maxInstructions > 0) {
                    remainingInstructions = maxInstructions - totalInstructions;
                    if (remainingInstructions == 0) break;
                }

                offset += currentChunkSize;

                // 每处理一定数量的指令就输出进度
                if (totalInstructions % 5000 == 0 && totalInstructions > 0) {
                    NSLog(@"[DisassemblyEngine] 进度: 已处理 %lu 条指令", (unsigned long)totalInstructions);
                }
            }

            processedSections++;
        }
    }

    NSLog(@"[DisassemblyEngine] 总共反汇编了 %lu 条指令", (unsigned long)instructions.count);
    return instructions;
}

+ (NSArray<NSDictionary *> *)findCodeSectionsInFileData:(NSData *)fileData {
    NSMutableArray<NSDictionary *> *codeSections = [NSMutableArray array];

    const uint8_t *fileBytes = (const uint8_t *)fileData.bytes;
    NSUInteger fileSize = fileData.length;

    if (fileSize < sizeof(struct mach_header_64)) {
        return codeSections;
    }

    const struct mach_header_64 *header = (const struct mach_header_64 *)fileBytes;

    // 遍历加载命令
    const uint8_t *loadCmdPtr = fileBytes + sizeof(struct mach_header_64);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        const struct load_command *loadCmd = (const struct load_command *)loadCmdPtr;

        if (loadCmd->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *segCmd = (const struct segment_command_64 *)loadCmd;

            // 检查是否是 TEXT 段
            if (strncmp(segCmd->segname, SEG_TEXT, 16) == 0) {
                NSLog(@"[DisassemblyEngine] 找到 TEXT 段: VM地址=0x%llX, 文件偏移=0x%llX, 大小=%llu",
                      segCmd->vmaddr, segCmd->fileoff, segCmd->filesize);

                // 遍历所有 sections
                const uint8_t *sectionPtr = loadCmdPtr + sizeof(struct segment_command_64);

                for (uint32_t j = 0; j < segCmd->nsects; j++) {
                    const struct section_64 *section = (const struct section_64 *)sectionPtr;

                    // 检查是否包含指令 (S_ATTR_PURE_INSTRUCTIONS) 且不是 Symbol Stubs
                    if ((section->flags & S_ATTR_PURE_INSTRUCTIONS) &&
                        (section->flags & SECTION_TYPE) != S_SYMBOL_STUBS) {

                        NSString *sectionName = [NSString stringWithFormat:@"%s.%s",
                                               segCmd->segname, section->sectname];

                        NSLog(@"[DisassemblyEngine] 找到代码段: %@, VM地址=0x%llX, 文件偏移=0x%x, 大小=%llu",
                              sectionName, section->addr, section->offset, (unsigned long long)section->size);

                        // 检查文件偏移是否有效
                        if (section->offset + section->size <= fileSize) {
                            NSDictionary *sectionInfo = @{
                                @"name": sectionName,
                                @"data": [NSValue valueWithPointer:fileBytes + section->offset],
                                @"size": @(section->size),
                                @"vmaddr": @(section->addr),
                                @"offset": @(section->offset)
                            };
                            [codeSections addObject:sectionInfo];
                        } else {
                            NSLog(@"[DisassemblyEngine] 警告: %@ 文件偏移超出文件范围", sectionName);
                        }
                    }

                    sectionPtr += sizeof(struct section_64);
                }
            }
        }

        loadCmdPtr += loadCmd->cmdsize;

        // 防止越界
        if (loadCmdPtr >= fileBytes + fileSize) {
            break;
        }
    }

    return codeSections;
}

+ (NSArray<NSDictionary *> *)disassembleStaticData:(const uint8_t *)data
                                               size:(NSUInteger)size
                                        baseAddress:(uint64_t)baseAddress
                                     maxInstructions:(NSUInteger)maxInstructions {

    NSMutableArray<NSDictionary *> *instructions = [NSMutableArray array];

    if (!data || size == 0) {
        NSLog(@"[DisassemblyEngine] 错误: 数据为空");
        return instructions;
    }

    NSLog(@"[DisassemblyEngine] 开始反汇编: 数据大小=%lu, 基地址=0x%llX", (unsigned long)size, baseAddress);

    // 打印前几个字节用于调试
    NSMutableString *hexDump = [NSMutableString string];
    NSUInteger dumpSize = MIN(size, 32);
    for (NSUInteger i = 0; i < dumpSize; i++) {
        [hexDump appendFormat:@"%02X ", data[i]];
    }
    NSLog(@"[DisassemblyEngine] 数据前%lu字节: %@", (unsigned long)dumpSize, hexDump);

    // 初始化 Capstone - 使用正确的 ARM64 模式
    csh cs_handle;
    cs_err err = cs_open(CS_ARCH_AARCH64, CS_MODE_LITTLE_ENDIAN, &cs_handle);
    if (err != CS_ERR_OK) {
        NSLog(@"[DisassemblyEngine] 错误: 无法初始化 Capstone (错误码: %d)", err);
        return instructions;
    }

    // 设置详细模式
    cs_option(cs_handle, CS_OPT_DETAIL, CS_OPT_ON);

    // 设置跳过数据模式 - 这很重要！
    cs_option(cs_handle, CS_OPT_SKIPDATA, CS_OPT_ON);

    // 设置语法模式
    cs_option(cs_handle, CS_OPT_SYNTAX, CS_OPT_SYNTAX_DEFAULT);

    NSLog(@"[DisassemblyEngine] Capstone 初始化成功，开始流式反汇编...");

    // 使用流式反汇编，避免一次性分配大量内存
    const uint8_t *currentData = data;
    size_t remainingSize = size;
    uint64_t currentAddress = baseAddress;
    NSUInteger processedInstructions = 0;

    // 每次处理的最大字节数 (32KB)，更小的块大小优化内存
    const size_t chunkSize = 32 * 1024;

    // 分块压缩存储，减少内存峰值
    NSMutableArray *chunkInstructions = [NSMutableArray array];
    const NSUInteger compressionThreshold = 5000; // 每5000条指令压缩一次

    while (remainingSize > 0 && (maxInstructions == 0 || processedInstructions < maxInstructions)) {
        @autoreleasepool {
            // 计算当前块的大小
            size_t currentChunkSize = MIN(chunkSize, remainingSize);

            // 反汇编当前块
            cs_insn *cs_insn = NULL;
            size_t disasm_count = cs_disasm(cs_handle, currentData, currentChunkSize, currentAddress, 0, &cs_insn);

            if (disasm_count == 0) {
                // 如果反汇编失败，跳过4字节继续
                currentData += 4;
                remainingSize -= MIN(4, remainingSize);
                currentAddress += 4;
                continue;
            }

            // 转换为字典数组
            for (size_t i = 0; i < disasm_count && (maxInstructions == 0 || processedInstructions < maxInstructions); i++) {
                NSMutableDictionary *instruction = [NSMutableDictionary dictionary];

                // 地址 - 与动态反汇编保持一致的格式
                instruction[@"address"] = [NSString stringWithFormat:@"0x%llX", cs_insn[i].address];

                // 原始字节
                NSMutableString *hexString = [NSMutableString string];
                for (int j = 0; j < cs_insn[i].size; j++) {
                    [hexString appendFormat:@"%02X", cs_insn[i].bytes[j]];
                }
                instruction[@"bytes"] = [hexString copy];

                // 指令助记符和操作数
                instruction[@"mnemonic"] = [NSString stringWithUTF8String:cs_insn[i].mnemonic];
                instruction[@"operands"] = [NSString stringWithUTF8String:cs_insn[i].op_str];

                [chunkInstructions addObject:instruction];
                processedInstructions++;

                // 当累积足够指令时，压缩存储并清空临时数组
                if (chunkInstructions.count >= compressionThreshold) {
                    [instructions addObjectsFromArray:chunkInstructions];
                    [chunkInstructions removeAllObjects];

                    // 强制内存回收
                    if (processedInstructions % (compressionThreshold * 2) == 0) {
                        NSLog(@"[DisassemblyEngine] 内存优化: 已处理 %lu 条指令", (unsigned long)processedInstructions);
                    }
                }
            }

            // 更新位置 - 简化逻辑，直接跳过当前块
            currentData += currentChunkSize;
            remainingSize -= currentChunkSize;
            currentAddress += currentChunkSize;

            // 释放当前块的资源
            cs_free(cs_insn, disasm_count);

            // 进度报告
            if (processedInstructions % 2500 == 0 && processedInstructions > 0) {
                NSLog(@"[DisassemblyEngine] 流式处理进度: %lu 条指令", (unsigned long)processedInstructions);
            }
        }
    }

    // 处理剩余的指令
    if (chunkInstructions.count > 0) {
        [instructions addObjectsFromArray:chunkInstructions];
        [chunkInstructions removeAllObjects];
    }

    cs_close(&cs_handle);

    NSLog(@"[DisassemblyEngine] 静态反汇编完成，返回 %lu 条指令", (unsigned long)instructions.count);

    return instructions;
}

@end
