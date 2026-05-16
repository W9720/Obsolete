#import "OnlineDisassemblerService.h"
#import "OnlineAssemblerService.h"

@implementation OnlineDisassemblerService

- (void)disassembleBytes:(NSString *)bytes completion:(void (^)(NSString * _Nullable result, NSError * _Nullable error))completion {
    NSString *cleanBytes = [self cleanHexString:bytes];
    
    NSString *urlString = [NSString stringWithFormat:@"https://shell-storm.org/online/Online-Assembler-and-Disassembler/?opcodes=%@&arch=arm64&endianness=little&baddr=0x00000000&dis_with_raw=True&dis_with_ins=True#disassembly", cleanBytes];
    
    NSString *encodedUrlString = [urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    
    if (!encodedUrlString) {
        NSError *error = [AssemblerError errorWithType:AssemblerErrorTypeNetwork message:@"无效的URL"];
        completion(nil, error);
        return;
    }
    
    NSURL *url = [NSURL URLWithString:encodedUrlString];
    if (!url) {
        NSError *error = [AssemblerError errorWithType:AssemblerErrorTypeNetwork message:@"无效的URL"];
        completion(nil, error);
        return;
    }
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSError *assemblerError = [AssemblerError errorWithType:AssemblerErrorTypeNetwork message:error.localizedDescription];
                completion(nil, assemblerError);
                return;
            }
            
            if (!data) {
                NSError *assemblerError = [AssemblerError errorWithType:AssemblerErrorTypeInvalidResponse message:@""];
                completion(nil, assemblerError);
                return;
            }
            
            NSString *htmlString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (htmlString) {
                NSString *disassemblyCode = [self extractDisassemblyCodeFromHTML:htmlString];
                if (disassemblyCode) {
                    completion(disassemblyCode, nil);
                } else {
                    NSError *assemblerError = [AssemblerError errorWithType:AssemblerErrorTypeParsing message:@"无法从响应中提取反汇编代码"];
                    completion(nil, assemblerError);
                }
            } else {
                NSError *assemblerError = [AssemblerError errorWithType:AssemblerErrorTypeParsing message:@"无法将响应解析为文本"];
                completion(nil, assemblerError);
            }
        });
    }];
    
    [task resume];
}

- (NSString *)cleanHexString:(NSString *)input {
    NSCharacterSet *hexChars = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef "];
    NSMutableString *filtered = [NSMutableString string];
    
    for (NSInteger i = 0; i < input.length; i++) {
        unichar character = [input characterAtIndex:i];
        if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:character] || [hexChars characterIsMember:character]) {
            [filtered appendFormat:@"%C", character];
        }
    }
    
    NSArray *components = [filtered componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSMutableArray *nonEmptyComponents = [NSMutableArray array];
    
    for (NSString *component in components) {
        if (component.length > 0) {
            [nonEmptyComponents addObject:component];
        }
    }
    
    return [nonEmptyComponents componentsJoinedByString:@"+"];
}

