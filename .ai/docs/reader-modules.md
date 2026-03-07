# Reader 模块详解

> 本文档详细介绍了 KOReader 阅读器应用中的所有模块，为 AI 编程助手提供全面的模块功能、API 和使用指南。

## 概述

KOReader 的阅读器功能由多个模块组成，每个模块负责特定的功能领域。这些模块都继承自 `InputContainer`，并通过事件系统与主阅读器 UI 交互。模块通过 `readerui.lua` 动态加载和初始化。

### 模块架构特点

1. **继承关系**：所有模块都继承自 `InputContainer`，使其能够接收和处理用户输入事件
2. **事件驱动**：模块通过 `handleEvent()` 方法响应事件
3. **配置管理**：使用 `G_reader_settings` 存储模块特定配置
4. **文档状态**：通过 `self.ui.document` 和 `self.ui.view` 访问文档和视图状态
5. **UI 集成**：通过 `UIManager` 显示对话框和界面元素

## 模块分类

### 1. 核心阅读功能模块

#### ReaderView (`readerview.lua`)
**功能**：核心视图管理，处理文档渲染、页面布局和显示设置
- 页面渲染和刷新
- 视图模式管理（滚动、分页）
- 屏幕方向处理
- 亮度调节

**主要 API**：
```lua
function ReaderView:onSetDimensions(dimensions)
function ReaderView:onPageUpdate(action)
function ReaderView:getVisiblePageArea()
function ReaderView:setViewMode(mode)
```

**事件处理**：
- `PageUpdate` - 页面更新时触发
- `SetDimensions` - 屏幕尺寸变化时触发
- `ChangeViewMode` - 切换视图模式

---

#### ReaderPaging (`readerpaging.lua`)
**功能**：分页模式下的页面导航
- 向前/向后翻页
- 跳转到指定页码
- 页面跳转历史记录

**主要 API**：
```lua
function ReaderPaging:gotoPage(number)
function ReaderPaging:goToNextPage()
function ReaderPaging:goToPrevPage()
function ReaderPaging:getCurrentPage()
```

**配置选项**：
- `page_jump_percentage` - 跳转百分比
- `page_overlap_enable` - 页面重叠启用

---

#### ReaderScrolling (`readerscrolling.lua`)
**功能**：滚动模式下的文档浏览
- 连续滚动
- 滚动速度和惯性控制
- 位置记忆和恢复

**主要 API**：
```lua
function ReaderScrolling:scrollToPosition(pos)
function ReaderScrolling:scrollByAmount(amount)
function ReaderScrolling:getScrollPosition()
```

---

#### ReaderRolling (`readerrolling.lua`)
**功能**：滚动模式的高级控制
- 平滑滚动动画
- 滚动步长调整
- 自动滚动功能

### 2. 导航与定位模块

#### ReaderToc (`readertoc.lua`)
**功能**：目录导航和管理
- 原生文档目录解析和显示
- 自定义目录创建和编辑
- 目录深度控制和折叠/展开
- 快速章节跳转

**主要 API**：
```lua
function ReaderToc:showToc()
function ReaderToc:gotoTocItem(item)
function ReaderToc:refreshToc()
```

**UI 元素**：
- 目录菜单 (`Menu` 组件)
- 章节标记和缩进显示
- 进度百分比显示

**配置选项**：
- `toc_items_per_page` - 目录每页显示项数
- `toc_collapsed` - 默认折叠状态

---

#### ReaderGoto (`readergoto.lua`)
**功能**：快速跳转到指定位置
- 页码跳转
- 位置百分比跳转
- 书内位置跳转

**主要 API**：
```lua
function ReaderGoto:showGotoDialog()
function ReaderGoto:gotoPercent(percent)
function ReaderGoto:gotoPage(page)
```

---

#### ReaderPageMap (`readerpagemap.lua`)
**功能**：页面缩略图导航
- 页面缩略图生成和显示
- 视觉化页面导航
- 多页面预览

### 3. 内容交互模块

#### ReaderHighlight (`readerhighlight.lua`)
**功能**：文本高亮和标记
- 多颜色高亮支持
- 高亮管理和编辑
- 高亮导出和分享

