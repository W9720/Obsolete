//
//  PluginFileManagerViewController.h
//  修改器
//
//  Created by AI Assistant on 2025-01-08.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PluginFileManagerViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) NSArray *filesArray;
@property (nonatomic, copy) NSString *currentPath;

// 刷新文件列表
- (void)refreshFileList;

// 返回上一级目录
- (void)goBack;

// 打开代码编辑器
- (void)openCodeEditorWithFilePath:(NSString *)filePath;

// 分享当前项目
- (void)shareCurrentProject;

@end

NS_ASSUME_NONNULL_END
