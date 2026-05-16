//
//  mem_utils.c
//  memui
//
//  Created by Liu Junqi on 4/24/18.
//  Copyright © 2018 DeviLeo. All rights reserved.
//

#include "mem_utils.h"

void *search_uint8(const void *b, size_t len, uint8_t v, int comparison) {
    size_t vlen = sizeof(uint8_t);
    char *sp = (char *)b;
    char *eos = sp + len - vlen;
    
    if(!(b && len && v)) return NULL;
    
    while (sp <= eos) {
        uint8_t v1 = *(uint8_t *)(sp);
        switch (comparison) {
            case SearchResultComparisonEQ: if (v1 == v) return sp; break;
            case SearchResultComparisonLT: if (v1 < v) return sp; break;
            case SearchResultComparisonLE: if (v1 <= v) return sp; break;
            case SearchResultComparisonGE: if (v1 >= v) return sp; break;
            case SearchResultComparisonGT: if (v1 > v) return sp; break;
        }
        sp += vlen;// Modify by innovator
    }
    
    return NULL;
}

void *search_int8(const void *b, size_t len, int8_t v, int comparison) {
    size_t vlen = sizeof(int8_t);
    char *sp = (char *)b;
    char *eos = sp + len - vlen;
    
    if(!(b && len && v)) return NULL;
    
    while (sp <= eos) {
        int8_t v1 = *(int8_t *)(sp);
        switch (comparison) {
            case SearchResultComparisonEQ: if (v1 == v) return sp; break;
            case SearchResultComparisonLT: if (v1 < v) return sp; break;
            case SearchResultComparisonLE: if (v1 <= v) return sp; break;
            case SearchResultComparisonGE: if (v1 >= v) return sp; break;
            case SearchResultComparisonGT: if (v1 > v) return sp; break;
        }
        sp += vlen;// Modify by innovator
    }
    
    return NULL;
}

void *search_uint16(const void *b, size_t len, uint16_t v, int comparison) {
    size_t vlen = sizeof(uint16_t);
    char *sp = (char *)b;
    char *eos = sp + len - vlen;
    
    if(!(b && len && v)) return NULL;
    
    while (sp <= eos) {
        uint16_t v1 = *(uint16_t *)(sp);
        switch (comparison) {
            case SearchResultComparisonEQ: if (v1 == v) return sp; break;
            case SearchResultComparisonLT: if (v1 < v) return sp; break;
            case SearchResultComparisonLE: if (v1 <= v) return sp; break;
            case SearchResultComparisonGE: if (v1 >= v) return sp; break;
            case SearchResultComparisonGT: if (v1 > v) return sp; break;
        }
        sp += vlen;// Modify by innovator
    }
    
    return NULL;
}

void *search_int16(const void *b, size_t len, int16_t v, int comparison) {
    size_t vlen = sizeof(int16_t);
    char *sp = (char *)b;
    char *eos   = sp + len - vlen;
    
    if(!(b && len && v)) return NULL;
    
    while (sp <= eos) {
        int16_t v1 = *(int16_t *)(sp);
        switch (comparison) {
            case SearchResultComparisonEQ: if (v1 == v) return sp; break;
            case SearchResultComparisonLT: if (v1 < v) return sp; break;
            case SearchResultComparisonLE: if (v1 <= v) return sp; break;
            case SearchResultComparisonGE: if (v1 >= v) return sp; break;
            case SearchResultComparisonGT: if (v1 > v) return sp; break;
        }
        sp += vlen;// Modify by innovator
    }
    
    return NULL;
}

