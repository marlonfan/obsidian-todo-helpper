#!/bin/bash

echo "🧪 测试 Obsidian Todo Mac 应用..."

# 检查应用包是否存在
if [ ! -d "Obsidian Todo Mac.app" ]; then
    echo "❌ 应用包不存在，请先运行 ./create-app.sh"
    exit 1
fi

echo "✅ 应用包存在"

# 检查可执行文件
if [ ! -f "Obsidian Todo Mac.app/Contents/MacOS/ObsidianTodoMac" ]; then
    echo "❌ 可执行文件不存在"
    exit 1
fi

echo "✅ 可执行文件存在"

# 检查Info.plist
if [ ! -f "Obsidian Todo Mac.app/Contents/Info.plist" ]; then
    echo "❌ Info.plist不存在"
    exit 1
fi

echo "✅ Info.plist存在"

# 验证应用包结构
echo "📂 应用包结构:"
find "Obsidian Todo Mac.app" -type f | head -10

echo ""
echo "🎉 所有测试通过!"
echo ""
echo "🚀 启动应用测试:"
echo "   open 'Obsidian Todo Mac.app'"