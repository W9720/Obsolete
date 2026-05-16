#import "OnlineAssemblerService.h"

@implementation AssemblerError

+ (instancetype)errorWithType:(AssemblerErrorType)type message:(NSString *)message {
    NSString *description;
    switch (type) {
        case AssemblerErrorTypeNetwork:
            description = [NSString stringWithFormat:@"网络错误: %@", message];
            break;
        case AssemblerErrorTypeParsing:
            description = [NSString stringWithFormat:@"解析错误: %@", message];
            break;
        case AssemblerErrorTypeInvalidResponse:
            description = @"服务器返回了无效响应";
            break;
    }
    
    return [AssemblerError errorWithDomain:@"AssemblerErrorDomain" 
                                      code:type 
                                  userInfo:@{NSLocalizedDescriptionKey: description}];
}

@end

@interface OnlineAssemblerService ()
@property (nonatomic, strong, readwrite, nullable) NSString *lastHtmlResponse;
@end

@implementation OnlineAssemblerService

- (void)assembleCode:(NSString *)code completion:(void (^)(NSString * _Nullable result, NSError * _Nullable error))completion {
    NSString *encodedCode = [code stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    
    if (!encodedCode) {
        NSError *error = [AssemblerError errorWithType:AssemblerErrorTypeNetwork message:@"无法对汇编代码进行URL编码"];
        completion(nil, error);
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"https://shell-storm.org/online/Online-Assembler-and-Disassembler/?inst=%@&arch=arm64&as_format=hex#assembly", encodedCode];
    
    NSURL *url = [NSURL URLWithString:urlString];
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
                self.lastHtmlResponse = htmlString;
                
                NSString *hexCode = [self extractHexCodeFromHTML:htmlString];
                if (hexCode) {
                    completion(hexCode, nil);
                } else {
                    NSError *assemblerError = [AssemblerError errorWithType:AssemblerErrorTypeParsing message:@"无法从响应中提取十六进制代码"];
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

- (NSString *)extractHexCodeFromHTML:(NSString *)html {
    NSError *error;
    
    // 主要模式匹配
    NSString *pattern = @"Hexadecimal[\\s\\S]*?<pre[^>]*>(.*?)</pre>";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    
    if (regex) {
        NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:html options:0 range:NSMakeRange(0, html.length)];
        
        if (matches.count > 0) {
            NSTextCheckingResult *match = matches.firstObject;
            if (match.numberOfRanges > 1) {
                NSRange hexRange = [match rangeAtIndex:1];
                if (hexRange.location != NSNotFound) {
                    NSString *hexWithTags = [html substringWithRange:hexRange];
                    hexWithTags = [hexWithTags stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    return [self removeHTMLTagsFromString:hexWithTags];
                }
            }
        }
    }
    
    // 备用模式匹配
    NSString *fallbackPattern = @"<code class=\"language-plaintext\">(.*?)</code>";
    NSRegularExpression *fallbackRegex = [NSRegularExpression regularExpressionWithPattern:fallbackPattern options:NSRegularExpressionDotMatchesLineSeparators error:&error];
    
    if (fallbackRegex) {
        NSArray<NSTextCheckingResult *> *fallbackMatches = [fallbackRegex matchesInString:html options:0 range:NSMakeRange(0, html.length)];
        
        if (fallbackMatches.count > 0) {
            NSTextCheckingResult *fallbackMatch = fallbackMatches.lastObject;
            if (fallbackMatch.numberOfRanges > 1) {
                NSRange hexRange = [fallbackMatch rangeAtIndex:1];
                if (hexRange.location != NSNotFound) {
                    NSString *hexWithTags = [html substringWithRange:hexRange];
                    hexWithTags = [hexWithTags stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    return [self removeHTMLTagsFromString:hexWithTags];
                }
            }
        }
    }
    
    // 十六进制模式匹配
    NSString *hexPattern = @"\\b([0-9a-fA-F]{2}\\s+[0-9a-fA-F]{2}\\s+[0-9a-fA-F]{2}\\s+[0-9a-fA-F]{2})\\b";
    NSRegularExpression *hexRegex = [NSRegularExpression regularExpressionWithPattern:hexPattern options:0 error:&error];
    
    if (hexRegex) {
        NSArray<NSTextCheckingResult *> *hexMatches = [hexRegex matchesInString:html options:0 range:NSMakeRange(0, html.length)];
        
        if (hexMatches.count > 0) {
            NSTextCheckingResult *hexMatch = hexMatches.firstObject;
            if (hexMatch.numberOfRanges > 1) {
                NSRange matchRange = [hexMatch rangeAtIndex:1];
                if (matchRange.location != NSNotFound) {
                    return [html substringWithRange:matchRange];
                }
            }
        }
    }
    
    // 常见模式匹配
    NSArray *commonPatterns = @[
        @"\\b(20\\s+00\\s+80\\s+52)\\b",
        @"\\b(c0\\s+03\\s+5f\\s+d6)\\b",
        @"\\b([0-9a-fA-F]{2})\\s+([0-9a-fA-F]{2})\\s+([0-9a-fA-F]{2})\\s+([0-9a-fA-F]{2})\\b"
    ];
    
    for (NSString *patternString in commonPatterns) {
        NSRegularExpression *patternRegex = [NSRegularExpression regularExpressionWithPattern:patternString options:0 error:&error];
        
        if (patternRegex) {
            NSArray<NSTextCheckingResult *> *patternMatches = [patternRegex matchesInString:html options:0 range:NSMakeRange(0, html.length)];
            
            if (patternMatches.count > 0) {
                NSTextCheckingResult *match = patternMatches.firstObject;
                
                if (match.numberOfRanges > 4) {
                    NSString *byte1 = [html substringWithRange:[match rangeAtIndex:1]];
                    NSString *byte2 = [html substringWithRange:[match rangeAtIndex:2]];
                    NSString *byte3 = [html substringWithRange:[match rangeAtIndex:3]];
                    NSString *byte4 = [html substringWithRange:[match rangeAtIndex:4]];
                    return [NSString stringWithFormat:@"%@ %@ %@ %@", byte1, byte2, byte3, byte4];
                } else if (match.numberOfRanges > 1) {
                    return [html substringWithRange:[match rangeAtIndex:1]];
                }
            }
        }
    }
    
    return nil;
}

- (NSString *)removeHTMLTagsFromString:(NSString *)string {
    NSString *result = string;
    
    // 移除特定标签
    result = [result stringByReplacingOccurrencesOfString:@"<code[^>]*>" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, result.length)];
    result = [result stringByReplacingOccurrencesOfString:@"</code>" withString:@""];
    result = [result stringByReplacingOccurrencesOfString:@"<pre[^>]*>" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, result.length)];
    result = [result stringByReplacingOccurrencesOfString:@"</pre>" withString:@""];
    
    // 移除所有HTML标签
    result = [result stringByReplacingOccurrencesOfString:@"<[^>]+>" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, result.length)];
    
    return [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end
