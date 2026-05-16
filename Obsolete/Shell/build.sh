#!/bin/sh

#  build.sh
#  TrollSpeed
#
#  Created by yiming on 2024/2/01.
#

# 项目版本号
export VERSION=$CURRENT_PROJECT_VERSION

# 项目名
export NAME=$PROJECT_NAME

# MachO文件的路径
export APP_BINARY=`plutil -convert xml1 -o - $TARGET_APP_PATH/Info.plist|grep -A1 Exec|tail -n1|cut -f2 -d\>|cut -f1 -d\<`

# .app路径
export appPath=$CODESIGNING_FOLDER_PATH

# 二进制文件路径
export DYLIB=$CODESIGNING_FOLDER_PATH

# Package 目录
export PACKAGE=${BUILT_PRODUCTS_DIR}/Package

# 清理
rm -f -r $PACKAGE

# 签名 
codesign -s - --entitlements "$PROJECT_DIR/$PROJECT_NAME/Shell/entitlements.plist" -f "${appPath}"

# 新建目录
mkdir -p "$PACKAGE/Payload"

# 拷贝目录
cp -r ${appPath} "$PACKAGE/Payload/"

cd "$PACKAGE" && zip -r "$PACKAGE/$NAME.tipa" *

# 打开路径
open "$PACKAGE/"