- (NSString *)extractDisassemblyCodeFromHTML:(NSString *)html {
    NSError *error;
    
    // 主要模式匹配
    NSString *pattern = @"<h4>Disassembly</h4><pre><code[^>]*>(.*?)</code></pre>";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    
    if (regex) {
        NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:html options:0 range:NSMakeRange(0, html.length)];
        
        if (matches.count > 0) {
            NSTextCheckingResult *match = matches.firstObject;
            if (match.numberOfRanges > 1) {
                NSRange disassemblyRange = [match rangeAtIndex:1];
                if (disassemblyRange.location != NSNotFound) {
                    NSString *disassemblyWithTags = [html substringWithRange:disassemblyRange];
                    disassemblyWithTags = [disassemblyWithTags stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    
                    NSString *cleanedDisassembly = [self removeHTMLTagsFromString:disassemblyWithTags];
                    return [self processMultilineInstructions:cleanedDisassembly];
                }
            }
        }
    }
    
    // 备用模式匹配
    NSString *backupPattern = @"<code class=\"language-plaintext\">(.*?)</code>";
    NSRegularExpression *backupRegex = [NSRegularExpression regularExpressionWithPattern:backupPattern options:NSRegularExpressionDotMatchesLineSeparators error:&error];
    
    if (backupRegex) {
        NSArray<NSTextCheckingResult *> *backupMatches = [backupRegex matchesInString:html options:0 range:NSMakeRange(0, html.length)];
        
        if (backupMatches.count > 0) {
            NSTextCheckingResult *backupMatch = backupMatches.lastObject;
            if (backupMatch.numberOfRanges > 1) {
                NSRange disassemblyRange = [backupMatch rangeAtIndex:1];
                if (disassemblyRange.location != NSNotFound) {
                    NSString *disassemblyWithTags = [html substringWithRange:disassemblyRange];
                    disassemblyWithTags = [disassemblyWithTags stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    
                    NSString *cleanedDisassembly = [self removeHTMLTagsFromString:disassemblyWithTags];
                    return [self processMultilineInstructions:cleanedDisassembly];
                }
            }
        }
    }
    
    // 查找特定指令
    if ([html containsString:@"movz w0, #0x1"]) {
        NSRange range = [html rangeOfString:@"movz w0, #0x1"];
        NSInteger startIndex = MAX(0, (NSInteger)range.location - 50);
        NSInteger endIndex = MIN(html.length, (NSInteger)range.location + (NSInteger)range.length + 200);
        
        NSString *context = [html substringWithRange:NSMakeRange(startIndex, endIndex - startIndex)];
        return [self extractAllInstructionsFromContext:context];
    }
    
    return nil;
}

- (NSString *)processMultilineInstructions:(NSString *)input {
    NSArray *lines = [input componentsSeparatedByString:@"\n"];
    NSMutableArray *instructions = [NSMutableArray array];
    
    for (NSString *line in lines) {
        if ([line containsString:@"    "]) {
            NSArray *components = [line componentsSeparatedByString:@"    "];
            if (components.count >= 2) {
                NSString *instruction = [components.lastObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (instruction.length > 0) {
                    [instructions addObject:instruction];
                }
            }
        } else if (line.length > 0 && ![line containsString:@"Disassembly"]) {
            [instructions addObject:[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        }
    }
    
    if (instructions.count == 0) {
        return input;
    }
    
    return [instructions componentsJoinedByString:@"\n"];
}

- (NSString *)extractAllInstructionsFromContext:(NSString *)context {
    NSMutableArray *instructions = [NSMutableArray array];
    
    NSString *instructionPattern = @"\\d{2}\\s\\d{2}\\s\\d{2}\\s\\d{2}\\s+([^<\\n]+)";
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:instructionPattern options:NSRegularExpressionDotMatchesLineSeparators error:&error];
    
    if (regex) {
        NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:context options:0 range:NSMakeRange(0, context.length)];
        
        for (NSTextCheckingResult *match in matches) {
            if (match.numberOfRanges > 1) {
                NSRange instructionRange = [match rangeAtIndex:1];
                if (instructionRange.location != NSNotFound) {
                    NSString *instruction = [context substringWithRange:instructionRange];
                    instruction = [instruction stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if (instruction.length > 0) {
                        [instructions addObject:instruction];
                    }
                }
            }
        }
    }
    
    if (instructions.count == 0) {
        NSArray *commonInstructions = @[@"movz", @"mov", @"add", @"sub", @"ldr", @"str", @"ret", @"bl", @"b"];
        
        for (NSString *instruction in commonInstructions) {
            NSRange range = [context rangeOfString:instruction options:NSRegularExpressionSearch];
            if (range.location != NSNotFound) {
                // 找到行的开始和结束
                NSInteger lineStart = 0;
                NSInteger lineEnd = context.length;
                
                // 向前查找换行符
                for (NSInteger i = range.location - 1; i >= 0; i--) {
                    if ([context characterAtIndex:i] == '\n') {
                        lineStart = i + 1;
                        break;
                    }
                }
                
                // 向后查找换行符
                for (NSInteger i = range.location + range.length; i < context.length; i++) {
                    if ([context characterAtIndex:i] == '\n') {
                        lineEnd = i;
                        break;
                    }
                }
                
                NSString *line = [context substringWithRange:NSMakeRange(lineStart, lineEnd - lineStart)];
                line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                
                NSRange instructionStart = [line rangeOfString:instruction];
                if (instructionStart.location != NSNotFound) {
                    NSString *instructionPart = [line substringFromIndex:instructionStart.location];
                    instructionPart = [instructionPart stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if (instructionPart.length > 0) {
                        [instructions addObject:instructionPart];
                    }
                }
            }
        }
    }
    
    return [instructions componentsJoinedByString:@"\n"];
}

- (NSString *)removeHTMLTagsFromString:(NSString *)string {
    NSString *result = string;
    
    // 替换换行标签
    result = [result stringByReplacingOccurrencesOfString:@"<br>" withString:@"\n"];
    result = [result stringByReplacingOccurrencesOfString:@"<br/>" withString:@"\n"];
    result = [result stringByReplacingOccurrencesOfString:@"</br>" withString:@"\n"];
    
    // 移除特定标签
    result = [result stringByReplacingOccurrencesOfString:@"<code[^>]*>" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, result.length)];
    result = [result stringByReplacingOccurrencesOfString:@"</code>" withString:@""];
    result = [result stringByReplacingOccurrencesOfString:@"<pre[^>]*>" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, result.length)];
    result = [result stringByReplacingOccurrencesOfString:@"</pre>" withString:@""];
    
    // 移除所有HTML标签
    result = [result stringByReplacingOccurrencesOfString:@"<[^>]+>" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, result.length)];
    
    // 解码HTML实体
    result = [result stringByReplacingOccurrencesOfString:@"&lt;" withString:@"<"];
    result = [result stringByReplacingOccurrencesOfString:@"&gt;" withString:@">"];
    result = [result stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
    result = [result stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];
    result = [result stringByReplacingOccurrencesOfString:@"&apos;" withString:@"'"];
    
    return [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end
