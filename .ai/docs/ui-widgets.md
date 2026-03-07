# UI Widget 系统详解

> 本文档详细介绍了 KOReader 的 UI Widget 系统，包括组件层次结构、常用组件和使用指南。

## 概述

KOReader 的 UI 系统采用组件化设计，所有界面元素都由 Widget 组成。Widget 继承自 `Widget` 基类，形成完整的组件层次结构。

### 核心设计原则

1. **组合优于继承**：通过容器组件组合基本 Widget 构建复杂界面
2. **事件驱动**：Widget 通过事件系统响应用户交互
3. **渲染分离**：Widget 负责自身渲染，通过 `paintTo()` 方法绘制到 Blitbuffer

## 组件层次结构

```
EventListener
    └── Widget
            └── WidgetContainer
                    ├── InputContainer (支持用户输入)
                    │       ├── Button
                    │       ├── Menu
                    │       ├── TextBoxWidget
                    │       └── ConfirmBox
                    │
                    └── Container (布局容器)
                            ├── FrameContainer (边框容器)
                            ├── CenterContainer (居中容器)
                            ├── VerticalGroup (垂直组)
                            ├── HorizontalGroup (水平组)
                            └── ...其他布局容器
```

## 基类组件

### Widget (`widget.lua`)
**功能**：所有 UI 组件的基类，提供基本的大小计算和渲染能力

**核心方法**：
```lua
-- 获取组件尺寸
function Widget:getSize()

-- 渲染到 Blitbuffer
function Widget:paintTo(bb, x, y)

-- 检查点是否在组件内
function Widget:pointInArea(x, y)
```

---

### WidgetContainer (`container/widgetcontainer.lua`)
**功能**：容器基类，可以包含子组件

**核心方法**：
```lua
-- 添加子组件（使用数组索引访问）
local container = VerticalGroup:new{
    TextWidget:new{text = "Title"},
    Button:new{text = "Click"},
}

-- 遍历子组件
function WidgetContainer:getChildren()
```

---

### InputContainer (`container/inputcontainer.lua`)
**功能**：处理用户输入事件的容器基类，所有交互式组件的父类

**核心特性**：
- 触摸区域管理 (`registerTouchZones`)
- 键盘事件处理 (`key_events`)
- 手势识别

**键盘事件定义**：
```lua
local MyWidget = InputContainer:extend{
    key_events = {
        Confirm = {"Enter"},           -- 单键
        Cancel = {"Back", "Escape"},   -- 多选一
        Pan = {Input.group.Cursor},    -- 组合键
    },
}

function MyWidget:onConfirm()
    -- 处理确认键
    return true
end
```

**触摸区域定义**：
```lua
function MyWidget:registerTouchZones()
    self:registerTouchZones({
        {
            id = "tap",
            ges = "tap",
            range = Geom:new{...},
            handler = function() ... end,
        },
    })
end
```

---

## 布局容器

### FrameContainer (`container/framecontainer.lua`)
**功能**：为子组件添加边框、背景和圆角

**属性**：
```lua
FrameContainer:new{
    background = Blitbuffer.COLOR_WHITE,  -- 背景色
    color = Blitbuffer.COLOR_BLACK,       -- 边框颜色
    radius = Size.radius.window,          -- 圆角半径
    bordersize = Size.border.window,      -- 边框宽度
    padding = Size.padding.default,       -- 内边距
    margin = 0,                           -- 外边距
}
```

---

### CenterContainer (`container/centercontainer.lua`)
**功能**：将子组件在容器内居中显示

**属性**：
```lua
CenterContainer:new{
    ignore_if_over = "height",  -- 如果内容超出时忽略高度计算
    -- 子组件
    TextWidget:new{text = "Centered"},
}
```

---

### VerticalGroup / HorizontalGroup
**功能**：垂直/水平排列子组件

```lua
VerticalGroup:new{
    align = "left",  -- 对齐方式
    TextWidget:new{text = "Line 1"},
    TextWidget:new{text = "Line 2"},
}
```

### 其他布局容器