**主要 API**：
```lua
function ReaderHighlight:addHighlight(selection, color)
function ReaderHighlight:removeHighlight(pos0, pos1)
function ReaderHighlight:getHighlights()
function ReaderHighlight:showHighlightMenu(selection)
```

**颜色支持**：
- Red, Orange, Yellow, Green, Olive
- Cyan, Blue, Purple, Gray

**数据存储**：
- 高亮存储在文档设置文件 (`*.sdr`) 中
- 支持位置标记和文本提取

---

#### ReaderBookmark (`readerbookmark.lua`)
**功能**：书签、笔记和高亮管理
- 页面书签添加/删除
- 高亮笔记附加
- 书签浏览和搜索

**主要 API**：
```lua
function ReaderBookmark:addBookmark(page)
function ReaderBookmark:removeBookmark(page)
function ReaderBookmark:showBookmarkManager()
```

**书签类型**：
- 页面书签 (`bookmark`)
- 高亮 (`highlight`) 
- 笔记 (`note`)

---

#### ReaderAnnotation (`readerannotation.lua`)
**功能**：注释和批注管理
- 文本注释添加
- 注释编辑和删除
- 注释导出

---

#### ReaderDictionary (`readerdictionary.lua`)
**功能**：词典查询和单词翻译
- 文本选择查词
- 多词典支持
- 单词定义显示
- 查询历史记录

**主要 API**：
```lua
function ReaderDictionary:lookupWord(word)
function ReaderDictionary:showWordDefinition(word, definition)
function ReaderDictionary:addToHistory(word)
```

**词典集成**：
- 支持 StarDict 格式
- 支持离线词典
- 支持在线词典服务

---

#### ReaderWikipedia (`readerwikipedia.lua`)
**功能**：维基百科查询
- 文本选择查询维基百科
- 文章摘要显示
- 多语言支持

### 4. 搜索与查找模块

#### ReaderSearch (`readersearch.lua`)
**功能**：全文搜索和文本查找
- 正则表达式搜索
- 大小写敏感/不敏感搜索
- 搜索结果导航
- 全文本搜索结果展示

**主要 API**：
```lua
function ReaderSearch:findText(pattern, case_insensitive, backward)
function ReaderSearch:findAllText(pattern, case_insensitive)
function ReaderSearch:showSearchDialog()
```

**搜索选项**：
- `max_hits` - 最大匹配数 (默认 2048)
- `findall_max_hits` - 全搜索最大匹配数 (默认 5000)
- `findall_nb_context_words` - 上下文单词数

**性能考虑**：
- 复杂正则表达式可能较慢
- 大量匹配时显示警告

---

#### ReaderLink (`readerlink.lua`)
**功能**：超链接和内部链接处理
- 文档内链接跳转
- 外部链接处理
- 链接预览和确认

### 5. 显示与排版模块

#### ReaderFont (`readerfont.lua`)
**功能**：字体设置和管理
- 字体选择和大小调整
- 行间距和字间距设置
- 字体渲染优化

**主要 API**：
```lua
function ReaderFont:setFontFace(font_face)
function ReaderFont:setFontSize(size)
function ReaderFont:showFontMenu()
```

**配置选项**：
- `font_size` - 字体大小
- `font_face` - 字体名称
- `line_spacing` - 行间距
- `word_spacing` - 字间距

---

#### ReaderTypography (`readertypography.lua`)
**功能**：排版优化和文本美化
- 连字处理
- 标点挤压
- 文本对齐优化

---

#### ReaderTypeset (`readertypeset.lua`)
**功能**：高级排版设置
- 页面边距调整
- 段落缩进设置
- 文本对齐方式

---

#### ReaderCropping (`readercropping.lua`)
**功能**：页面裁剪和边距调整
- 自动/手动裁剪
- 边距设置
- 裁剪预览

### 6. 视图与缩放模块

#### ReaderZooming (`readerzooming.lua`)
**功能**：页面缩放和细节查看
- 缩放级别调整
- 缩放区域选择
- 缩放模式切换

**缩放模式**：
- 自由缩放
- 适应宽度/高度
- 页面级别缩放

---

