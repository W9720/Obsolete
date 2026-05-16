#ifndef SettingsEnums_h
#define SettingsEnums_h

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SettingsSectionType) {
    SettingsSectionTypeSearchRange = 0,
    SettingsSectionTypeNearRange = 1,
    SettingsSectionTypeFloatErrorRange = 2,  // 浮点数误差范围分区
    SettingsSectionTypeLoopLock = 3,         // 循环锁定分区
    SettingsSectionTypeHelp = 4              // 使用说明分区
};

typedef NS_ENUM(NSInteger, SettingsRowType) {
    // 搜索范围部分
    SettingsRowTypeSearchLowerLimit = 0,
    SettingsRowTypeSearchUpperLimit = 1,
    
    // 临近范围部分
    SettingsRowTypeNearRangeValue = 0,
    SettingsRowTypeLimitCount = 1,
    
    // 浮点数误差范围部分
    SettingsRowTypeFloatErrorRange = 0,
    // 删除整数误差行
    SettingsRowTypeFloatSignMode = 1,        // 有符号/无符号模式行 (调整序号)
    SettingsRowTypeFuzzyString = 2,          // 模糊字符行 (调整序号)
    
    // 循环锁定部分
    SettingsRowTypeLoopScript = 0,     // 循环脚本
    SettingsRowTypeDataLock = 1,       // 数据锁定
    
    // 使用说明部分
    SettingsRowTypeUserAgreement = 0,  // 使用协议
    SettingsRowTypeFeedbackGroup = 1,  // 加群反馈
    SettingsRowTypeAboutApp = 2        // 关于应用
};

#endif /* SettingsEnums_h */ 