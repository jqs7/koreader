# 工具模块详解

> 本文档详细介绍 KOReader 中的核心工具模块，为 AI 编程助手提供 API 参考和使用指南。

## 核心工具模块概览

| 模块 | 功能 |
|------|------|
| `util` | 通用工具函数（字符串、文件、时间等） |
| `logger` | 日志记录系统 |
| `datetime` | 日期时间处理 |
| `cache` | 缓存管理 |
| `dispatcher` | 事件分发器 |
| `luasettings` | 设置文件管理 |
| `docsettings` | 文档设置管理 |

---

## util 模块 (`util.lua`)

通用工具函数集合，提供字符串处理、文件操作、数学计算等功能。

### 字符串处理

```lua
local util = require("util")

-- 去除首尾空白
util.trim("  hello  ")  -- "hello"
util.ltrim("  hello")   -- "hello"
util.rtrim("hello  ")   -- "hello"

-- 清理选中文本
util.cleanupSelectedText("  text\n  with  spaces  ")  -- "text\nwith spaces"

-- 去除标点符号
util.stripPunctuation("Hello, World!")  -- "HelloWorld"
```

### 文件操作

```lua
-- 获取文件扩展名
util.getFileExtension("/path/to/file.txt")  -- "txt"

-- 获取文件名（不含扩展名）
util.getFileNameSuffix("/path/to/file.txt")  -- "file"

-- 检查路径是否为目录
util.pathExists("/path/to/dir")

-- 获取文件大小
util.getSize("/path/to/file")  -- bytes

-- 复制文件
util.copyFile("source.txt", "dest.txt")

-- 创建目录
util.makeDir("/path/to/dir")
```

### 路径处理

```lua
-- 规范化路径
util.fixUTF8("/path/to/file")  -- 修复 UTF-8 编码

-- 获取绝对路径
util.realPath("/path/to/file")

-- 路径拼接
util.pathJoin("/dir", "subdir", "file.txt")  -- "/dir/subdir/file.txt"
```

### 时间与日期

```lua
-- 获取当前时间戳（毫秒）
util.getTime()  -- 1706123456789

-- 格式化时间差
util.getDurationText(seconds)  -- "2h 30m"

-- 格式化日期
util.getDateText(timestamp)  -- "2024-01-24"
```

### 数学计算

```lua
-- Clamp 值到范围
util.clamp(15, 0, 10)  -- 10

-- 舍入到指定小数位
util.round(3.14159, 2)  -- 3.14

-- 百分比计算
util.round(50, 100, 0)  -- 50%
```

---

## logger 模块 (`logger.lua`)

日志记录系统，提供分级日志输出。

### 日志级别

| 级别 | 方法 | 用途 |
|------|------|------|
| DEBUG | `logger.dbg()` | 调试信息 |
| INFO | `logger.info()` | 一般信息 |
| WARN | `logger.warn()` | 警告信息 |
| ERROR | `logger.err()` | 错误信息 |

### 基本用法

```lua
local logger = require("logger")

logger.dbg("Debug info:", some_var)
logger.info("Operation completed")
logger.warn("Potential issue:", warning_details)
logger.err("Critical error:", error_msg)
```

### 高级用法

```lua
-- 打印表格（自动格式化）
logger.dbg("Table content:", {
    key1 = "value1",
    key2 = { nested = "table" }
})

-- 条件日志
if some_condition then
    logger.info("Condition met")
end
```

---

## datetime 模块 (`datetime.lua`)

日期时间处理和国际化。

### 格式转换

```lua
local datetime = require("datetime")

-- 时间戳转日期表
datetime.timestampToDate(os.time())  -- {year=2024, month=1, day=24, ...}

-- 日期表转时间戳
datetime.dateToTimestamp{year=2024, month=1, day=24}

-- 格式化日期
datetime.formatDate(os.time())  -- "January 24, 2024"
datetime.formatDateShort(os.time())  -- "Jan 24, 2024"

-- 格式化时间
datetime.formatTime(os.time())  -- "10:30 AM"
```

### 相对时间

```lua
-- 相对时间描述
datetime.formatDuration(3661)  -- "1h 1m"
datetime.formatRelative(os.time() - 3600)  -- "1 hour ago"
```

### 国际化

```lua
-- 星期名称翻译
datetime.weekDays  -- {"Sun", "Mon", ...}

-- 月份名称翻译
datetime.shortMonthTranslation  -- {"Jan" = "一月", ...}
datetime.longMonthTranslation   -- {"January" = "一月", ...}
```

---

## cache 模块 (`cache.lua`)

缓存管理系统，支持内存缓存和磁盘缓存。

### 基本用法

```lua
local cache = require("cache")

-- 创建缓存
local my_cache = cache:new{
    max_size = 512 * 1024,  -- 512KB
    cache_empty_string = false,
}

-- 存入缓存
my_cache:set("key", some_data)

-- 读取缓存
local data = my_cache:get("key")

-- 检查存在
if my_cache:has("key") then
    -- 使用缓存
end

-- 删除缓存
my_cache:del("key")

-- 清空缓存
my_cache:flush()
```