#### ReaderPanning (`readerpanning.lua`)
**功能**：页面平移和导航
- 触摸拖拽平移
- 惯性滚动
- 边界限制处理

---

#### ReaderFlipping (`readerflipping.lua`)
**功能**：翻页动画和效果
- 翻页动画控制
- 翻页方向设置
- 动画性能优化

### 7. 工具与实用模块

#### ReaderMenu (`readermenu.lua`)
**功能**：阅读器主菜单管理
- 菜单结构定义
- 快捷菜单访问
- 菜单项动态更新

**菜单层次**：
1. 主菜单（阅读器设置）
2. 底部菜单（快速操作）
3. 上下文菜单（选择相关）

---

#### ReaderConfig (`readerconfig.lua`)
**功能**：阅读器配置管理
- 配置选项组织
- 设置导入/导出
- 配置预设管理

---

#### ReaderFooter (`readerfooter.lua`)
**功能**：底部状态栏显示
- 页面信息显示
- 电池状态
- 时间显示
- 阅读进度

**显示元素**：
- 页码/总页数
- 阅读进度百分比
- 电池电量图标
- 当前时间

**配置选项**：
- `footer_mode` - 显示模式
- `show_battery` - 显示电池状态
- `show_time` - 显示时间

---

#### ReaderDeviceStatus (`readerdevicestatus.lua`)
**功能**：设备状态监控
- 电池状态检测
- 存储空间监控
- 网络状态显示

---

#### ReaderActivityIndicator (`readeractivityindicator.lua`)
**功能**：活动指示器
- 加载状态显示
- 操作反馈
- 进度指示

### 8. 手势与输入模块

#### ReaderKoptListener (`readerkoptlistener.lua`)
**功能**：KOReader 优化触摸手势处理
- 触摸手势识别
- 手势动作映射
- 手势灵敏度调整

**支持手势**：
- 点击、双击
- 滑动、长按
- 捏合缩放

---

#### ReaderCoptListener (`readercoptlistener.lua`)
**功能**：兼容性触摸手势处理
- 传统触摸设备支持
- 手势事件转换
- 输入设备兼容

---

#### ReaderHinting (`readerhinting.lua`)
**功能**：用户提示和引导
- 功能使用提示
- 手势操作提示
- 新手引导

### 9. 专业功能模块

#### ReaderDogear (`readerdogear.lua`)
**功能**：书角折叠标记
- 书角位置标记
- 折叠状态记忆
- 视觉书签功能

---

#### ReaderUserHyph (`readeruserhyph.lua`)
**功能**：用户自定义断字规则
- 自定义连字符规则
- 语言特定断字
- 断字词典管理

---

#### ReaderStyleTweak (`readerstyletweak.lua`)
**功能**：样式微调和自定义
- CSS 样式覆盖
- 文本样式调整
- 视觉主题微调

---

#### ReaderHandmade (`readerhandmade.lua`)
**功能**：手工制作书籍支持
- 自定义书籍格式
- 手工排版调整
- 特殊格式处理

---

#### ReaderThumbnail (`readerthumbnail.lua`)
**功能**：缩略图生成和管理
- 页面缩略图缓存
- 缩略图质量设置
- 内存使用优化

## 模块初始化与生命周期

### 初始化流程

```lua
function ReaderUI:initModules()
    -- 1. 创建模块实例
    self.handlers = {}
    
    -- 2. 按顺序初始化核心模块
    self.handlers.readerview = ReaderView:new{ui = self}
    self.handlers.readerfooter = ReaderFooter:new{ui = self}
    
    -- 3. 初始化功能模块
    self.handlers.readerhighlight = ReaderHighlight:new{ui = self}
    self.handlers.readerbookmark = ReaderBookmark:new{ui = self}
    
    -- 4. 注册模块事件处理器
    for _, handler in pairs(self.handlers) do
        self.event_handlers[handler] = true
    end
end
```

### 事件处理链

1. **事件产生**：用户输入、系统事件、定时器
2. **事件分发**：通过 `UIManager:broadcastEvent(event)` 分发
3. **模块处理**：各模块的 `handleEvent()` 方法按注册顺序调用
4. **事件消费**：返回 `true` 表示事件已消费，停止传播

### 模块通信模式

