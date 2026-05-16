void *search_string(const void *b, size_t len, const char *str, size_t str_len, int comparison) {
    char *sp = (char *)b;
    char *eos = sp + len - str_len;
    
    if (!(b && len && str && str_len)) return NULL;
    
    // 根据比较类型执行不同的搜索
    if (comparison == SearchResultComparisonEQ) {
        // 精确搜索 - 只匹配完全相同的字符串
        while (sp <= eos) {
            // 检查当前位置是否精确匹配
            int match = 1;
            for (size_t i = 0; i < str_len; i++) {
                if (sp[i] != str[i]) {
                    match = 0;
                    break;
                }
            }
            
            // 只有当完全匹配并且后面是结束符或非可打印字符时才返回
            // 这确保我们找到的是独立的完整字符串，而不是较长字符串的一部分
            if (match) {
                // 检查是否是完整字符串（后面是结束符或非可打印字符）
                if (sp + str_len >= (char *)b + len || 
                    sp[str_len] == '\0' || 
                    sp[str_len] < 32 || 
                    sp[str_len] > 126) {
                    return sp;
                }
            }
            sp++;
        }
    } else if (comparison == SearchResultComparisonLE) {
        // 模糊搜索: 查找包含指定子字符串的任意字符串
        char *end_pos = (char *)b + len;
        
        // 逐个字节扫描内存
        for (char *curr_pos = sp; curr_pos < end_pos - str_len + 1; curr_pos++) {
            // 在当前位置检查是否包含目标子字符串
            size_t i;
            for (i = 0; i < str_len; i++) {
                if (curr_pos[i] != str[i]) {
                    break;  // 不匹配，跳出内部循环
                }
            }
            
            // 如果完全匹配子字符串
            if (i == str_len) {
                // 找到了匹配的子字符串，现在尝试找到整个字符串
                
                // 查找字符串的开始位置（向前搜索）
                char *start = curr_pos;
                while (start > (char *)b) {
                    // 如果前一个字符不是可打印字符或是null，则认为这是字符串的开始
                    if (*(start-1) < 32 || *(start-1) > 126 || *(start-1) == 0) {
                        break;
                    }
                    start--;
                }
                
                // 返回字符串的开始位置
                return start;
            }
        }
    } else {
        // 其他比较类型暂不支持
        return NULL;
    }
    
    return NULL;
} 