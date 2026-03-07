# KOReader 项目架构

## 概述

KOReader 是一个开源的电子书阅读器，采用 **Lua + C/FFI** 架构，支持多种电子墨水设备和桌面平台。

## 技术栈

| 技术 | 用途 |
|------|------|
| **Lua** | 主要开发语言（前端、UI、业务逻辑） |
| **LuaJIT** | Lua 运行时，提供 FFI 支持 |
| **C/C++** | 底层库和性能关键代码 |
| **FFI** | Lua 调用 C 库的桥梁 |

## 目录结构

```
koreader/
├── base/                   # koreader-base 子模块（底层 C/C++ 库、FFI 绑定）
│   ├── ffi/               # LuaJIT FFI 绑定
│   └── thirdparty/        # 第三方 C/C++ 库（64个）
├── frontend/              # Lua 前端核心代码
│   ├── apps/              # 应用模块
│   │   ├── reader/        # 阅读器应用
│   │   ├── filemanager/   # 文件管理器
│   │   └── cloudstorage/  # 云存储
│   ├── device/            # 设备抽象层
│   ├── document/          # 文档处理模块
│   ├── ui/                # UI 框架
│   │   ├── widget/        # UI 组件（80+）
│   │   └── uimanager.lua  # UI 管理器
│   └── luadefaults.lua    # Lua 默认配置
├── plugins/               # 插件目录（36个 .koplugin）
├── platform/              # 平台特定代码（13个平台）
├── l10n/                  # 国际化翻译（60+ 语言）
├── spec/                  # 前端单元测试
├── test/                  # 测试数据（子模块）
├── doc/                   # 开发文档
├── resources/             # 字体、图标资源
├── make/                  # 各平台构建规则
├── tools/                 # 构建和发布工具
├── reader.lua             # 主入口
├── setupkoenv.lua         # 环境设置
├── datastorage.lua        # 数据存储路径管理
└── defaults.lua           # 默认配置
```

## 核心模块

### 入口点

- `reader.lua` - 主入口，启动 KOReader
- `setupkoenv.lua` - Lua/FFI 搜索路径设置
- `datastorage.lua` - 数据存储路径管理
- `defaults.lua` - 默认配置

### 设备抽象层 (`frontend/device/`)

支持的设备平台：
- `kindle/` - Amazon Kindle 系列
- `kobo/` - Kobo 系列
- `android/` - Android 设备
- `remarkable/` - reMarkable 平板
- `pocketbook/` - PocketBook 系列
- `cervantes/` - BQ Cervantes
- `sony-prstux/` - Sony PRS-T
- `sdl/` - 桌面模拟器

关键文件：
- `input.lua` - 输入事件处理
- `gesturedetector.lua` - 手势识别
- `key.lua` - 按键映射
- `sysfs_light.lua` - 背光控制

### 文档处理 (`frontend/document/`)

- `credocument.lua` - CREngine 文档（EPUB、FB2、DOC、RTF 等）
- `pdfdocument.lua` - PDF 文档（MuPDF）
- `djvudocument.lua` - DjVu 文档
- `picdocument.lua` - 图片文档

### UI 框架 (`frontend/ui/`)

- `uimanager.lua` - UI 管理器，事件循环
- `widget/` - 80+ UI 组件
- `font.lua` - 字体管理
- `bidi.lua` - RTL 语言支持

### 阅读器模块 (`frontend/apps/reader/modules/`)

36 个功能模块：
- `readerbookmark.lua` - 书签管理
- `readerhighlight.lua` - 高亮标注
- `readerdictionary.lua` - 词典查询
- `readertoc.lua` - 目录导航
- `readerfooter.lua` - 页脚状态栏
- `readerfont.lua` - 字体设置
- `readerview.lua` - 视图渲染
- `readerrolling.lua` - 滚动模式
- `readerpaging.lua` - 翻页模式

## 第三方库

主要依赖（位于 `base/thirdparty/`）：

| 库 | 用途 |
|---|------|
| MuPDF | PDF/XPS/EPUB 渲染 |
| CREngine (kpvcrlib) | EPUB/FB2/DOC/RTF 渲染 |
| DjVuLibre | DjVu 格式支持 |
| FreeType2 | 字体渲染 |
| HarfBuzz | 文本整形 |
| SDL3 | 跨平台图形/输入（模拟器） |
| libk2pdfopt | PDF 重排 |
| Tesseract | OCR |
| SQLite | 数据库 |
| cURL | 网络请求 |
| ZeroMQ | 消息队列 |

## 数据流

```
用户输入 → Device/Input → GestureDetector → UIManager → Widget
                                                ↓
                                           Event System
                                                ↓
                                         Reader Modules
                                                ↓
                                        Document Layer
                                                ↓
                                      FFI → C Libraries
```

## 事件系统

KOReader 使用事件驱动架构：

1. 所有 Widget 继承自 `EventListener`
2. 事件通过 `handleEvent` 方法传递
3. 子组件优先处理事件，返回 `true` 表示消费
4. `UIManager` 管理事件分发和窗口栈
