# KOReader 数据流与交互文档

> 本文档详细说明 KOReader 中的事件系统、数据流和模块交互。

## 目录

1. [事件系统](#事件系统)
2. [UI 渲染流程](#ui-渲染流程)
3. [用户交互流程](#用户交互流程)
4. [文档处理流程](#文档处理流程)
5. [模块间通信](#模块间通信)

---

## 事件系统

KOReader 采用事件驱动架构，所有交互都通过事件进行。

### 事件定义

**文件**: `frontend/ui/event.lua`

```lua
local Event = {}

function Event:new(name, ...)
    local o = {
        handler = "on"..name,      -- 事件处理器名称
        args = table.pack(...),     -- 事件参数
    }
    return o
end
```

### 事件传播机制

事件传播遵循**冒泡模式**：

```
WidgetContainer (父容器)
    ├─▶ Child Widget 1
    ├─▶ Child Widget 2
    └─▶ Child Widget 3
        └─▶ 如果未被消费，父容器自己处理
```

**传播规则**:
1. 事件首先传递给子组件
2. 如果子组件返回 `true`，事件被消费，停止传播
3. 如果所有子组件都未消费，父组件自己处理
4. 如果父组件也未消费，事件继续向上传播

### 事件处理代码

```lua
-- frontend/ui/widget/container/widgetcontainer.lua
function WidgetContainer:handleEvent(event)
    -- 1. 先传递给子组件
    for _, widget in ipairs(self) do
        if widget:handleEvent(event) then
            return true  -- 事件被消费
        end
    end
    -- 2. 子组件未消费，自己处理
    local handler = self[event.handler]
    if handler then
        return handler(self, unpack(event.args, 1, event.args.n))
    end
end
```

### 内置事件类型

#### UI 事件

| 事件名 | 触发时机 | 典型处理器 |
|--------|----------|------------|
| `Show` | Widget 被显示 | `onShow()` |
| `Close` | Widget 被关闭 | `onClose()` |
| `UpdateUI` | UI 需要更新 | `onUpdateUI()` |
| `SetDirty` | 区域需要重绘 | `onSetDirty()` |
| `PaintTo` | 绘制请求 | `paintTo()` |

#### 输入事件

| 事件名 | 触发时机 | 参数 |
|--------|----------|------|
| `Tap` | 点击 | `ges` (手势对象) |
| `Hold` | 长按 | `ges` |
| `Swipe` | 滑动 | `ges` |
| `Pan` | 拖动 | `ges` |
| `Pinch` | 捏合 | `ges` |
| `Spread` | 展开 | `ges` |
| `Rotate` | 旋转 | `ges` |
| `KeyPress` | 按键 | `key` |
| `KeyRepeat` | 按键重复 | `key` |

#### 阅读器事件

| 事件名 | 触发时机 | 来源模块 |
|--------|----------|----------|
| `UpdatePos` | 排版/位置变化 | ReaderTypeset |
| `PosUpdate` | 滚动位置更新 | ReaderRolling |
| `PageUpdate` | 页码变化 | ReaderPaging |
| `GotoPage` | 跳转页面 | ReaderToc, ReaderLink |
| `GotoLink` | 点击链接 | ReaderLink |
| `Highlight` | 添加高亮 | ReaderHighlight |
| `AddBookmark` | 添加书签 | ReaderBookmark |
| `SetZoom` | 缩放变化 | ReaderZooming |
| `SetFontSize` | 字体大小变化 | ReaderFont |
| `SetStyle` | 样式变化 | ReaderTypeset |
| `DocumentReady` | 文档加载完成 | ReaderUI |

#### 系统事件

| 事件名 | 触发时机 | 处理者 |
|--------|----------|--------|
| `Power` | 电源键 | Device |
| `SaveState` | 保存状态 | 各模块 |
| `Suspend` | 休眠 | Device |
| `Resume` | 唤醒 | Device |
| `Charging` | 充电状态变化 | Device |
| `WifiState` | WiFi 状态变化 | NetworkListener |
| `UsbPlugIn/Out` | USB 插拔 | Device |
| `StorageHotplug` | 存储热插拔 | Device |

### 事件发送方法

```lua
-- 1. 直接发送给特定 widget
widget:handleEvent(Event:new("Tap", ges))

-- 2. 通过 UIManager 发送给顶部 widget
UIManager:sendEvent(Event:new("Show"))

-- 3. 广播给所有 active widgets
UIManager:broadcastEvent(Event:new("SaveState"))

-- 4. 延迟执行
UIManager:nextTick(function()
    -- 下一帧执行
end)

-- 5. 定时任务
UIManager:scheduleIn(5, function()
    -- 5 秒后执行
end)
```

---

## UI 渲染流程

### 渲染架构

KOReader 采用**脏矩形（Dirty Rectangle）**渲染机制：

```
+------------------------------------------+
|               UIManager                  |
|  +------------------------------------+  |
|  |         _window_stack              |  |
|  |  [Modal] [Dialog] [Base Widget]    |  |
|  +------------------------------------+  |
|  +------------------------------------+  |
|  |         _dirty[]                   |  |
|  |  标记需要重绘的区域                 |  |
|  +------------------------------------+  |
|  +------------------------------------+  |
|  |         _refresh_stack[]           |  |
|  |  刷新请求队列                       |  |
|  +------------------------------------+  |
+------------------------------------------+
```

### 渲染流程图

```
UIManager:run() 主循环
    │
    ▼
处理输入事件 ──────────────▶ 更新 Widget 状态
    │                              │
    ▼                              ▼
调用 setDirty() ◀─────────── 标记脏区域
    │
    ▼
收集脏区域 _dirty[]
    │
    ▼
widget:paintTo(bb, geom) ──▶ 绘制到缓冲区
    │
    ▼
Screen:refresh(refresh_type, region)
    │
    ▼
硬件刷新 (partial/full/flash)
```

### 渲染类型

| 类型 | 用途 | 典型场景 |
|------|------|----------|
| `full` | 全屏刷新 | 屏保退出、页面切换 |
| `partial` | 局部刷新 | 菜单更新、文本变化 |
| `ui` | UI 刷新 | 对话框、按钮 |
| `flashpartial` | 带闪烁的局部刷新 | 清除残影 |
| `flashui` | 带闪烁的 UI 刷新 | 重要的 UI 变化 |
| `fast` | 快速刷新 | 频繁变化的区域 |
| `a2` | A2 模式 | 快速翻页预览 |

### 渲染代码示例

```lua
-- ReaderView 渲染流程
function ReaderView:paintTo(bb, x, y)
    -- 1. 绘制文档页面
    if self.ui.document then
        self.ui.document:drawPage(...)
    end
    
    -- 2. 绘制高亮
    if self.highlight then
        self.highlight:paintTo(bb, x, y)
    end
    
    -- 3. 绘制书签标记
    if self.dogear then
        self.dogear:paintTo(bb, x, y)
    end
    
    -- 4. 绘制脚注
    if self.footnote then
        self.footnote:paintTo(bb, x, y)
    end
end
```

### 页面绘制详细流程

```
ReaderView:paintTo(bb, x, y)
    │
    ├─▶ 获取当前页面范围
    │       getCurrentPageList()
    │
    ├─▶ 绘制页面内容
    │       document:drawPage()
    │           │
    │           ├─▶ 检查 DocCache
    │           │       命中：返回缓存的 blitbuffer
    │           │       未命中：继续渲染
    │           │
    │           └─▶ renderPage()
    │                   │
    │                   ├─▶ _document:openPage(pageno)
    │                   ├─▶ page:draw(dc, bb, x, y, zoom, rotation)
    │                   └─▶ page:close()
    │
    ├─▶ 绘制高亮区域
    │       ReaderHighlight:paintTo()
    │
    ├─▶ 绘制书签角标
    │       ReaderDogear:paintTo()
    │
    └─▶ 绘制脚注预览
            ReaderFooter:paintTo()
```

---

## 用户交互流程

### 触摸事件处理流程

```
硬件触摸输入
    │
    ▼
Device.input:waitEvent()
    │
    ▼
解析原始事件 ──────────────▶ Input:handleTouchEv()
    │                              │
    ▼                              ▼
GestureDetector:feedEvent() ◀─── 解析手势
    │
    ├─▶ 识别手势类型
    │       Tap, Hold, Swipe, Pan, Pinch...
    │
    └─▶ 触发对应事件
            Event:new("Tap", ges)
                │
                ▼
        UIManager:sendEvent()
                │
                ▼
        Widget:handleEvent()
                │
                ├─▶ InputContainer:onTap()
                │       │
                │       ├─▶ 检查 TouchZone
                │       └─▶ 调用注册的处理函数
                │
                └─▶ 或子 Widget 处理
```

### 触摸区域注册

```lua
-- 注册触摸区域示例 (InputContainer)
self:registerTouchZones({
    {
        id = "tap_zone_reader",
        ges = "tap",
        screen_zone = {
            ratio_x = 0, ratio_y = 0,
            ratio_w = 1, ratio_h = 1,
        },
        handler = function(ges)
            return self:onTapReader(ges)
        end,
    },
    {
        id = "swipe_zone",
        ges = "swipe",
        screen_zone = { ... },
        handler = function(ges)
            return self:onSwipe(ges)
        end,
    },
})
```

### 手势映射

```
┌─────────────────────────────────────────┐
│  ┌─────────────┐  ┌─────────────┐      │
│  │  上一页     │  │   菜单      │      │
│  │  (Tap)      │  │   (Tap)     │      │
│  └─────────────┘  └─────────────┘      │
│  ┌─────────────────────────────────┐   │
│  │                                 │   │
│  │         阅读区域                │   │
│  │      (Tap: 下一页)              │   │
│  │      (Hold: 选择文本)           │   │
│  │      (Swipe: 翻页)              │   │
│  │                                 │   │
│  └─────────────────────────────────┘   │
│  ┌─────────────────────────────────┐   │
│  │        底部状态栏               │   │
│  │      (Tap: 配置面板)            │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### 手势处理优先级

```lua
-- 高优先级（Modal）
Dialog > Menu > ConfigPanel

-- 中优先级（功能区域）
Highlight > Link > Bookmark

-- 低优先级（阅读区域）
ReaderView > Footer

-- 默认处理
UIManager 默认处理器
```

---

## 文档处理流程

### 文档打开流程

```
用户点击书籍
    │
    ▼
FileChooser:onMenuSelect()
    │
    ▼
FileManager:openFile(file)
    │
    ├─▶ 检查文件类型
    │       DocumentRegistry:hasProvider(file)
    │
    ├─▶ 打开文档设置
    │       DocSettings:open(file)
    │
    ├─▶ 加载文档
    │       DocumentRegistry:openDocument(file)
    │           │
    │           ├─▶ 查找对应的 Document 类
    │           │       根据文件扩展名
    │           │
    │           └─▶ 创建 Document 实例
    │                   document:init()
    │                       │
    │                       ├─▶ 初始化引擎
    │                       │       crengine/mupdf/djvu
    │                       │
    │                       └─▶ 加载文档元数据
    │                               页数、目录、元信息
    │
    └─▶ 启动 ReaderUI
            ReaderUI:new{document = document}
                │
                └─▶ 初始化各模块
                        ReaderView, ReaderRolling, ...
```

### 文档渲染流程（滚动模式）

```
ReaderRolling 初始化
    │
    ▼
加载文档进度
    ├─▶ 从 DocSettings 读取 last_xpointer
    ├─▶ 或从 G_reader_settings 读取 last_percent
    └─▶ 计算初始位置
            │
            ▼
    document:getPosFromXPointer(xpointer)
            │
            ▼
触发位置更新
    Event:new("PosUpdate", pos, page)
        │
        ├─▶ ReaderView:onPosUpdate()
        │       更新视图位置
        │
        ├─▶ ReaderToc:onPosUpdate()
        │       更新当前章节
        │
        ├─▶ ReaderFooter:onPosUpdate()
        │       更新页码/进度显示
        │
        └─▶ ReaderBookmark:onPosUpdate()
                检查当前页书签状态
```

### 文档渲染流程（翻页模式）

```
ReaderPaging 初始化
    │
    ▼
加载当前页
    ├─▶ 从 DocSettings 读取 last_page
    └─▶ document:openPage(pageno)
            │
            ▼
渲染页面
    page:draw(dc, bb, x, y, zoom, rotation)
        │
        ├─▶ 检查缓存
        │       DocCache:check(hash)
        │
        ├─▶ 未命中则渲染
        │       引擎原生渲染
        │
        └─▶ 存入缓存
                DocCache:insert(hash, cache_item)
                │
                ▼
        缓存清理（LRU）
                DocCache:memmgr()
```

---

## 模块间通信

### 阅读器模块依赖关系

```
ReaderUI (协调者)
    │
    ├─▶ ReaderView (视图)
    │       ├─◀ document (页面渲染)
    │       ├─◀ ReaderHighlight (高亮绘制)
    │       └─◀ ReaderDogear (书签角标)
    │
    ├─▶ ReaderRolling/ReaderPaging (导航)
    │       └─▶ Event:"PosUpdate"/"PageUpdate"
    │               ├─▶ ReaderView (重绘)
    │               ├─▶ ReaderToc (更新章节)
    │               ├─▶ ReaderFooter (更新页码)
    │               └─▶ ReaderBookmark (更新书签状态)
    │
    ├─▶ ReaderToc (目录)
    │       └─▶ Event:"GotoPage"
    │               └─▶ ReaderRolling/ReaderPaging
    │
    ├─▶ ReaderBookmark (书签)
    │       ├─◀ ReaderView (获取当前位置)
    │       └─◀ ReaderAnnotation (共享数据)
    │
    ├─▶ ReaderHighlight (高亮)
    │       ├─◀ ReaderView (获取选择区域)
    │       ├─▶ Event:"Highlight"
    │       │       └─▶ ReaderBookmark (添加书签)
    │       └─▶ Event:"ShowNote"
    │               └─▶ ReaderView (显示批注)
    │
    ├─▶ ReaderLink (链接)
    │       └─▶ Event:"GotoLink"
    │               ├─▶ ReaderRolling/ReaderPaging (内部跳转)
    │               └─▶ Device:openLink() (外部链接)
    │
    ├─▶ ReaderFont (字体)
    │       └─▶ Event:"UpdatePos"
    │               └─▶ 所有依赖排版的模块刷新
    │
    └─▶ ReaderTypeset (排版)
            └─▶ Event:"UpdatePos"
                    └─▶ 同上
```

### 配置变更传播

```lua
-- 用户修改字体大小
ReaderFont:onSetFontSize(new_size)
    │
    ├─▶ 更新文档设置
    │       self.document.configurable.font_size = new_size
    │
    ├─▶ 应用到引擎
    │       self.ui.document:setFontSize(new_size)
    │
    └─▶ 广播更新事件
            UIManager:broadcastEvent(Event:new("UpdatePos"))
                │
                ├─▶ ReaderView:onUpdatePos() - 重排视图
                ├─▶ ReaderToc:onUpdatePos() - 更新章节位置
                ├─▶ ReaderBookmark:onUpdatePos() - 更新书签位置
                └─▶ ReaderFooter:onUpdatePos() - 更新进度计算
```

### 设置持久化流程

```
设置变更
    │
    ▼
更新内存中的设置
    G_reader_settings:saveSetting(key, value)
        │
        ▼
标记为已修改
    settings.is_modified = true
        │
        ▼
延迟保存（防抖）
    UIManager:scheduleIn(1, flushSettings)
        │
        ▼
写入文件
    LuaSettings:flush()
        └─▶ 序列化为 Lua 表
        └─▶ 写入设置文件
        └─▶ settings/persistent.settings.lua
```

---

## 数据持久化

### 设置文件结构

```
settings/
├── persistent.settings.lua      # 全局设置
├── reader_settings.lua          # 阅读器设置 (旧版)
└── <document_location>/
    └── <filename>.sdr/
        ├── metadata.lua         # 文档元数据
        ├── metadata.epub.lua    # 格式特定元数据
        ├── bookmarks.lua        # 书签数据
        └── history.lua          # 阅读历史
```

### 文档设置（Sidecar）

```lua
-- .sdr/metadata.lua 示例
{
    ["doc_props"] = {
        ["title"] = "Book Title",
        ["authors"] = "Author Name",
        ["series"] = "Series Name",
        ["language"] = "en-US",
    },
    ["summary"] = {
        ["status"] = "reading",  -- reading, finished, abandoned
        ["notes"] = "Personal notes",
    },
    ["stats"] = {
        ["pages"] = 100,
        ["total_time_in_sec"] = 3600,
    },
    ["bookmarks"] = {
        -- 书签列表
    },
    ["highlight"] = {
        -- 高亮列表
    },
    ["last_xpointer"] = "/body/DocFragment[1]/body/p[10]",
    ["percent_finished"] = 0.25,
}
```

### 缓存系统

```
┌─────────────────────────────────────────┐
│              DocCache                    │
│  ┌─────────────────────────────────┐   │
│  │  LRU 缓存队列                    │   │
│  │  ┌───┐ ┌───┐ ┌───┐ ┌───┐       │   │
│  │  │ A │→│ B │→│ C │→│ D │       │   │
│  │  └───┘ └───┘ └───┘ └───┘       │   │
│  └─────────────────────────────────┘   │
│  容量: 32MB (可配置)                      │
└─────────────────────────────────────────┘

缓存键格式:
    "pgdim|filename|mtime|pageno"    -- 页面尺寸
    "render|filename|mtime|pageno|zoom|rotation"  -- 渲染结果
    "toc|filename|mtime"              -- 目录
    "metadata|filename|mtime"         -- 元数据
```

---

## 性能优化数据流

### 渲染优化

```lua
-- 1. 双缓冲机制
-- 当前页预渲染 + 下一页预渲染
function ReaderRolling:updateTopStatusBar()
    -- 预取附近页面
    self.ui.document:hintPage(current_page + 1)
    self.ui.document:hintPage(current_page - 1)
end

-- 2. 增量刷新
-- 仅标记变化区域为 dirty
function ReaderView:onSetDirty(dimen)
    UIManager:setDirty(self.dialog, "partial", dimen)
end

-- 3. 批量刷新
-- 收集多次 setDirty，一次刷新
UIManager:_refresh_stack[]
```

### 事件批处理

```
连续快速翻页
    │
    ├─▶ Event:"GotoPage", 5
    ├─▶ Event:"GotoPage", 6
    ├─▶ Event:"GotoPage", 7
    └─▶ Event:"GotoPage", 8
            │
            ▼
    UIManager 队列合并
            │
            ▼
    最终只处理 "GotoPage", 8
```

---

## 参考文档

- [项目架构](project-architecture.md) - 整体架构说明
- [模块说明](module-reference.md) - 各模块功能
- [核心类说明](core-classes.md) - 核心类详解
- [Events.md](/doc/Events.md) - 官方事件文档