#### 直接方法调用
```lua
-- 从其他模块访问高亮功能
local highlights = self.ui.handlers.readerhighlight:getHighlights()
```

#### 事件广播
```lua
-- 发送页面更新事件
self.ui:handleEvent(Event:new("PageUpdate", page))
```

#### 配置共享
```lua
-- 读取共享配置
local font_size = G_reader_settings:readSetting("font_size")
```

## 配置管理

### 模块配置存储

```lua
-- 保存模块特定配置
G_reader_settings:saveSetting("highlight_colors", self.colors)

-- 读取配置
local colors = G_reader_settings:readSetting("highlight_colors") or self.default_colors
```

### 配置命名空间

- `reader_` 前缀：阅读器全局配置
- `module_` 前缀：模块特定配置
- 无前缀：共享配置项

## 最佳实践

### 模块开发指南

1. **继承正确基类**：所有阅读器模块应继承自 `InputContainer`
2. **事件处理**：实现 `handleEvent()` 方法，及时返回事件消费状态
3. **资源清理**：在 `onClose()` 中释放资源和取消定时器
4. **配置默认值**：提供合理的默认配置值
5. **错误处理**：使用 `pcall()` 包装可能失败的操作

### 性能优化

1. **延迟加载**：大型资源在需要时加载
2. **缓存管理**：合理使用内存缓存和磁盘缓存
3. **事件去重**：避免频繁触发重复事件
4. **界面响应**：长时间操作使用异步或进度提示

### 用户界面集成

1. **对话框使用**：使用标准 UI 组件 (`ButtonDialog`, `ConfirmBox`)
2. **菜单结构**：遵循统一的菜单组织和命名
3. **手势兼容**：支持多种输入设备的手势操作
4. **无障碍支持**：确保屏幕阅读器兼容性

## 常见模式与示例

### 添加新模块的步骤

```lua
-- 1. 创建模块文件 frontend/apps/reader/modules/readerexample.lua
local InputContainer = require("ui/widget/container/inputcontainer")
local ReaderExample = InputContainer:extend{
    name = "readerexample",
    is_enabled = true,
}

function ReaderExample:init()
    self:registerKeyEvents()
    self:registerGestureEvents()
end

function ReaderExample:handleEvent(event)
    if event.type == "CustomEvent" then
        -- 处理事件
        return true
    end
end

return ReaderExample
```

### 模块间协作示例

```lua
-- 高亮模块与书签模块协作
function ReaderHighlight:addHighlightWithNote(selection, color, note_text)
    -- 1. 添加高亮
    local highlight = self:addHighlight(selection, color)
    
    -- 2. 通过书签模块添加笔记
    if note_text then
        self.ui.handlers.readerbookmark:addNoteToHighlight(highlight, note_text)
    end
    
    -- 3. 发送更新通知
    self.ui:handleEvent(Event:new("HighlightAdded", highlight))
end
```

## 故障排除

### 常见问题

1. **模块未加载**：检查模块文件名和注册代码
2. **事件未处理**：确认 `handleEvent()` 方法正确实现
3. **配置丢失**：验证配置读写权限和路径
4. **内存泄漏**：检查定时器和回调函数清理

### 调试技巧

1. **日志记录**：使用 `logger.dbg()` 记录模块状态
2. **事件追踪**：添加事件类型日志
3. **性能分析**：使用 `util.gettime()` 测量执行时间
4. **内存监控**：检查 `collectgarbage("count")` 返回值

## 扩展与定制

### 创建自定义模块

开发者可以通过以下方式扩展阅读器功能：

1. **插件模块**：创建 `.koplugin` 格式的独立插件
2. **模块补丁**：通过猴子补丁修改现有模块行为
3. **事件钩子**：注册自定义事件处理器
4. **配置扩展**：添加新的配置选项

### 模块禁用与启用

```lua
-- 动态启用/禁用模块
function toggleModule(module_name, enabled)
    local module = self.ui.handlers[module_name]
    if module then
        module.is_enabled = enabled
        if enabled then
            module:init()
        else
            module:onClose()
        end
    end
end
```

---

> 本文档最后更新：2025年2月24日
> 对应 KOReader 版本：v2024.01+