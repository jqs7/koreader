# KOReader 代码风格指南

## 编辑器配置

项目使用 `.editorconfig` 统一代码格式：

```ini
# 默认配置
indent_style = space
indent_size = 4
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

# Markdown 文件
[*.md]
indent_size = 2
trim_trailing_whitespace = false

# Makefile
[Makefile*]
indent_style = tab
indent_size = 8
```

## Lua 代码规范

### Luacheck 配置

项目使用 Luacheck 进行静态检查（`.luacheckrc`）：

```lua
std = "luajit"
unused_args = false
self = false  -- 忽略隐式 self

-- 全局变量
globals = {
    "G_reader_settings",
    "G_defaults",
    "table.pack",
    "table.unpack",
}

-- 忽略的警告
ignore = {
    "211/__*",  -- 以 __ 开头的未使用局部变量
    "231/__",
    "631",      -- 行过长（暂时忽略）
}
```

### 命名约定

```lua
-- 局部变量：小写下划线
local my_variable = 1

-- 模块/类：大驼峰
local MyWidget = WidgetContainer:extend{}

-- 常量：大写下划线
local MAX_ITEMS = 100

-- 私有变量：双下划线前缀
local __internal_state = {}

-- 事件处理器：on + 事件名
function MyWidget:onTap(arg)
    return true  -- 返回 true 表示消费事件
end
```

### 模块结构

```lua
-- 标准模块结构
local MyModule = require("ui/widget/widget"):extend{}

-- 类属性
MyModule.name = "my_module"
MyModule.default_value = 0

-- 初始化
function MyModule:init()
    -- 初始化代码
end

-- 公共方法
function MyModule:doSomething()
    -- 实现
end

-- 事件处理
function MyModule:onSomeEvent(args)
    return true
end

return MyModule
```

### require 规范

```lua
-- 使用相对路径
local UIManager = require("ui/uimanager")
local Device = require("device")
local logger = require("logger")

-- 延迟加载（避免循环依赖）
local ReaderUI
function MyModule:getReaderUI()
    if not ReaderUI then
        ReaderUI = require("apps/reader/readerui")
    end
    return ReaderUI
end
```

## 日志规范

```lua
local logger = require("logger")

-- 调试日志（生产环境不输出）
logger.dbg("table a:", a)

-- 信息日志
logger.info("Loading document:", path)

-- 警告日志
logger.warn("Deprecated function called")

-- 错误日志
logger.err("Failed to open file:", err)

-- 注意：避免在日志参数中进行复杂计算
-- 错误示例
logger.dbg("result:", expensive_computation())

-- 正确示例
if logger.dbg.is_on then
    logger.dbg("result:", expensive_computation())
end
```

## UI 组件规范

### Widget 继承

```lua
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local MyWidget = WidgetContainer:extend{
    width = nil,
    height = nil,
    -- 其他属性
}

function MyWidget:init()
    self[1] = FrameContainer:new{
        -- 子组件
    }
end
```

### 事件处理

```lua
-- 事件传播：子组件优先
function MyWidget:handleEvent(event)
    -- 先传递给子组件
    for _, widget in ipairs(self) do
        if widget:handleEvent(event) then
            return true  -- 子组件消费了事件
        end
    end
    -- 自己处理
    return self["on"..event.name](self, unpack(event.args))
end

-- 发送事件
UIManager:sendEvent(Event:new("Refresh"))
UIManager:broadcastEvent(Event:new("UpdatePos"))
```

## 测试规范

```lua
-- 测试文件位于 spec/unit/
-- 使用 busted 框架

describe("MyModule", function()
    local MyModule
    
    setup(function()
        MyModule = require("mymodule")
    end)
    
    it("should do something", function()
        local result = MyModule:doSomething()
        assert.is_true(result)
    end)
end)
```

## Git 提交规范

提交信息格式：
```
<type>(<scope>): <subject>

<body>

<footer>
```

类型：
- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `style`: 代码格式
- `refactor`: 重构
- `test`: 测试
- `chore`: 构建/工具
