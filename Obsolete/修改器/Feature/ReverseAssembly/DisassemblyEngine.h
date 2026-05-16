//
//  DisassemblyEngine.h
//  Obsolete
//
//  Created by AI Assistant on 2025-01-08.
//

#import <Foundation/Foundation.h>
#import "../PointerScan/PointerScanManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface DisassemblyEngine : NSObject

// 静态文件反汇编（推荐使用）
+ (NSArray<NSDictionary *> *)disassembleFile:(NSString *)filePath maxInstructions:(NSUInteger)maxInstructions;

// 动态模块反汇编（已弃用，保留兼容性）
+ (NSArray<NSDictionary *> *)disassembleModule:(ModuleInfo *)module maxInstructions:(NSUInteger)maxInstructions;
+ (NSArray<NSDictionary *> *)disassembleAtAddress:(uint64_t)address size:(NSUInteger)size maxInstructions:(NSUInteger)maxInstructions;

@end

NS_ASSUME_NONNULL_END
