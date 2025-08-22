# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Building the Application
```bash
# Build the Swift package
./build.sh

# Create complete macOS application bundle
./create-app.sh

# Test application bundle structure
./test.sh
```

### Running the Application
```bash
# Run compiled executable directly
./.build/ObsidianTodoMac

# Run application bundle
open "Obsidian Todo Mac.app"
```

### Manual Swift Commands
```bash
# Compile in release mode
swift build -c release

# Compile in debug mode
swift build
```

## Recent Improvements (Latest Updates)

### Fixed Issues
1. **Todo Creation Bug**: Fixed the addTodoToContent parser logic that was preventing new todos from being added properly
2. **Performance Optimization**: Limited "全部todo" view to only show recent 30 days instead of all historical data
3. **UI Direction**: Changed expansion direction from right to left for better screen edge usage
4. **Hover Precision**: Reduced hover area to only the time text instead of entire compact view
5. **Hover Stability**: Fixed infinite expand/collapse loop by implementing proper hover state management with timer debouncing
6. **Input Field Focus**: Fixed TextField click issue by removing Settings scene and creating custom FloatingWindow class that can accept keyboard focus
7. **UI Alignment**: Fixed input field and button alignment issues
8. **Historical Todo Editing**: Fixed inability to complete/uncomplete todos in "全部todo" view by implementing toggleHistoricalTodo method
9. **Simplified Input**: Removed add button, now using Enter key only for a cleaner interface

### New Features
10. **Template File Support**: Added ability to set a template file that automatically creates daily notes when they don't exist
11. **Custom Todo Section Header**: Made the todo section identifier configurable (default: "### 重点事项")
12. **Settings Interface**: Added comprehensive settings panel accessible via gear icon in the main interface

### UI/UX Enhancements
1. **Clean Time Display**: 
   - Simplified time component with transparent background
   - Black text for better readability
   - Subtle hover scaling effect

2. **Improved Todo Display**:
   - Visual feedback for completed todos (green background tint)
   - Better checkboxes using circle icons instead of squares
   - Enhanced spacing and padding

3. **Enhanced Date Display**:
   - Smart date formatting (今天/昨天/MM月dd日)
   - Todo count badges for each day
   - Calendar icons for better visual hierarchy

4. **Better Input Experience**:
   - Streamlined single input field with Enter-to-add functionality
   - Clean design with rounded corners and blue accent borders
   - Contextual placeholder text and helpful hints
   - Full keyboard-driven workflow
   - Historical todo editing support in "全部todo" view

5. **Advanced Configuration**:
   - Template file support with {{date}} and {{today}} placeholders
   - Customizable todo section headers for different workflows
   - Persistent settings storage in ~/Library/Application Support/ObsidianTodoMac/
   - File picker integration for easy template selection

## Project Architecture

This is a native macOS application built with Swift and SwiftUI that creates a floating todo widget for Obsidian daily notes.

### Core Components

- **App.swift**: Application entry point and window configuration. Creates a borderless floating window positioned in the top-right corner of the screen. Configured as accessory app (no dock icon). Uses custom FloatingWindow class for keyboard focus support.

- **TodoViewModel.swift**: Main business logic handling Obsidian vault detection, file monitoring, and todo management. Automatically searches common Obsidian locations and provides file system monitoring for real-time updates. Includes AppConfig class for persistent settings management.

- **ObsidianParser.swift**: Markdown parsing engine with configurable section headers. Supports custom todo section identifiers and template-based file creation with placeholder substitution ({{date}}, {{today}}).

- **ContentView.swift**: SwiftUI interface with dual-mode display (compact time view ⇄ expanded todo interface). Features modern glass morphism design, settings panel, and comprehensive todo management UI.

- **WindowController.swift**: Window management utilities for resizing and positioning. Updated to expand leftward instead of rightward.

- **Models.swift**: Data structures for Todo items and DailyTodos collections.

### Key Features

- **Dual Interface**: Compact 180×120 time display that expands to 480×560 todo interface on precise hover
- **Obsidian Integration**: Reads and writes directly to Obsidian daily note files (YYYY-MM-DD.md format)
- **Template System**: Automatically creates daily files from customizable templates when they don't exist
- **Configurable Parsing**: Customizable todo section headers to adapt to different Obsidian workflows
- **File Monitoring**: Real-time synchronization when Obsidian files are modified externally
- **Auto-Discovery**: Automatically detects Obsidian vaults in common locations
- **Transparent Window**: Borderless floating window that stays on top of all applications
- **Performance Optimized**: 30-day limit on historical todo loading
- **Modern UI**: Clean design with settings panel and visual feedback
- **Historical Editing**: Can complete/uncomplete todos from any date in the past 30 days

### Configuration Storage

Application stores all configurations in:
```
~/Library/Application Support/ObsidianTodoMac/
├── vault_path.txt      # Obsidian vault directory path
├── template_path.txt   # Template file path (optional)
└── todo_header.txt     # Custom todo section header
```

### Supported Markdown Format

The application parses configurable todo sections in daily note files (default: "### 重点事项"):
```markdown
2024-08-22

### 重点事项
- [ ] Incomplete task
- [x] Completed task

### Other sections are ignored
```

### Template System

Templates support the following placeholders:
- `{{date}}` - Current date in YYYY-MM-DD format
- `{{today}}` - Same as {{date}}

Example template:
```markdown
# {{date}}

## 📅 今日计划
### 重点事项
- [ ] 

## 📝 笔记

## 🎯 总结
```

### System Requirements

- macOS 13.0+ (specified in Package.swift)
- Swift 5.9+ (swift-tools-version)
- No external dependencies (native SwiftUI/AppKit only)