void *search_uint32(const void *b, size_t len, uint32_t v, int comparison) {
    if(!(b && len && v)) return NULL;

    const uint32_t *ptr = (const uint32_t *)b;
    const uint32_t *end = ptr + (len / sizeof(uint32_t));

    // 针对最常见的相等比较进行优化
    if (comparison == SearchResultComparisonEQ) {
        // 使用循环展开优化
        while (ptr + 3 < end) {
            if (ptr[0] == v) return (void*)&ptr[0];
            if (ptr[1] == v) return (void*)&ptr[1];
            if (ptr[2] == v) return (void*)&ptr[2];
            if (ptr[3] == v) return (void*)&ptr[3];
            ptr += 4;
        }
        // 处理剩余元素
        while (ptr < end) {
            if (*ptr == v) return (void*)ptr;
            ptr++;
        }
        return NULL;
    }

    // 其他比较类型
    while (ptr < end) {
        uint32_t v1 = *ptr;
        switch (comparison) {
            case SearchResultComparisonLT: if (v1 < v) return (void*)ptr; break;
            case SearchResultComparisonLE: if (v1 <= v) return (void*)ptr; break;
            case SearchResultComparisonGE: if (v1 >= v) return (void*)ptr; break;
            case SearchResultComparisonGT: if (v1 > v) return (void*)ptr; break;
        }
        ptr++;
    }

    return NULL;
}

void *search_int32(const void *b, size_t len, int32_t v, int comparison) {
    if(!(b && len)) return NULL;

    const int32_t *ptr = (const int32_t *)b;
    const int32_t *end = ptr + (len / sizeof(int32_t));

    // 针对最常见的相等比较进行优化
    if (comparison == SearchResultComparisonEQ) {
        // 使用指针算术和循环展开优化
        while (ptr + 3 < end) {
            if (ptr[0] == v) return (void*)&ptr[0];
            if (ptr[1] == v) return (void*)&ptr[1];
            if (ptr[2] == v) return (void*)&ptr[2];
            if (ptr[3] == v) return (void*)&ptr[3];
            ptr += 4;
        }
        // 处理剩余元素
        while (ptr < end) {
            if (*ptr == v) return (void*)ptr;
            ptr++;
        }
        return NULL;
    }

    // 其他比较类型使用原来的逻辑
    while (ptr < end) {
        int32_t v1 = *ptr;
        switch (comparison) {
            case SearchResultComparisonLT: if (v1 < v) return (void*)ptr; break;
            case SearchResultComparisonLE: if (v1 <= v) return (void*)ptr; break;
            case SearchResultComparisonGE: if (v1 >= v) return (void*)ptr; break;
            case SearchResultComparisonGT: if (v1 > v) return (void*)ptr; break;
        }
        ptr++;
    }

    return NULL;
}

void *search_uint64(const void *b, size_t len, uint64_t v, int comparison) {
    size_t vlen = sizeof(uint64_t);
    char *sp = (char *)b;
    char *eos = sp + len - vlen;
    
    if(!(b && len && v)) return NULL;
    
    while (sp <= eos) {
        uint64_t v1 = *(uint64_t *)(sp);
        switch (comparison) {
            case SearchResultComparisonEQ: if (v1 == v) return sp; break;
            case SearchResultComparisonLT: if (v1 < v) return sp; break;
            case SearchResultComparisonLE: if (v1 <= v) return sp; break;
            case SearchResultComparisonGE: if (v1 >= v) return sp; break;
            case SearchResultComparisonGT: if (v1 > v) return sp; break;
        }
        sp += vlen;// Modify by innovato
    }
    
    return NULL;
}

void *search_int64(const void *b, size_t len, int64_t v, int comparison) {
    size_t vlen = sizeof(int64_t);
    char *sp = (char *)b;
    char *eos   = sp + len - vlen;
    
    if(!(b && len && v)) return NULL;
    
    while (sp <= eos) {
        int64_t v1 = *(int64_t *)(sp);
        switch (comparison) {
            case SearchResultComparisonEQ: if (v1 == v) return sp; break;
            case SearchResultComparisonLT: if (v1 < v) return sp; break;
            case SearchResultComparisonLE: if (v1 <= v) return sp; break;
            case SearchResultComparisonGE: if (v1 >= v) return sp; break;
            case SearchResultComparisonGT: if (v1 > v) return sp; break;
        }
        sp += vlen;// Modify by innovato
    }
    
    return NULL;
}