### 缓存配置

```lua
-- LRU 缓存
cache:new{
    max_size = 1024 * 1024,     -- 最大 1MB
    max_count = 100,           -- 最大 100 项
    cache_empty_string = true, -- 是否缓存空字符串
}
```

---

## dispatcher 模块 (`dispatcher.lua`)

事件分发和命令调度系统。

### 事件注册

```lua
local dispatcher = require("dispatcher")

-- 注册动作
dispatcher:register("action_name", {
    event = "ActionName",
    args = {arg1 = "default"},
    category = "navigation",
})

-- 触发动作
dispatcher:dispatch("action_name", {arg1 = "value"})
```

### 动作定义

```lua
-- 定义可调度动作
dispatcher:register("goto_page", {
    event = "GotoPage",
    args = {page = 1},
    device = true,
})
```

---

## luasettings 模块 (`luasettings.lua`)

通用设置文件管理。

### 基本操作

```lua
local LuaSettings = require("luasettings")

-- 创建设置实例
local settings = LuaSettings:open("/path/to/settings.lua")

-- 读取设置
local value = settings:readSetting("key")
local has_key = settings:has("key")

-- 写入设置
settings:saveSetting("key", value)
settings:saveSetting("table_key", {nested = "value"})

-- 删除设置
settings:delSetting("key")

-- 保存到磁盘
settings:flush()

-- 关闭
settings:close()
```

### 批量操作

```lua
-- 批量写入
settings:batch(function()
    settings:saveSetting("key1", "value1")
    settings:saveSetting("key2", "value2")
end)
```

---

## docsettings 模块 (`docsettings.lua`)

文档特定设置管理，继承自 LuaSettings。

### 文档设置路径

```lua
local DocSettings = require("docsettings")

-- 根据文档路径获取设置文件路径
local settings_path = DocSettings:file_path("/path/to/book.epub")
-- 返回: /path/to/book.sdr/book.lua
```

### 使用示例

```lua
local DocSettings = require("docsettings")

-- 打开文档设置
local doc_settings = DocSettings:open("/path/to/book.epub")

-- 读取文档元数据
local last_page = doc_settings:readSetting("last_page") or 1
local bookmarks = doc_settings:readSetting("bookmarks") or {}

-- 保存阅读进度
doc_settings:saveSetting("last_page", current_page)

-- 保存高亮
doc_settings:saveSetting("highlights", {
    {page = 10, text = "Important", color = "yellow"}
})

-- 保存书签
doc_settings:saveSetting("bookmarks", {10, 25, 50})

-- 完成
doc_settings:close()
```

### 自动保存

```lua
-- 文档关闭时自动保存
doc_settings:close()
-- 设置文件会自动写入磁盘
```

---

## 其他工具模块

### sort 模块 (`sort.lua`)

文件和列表排序。

```lua
local sort = require("sort")

sort.byTitle(items)
sort.byDate(items)
sort.byAuthor(items)
sort.byProgress(items)
```

### random 模块 (`random.lua`)

随机数生成。

```lua
local random = require("random")

random:random()
random:random(1, 100)
random:shuffle(table)
```

### optmath 模块 (`optmath.lua`)

数学优化函数。

```lua
local Math = require("optmath")

Math.round(x)
Math.floor(x)
Math.ceil(x)
Math.min(a, b)
Math.max(a, b)
```

### readhistory 模块 (`readhistory.lua`)

阅读历史记录管理。

```lua
local readhistory = require("readhistory")

readhistory:add("/path/to/book.epub")
readhistory:remove("/path/to/book.epub")
local history = readhistory:open()
```

### readcollection 模块 (`readcollection.lua`)

书籍收藏管理。

```lua
local ReadCollection = require("readcollection")

ReadCollection:add("/path/to/book.epub")
ReadCollection:remove("/path/to/book.epub")
local collection = ReadCollection:open()
```

---

## 最佳实践

### 配置持久化

```lua
local DocSettings = require("docsettings")

function saveReaderState(doc_path, state)
    local settings = DocSettings:open(doc_path)
    settings:saveSetting("reader_state", state)
    settings:flush()
    settings:close()
end
```

### 日志记录规范

```lua
local logger = require("logger")

-- 调试信息（开发时使用）
logger.dbg("Function called with:", {arg1, arg2})

-- 重要状态变化
logger.info("Document loaded:", doc_path)

-- 潜在问题
logger.warn("Fallback to default:", reason)

-- 错误处理
logger.err("Operation failed:", error_msg)
```

### 缓存使用

```lua
local cache = require("cache")

-- 为频繁访问的数据创建缓存
local thumbnail_cache = cache:new{
    max_size = 10 * 1024 * 1024,  -- 10MB
}

-- 使用缓存
local thumbnail = thumbnail_cache:get(key)
if not thumbnail then
    thumbnail = generateThumbnail(key)
    thumbnail_cache:set(key, thumbnail)
end
```

---

> 本文档最后更新：2025年2月24日
