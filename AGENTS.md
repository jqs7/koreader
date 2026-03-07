# KOReader AI 开发助手指南

> 本文档为 AI 编程助手提供 KOReader 项目的上下文信息。

## 项目概述

KOReader 是一个开源的电子书阅读器，采用 **Lua + C/FFI** 架构，支持 Kindle、Kobo、reMarkable、PocketBook、Android 等多种平台。

## 技术栈

- **主语言**: Lua (LuaJIT)
- **底层**: C/C++ (通过 FFI 调用)
- **构建**: Make + CMake + Meson
- **测试**: Busted (Lua 单元测试)

## 详细文档

| 文档 | 说明 |
|------|------|
| [项目架构](.ai/docs/project-architecture.md) | 目录结构、核心模块、技术栈、数据流 |
| [模块说明](.ai/docs/module-reference.md) | 各模块功能详解、文件说明 |
| [数据流与交互](.ai/docs/dataflow.md) | 事件系统、渲染流程、模块通信 |
| [核心类说明](.ai/docs/core-classes.md) | UIManager、Document、Widget 等核心类 |
| [算法机制](.ai/docs/algorithms.md) | 手势检测、缓存、渲染等核心算法 |
| [Reader模块](.ai/docs/reader-modules.md) | 39个阅读器模块详解 |
| [UI组件](.ai/docs/ui-widgets.md) | UI 组件系统、容器、对话框 |
| [工具模块](.ai/docs/utilities.md) | 工具函数、日志、缓存等 |
| [开发指南](.ai/docs/development-guide.md) | 环境设置、构建运行、调试方法 |
| [代码风格](.ai/docs/code-style.md) | 编码规范、命名约定、日志规范 |
| [测试指南](.ai/docs/testing.md) | 测试框架、编写测试、运行测试 |
| [插件开发](.ai/docs/plugin-development.md) | 插件结构、API 使用、示例代码 |
| [krengine库](.ai/docs/krengine.md) | Rust底层库、压缩解压、图像处理、哈希计算 |

## 快速参考

### 目录结构

```
koreader/
├── frontend/          # Lua 前端代码
│   ├── apps/          # 应用（阅读器、文件管理器）
│   ├── device/        # 设备抽象层
│   ├── document/      # 文档处理
│   └── ui/            # UI 框架和组件
├── plugins/           # 插件 (*.koplugin)
├── base/              # C/C++ 底层库和 FFI 绑定
├── platform/          # 平台特定代码
├── spec/              # 单元测试
└── doc/               # 官方文档
```

### 常用命令

```bash
./kodev build          # 构建模拟器
./kodev run            # 运行模拟器
./kodev test           # 运行测试
./kodev test front     # 仅前端测试
./kodev wbuilder       # Widget 开发调试
```

### 关键入口文件

- `reader.lua` - 主入口
- `frontend/apps/reader/readerui.lua` - 阅读器 UI
- `frontend/apps/filemanager/filemanager.lua` - 文件管理器
- `frontend/ui/uimanager.lua` - UI 管理器
- `frontend/device.lua` - 设备检测

### 代码规范要点

- 缩进：4 空格
- 命名：模块用大驼峰，变量用小写下划线
- 日志：使用 `logger.dbg/info/warn/err`
- 国际化：使用 `_("text")` 包装文本
- 事件：返回 `true` 表示消费事件

## 官方文档

项目自带文档位于 `doc/` 目录：
- `doc/Building.md` - 构建环境
- `doc/Hacking.md` - 开发调试
- `doc/Events.md` - 事件系统
- `doc/Unit_tests.md` - 单元测试