| 容器 | 功能 |
|------|------|
| LeftContainer | 左对齐 |
| RightContainer | 右对齐 |
| TopContainer | 顶部对齐 |
| BottomContainer | 底部对齐 |
| ScrollableContainer | 可滚动容器 |
| MovableContainer | 可移动容器 |
| OverlapGroup | 重叠组合 |

## 基础组件

### TextWidget (`textwidget.lua`)
**功能**：单行文本显示组件

```lua
TextWidget:new{
    text = "Hello KOReader",
    face = Font:getFace("cfont"),     -- 字体
    bold = true,                       -- 粗体
    fgcolor = Blitbuffer.COLOR_BLACK,  -- 文字颜色
    max_width = 300,                   -- 最大宽度（超长截断）
    truncate_with_ellipsis = true,    -- 截断时显示省略号
}
```

---

### TextBoxWidget (`textboxwidget.lua`)
**功能**：多行文本显示，支持自动换行

```lua
TextBoxWidget:new{
    text = "Multi-line\ntext content",
    face = Font:getFace("cfont", 20),
    width = 400,                       -- 宽度（决定换行位置）
    alignment = "left",                -- 对齐方式
    justified = false,                 -- 两端对齐
    line_height = 0.3,                 -- 行高（em 单位）
}
```

---

### Button (`button.lua`)
**功能**：按钮组件，处理点击事件

```lua
Button:new{
    text = "Click Me",                 -- 按钮文字
    icon = "app.settings",             -- 图标（可选）
    callback = function()              -- 点击回调
        print("Button pressed!")
    end,
    enabled = true,                    -- 是否启用
    width = 200,                       -- 宽度
}
```

---

### Menu (`menu.lua`)
**功能**：菜单列表组件

```lua
Menu:new{
    title = "Settings",
    items = {
        {text = "Option 1", callback = function() end},
        {text = "Option 2", callback = function() end},
    },
    on_menu_selected = function(item) end,
}
```

**配置选项**：
- `items_per_page` - 每页显示项数
- `item_font_size` - 字体大小
- `shortcut_enable` - 显示快捷键

---

## 对话框组件

### ConfirmBox (`confirmbox.lua`)
**功能**：确认对话框

```lua
ConfirmBox:new{
    text = "Save changes?",
    ok_text = _("Save"),
    ok_callback = function()
        -- 保存操作
    end,
    cancel_callback = function()
        -- 取消操作
    end,
}
```

---

### ButtonDialog (`buttondialog.lua`)
**功能**：按钮列表对话框

```lua
ButtonDialog:new{
    title = "Choose action",
    buttons = {
        {
            {text = "Option 1", callback = function() end},
            {text = "Option 2", callback = function() end},
        },
    },
}
```

---

### InputDialog (`inputdialog.lua`)
**功能**：带输入框的对话框

```lua
InputDialog:new{
    title = "Enter name",
    input = "default value",
    input_hint = "placeholder",
    callback = function(input)
        print("Input:", input)
    end,
}
```

---

## 选择组件

### CheckButton (`checkbutton.lua`)
**功能**：复选框

```lua
CheckButton:new{
    text = "Enable feature",
    checked = false,
    callback = function()
        -- 切换状态
    end,
}
```

---

### RadioButton / RadioButtonTable
**功能**：单选按钮/单选按钮组

```lua
RadioButtonTable:new{
    choices = {
        {text = "Option A", value = "a"},
        {text = "Option B", value = "b"},
    },
    selected = "a",
}
```

---

### ToggleSwitch (`toggleswitch.lua`)
**功能**：开关组件

```lua
ToggleSwitch:new{
    name = "feature_enabled",
    default = true,
    values = {true, false},
    labels = {_("On"), _("Off")},
}
```

---

### SpinWidget (`spinwidget.lua`)
**功能**：数字选择器

```lua
SpinWidget:new{
    title = "Select size",
    value = 16,
    min = 8,
    max = 32,
    step = 2,
    callback = function(value)
        print("Selected:", value)
    end,
}
```

---

