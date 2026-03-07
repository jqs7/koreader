# KOReader 开发指南

## 开发环境设置

### 系统依赖

```bash
# macOS
brew install autoconf cmake meson ninja nasm gettext pkg-config

# Ubuntu/Debian
sudo apt install autoconf cmake meson ninja-build nasm gettext git make perl pkg-config

# 编译器要求
# - GCC/G++ 或 Clang/Clang++
# - 支持 C11 和 C++17
```

### 获取代码

```bash
git clone --recursive https://github.com/koreader/koreader.git
cd koreader

# 如果忘记 --recursive
git submodule update --init --recursive
```

### 构建和运行

```bash
# 主要开发脚本
./kodev --help

# 构建模拟器
./kodev build

# 运行模拟器
./kodev run

# 获取第三方依赖
./kodev fetch-thirdparty

# 清理构建
./kodev clean
```

## 调试

### 日志调试

```lua
local logger = require("logger")

-- 打印变量
logger.dbg("variable:", my_var)

-- 打印表
logger.dbg("table:", my_table)

-- 日志输出到 crash.log
```

日志格式：
```
04/06/17-21:44:53 DEBUG foo
```

### Widget 开发调试

使用 `wbuilder` 工具快速测试 UI 组件：

```bash
./kodev wbuilder
```

在 `tools/wbuilder.lua` 末尾添加测试代码：

```lua
local MyWidget = require("ui/widget/mywidget")
UIManager:show(MyWidget:new{
    -- 参数
})
```

## 构建目标平台

```bash
# 查看所有目标
./kodev build --help

# 构建特定平台
./kodev build kindle
./kodev build kobo
./kodev build android
./kodev build remarkable
./kodev build linux
./kodev build macos
```

平台构建规则位于 `make/` 目录：
- `kindle.mk`
- `kobo.mk`
- `android.mk`
- `remarkable.mk`
- `linux.mk`
- `macos.mk`

## 运行测试

```bash
# 运行所有测试
./kodev test

# 仅前端测试
./kodev test front

# 仅 base 测试
./kodev test base

# 运行单个测试
./kodev test front readerbookmark_spec.lua

# 列出可用测试
./kodev test -l
```

测试框架：
- **Busted** - Lua 单元测试
- **Meson test runner** - 并行执行

测试文件位置：
- `spec/unit/` - 前端测试
- `base/spec/unit/` - Base 层测试

## 代码检查

```bash
# Lua 静态检查
luacheck frontend plugins

# 配置文件：.luacheckrc
```

## 常用开发任务

### 添加新的阅读器模块

1. 在 `frontend/apps/reader/modules/` 创建文件
2. 继承 `EventListener` 或 `InputContainer`
3. 在 `frontend/apps/reader/readerui.lua` 中注册

```lua
-- frontend/apps/reader/modules/readermyfeature.lua
local EventListener = require("ui/widget/eventlistener")

local ReaderMyFeature = EventListener:extend{}

function ReaderMyFeature:init()
    -- 初始化
end

function ReaderMyFeature:onReaderReady()
    -- 阅读器准备就绪时调用
end

return ReaderMyFeature
```

### 添加新的 UI 组件

1. 在 `frontend/ui/widget/` 创建文件
2. 继承合适的基类（Widget、WidgetContainer 等）
3. 使用 `wbuilder` 测试

```lua
-- frontend/ui/widget/mywidget.lua
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local MyWidget = WidgetContainer:extend{
    width = nil,
    height = nil,
}

function MyWidget:init()
    -- 构建 UI
end

return MyWidget
```

### 添加设备支持

1. 在 `frontend/device/` 创建设备目录
2. 实现设备类，继承 `Generic`
3. 在 `frontend/device.lua` 中注册

## 文档生成

```bash
# 生成 API 文档（使用 LDoc）
# 配置文件：doc/config.ld
```

## 资源

- [官方文档](https://github.com/koreader/koreader/wiki)
- [开发者论坛](https://www.mobileread.com/forums/forumdisplay.php?f=276)
- [Issue 跟踪](https://github.com/koreader/koreader/issues)
