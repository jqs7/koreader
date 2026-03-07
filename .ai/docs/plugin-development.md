# KOReader 插件开发指南

## 插件概述

KOReader 插件是独立的功能模块，位于 `plugins/` 目录，以 `.koplugin` 后缀命名。

## 现有插件

| 插件 | 功能 |
|------|------|
| `calibre.koplugin` | Calibre 无线连接 |
| `kosync.koplugin` | 阅读进度云同步 |
| `statistics.koplugin` | 阅读统计 |
| `vocabbuilder.koplugin` | 生词本 |
| `opds.koplugin` | OPDS 目录浏览 |
| `SSH.koplugin` | SSH 服务器 |
| `exporter.koplugin` | 笔记导出 |
| `newsdownloader.koplugin` | 新闻下载 |
| `wallabag.koplugin` | Wallabag 集成 |
| `coverbrowser.koplugin` | 封面浏览 |
| `gestures.koplugin` | 自定义手势 |
| `profiles.koplugin` | 配置文件 |
| `readtimer.koplugin` | 阅读计时器 |
| `terminal.koplugin` | 终端模拟器 |
| `texteditor.koplugin` | 文本编辑器 |

## 插件结构

```
plugins/
└── myplugin.koplugin/
    ├── main.lua           # 入口文件（必需）
    ├── _meta.lua          # 元数据（可选）
    └── ...                # 其他模块
```

### main.lua 基本结构

```lua
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local MyPlugin = WidgetContainer:extend{
    name = "myplugin",
    is_doc_only = false,  -- true 表示仅在阅读文档时可用
}

function MyPlugin:init()
    self.ui.menu:registerToMainMenu(self)
end

function MyPlugin:addToMainMenu(menu_items)
    menu_items.myplugin = {
        text = _("My Plugin"),
        sorting_hint = "tools",
        sub_item_table = {
            {
                text = _("Settings"),
                callback = function()
                    self:showSettings()
                end,
            },
        },
    }
end

function MyPlugin:showSettings()
    -- 显示设置界面
end

return MyPlugin
```

### _meta.lua 元数据

```lua
local _ = require("gettext")
return {
    name = "myplugin",
    fullname = _("My Plugin"),
    description = _([[A description of what this plugin does.]]),
}
```

## 插件类型

### 1. 文档相关插件 (is_doc_only = true)

仅在打开文档时加载：

```lua
local MyPlugin = WidgetContainer:extend{
    name = "myplugin",
    is_doc_only = true,
}

function MyPlugin:init()
    -- self.ui 是 ReaderUI 实例
    -- self.ui.document 是当前文档
end
```

### 2. 全局插件 (is_doc_only = false)

始终可用：

```lua
local MyPlugin = WidgetContainer:extend{
    name = "myplugin",
    is_doc_only = false,
}

function MyPlugin:init()
    -- 在文件管理器和阅读器中都可用
end
```

## 常用 API

### 菜单注册

```lua
function MyPlugin:addToMainMenu(menu_items)
    menu_items.myplugin = {
        text = _("My Plugin"),
        sorting_hint = "tools",  -- 菜单位置
        sub_item_table = {
            {
                text = _("Option 1"),
                callback = function() ... end,
            },
            {
                text = _("Toggle Option"),
                checked_func = function()
                    return self.enabled
                end,
                callback = function()
                    self.enabled = not self.enabled
                end,
            },
        },
    }
end
```

### 设置存储

```lua
-- 全局设置
local settings = G_reader_settings:readSetting("myplugin") or {}
G_reader_settings:saveSetting("myplugin", settings)

-- 文档设置
local doc_settings = self.ui.doc_settings
local value = doc_settings:readSetting("myplugin_value")
doc_settings:saveSetting("myplugin_value", value)
```

### UI 组件

```lua
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")

-- 显示消息
UIManager:show(InfoMessage:new{
    text = _("Hello World!"),
})

-- 输入对话框
local dialog = InputDialog:new{
    title = _("Enter value"),
    input = "",
    buttons = {
        {
            {
                text = _("Cancel"),
                callback = function()
                    UIManager:close(dialog)
                end,
            },
            {
                text = _("OK"),
                callback = function()
                    local value = dialog:getInputText()
                    UIManager:close(dialog)
                    -- 处理输入
                end,
            },
        },
    },
}
UIManager:show(dialog)
dialog:onShowKeyboard()
```

### 事件处理

```lua
function MyPlugin:onReaderReady()
    -- 文档加载完成
end

function MyPlugin:onCloseDocument()
    -- 文档关闭前
end

function MyPlugin:onPageUpdate(pageno)
    -- 页面更新
end

function MyPlugin:onHighlight(highlight)
    -- 高亮创建
end
```

### 网络请求

```lua
local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("json")

local function fetchData(url)
    local response = {}
    local _, code = http.request{
        url = url,
        sink = ltn12.sink.table(response),
    }
    if code == 200 then
        return json.decode(table.concat(response))
    end
    return nil
end
```

## 调试插件

```lua
local logger = require("logger")

function MyPlugin:init()
    logger.dbg("MyPlugin: initializing")
end
```

查看日志：`crash.log`

## 示例：hello.koplugin

参考 `plugins/hello.koplugin/` 作为最简单的插件示例。

## 最佳实践

1. **国际化**：使用 `_("text")` 包装所有用户可见文本
2. **错误处理**：捕获并记录错误，避免崩溃
3. **资源清理**：在 `onCloseDocument` 中清理资源
4. **设置持久化**：使用 `G_reader_settings` 或 `doc_settings`
5. **菜单组织**：使用合适的 `sorting_hint`