### NumberPickerWidget (`numberpickerwidget.lua`)
**功能**：日期/时间选择器

```lua
DateTimeWidget:new{
    year = 2024,
    month = 1,
    day = 15,
    hour = 12,
    min = 0,
    max = 23,
}
```

---

## 特殊组件

### ImageWidget (`imagewidget.lua`)
**功能**：图片显示

```lua
ImageWidget:new{
    file = "path/to/image.png",
    alpha = true,          -- 透明通道
    scale = "contain",     -- 缩放模式
}
```

---

### IconWidget (`iconwidget.lua`)
**功能**：图标显示

```lua
IconWidget:new{
    icon = "app.settings",  -- 图标名称
    size = 32,              -- 图标大小
}
```

---

### Notification (`notification.lua`)
**功能**：通知消息（底部弹出）

```lua
Notification:new{
    text = "Operation complete",
    icon = "check",
}
```

---

### ProgressWidget (`progresswidget.lua`)
**功能**：进度条

```lua
ProgressWidget:new{
    percentage = 50,        -- 进度百分比
    width = 300,
    height = 20,
}
```

---

## 组件组合示例

### 创建带标题的对话框

```lua
local VerticalGroup = require("ui/widget/verticalgroup")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local TextWidget = require("ui/widget/textwidget")
local Button = require("ui/widget/button")
local FrameContainer = require("ui/widget/container/framecontainer")

local dialog = FrameContainer:new{
    margin = 10,
    padding = 10,
    VerticalGroup:new{
        TextWidget:new{text = "Dialog Title", bold = true},
        -- 内容区域
        HorizontalGroup:new{
            Button:new{text = "Cancel"},
            Button:new{text = "OK"},
        },
    },
}
```

### 创建可滚动列表

```lua
local ListView = require("ui/widget/listview")
local ScrollTextWidget = require("ui/widget/scrolltextwidget")

ListView:new{
    allow_short_vertical_gap = true,
    ListView.Item = HorizontalGroup:new{
        TextWidget:new{text = "Item 1"},
    },
}
```

---

## 事件处理

### 触摸事件

```lua
local GestureRange = require("ui/gesturerange")

Button:new{
    -- 限制触摸区域
    bordersize = 0,
    padding = 10,
}
```

### 键盘事件

```lua
InputContainer:extend{
    key_events = {
        Select = {"Enter"},
        Cancel = {"Back", "Escape"},
        Home = {"Home"},
    },
}

function MyWidget:onSelect()
    return true  -- 表示事件已消费
end
```

---

## 尺寸与缩放

### 使用 Screen:scaleBySize

```lua
-- 屏幕尺寸缩放
local width = Screen:scaleBySize(400)  -- 屏幕宽度的比例缩放
local height = Screen:scaleBySize(50)  -- 屏幕高度的比例缩放
```

### 使用 Size 模块

```lua
local Size = require("ui/size")

Size.padding.default    -- 默认内边距
Size.border.window      -- 窗口边框宽度
Size.radius.window      -- 窗口圆角半径
```

---

## 性能优化

### 渲染优化

1. **减少重绘**：使用 `UIManager:setDirty()` 只标记需要重绘的区域
2. **缓存尺寸**：在 `init()` 中计算并缓存复杂布局的尺寸
3. **延迟加载**：大型组件使用懒加载

### 内存优化

1. **复用组件**：相同类型的组件尽量复用
2. **及时清理**：对话框关闭时清理引用
3. **控制数量**：避免创建大量临时组件

---

## 无障碍支持

### 语义标签

```lua
-- 为组件添加语义信息
Button:new{
    text = "Settings",
    accesskey = "s",  -- 快捷键
}
```

---

## 调试技巧

### 查看组件结构

```lua
-- 打印组件尺寸
print(widget:getSize())
print(widget.dimen)
```

### 边框调试

```lua
-- 添加临时边框查看布局
FrameContainer:new{
    bordersize = 1,
    color = Blitbuffer.RED,
    -- 内容
}
```

---

> 本文档最后更新：2025年2月24日
