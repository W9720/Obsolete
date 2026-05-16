//
//  TheosProjectManager.m
//  修改器
//
//  Created by AI Assistant on 2025-01-08.
//

#import "TheosProjectManager.h"

@implementation TheosProjectManager

+ (instancetype)sharedManager {
    static TheosProjectManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (NSString *)getProjectsRootPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *projectsPath = [documentsDirectory stringByAppendingPathComponent:@"TheosProjects"];
    
    // 确保目录存在
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:projectsPath]) {
        [fileManager createDirectoryAtPath:projectsPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return projectsPath;
}

- (BOOL)createProjectWithConfig:(NSDictionary *)config error:(NSError **)error {
    NSString *projectName = config[@"projectName"];
    NSString *packageName = config[@"packageName"];
    NSString *author = config[@"author"];
    NSString *description = config[@"description"];
    NSString *targetBundle = config[@"targetBundle"];
    
    // 验证必要参数
    if (!projectName || !packageName || !targetBundle) {
        if (error) {
            *error = [NSError errorWithDomain:@"TheosProjectManager" 
                                         code:1001 
                                     userInfo:@{NSLocalizedDescriptionKey: @"缺少必要的项目参数"}];
        }
        return NO;
    }
    
    // 创建项目目录
    NSString *projectPath = [[self getProjectsRootPath] stringByAppendingPathComponent:projectName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:projectPath]) {
        if (error) {
            *error = [NSError errorWithDomain:@"TheosProjectManager" 
                                         code:1002 
                                     userInfo:@{NSLocalizedDescriptionKey: @"项目已存在"}];
        }
        return NO;
    }
    
    BOOL success = [fileManager createDirectoryAtPath:projectPath withIntermediateDirectories:YES attributes:nil error:error];
    if (!success) {
        return NO;
    }
    
    // 创建Tweak.xm文件
    NSString *tweakPath = [projectPath stringByAppendingPathComponent:@"Tweak.xm"];
    NSString *tweakContent = [self generateTweakContentWithTargetBundle:targetBundle];
    success = [tweakContent writeToFile:tweakPath atomically:YES encoding:NSUTF8StringEncoding error:error];
    if (!success) return NO;
    
    // 创建Makefile
    NSString *makefilePath = [projectPath stringByAppendingPathComponent:@"Makefile"];
    NSString *makefileContent = [self generateMakefileContentWithProjectName:projectName];
    success = [makefileContent writeToFile:makefilePath atomically:YES encoding:NSUTF8StringEncoding error:error];
    if (!success) return NO;
    
    // 创建control文件
    NSString *controlPath = [projectPath stringByAppendingPathComponent:@"control"];
    NSString *controlContent = [self generateControlContentWithConfig:config];
    success = [controlContent writeToFile:controlPath atomically:YES encoding:NSUTF8StringEncoding error:error];
    if (!success) return NO;
    
    // 创建plist文件
    NSString *plistPath = [projectPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", projectName]];
    NSDictionary *plistContent = @{@"Filter": @{@"Bundles": @[targetBundle]}};
    success = [plistContent writeToFile:plistPath atomically:YES];
    if (!success) {
        if (error) {
            *error = [NSError errorWithDomain:@"TheosProjectManager" 
                                         code:1003 
                                     userInfo:@{NSLocalizedDescriptionKey: @"创建plist文件失败"}];
        }
        return NO;
    }
    
    // 创建README.md文件
    NSString *readmePath = [projectPath stringByAppendingPathComponent:@"README.md"];
    NSString *readmeContent = [self generateReadmeContentWithConfig:config];
    [readmeContent writeToFile:readmePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    return YES;
}

- (NSString *)generateTweakContentWithTargetBundle:(NSString *)targetBundle {
    return [NSString stringWithFormat:@"#import <UIKit/UIKit.h>\n\n// Hook示例 - 请根据需要修改\n%%hook UIViewController\n\n- (void)viewDidLoad {\n    %%orig;\n    NSLog(@\"[%@] %%@ viewDidLoad called\", NSStringFromClass([self class]));\n}\n\n%%end\n\n// 构造函数 - Tweak加载时执行\n%%ctor {\n    NSLog(@\"[%@] Tweak loaded successfully!\");\n}\n", targetBundle, targetBundle];
}

- (NSString *)generateMakefileContentWithProjectName:(NSString *)projectName {
    return [NSString stringWithFormat:@"ARCHS = arm64 arm64e\nTARGET = iphone:clang:latest:13.0\n\ninclude $(THEOS)/makefiles/common.mk\n\nTWEAK_NAME = %@\n%@_FILES = Tweak.xm\n\ninclude $(THEOS_MAKE_PATH)/tweak.mk\n\nafter-install::\n\tinstall.exec \"killall -9 SpringBoard\"", projectName, projectName];
}

- (NSString *)generateControlContentWithConfig:(NSDictionary *)config {
    NSString *projectName = config[@"projectName"];
    NSString *packageName = config[@"packageName"];
    NSString *author = config[@"author"];
    NSString *description = config[@"description"];
    
    return [NSString stringWithFormat:@"Package: %@\nName: %@\nVersion: 1.0.0\nArchitecture: iphoneos-arm\nDescription: %@\nMaintainer: %@\nAuthor: %@\nSection: Tweaks\nDepends: mobilesubstrate (>= 0.9.5000)\nIcon: file:///Library/PreferenceBundles/%@.bundle/icon.png", packageName, projectName, description, author, author, projectName];
}

- (NSString *)generateReadmeContentWithConfig:(NSDictionary *)config {
    NSString *projectName = config[@"projectName"];
    NSString *description = config[@"description"];
    NSString *author = config[@"author"];
    NSString *targetBundle = config[@"targetBundle"];
    
    return [NSString stringWithFormat:@"# %@\n\n%@\n\n## 项目信息\n\n- **作者**: %@\n- **目标应用**: %@\n- **版本**: 1.0.0\n\n## 编译说明\n\n1. 确保已安装Theos开发环境\n2. 在项目目录下执行: `make package`\n3. 安装生成的deb包: `dpkg -i packages/*.deb`\n\n## 使用说明\n\n请根据需要修改Tweak.xm文件中的Hook代码。\n\n## 注意事项\n\n- 请确保目标应用的Bundle ID正确\n- 修改代码后需要重新编译和安装\n- 安装后可能需要重启SpringBoard", projectName, description, author, targetBundle];
}

- (NSArray<NSString *> *)getAllProjects {
    NSString *projectsPath = [self getProjectsRootPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:projectsPath error:&error];
    
    if (error) {
        NSLog(@"Error listing projects: %@", error.localizedDescription);
        return @[];
    }
    
    // 过滤出目录
    NSMutableArray *projects = [NSMutableArray array];
    for (NSString *item in contents) {
        NSString *itemPath = [projectsPath stringByAppendingPathComponent:item];
        BOOL isDirectory;
        if ([fileManager fileExistsAtPath:itemPath isDirectory:&isDirectory] && isDirectory) {
            [projects addObject:item];
        }
    }
    
    return [projects copy];
}

- (BOOL)deleteProject:(NSString *)projectName error:(NSError **)error {
    NSString *projectPath = [[self getProjectsRootPath] stringByAppendingPathComponent:projectName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:projectPath]) {
        if (error) {
            *error = [NSError errorWithDomain:@"TheosProjectManager" 
                                         code:1004 
                                     userInfo:@{NSLocalizedDescriptionKey: @"项目不存在"}];
        }
        return NO;
    }
    
    return [fileManager removeItemAtPath:projectPath error:error];
}

@end
