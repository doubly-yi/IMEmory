#!/bin/bash
# 构建并安装到 /Applications/输入定格.app
# 说明:可执行文件名保持 ASCII 的 IMEmory(进程名/pgrep 用),
#       但 .app bundle 文件名用中文“输入定格”,这样 Finder/访达里显示中文名。
#       因为用 Apple Development 证书签名,TCC 权限按身份匹配、与路径无关,改名不丢授权。
set -e
cd "$(dirname "$0")/.."

# 需要你自己的 Apple 开发者团队 ID 来做身份签名(TCC 权限按身份匹配,不丢授权)。
# 用法:export DEVELOPMENT_TEAM=你的TeamID  然后再跑本脚本。
# 团队 ID 可在 https://developer.apple.com/account 的 Membership 页查看(10 位字符)。
: "${DEVELOPMENT_TEAM:?请先设置 DEVELOPMENT_TEAM(你的 Apple 开发者团队 ID),例如 export DEVELOPMENT_TEAM=XXXXXXXXXX}"

xcodegen generate
xcodebuild -project IMEmory.xcodeproj -scheme IMEmoryApp -configuration Release \
    -derivedDataPath build build | tail -2

pkill -9 -x IMEmory 2>/dev/null || true
rm -rf "/Applications/输入定格.app"
cp -R build/Build/Products/Release/IMEmory.app "/Applications/输入定格.app"
codesign --verify --verbose "/Applications/输入定格.app" 2>&1 | tail -1
echo "✓ 已安装到 /Applications/输入定格.app"