void *search_float(const void *b, size_t len, float v, int comparison) {
    if(!(b && len && v)) return NULL;

    const float *ptr = (const float *)b;
    const float *end = ptr + (len / sizeof(float));

    // 针对浮点数相等比较，使用更高效的方法
    if (comparison == SearchResultComparisonEQ) {
        // 使用循环展开优化
        while (ptr + 3 < end) {
            if (ptr[0] == v) return (void*)&ptr[0];
            if (ptr[1] == v) return (void*)&ptr[1];
            if (ptr[2] == v) return (void*)&ptr[2];
            if (ptr[3] == v) return (void*)&ptr[3];
            ptr += 4;
        }
        // 处理剩余元素
        while (ptr < end) {
            if (*ptr == v) return (void*)ptr;
            ptr++;
        }
        return NULL;
    }

    // 其他比较类型
    while (ptr < end) {
        float v1 = *ptr;
        switch (comparison) {
            case SearchResultComparisonLT: if (v1 < v) return (void*)ptr; break;
            case SearchResultComparisonLE: if (v1 <= v) return (void*)ptr; break;
            case SearchResultComparisonGE: if (v1 >= v) return (void*)ptr; break;
            case SearchResultComparisonGT: if (v1 > v) return (void*)ptr; break;
        }
        ptr++;
    }

    return NULL;
}

void *search_double(const void *b, size_t len, double v, int comparison) {
    size_t vlen = sizeof(double);
    char *sp = (char *)b;
    char *eos   = sp + len - vlen;
    
    if(!(b && len && v)) return NULL;
    
    while (sp <= eos) {
        double v1 = *(double *)(sp);
        switch (comparison) {
            case SearchResultComparisonEQ: if (v1 == v) return sp; break;
            case SearchResultComparisonLT: if (v1 < v) return sp; break;
            case SearchResultComparisonLE: if (v1 <= v) return sp; break;
            case SearchResultComparisonGE: if (v1 >= v) return sp; break;
            case SearchResultComparisonGT: if (v1 > v) return sp; break;
        }
        sp += vlen;// Modify by innovato
    }
    
    return NULL;
}

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
            
            // 只有当完全匹配并且是独立字符串时才返回
            if (match) {
                // 确保这是一个完整的字符串而不是较长字符串的一部分
                // 检查字符串后面是否为空字符或非打印字符，以确保这是一个完整字符串
                char next_char = (sp + str_len < (char *)b + len) ? sp[str_len] : 0;
                if (next_char == 0 || next_char < 32 || next_char > 126) {
                    // 前面也应该是字符串开始或非打印字符
                    if (sp == (char *)b || (sp > (char *)b && (sp[-1] == 0 || sp[-1] < 32 || sp[-1] > 126))) {
                        return sp;
                    }
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

void *search_mem_value(const void *b, size_t len, void *v, size_t vlen, int type, int comparison) {
    if (type == SearchResultValueTypeUInt8) {
        uint8_t vv = *(uint8_t *)(v);
        return search_uint8(b, len, vv, comparison);
    } else if (type == SearchResultValueTypeSInt8) {
        int8_t vv = *(int8_t *)(v);
        return search_int8(b, len, vv, comparison);
    } else if (type == SearchResultValueTypeUInt16) {
        uint16_t vv = *(uint16_t *)(v);
        return search_uint16(b, len, vv, comparison);
    } else if (type == SearchResultValueTypeSInt16) {
        int16_t vv = *(int16_t *)(v);
        return search_int16(b, len, vv, comparison);
    } else if (type == SearchResultValueTypeUInt32) {
        uint32_t vv = *(uint32_t *)(v);
        return search_uint32(b, len, vv, comparison);
    } else if (type == SearchResultValueTypeSInt32) {
        int32_t vv = *(int32_t *)(v);
        return search_int32(b, len, vv, comparison);
    } else if (type == SearchResultValueTypeUInt64) {
        uint64_t vv = *(uint64_t *)(v);
        return search_uint64(b, len, vv, comparison);
    } else if (type == SearchResultValueTypeSInt64) {
        int64_t vv = *(int64_t *)(v);
        return search_int64(b, len, vv, comparison);
    } else if (type == SearchResultValueTypeFloat) {
        float vv = *(float *)(v);
        return search_float(b, len, vv, comparison);
    } else if (type == SearchResultValueTypeDouble) {
        double vv = *(double *)(v);
        return search_double(b, len, vv, comparison);
    } else if (type == 11) { // 字符串类型 SearchResultValueTypeStr
        return search_string(b, len, (const char *)v, vlen, comparison);
    }
    
    return NULL;
}

