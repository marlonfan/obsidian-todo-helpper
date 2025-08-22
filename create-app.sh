#!/bin/bash

echo "📦 创建应用包..."

# 构建应用
./build.sh

if [ $? -ne 0 ]; then
    echo "❌ 构建失败"
    exit 1
fi

# 创建应用包结构
APP_NAME="Obsidian Todo Mac"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🗂 创建应用包结构..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 复制可执行文件
cp .build/ObsidianTodoMac "${MACOS_DIR}/ObsidianTodoMac"

# 创建 Info.plist
cat > "${CONTENTS_DIR}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ObsidianTodoMac</string>
    <key>CFBundleIdentifier</key>
    <string>com.obsidian.todo.mac</string>
    <key>CFBundleName</key>
    <string>Obsidian Todo Mac</string>
    <key>CFBundleDisplayName</key>
    <string>Obsidian Todo Mac</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# 设置执行权限
chmod +x "${MACOS_DIR}/ObsidianTodoMac"

echo "✅ 应用包创建完成: ${APP_DIR}"
echo ""
echo "🚀 运行应用:"
echo "   open '${APP_DIR}'"
echo ""
echo "📁 或双击应用包运行"