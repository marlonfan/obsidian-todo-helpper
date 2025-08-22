#!/bin/bash

echo "🚀 构建 Obsidian Todo Mac..."

# 检查是否有 Swift
if ! command -v swift &> /dev/null; then
    echo "❌ 错误: 需要安装 Xcode 或 Swift toolchain"
    exit 1
fi

# 创建构建目录
mkdir -p .build

# 编译项目
echo "📦 编译中..."
swift build -c release

if [ $? -eq 0 ]; then
    echo "✅ 编译成功!"
    
    # 复制可执行文件
    cp .build/release/ObsidianTodoMac .build/ObsidianTodoMac
    
    echo "🎉 构建完成!"
    echo "可执行文件: .build/ObsidianTodoMac"
    echo ""
    echo "运行应用: ./.build/ObsidianTodoMac"
else
    echo "❌ 编译失败!"
    exit 1
fi