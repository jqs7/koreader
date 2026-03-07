# KOReader 核心类说明文档

> 本文档详细介绍 KOReader 的核心类和关键 API。

## 目录

1. [UIManager](#uimanager)
2. [Device](#device)
3. [Document 类族](#document-类族)
4. [ReaderUI 和模块](#readerui-和模块)
5. [Widget 类族](#widget-类族)
6. [Event 和事件处理](#event-和事件处理)
7. [设置管理类](#设置管理类)
8. [缓存系统](#缓存系统)

---

## UIManager

**文件**: `frontend/ui/uimanager.lua`

**职责**: UI 管理器，负责事件循环、窗口栈管理和刷新调度。

### 单例模式

```lua
local UIManager = {
    _window_stack = {},      -- 窗口栈
    _task_queue = {},        -- 任务队列
    _dirty = {},             -- 脏区域标记
    _refresh_stack = {},     -- 刷新请求栈
    -- ... 其他属性
}
```

### 核心方法

#### 窗口管理

```lua
-- 显示 widget
function UIManager:show(widget, refreshtype, refreshregion, refreshdither)
    -- 将 widget 添加到窗口栈
    -- refreshtype: "full", "partial", "ui", "flashui", "fast", "a2"
end

-- 关闭 widget
function UIManager:close(widget, refreshtype, refreshregion, refreshdither)
    -- 从窗口栈移除 widget
end

-- 获取顶部 widget
function UIManager:getTopWidget()
    return self._window_stack[#self._window_stack]
end
```

#### 事件发送

```lua
-- 发送事件给顶部 widget
function UIManager:sendEvent(event)
    -- 从栈顶向下传递，直到被消费
end

-- 广播事件给所有 active widgets
function UIManager:broadcastEvent(event)
    -- 遍历 _window_stack，发送给所有 is_always_active 的 widget
end

-- 设置 dirty 区域（标记需要重绘）
function UIManager:setDirty(widget, refreshtype, refreshregion)
    -- 添加到 _dirty 和 _refresh_stack
end
```

#### 任务调度

```lua
-- 下一帧执行
function UIManager:nextTick(callback)
    table.insert(self._task_queue, { callback = callback })
end

-- 延迟执行
function UIManager:scheduleIn(seconds, callback)
    local when = time.now() + seconds * 1000
    table.insert(self._task_queue, { when = when, callback = callback })
end

-- 取消任务
function UIManager:unschedule(callback)
    -- 从任务队列移除
end
```

#### 主循环

```lua
function UIManager:run()
    while self._exit_code == nil do
        -- 1. 处理输入事件
        self:_handleInput()
        
        -- 2. 执行任务队列
        self:_checkTasks()
        
        -- 3. 绘制 dirty widgets
        self:_repaint()
        
        -- 4. 刷新屏幕
        self:_refresh()
    end
end
```

### 使用示例

```lua
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local _ = require("gettext")

-- 显示提示
UIManager:show(InfoMessage:new{
    text = _("Hello, KOReader!")
})

-- 发送事件
UIManager:sendEvent(Event:new("UpdateUI"))

-- 延迟任务
UIManager:scheduleIn(5, function()
    print("5 seconds later")
end)
```

---

## Device

**文件**: `frontend/device.lua`, `frontend/device/generic/device.lua`

**职责**: 设备抽象层，提供硬件功能的统一接口。

### 设备检测

```lua
-- frontend/device.lua
local function probeDevice()
    if isAndroid then
        return require("device/android/device")
    elseif lfs.attributes("/proc/usid") then
        return require("device/kindle/device")
    elseif lfs.attributes("/bin/kobo_config.sh") then
        return require("device/kobo/device")
    -- ... 其他平台
    end
end

return probeDevice()
```

### 核心属性

```lua
local Device = {
    -- 硬件组件
    screen = nil,      -- Screen 对象
    input = nil,       -- Input 对象
    powerd = nil,      -- 电源管理
    
    -- 状态
    screen_saver_mode = false,
    is_cover_closed = false,
    
    -- 能力标志（函数）
    hasBattery = yes,
    hasTouchDevice = no,
    hasFrontlight = no,
    canSuspend = no,
    canReboot = no,
    -- ...
}
```

### 核心方法

#### 硬件控制

```lua
-- 电源管理
function Device:onPowerEvent(ev) end
function Device:suspend() end
function Device:resume() end
function Device:reboot() end
function Device:powerOff() end

-- WiFi
function Device:initNetworkManager() end
function Device:retrieveNetworkInfo() end

-- 输入
function Device:setIgnoreInput(toggle) end
function Device:restoreInput() end
```

#### 能力检测

```lua
-- 检测平台
function Device:isAndroid() end
function Device:isKindle() end
function Device:isKobo() end
function Device:isSDL() end

-- 检测硬件能力
function Device:hasBattery() end
function Device:hasKeyboard() end
function Device:hasFrontlight() end
function Device:hasWifiToggle() end
```

### 使用示例

```lua
local Device = require("device")

-- 检测平台
if Device:isKindle() then
    -- Kindle 特定代码
end

-- 检查硬件能力
if Device:hasFrontlight() then
    Device.powerd:setIntensity(50)
end

-- 控制 WiFi
if Device:hasWifiToggle() then
    Device:initNetworkManager()
end
```

---

## Document 类族

**基类文件**: `frontend/document/document.lua`

### Document 基类

```lua
local Document = {
    file = nil,              -- 文件路径
    _document = nil,         -- 底层引擎实例
    is_open = false,
    is_locked = false,
    is_edited = false,
    
    info = {
        has_pages = false,   -- 是否分页
        number_of_pages = 0,
        doc_height = 0,      -- 滚动文档高度
    },
    
    links = {},              -- 链接表
    bbox = {},               -- 边界框
}
```

#### 核心方法

```lua
-- 生命周期
function Document:new(o) end
function Document:init() end
function Document:close() end
function Document:unlock(password) end

-- 页面信息
function Document:getNativePageDimensions(pageno) end
function Document:getPageCount() end
function Document:getToc() end

-- 渲染
function Document:drawPage(target, x, y, rect, pageno, zoom, rotation) end
function Document:renderPage(pageno, rect, zoom, rotation) end

-- 链接
function Document:getPageLinks(pageno) end
function Document:getLinkFromPosition(pageno, x, y) end
```

### CreDocument (EPUB/FB2/HTML/TXT)

**文件**: `frontend/document/credocument.lua`

**引擎**: CREngine

```lua
local CreDocument = Document:extend{
    -- CRE 特有属性
    engine_initilized = false,
    default_css = "./data/epub.css",
    
    -- 可配置项
    configurable = {
        font_size = 22,
        line_space_percent = 100,
        page_margins = { ... },
        -- ...
    }
}
```

#### 特有方法

```lua
-- 基于位置的导航
function CreDocument:getPosFromXPointer(xpointer) end
function CreDocument:getXPointer() end
function CreDocument:gotoXPointer(xpointer) end

-- 文本选择
function CreDocument:getTextFromPositions(pos0, pos1) end

-- 排版设置
function CreDocument:setFontSize(size) end
function CreDocument:setStyleSheet(css) end
function CreDocument:setEmbeddedStyleSheet(enable) end
```

### PdfDocument (PDF)

**文件**: `frontend/document/pdfdocument.lua`

**引擎**: MuPDF

```lua
local PdfDocument = Document:extend{
    is_color_capable = true,
    -- PDF 特有属性
}
```

#### 特有方法

```lua
-- 文本提取
function PdfDocument:getTextFromPositions(pos0, pos1) end
function PdfDocument:getPageText(pageno) end

-- 页面属性
function PdfDocument:getPageLinks(pageno) end
function PdfDocument:getUsedBBox(pageno) end
```

### DocumentRegistry

**文件**: `frontend/document/documentregistry.lua`

**职责**: 文档类型注册和管理。

```lua
local DocumentRegistry = {
    providers = {},          -- 格式 -> Document 类映射
    document_cache = {},     -- 文档实例缓存
}
```

#### 核心方法

```lua
-- 注册文档类型
function DocumentRegistry:addProvider(extension, mimetype, provider)
    -- extension: "epub", "pdf", ...
    -- provider: CreDocument, PdfDocument, ...
end

-- 检查是否支持
function DocumentRegistry:hasProvider(file) end

-- 打开文档
function DocumentRegistry:openDocument(file, password)
    -- 查找 provider
    -- 创建实例
    -- 管理引用计数
end
```

---

## ReaderUI 和模块

### ReaderUI

**文件**: `frontend/apps/reader/readerui.lua`

**职责**: 阅读器主控制器，协调所有阅读器模块。

```lua
local ReaderUI = InputContainer:extend{
    name = "ReaderUI",
    document = nil,          -- Document 实例
    doc_settings = nil,      -- 文档设置
    
    -- 注册的模块
    view = nil,              -- ReaderView
    rolling = nil,           -- ReaderRolling
    paging = nil,            -- ReaderPaging
    toc = nil,               -- ReaderToc
    bookmark = nil,          -- ReaderBookmark
    -- ... 其他模块
}
```

#### 核心方法

```lua
-- 模块注册
function ReaderUI:registerModule(name, ui_module, always_active)
    self[name] = ui_module
    table.insert(self, ui_module)
    if always_active then
        table.insert(self.active_widgets, ui_module)
    end
end

-- 初始化回调
function ReaderUI:registerPostInitCallback(callback) end
function ReaderUI:registerPostReaderReadyCallback(callback) end
```

#### 模块初始化顺序

```lua
function ReaderUI:init()
    -- 1. 视图层（必须先注册）
    self:registerModule("view", ReaderView:new{...})
    
    -- 2. 导航层
    self:registerModule("link", ReaderLink:new{...})
    self:registerModule("highlight", ReaderHighlight:new{...})
    
    -- 3. 菜单层（在 link/highlight 之后）
    self:registerModule("menu", ReaderMenu:new{...})
    
    -- 4. 功能模块
    self:registerModule("toc", ReaderToc:new{...})
    self:registerModule("bookmark", ReaderBookmark:new{...})
    self:registerModule("rolling", ReaderRolling:new{...})
    -- ... 更多模块
end
```

### ReaderView

**文件**: `frontend/apps/reader/modules/readerview.lua`

**职责**: 阅读视图，负责页面渲染和显示。

```lua
local ReaderView = OverlapGroup:extend{
    ui = nil,                -- ReaderUI 引用
    document = nil,          -- Document 引用
    
    -- 视图状态
    current_pos = 0,         -- 当前位置（滚动模式）
    current_page = 1,        -- 当前页码（翻页模式）
    
    -- 渲染状态
    dimen = nil,             -- 视图尺寸
    visible_area = nil,      -- 可见区域
    page_area = nil,         -- 页面区域
}
```

#### 核心方法

```lua
-- 渲染
function ReaderView:paintTo(bb, x, y)
    -- 绘制页面
    -- 绘制高亮
    -- 绘制脚注
    -- 绘制其他覆盖层
end

-- 位置计算
function ReaderView:recalculate() end
function ReaderView:getCurrentPageList() end

-- 事件处理
function ReaderView:onPosUpdate(pos, page) end
function ReaderView:onPageUpdate(page) end
function ReaderView:onUpdatePos() end
```

### ReaderRolling

**文件**: `frontend/apps/reader/modules/readerrolling.lua`

**职责**: 滚动模式导航（EPUB 等流式文档）。

```lua
local ReaderRolling = ReaderPanning:extend{
    current_pos = 0,         -- 当前滚动位置
    old_pos = 0,
    
    -- 页面信息
    page_positions = {},     -- 页面位置表
    view = nil,              -- ReaderView 引用
}
```

#### 核心方法

```lua
-- 导航
function ReaderRolling:gotoPos(pos) end
function ReaderRolling:gotoXPointer(xpointer) end
function ReaderRolling:gotoPercent(percent) end

-- 页面信息
function ReaderRolling:getCurrentPage() end
function ReaderRolling:getNextPage(pageno) end
function ReaderRolling:getPrevPage(pageno) end

-- 事件处理
function ReaderRolling:onPosUpdate(pos, page) end
function ReaderRolling:onPanRelease(args, ges) end
```

### ReaderPaging

**文件**: `frontend/apps/reader/modules/readerpaging.lua`

**职责**: 翻页模式导航（PDF/DJVU 等分页文档）。

```lua
local ReaderPaging = ReaderPanning:extend{
    current_page = 1,
    first_page = 1,
    last_page = nil,
    
    -- 翻页模式
    page_mode = "single",    -- single, facing, scroll
    zoom_mode = "page",      -- page, width, content
}
```

#### 核心方法

```lua
-- 导航
function ReaderPaging:gotoPage(page) end
function ReaderPaging:gotoNext() end
function ReaderPaging:gotoPrev() end

-- 翻页模式
function ReaderPaging:setPageMode(mode) end
function ReaderPaging:onGotoNextPage() end
function ReaderPaging:onGotoPrevPage() end
```

---

## Widget 类族

### 继承层次

```
EventListener (eventlistener.lua)
    └─ Widget (widget.lua)
        ├─ TextWidget (textwidget.lua)
        ├─ ImageWidget (imagewidget.lua)
        └─ WidgetContainer (container/widgetcontainer.lua)
            ├─ InputContainer (container/inputcontainer.lua)
            │       ├─ ReaderView
            │       ├─ FileManager
            │       └─ ...
            ├─ FrameContainer (container/framecontainer.lua)
            ├─ CenterContainer (container/centercontainer.lua)
            └─ OverlapGroup (overlapgroup.lua)
```

### EventListener

**文件**: `frontend/ui/widget/eventlistener.lua`

```lua
local EventListener = {
    is_always_active = false,    -- 是否始终接收事件
}

function EventListener:handleEvent(event)
    -- 子类重写此方法
end
```

### Widget

**文件**: `frontend/ui/widget/widget.lua`

```lua
local Widget = EventListener:extend{
    dimen = nil,                 -- 几何尺寸 (Geom)
    is_visible = true,
}

-- 核心方法
function Widget:paintTo(bb, x, y)
    -- 绘制到缓冲区 bb 的 (x,y) 位置
end

function Widget:getSize() end
function Widget:getContentSize() end

-- 生命周期
function Widget:init() end
function Widget:onShow() end
function Widget:onClose() end
```

### WidgetContainer

**文件**: `frontend/ui/widget/container/widgetcontainer.lua`

```lua
local WidgetContainer = Widget:extend{
    -- 继承自 Widget，同时也是一个数组
}

-- 子组件管理
function WidgetContainer:addWidget(widget, refresh)
    table.insert(self, widget)
end

function WidgetContainer:removeWidget(widget)
    -- 从数组移除
end

-- 事件传播
function WidgetContainer:handleEvent(event)
    -- 先传递给子组件
    for _, widget in ipairs(self) do
        if widget:handleEvent(event) then
            return true
        end
    end
    -- 子组件未消费，自己处理
    return Widget.handleEvent(self, event)
end

-- 绘制
function WidgetContainer:paintTo(bb, x, y)
    -- 绘制所有子组件
    for _, widget in ipairs(self) do
        if widget.is_visible then
            widget:paintTo(bb, x + widget.dimen.x, y + widget.dimen.y)
        end
    end
end
```

### InputContainer

**文件**: `frontend/ui/widget/container/inputcontainer.lua`

**职责**: 处理触摸和手势输入。

```lua
local InputContainer = WidgetContainer:extend{
    _touch_zones = {},       -- 触摸区域注册表
    _input_handlers = {},    -- 输入处理器
}
```

#### 核心方法

```lua
-- 注册触摸区域
function InputContainer:registerTouchZones(touch_zones)
    -- touch_zones: {
    --     {
    --         id = "zone_id",
    --         ges = "tap",      -- tap, hold, swipe, pan, ...
    --         screen_zone = { ratio_x, ratio_y, ratio_w, ratio_h },
    --         handler = function(ges) ... end,
    --     }
    -- }
end

-- 处理手势
function InputContainer:onGesture(ev) end
function InputContainer:onTap(arg, ges) end
function InputContainer:onHold(arg, ges) end
function InputContainer:onSwipe(arg, ges) end
function InputContainer:onPan(arg, ges) end
```

---

## Event 和事件处理

### Event 类

**文件**: `frontend/ui/event.lua`

```lua
local Event = {}

function Event:new(name, ...)
    return {
        handler = "on"..name,       -- 事件处理器名称
        args = table.pack(...),      -- 事件参数
    }
end

-- 使用示例
local event = Event:new("Tap", ges)
-- 将调用 widget:onTap(ges)
```

### 事件处理器命名约定

```lua
-- 事件名 -> 处理器名
"Tap"           -> "onTap"
"Hold"          -> "onHold"
"Swipe"         -> "onSwipe"
"GotoPage"      -> "onGotoPage"
"UpdatePos"     -> "onUpdatePos"
```

### 自定义事件处理器

```lua
local MyWidget = InputContainer:extend{
    -- ...
}

function MyWidget:onTap(ges)
    -- 处理点击
    return true  -- 消费事件
end

function MyWidget:onHold(ges)
    -- 处理长按
    return true
end

function MyWidget:onSwipe(ges)
    -- 处理滑动手势
    local direction = ges.direction
    if direction == "west" then
        -- 向右滑动 -> 下一页
        self:onGotoNextPage()
        return true
    elseif direction == "east" then
        -- 向左滑动 -> 上一页
        self:onGotoPrevPage()
        return true
    end
    return false  -- 未消费，继续传播
end
```

---

## 设置管理类

### LuaSettings

**文件**: `frontend/luasettings.lua`

**职责**: Lua 格式设置文件的读写。

```lua
local LuaSettings = {
    file = nil,              -- 设置文件路径
    data = {},               -- 设置数据表
    is_modified = false,     -- 是否已修改
}
```

#### 核心方法

```lua
-- 静态方法：打开设置文件
function LuaSettings:open(file)
    -- 加载或创建设置文件
end

-- 读取设置
function LuaSettings:readSetting(key, default)
    return self.data[key] or default
end

-- 保存设置
function LuaSettings:saveSetting(key, value)
    self.data[key] = value
    self.is_modified = true
end

-- 删除设置
function LuaSettings:delSetting(key)
    self.data[key] = nil
    self.is_modified = true
end

-- 刷新到文件（延迟保存）
function LuaSettings:flush()
    if self.is_modified then
        -- 序列化为 Lua 表
        -- 写入文件
        self.is_modified = false
    end
end
```

### DocSettings

**文件**: `frontend/docsettings.lua`

**职责**: 文档特定设置管理（sidecar 文件）。

```lua
local DocSettings = LuaSettings:extend{
    -- 继承自 LuaSettings
}

-- 打开文档设置
function DocSettings:open(docfile)
    -- 确定 sidecar 目录位置
    -- <docfile_location>/<filename>.sdr/
    -- 或全局设置目录
end
```

### 全局设置对象

```lua
-- frontend/luadefaults.lua
G_defaults = LuaSettings:open("defaults.lua")

-- 运行时设置对象（在 reader.lua 中创建）
G_reader_settings = LuaSettings:open("settings/persistent.settings.lua")
```

### 使用示例

```lua
-- 全局设置
G_reader_settings:saveSetting("frontlight_intensity", 50)
local intensity = G_reader_settings:readSetting("frontlight_intensity", 25)

-- 文档设置
local doc_settings = DocSettings:open("/path/to/book.epub")
doc_settings:saveSetting("last_xpointer", xpointer)
doc_settings:saveSetting("bookmarks", bookmarks)
doc_settings:flush()
```

---

## 缓存系统

### Cache

**文件**: `frontend/cache.lua`

**职责**: 通用 LRU 缓存管理。

```lua
local Cache = {
    cache_path = nil,        -- 缓存目录
    cached = {},             -- 缓存表: key -> CacheItem
    cache_order = {},        -- LRU 顺序
    
    -- 容量限制
    max_memsize = 5 * 1024 * 1024,      -- 5MB 内存
    max_cache_size = 20 * 1024 * 1024,  -- 20MB 磁盘
}
```

#### 核心方法

```lua
-- 插入缓存
function Cache:insert(key, object, cachable)
    -- 添加到内存缓存
    self.cached[key] = object
    table.insert(self.cache_order, key)
    
    -- 可选：序列化到磁盘
    if cachable ~= false then
        self:serialize(key, object)
    end
    
    -- 内存管理
    self:memmgr()
end

-- 检查缓存
function Cache:check(key)
    local item = self.cached[key]
    if item then
        -- 更新 LRU 顺序
        self:moveToFront(key)
        return item
    end
    
    -- 尝试从磁盘加载
    return self:deserialize(key)
end

-- 内存管理（LRU 淘汰）
function Cache:memmgr()
    local total_size = 0
    for _, item in pairs(self.cached) do
        total_size = total_size + item.size
    end
    
    -- 超过限制，淘汰最久未使用
    while total_size > self.max_memsize do
        local key = table.remove(self.cache_order)
        if key then
            total_size = total_size - self.cached[key].size
            self.cached[key] = nil
        end
    end
end
```

### DocCache

**文件**: `frontend/document/doccache.lua`

**职责**: 文档专用缓存。

```lua
local DocCache = Cache:extend{
    -- 文档缓存特定配置
}

-- 获取缓存实例
function DocCache:getCache()
    return self  -- 单例
end
```

### CacheItem

**文件**: `frontend/cacheitem.lua`

```lua
local CacheItem = {
    size = 0,                -- 缓存项大小
    reference_count = 0,     -- 引用计数
    persistent = false,      -- 是否持久化
}

-- 计算大小（供内存管理使用）
function CacheItem:sizeof() end

-- 持久化
function CacheItem:persist(location) end
function CacheItem:depersist(location) end
```

### 使用示例

```lua
local DocCache = require("document/doccache")
local CacheItem = require("cacheitem")

-- 生成缓存键
local hash = "render|" .. self.file .. "|" .. pageno .. "|" .. zoom

-- 检查缓存
local cached = DocCache:check(hash)
if cached then
    return cached[1]
end

-- 渲染并缓存
local rendered = self:renderPage(pageno, zoom)
DocCache:insert(hash, CacheItem:new{ rendered })

return rendered
```

---

## 其他核心类

### Geom

**文件**: `frontend/ui/geometry.lua`

**职责**: 几何计算和矩形操作。

```lua
local Geom = {
    x = 0, y = 0,            -- 位置
    w = 0, h = 0,            -- 尺寸
}

-- 方法
function Geom:copy() end
function Geom:translate(dx, dy) end
function Geom:scale(s) end
function Geom:contains(other) end       -- 包含检测
function Geom:intersect(other) end      -- 交集
function Geom:offsetBy(other) end       -- 偏移
function Geom:combine(other) end        -- 合并
```

### BlitBuffer

**文件**: `ffi/blitbuffer.lua`

**职责**: 位图缓冲区操作（通过 FFI 调用 C 库）。

```lua
-- 创建缓冲区
local bb = Blitbuffer.new(width, height, Blitbuffer.TYPE_BB8)

-- 绘制操作
bb:paintPixel(x, y, color)
bb:paintRect(x, y, w, h, color)
bb:paintCircle(x, y, r, color)
bb:paintBorder(x, y, w, h, bw, color)

-- 混合
bb:addblitFrom(source, x, y)
bb:blitFrom(source, x, y)

-- 旋转/缩放
bb:rotate(degree)
bb:scaleBy(zoom)
```

### Logger

**文件**: `frontend/logger.lua`

**职责**: 日志系统。

```lua
local logger = require("logger")

-- 日志级别
logger.dbg("debug message")     -- 调试
logger.info("info message")     -- 信息
logger.warn("warning message")  -- 警告
logger.err("error message")     -- 错误
```

---

## 参考文档

- [项目架构](project-architecture.md) - 整体架构说明
- [模块说明](module-reference.md) - 各模块功能
- [数据流与交互](dataflow.md) - 事件和数据流
- [开发指南](development-guide.md) - 开发环境设置
