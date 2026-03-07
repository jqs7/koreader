# KOReader 算法机制文档

> 本文档详细说明 KOReader 中的关键算法实现机制。

## 目录

1. [手势检测算法](#手势检测算法)
2. [缓存算法](#缓存算法)
3. [渲染算法](#渲染算法)
4. [事件传播算法](#事件传播算法)
5. [任务调度算法](#任务调度算法)
6. [几何计算算法](#几何计算算法)
7. [文本选择算法](#文本选择算法)
8. [搜索算法](#搜索算法)
9. [内存管理算法](#内存管理算法)

---

## 手势检测算法

**文件**: `frontend/device/gesturedetector.lua`

### 状态机设计

手势检测采用**有限状态机（FSM）**模式，每个触摸点对应一个 `Contact` 对象，包含状态函数：

```lua
-- 状态函数表
Contact.initialState = function(self, tev) ... end
Contact.downState = function(self, tev) ... end
Contact.holdState = function(self, tev) ... end
Contact.panState = function(self, tev) ... end
Contact.voidState = function(self, tev) ... end  -- 多指手势中的无效状态
```

### 状态转换图

```
initialState
    ↓ (接触开始)
downState
    ├─▶ (hold 计时器触发) → holdState
    │       ├─▶ (移动超过阈值) → panState
    │       └─▶ (抬起) → 触发 hold_release
    │
    ├─▶ (快速抬起) → 触发 tap
    │       └─▶ (二次点击) → 触发 double_tap
    │
    └─▶ (移动超过阈值) → panState
            ├─▶ (快速移动) → 触发 swipe
            └─▶ (缓慢移动) → 持续 pan
```

### 关键参数

```lua
-- 时间参数（毫秒）
TAP_INTERVAL_MS = 0          -- 点击间隔
DOUBLE_TAP_INTERVAL_MS = 300 -- 双击间隔
TWO_FINGER_TAP_DURATION_MS = 300  -- 双指点击持续时间
HOLD_INTERVAL_MS = 500       -- 长按识别时间
LONG_HOLD_INTERVAL_S = 3     -- 超长按时间（秒）
SWIPE_INTERVAL_MS = 900      -- 滑动识别时间

-- 距离参数（DPI 缩放）
TWO_FINGER_TAP_REGION = screen:scaleByDPI(20)   -- 双指点击区域
DOUBLE_TAP_DISTANCE = screen:scaleByDPI(50)     -- 双击最大距离
PAN_THRESHOLD = screen:scaleByDPI(35)           -- 拖动阈值
MULTISWIPE_THRESHOLD = DOUBLE_TAP_DISTANCE      -- 多向滑动阈值
```

### 手势识别算法

#### 1. Tap 识别

```lua
function Contact:_checkTap(tev)
    local distance = self:_distance(self.initial_tev, tev)
    local elapsed = tev.timev - self.initial_tev.timev
    
    -- 条件：移动距离小、时间短、无其他手势
    if distance < self.ges_dec.PAN_THRESHOLD and
       elapsed < self.ges_dec.ges_tap_interval and
       not self.mt_gesture then
        return true
    end
    return false
end
```

#### 2. Double Tap 识别

```lua
function GestureDetector:_checkDoubleTap(contact, tev)
    local prev_tap = self.previous_tap[contact.slot]
    if not prev_tap then return false end
    
    local distance = self:_distance(prev_tap, tev)
    local elapsed = tev.timev - prev_tap.timev
    
    -- 条件：在指定时间和距离内
    if elapsed < self.ges_double_tap_interval and
       distance < self.DOUBLE_TAP_DISTANCE then
        return true
    end
    return false
end
```

#### 3. Swipe 识别

```lua
function Contact:_checkSwipe(tev)
    local distance = self:_distance(self.initial_tev, tev)
    local elapsed = tev.timev - self.initial_tev.timev
    local velocity = distance / elapsed  -- 像素/毫秒
    
    -- 条件：移动距离大、速度快、时间短
    if distance > self.ges_dec.PAN_THRESHOLD and
       velocity > 0.5 and  -- 约 500 像素/秒
       elapsed < self.ges_dec.ges_swipe_interval then
        return self:_getDirection(self.initial_tev, tev)
    end
    return nil
end
```

#### 4. 多指手势检测

```lua
-- 检测双指手势
function GestureDetector:_checkTwoFingerGesture(contact1, contact2)
    -- 检查两个接触点是否同时存在
    if not contact1.down or not contact2.down then
        return false
    end
    
    -- 检查距离是否在双指手势范围内
    local distance = self:_distance(
        contact1.current_tev, 
        contact2.current_tev
    )
    
    if distance < self.TWO_FINGER_TAP_REGION then
        -- 双指点击
        if elapsed < self.ges_two_finger_tap_duration then
            return "two_finger_tap"
        end
    else
        -- 双指拖动/缩放/旋转
        local dx1 = contact1.current_tev.x - contact1.initial_tev.x
        local dy1 = contact1.current_tev.y - contact1.initial_tev.y
        local dx2 = contact2.current_tev.x - contact2.initial_tev.x
        local dy2 = contact2.current_tev.y - contact2.initial_tev.y
        
        -- 计算相对运动
        if math.abs(dx1 - dx2) > self.PAN_THRESHOLD or
           math.abs(dy1 - dy2) > self.PAN_THRESHOLD then
            return "pinch"  -- 或 "spread"、"rotate"
        end
    end
    return nil
end
```

### 方向计算

```lua
-- 8方向计算（东、西、南、北、东北、西北、东南、西南）
function GestureDetector:_getDirection(start_tev, end_tev)
    local dx = end_tev.x - start_tev.x
    local dy = end_tev.y - start_tev.y
    local angle = math.atan2(dy, dx) * 180 / math.pi
    
    -- 角度到方向映射
    if math.abs(dx) > math.abs(dy) * 2 then
        return dx > 0 and "east" or "west"
    elseif math.abs(dy) > math.abs(dx) * 2 then
        return dy > 0 and "south" or "north"
    else
        -- 对角线方向
        if dx > 0 and dy > 0 then return "southeast"
        elseif dx > 0 and dy < 0 then return "northeast"
        elseif dx < 0 and dy > 0 then return "southwest"
        else return "northwest" end
    end
end
```

### 防抖处理

```lua
-- 防止误触（"bounce" 检测）
function GestureDetector:_checkBounce(contact, tev)
    -- 检查是否在双击距离内但有长时间延迟
    local distance = self:_distance(self.previous_tap[contact.slot], tev)
    local elapsed = tev.timev - self.previous_tap[contact.slot].timev
    
    if distance < self.SINGLE_TAP_BOUNCE_DISTANCE and
       elapsed > self.ges_double_tap_interval then
        -- 清除之前的点击记录，防止误判为双击
        self.previous_tap[contact.slot] = nil
        return true
    end
    return false
end
```

---

## 缓存算法

**文件**: `frontend/cache.lua`, `ffi/lru.lua`

### LRU（最近最少使用）算法

KOReader 使用**双向链表 + 哈希表**实现 LRU 缓存：

```lua
-- 节点结构
local Node = {
    key = nil,      -- 缓存键
    value = nil,    -- 缓存值
    size = 0,       -- 占用大小
    prev = nil,     -- 前驱节点
    next = nil,     -- 后继节点
}

-- LRU 缓存结构
local LRU = {
    head = nil,     -- 最近使用的节点
    tail = nil,     -- 最久未使用的节点
    map = {},       -- 键到节点的映射
    slots = 0,      -- 最大槽位数
    used_slots = 0, -- 已使用槽位
    size = 0,       -- 最大容量（字节）
    used_size = 0,  -- 已使用容量
}
```

### 访问操作（get）

```lua
function LRU:get(key)
    local node = self.map[key]
    if not node then return nil end
    
    -- 移动到链表头部（标记为最近使用）
    self:_moveToFront(node)
    
    -- 更新统计信息
    self.hits = self.hits + 1
    return node.value
end
```

### 插入操作（set）

```lua
function LRU:set(key, value, size)
    size = size or self:_estimateSize(value)
    
    -- 检查是否过大
    if not self:_willAccept(size) then
        logger.warn("Object too large for cache:", key)
        return false
    end
    
    -- 如果已存在，更新值并移动到头部
    local node = self.map[key]
    if node then
        self.used_size = self.used_size - node.size + size
        node.value = value
        node.size = size
        self:_moveToFront(node)
        return true
    end
    
    -- 创建新节点
    node = Node:new{key = key, value = value, size = size}
    
    -- 如果缓存已满，淘汰最久未使用的
    while self.used_slots >= self.slots or 
          (self.size and self.used_size + size > self.size) do
        self:_evict()
    end
    
    -- 插入到链表头部
    self:_insertAtFront(node)
    self.map[key] = node
    self.used_slots = self.used_slots + 1
    self.used_size = self.used_size + size
    
    return true
end
```

### 淘汰策略（evict）

```lua
function LRU:_evict()
    if not self.tail then return end
    
    local node = self.tail
    self.map[node.key] = nil
    
    -- 从链表尾部移除
    if node.prev then
        node.prev.next = nil
        self.tail = node.prev
    else
        self.head = nil
        self.tail = nil
    end
    
    -- 更新统计
    self.used_slots = self.used_slots - 1
    self.used_size = self.used_size - node.size
    
    -- 调用清理回调（如果启用）
    if self.eviction_cb and node.value.onFree then
        node.value:onFree()
    end
    
    -- 统计
    self.evictions = self.evictions + 1
end
```

### 链表操作

```lua
-- 移动到链表头部
function LRU:_moveToFront(node)
    -- 如果已经是头部，直接返回
    if node == self.head then return end
    
    -- 从当前位置断开
    if node.prev then node.prev.next = node.next end
    if node.next then node.next.prev = node.prev end
    
    -- 如果是尾部，更新尾部指针
    if node == self.tail then self.tail = node.prev end
    
    -- 插入到头部
    node.next = self.head
    node.prev = nil
    if self.head then self.head.prev = node end
    self.head = node
    
    -- 如果链表为空，同时设置尾部
    if not self.tail then self.tail = node end
end

-- 在头部插入新节点
function LRU:_insertAtFront(node)
    node.next = self.head
    node.prev = nil
    if self.head then self.head.prev = node end
    self.head = node
    if not self.tail then self.tail = node end
end
```

### 磁盘缓存

```lua
-- 检查磁盘缓存
function Cache:check(key, ItemClass)
    -- 1. 先检查内存缓存
    local value = self.cache:get(key)
    if value then return value end
    
    -- 2. 检查磁盘缓存
    local key_md5 = md5(key)
    local cached_file = self.cached[key_md5]
    if cached_file and ItemClass then
        -- 从磁盘加载
        local item = ItemClass:new{}
        local ok, msg = pcall(item.load, item, cached_file)
        if ok then
            -- 加载成功，存入内存缓存
            self:insert(key, item)
            return item
        else
            -- 加载失败，删除损坏的文件
            logger.warn("Failed to load disk cache:", msg)
            os.remove(cached_file)
            self:refreshSnapshot()
        end
    end
    return nil
end
```

### 内存压力检测

```lua
function Cache:memoryPressureCheck()
    local memfree, memtotal = util.calcFreeMem()
    if not memtotal then return end  -- 非 Linux 系统
    
    local free_fraction = memfree / memtotal
    
    -- 如果可用内存少于 20%
    if free_fraction < 0.20 then
        logger.warn(string.format(
            "内存不足 (~%d%%, ~%.2f/%d MiB)，淘汰一半缓存...",
            free_fraction * 100,
            memfree / (1024 * 1024),
            memtotal / (1024 * 1024)
        ))
        
        -- 淘汰一半缓存
        self.cache:chop()
        
        -- 强制垃圾回收
        collectgarbage()
        collectgarbage()
    end
end
```

### 缓存键生成策略

```lua
-- 文档渲染缓存键
function Document:getFullPageHash(pageno, zoom, rotation, gamma)
    return string.format("render|%s|%s|%d|%s|%s|%s|%s",
        self.file,              -- 文件路径
        self.mod_time,          -- 修改时间
        pageno,                 -- 页码
        zoom,                   -- 缩放比例
        rotation,               -- 旋转角度
        gamma,                  -- Gamma 值
        self.render_mode,       -- 渲染模式
        self.render_color and "color" or "bw"  -- 颜色模式
    )
end

-- 页面部分渲染缓存键
function Document:getPagePartHash(pageno, zoom, rotation, gamma, rect)
    return string.format("renderpgpart|%s|%s|%d|%s|%s|%s|%s|%s",
        self.file,
        self.mod_time,
        pageno,
        tostring(rect),         -- 矩形区域
        zoom,
        tostring(rect.scaled_rect),  -- 缩放后的矩形
        rotation,
        gamma,
        self.render_mode,
        self.render_color and "color" or "bw"
    )
end
```

---

## 渲染算法

**文件**: `frontend/document/document.lua`, `frontend/document/doccache.lua`

### 渲染管线

```
渲染请求 → 检查缓存 → 命中 → 返回缓存
                    ↓ 未命中
              确定渲染区域
                    ↓
              创建画布缓冲区
                    ↓
              调用引擎渲染
                    ↓
              存入缓存 → 返回结果
```

### 智能渲染区域选择

```lua
function Document:renderPage(pageno, rect, zoom, rotation, gamma, hinting)
    local is_prescaled = rect and rect.scaled_rect ~= nil
    
    -- 1. 生成缓存键
    local hash, tile
    if is_prescaled then
        hash = self:getPagePartHash(pageno, zoom, rotation, gamma, rect)
        tile = DocCache:check(hash, TileCacheItem)
    else
        hash = self:getFullPageHash(pageno, zoom, rotation, gamma)
        tile = DocCache:check(hash, TileCacheItem)
        
        -- 尝试查找部分渲染的缓存
        if not tile and rect then
            local hash_excerpt = hash .. "|" .. tostring(rect)
            tile = DocCache:check(hash_excerpt)
        end
    end
    
    -- 2. 缓存命中
    if tile then
        if self.tile_cache_validity_ts then
            -- 检查缓存时间戳
            if tile.created_ts and tile.created_ts >= self.tile_cache_validity_ts then
                return tile
            end
            logger.dbg("丢弃过时的缓存瓦片")
        else
            return tile
        end
    end
    
    -- 3. 确定渲染尺寸
    local page_size = self:getPageDimensions(pageno, zoom, rotation)
    local size
    if is_prescaled then
        size = rect.scaled_rect
    else
        size = page_size
        -- 检查是否适合缓存
        local estimated_size = size.w * size.h * (self.render_color and 4 or 1) + 512
        if not DocCache:willAccept(estimated_size) then
            -- 只渲染请求的区域
            if not rect then
                logger.warn("未指定渲染区域，放弃渲染！")
                return
            end
            size = rect
            hash = hash_excerpt
        end
    end
    
    -- 4. 创建渲染目标
    tile = TileCacheItem:new{
        persistent = not is_prescaled,  -- 不持久化页面片段
        doc_path = self.file,
        created_ts = os.time(),
        excerpt = size,
        pageno = pageno,
        bb = Blitbuffer.new(size.w, size.h, self.render_color and self.color_bb_type or nil)
    }
    tile.size = tonumber(tile.bb.stride) * tile.bb.h + 512  -- 估算大小
    
    -- 5. 执行渲染
    local dc = DrawContext.new()
    dc:setRotate(rotation)
    dc:setZoom(zoom)
    if gamma ~= self.GAMMA_NO_GAMMA then
        dc:setGamma(gamma)
    end
    
    -- 处理旋转偏移
    if rotation == 90 then
        dc:setOffset(page_size.w, 0)
    elseif rotation == 180 then
        dc:setOffset(page_size.w, page_size.h)
    elseif rotation == 270 then
        dc:setOffset(0, page_size.h)
    end
    
    -- 调用引擎渲染
    local page = self._document:openPage(pageno)
    page:draw(dc, tile.bb, size.x, size.y, self.render_mode)
    page:close()
    
    -- 6. 存入缓存
    DocCache:insert(hash, tile)
    
    return tile
end
```

### 渐进式渲染优化

```lua
-- 预渲染提示
function Document:hintPage(pageno, zoom, rotation, gamma)
    logger.dbg("预渲染页面", pageno)
    
    -- 启用多核渲染（提示模式）
    CanvasContext:enableCPUCores(2)
    local tile = self:renderPage(pageno, nil, zoom, rotation, gamma, true)
    CanvasContext:enableCPUCores(1)
    
    return tile
end
```

### 抖动渲染（E-ink 优化）

```lua
function Document:drawPage(target, x, y, rect, pageno, zoom, rotation, gamma)
    local tile = self:renderPage(pageno, rect, zoom, rotation, gamma)
    
    -- 软件抖动（E-ink 优化）
    if self.sw_dithering then
        target:ditherblitFrom(tile.bb,
            x, y,
            rect.x - tile.excerpt.x,
            rect.y - tile.excerpt.y,
            rect.w, rect.h)
    else
        target:blitFrom(tile.bb,
            x, y,
            rect.x - tile.excerpt.x,
            rect.y - tile.excerpt.y,
            rect.w, rect.h)
    end
end
```

### 图片查看器渲染优化

```lua
function Document:drawPagePart(pageno, native_rect, rotation)
    local rect = Geom:new(native_rect)
    local canvas_size = CanvasContext:getSize()
    
    -- 自动旋转以获得最佳显示效果
    local rotate = false
    if G_reader_settings:isTrue("imageviewer_rotate_auto_for_best_fit") then
        rotate = (canvas_size.w > canvas_size.h) ~= (rect.w > rect.h)
    end
    
    -- 计算最佳缩放比例
    local zoom = rotate and 
        math.min(canvas_size.w / rect.h, canvas_size.h / rect.w) or
        math.min(canvas_size.w / rect.w, canvas_size.h / rect.h)
    
    -- 缩放矩形
    local scaled_rect = self:transformRect(rect, zoom, rotation)
    rect.scaled_rect = scaled_rect  -- 标记为已缩放
    
    -- 使用多核渲染（hinting=true）
    local tile = self:renderPage(pageno, rect, zoom, rotation, 1.0, true)
    
    return tile.bb, rotate
end
```

---

## 事件传播算法

**文件**: `frontend/ui/widget/container/widgetcontainer.lua`

### 冒泡传播模型

```
父容器收到事件
    ↓
for each 子组件 in 子组件列表
    ↓
子组件:handleEvent(event)
    ↓
if 返回 true then
    ↓
    事件被消费，停止传播
    ↓
    return true
end
    ↓
循环结束
    ↓
父组件自己处理事件
    ↓
return 处理结果
```

### 实现代码

```lua
function WidgetContainer:handleEvent(event)
    -- 1. 先传递给子组件（从后往前，最上面的组件先处理）
    for i = #self, 1, -1 do
        local widget = self[i]
        if widget:handleEvent(event) then
            return true  -- 事件被消费
        end
    end
    
    -- 2. 子组件未消费，自己处理
    local handler = self[event.handler]
    if handler then
        return handler(self, unpack(event.args, 1, event.args.n))
    end
    
    return false  -- 事件未被消费
end
```

### 触摸区域优先级

```lua
-- 触摸区域冲突解决
function InputContainer:_resolveTouchZoneConflict(ges)
    local zones = self:_getTouchZonesForGesture(ges)
    if #zones == 0 then return nil end
    
    -- 按优先级排序
    table.sort(zones, function(a, b)
        -- 1. 有 overrides 的优先
        if a.overrides and not b.overrides then return true end
        if b.overrides and not a.overrides then return false end
        
        -- 2. 注册时间晚的优先（后注册的先处理）
        return a.register_time > b.register_time
    end)
    
    return zones[1]
end
```

### 手势覆盖规则

```lua
-- 手势覆盖配置示例
self:registerTouchZones({
    {
        id = "tap_link",
        ges = "tap",
        screen_zone = {ratio_x = 0, ratio_y = 0, ratio_w = 1, ratio_h = 1},
        overrides = {
            "readerhighlight_tap",
            "tap_top_left_corner",
            "tap_top_right_corner",
            "readerfooter_tap",
            "readerconfigmenu_tap",
            "readermenu_tap",
        },
        handler = function(ges) return self:onTap(_, ges) end,
    }
})
```

---

## 任务调度算法

**文件**: `frontend/ui/uimanager.lua`

### 定时任务队列

```lua
-- 任务队列结构
local task_queue = {
    -- 按执行时间排序
    {time = t1, action = func1, args = {...}},
    {time = t2, action = func2, args = {...}},
    ...
}
```

### 二分查找插入

```lua
function UIManager:schedule(when, action, ...)
    local sched_time = when
    
    -- 二分查找插入位置
    local lo, hi = 1, #self._task_queue
    while lo <= hi do
        -- 防止整数溢出：mid = (lo + hi) >> 1
        local mid = bit.rshift(lo + hi, 1)
        local mid_time = self._task_queue[mid].time
        if mid_time <= sched_time then
            hi = mid - 1
        else
            lo = mid + 1
        end
    end
    
    -- 插入到正确位置
    table.insert(self._task_queue, lo, {
        time = sched_time,
        action = action,
        args = table.pack(...),
    })
    self._task_queue_dirty = true
end
```

### 防抖（Debounce）算法

```lua
function UIManager:debounce(seconds, immediate, action)
    -- 移植自 underscore.js
    local args = nil
    local previous_call_at = nil
    local is_scheduled = false
    local result = nil
    
    local scheduled_action
    scheduled_action = function()
        local passed_from_last_call = time:now() - previous_call_at
        if seconds > passed_from_last_call then
            -- 重新调度
            self:scheduleIn(seconds - passed_from_last_call, scheduled_action)
            is_scheduled = true
        else
            is_scheduled = false
            if not immediate then
                -- 执行实际函数
                result = action(unpack(args, 1, args.n))
            end
            if not is_scheduled then
                args = nil  -- 清理参数
            end
        end
    end
    
    local debounced_action_wrapper = function(...)
        args = table.pack(...)
        previous_call_at = time:now()
        if not is_scheduled then
            self:scheduleIn(seconds, scheduled_action)
            is_scheduled = true
            if immediate then
                result = action(unpack(args, 1, args.n))
            end
        end
        return result
    end
    
    return debounced_action_wrapper
end
```

### 任务执行循环

```lua
function UIManager:_checkTasks()
    local now = time.now()
    
    while #self._task_queue > 0 do
        local task = self._task_queue[1]
        if task.time > now then
            break  -- 任务还未到执行时间
        end
        
        -- 从队列移除
        table.remove(self._task_queue, 1)
        
        -- 执行任务
        local ok, err = pcall(task.action, unpack(task.args, 1, task.args.n))
        if not ok then
            logger.err("Error in scheduled task:", err)
        end
    end
end
```

---

## 几何计算算法

**文件**: `frontend/ui/geometry.lua`

### 矩形运算

```lua
-- 矩形交集
function Geom:intersect(other)
    local x1 = math.max(self.x, other.x)
    local y1 = math.max(self.y, other.y)
    local x2 = math.min(self.x + self.w, other.x + other.w)
    local y2 = math.min(self.y + self.h, other.y + other.h)
    
    if x2 <= x1 or y2 <= y1 then
        return nil  -- 无交集
    end
    
    return Geom:new{
        x = x1,
        y = y1,
        w = x2 - x1,
        h = y2 - y1,
    }
end

-- 矩形并集
function Geom:combine(other)
    local x1 = math.min(self.x, other.x)
    local y1 = math.min(self.y, other.y)
    local x2 = math.max(self.x + self.w, other.x + other.w)
    local y2 = math.max(self.y + self.h, other.y + other.h)
    
    return Geom:new{
        x = x1,
        y = y1,
        w = x2 - x1,
        h = y2 - y1,
    }
end

-- 点是否在矩形内
function Geom:containsPoint(x, y)
    return x >= self.x and x <= self.x + self.w and
           y >= self.y and y <= self.y + self.h
end

-- 矩形是否包含另一个矩形
function Geom:contains(other)
    return other.x >= self.x and
           other.y >= self.y and
           other.x + other.w <= self.x + self.w and
           other.y + other.h <= self.y + self.h
end
```

### 坐标变换

```lua
-- 仿射变换
function Geom:transform(zoom, rotation, offset_x, offset_y)
    local new_geom = self:copy()
    
    -- 缩放
    if zoom and zoom ~= 1 then
        new_geom.x = new_geom.x * zoom
        new_geom.y = new_geom.y * zoom
        new_geom.w = new_geom.w * zoom
        new_geom.h = new_geom.h * zoom
    end
    
    -- 旋转（以中心为原点）
    if rotation and rotation ~= 0 then
        local cx = new_geom.x + new_geom.w / 2
        local cy = new_geom.y + new_geom.h / 2
        
        -- 转换为极坐标，添加旋转，再转回笛卡尔坐标
        local rad = math.rad(rotation)
        local cos_theta = math.cos(rad)
        local sin_theta = math.sin(rad)
        
        -- 旋转四个角点
        local corners = {
            {x = new_geom.x, y = new_geom.y},
            {x = new_geom.x + new_geom.w, y = new_geom.y},
            {x = new_geom.x, y = new_geom.y + new_geom.h},
            {x = new_geom.x + new_geom.w, y = new_geom.y + new_geom.h},
        }
        
        local min_x, min_y = math.huge, math.huge
        local max_x, max_y = -math.huge, -math.huge
        
        for _, corner in ipairs(corners) do
            -- 相对于中心
            local dx = corner.x - cx
            local dy = corner.y - cy
            
            -- 旋转
            local new_x = dx * cos_theta - dy * sin_theta
            local new_y = dx * sin_theta + dy * cos_theta
            
            -- 更新边界
            local abs_x = cx + new_x
            local abs_y = cy + new_y
            min_x = math.min(min_x, abs_x)
            min_y = math.min(min_y, abs_y)
            max_x = math.max(max_x, abs_x)
            max_y = math.max(max_y, abs_y)
        end
        
        new_geom.x = min_x
        new_geom.y = min_y
        new_geom.w = max_x - min_x
        new_geom.h = max_y - min_y
    end
    
    -- 平移
    if offset_x then new_geom.x = new_geom.x + offset_x end
    if offset_y then new_geom.y = new_geom.y + offset_y end
    
    return new_geom
end
```

### 屏幕适配算法

```lua
-- 保持宽高比的缩放
function Geom:scaleToFit(container_width, container_height, keep_aspect)
    if not keep_aspect then
        return Geom:new{
            x = 0, y = 0,
            w = container_width,
            h = container_height,
        }
    end
    
    local scale_w = container_width / self.w
    local scale_h = container_height / self.h
    local scale = math.min(scale_w, scale_h)
    
    local new_width = self.w * scale
    local new_height = self.h * scale
    local x_offset = (container_width - new_width) / 2
    local y_offset = (container_height - new_height) / 2
    
    return Geom:new{
        x = x_offset,
        y = y_offset,
        w = new_width,
        h = new_height,
    }
end
```

---

## 文本选择算法

### 文本位置映射

```lua
-- 将屏幕坐标映射到文档位置
function CreDocument:getPosFromScreen(x, y)
    -- 1. 转换为页面坐标
    local page_x, page_y = self.view:screenToPage(x, y)
    
    -- 2. 调用引擎获取位置
    local pos = self._document:getPosFromXY(page_x, page_y)
    
    -- 3. 处理边界情况
    if pos < 0 then pos = 0 end
    if pos > self.info.doc_height then pos = self.info.doc_height end
    
    return pos
end
```

### 选择区域扩展

```lua
function ReaderHighlight:extendSelection(direction)
    local current_pos = self.selected_text.pos0
    local target_pos
    
    if direction == "word" then
        -- 扩展到整个单词
        target_pos = self.ui.document:getNextWordBoundary(current_pos)
    elseif direction == "sentence" then
        -- 扩展到整个句子
        target_pos = self.ui.document:getNextSentenceBoundary(current_pos)
    elseif direction == "paragraph" then
        -- 扩展到整个段落
        target_pos = self.ui.document:getNextParagraphBoundary(current_pos)
    end
    
    if target_pos and target_pos ~= current_pos then
        self.selected_text.pos1 = target_pos
        self:_updateSelectionDisplay()
    end
end
```

---

## 搜索算法

**文件**: `frontend/apps/reader/modules/readersearch.lua`

### 正则表达式搜索

```lua
function ReaderSearch:findText(pattern, case_insensitive, is_regex)
    local results = {}
    local current_page = self.ui.paging and self.ui.paging.current_page or 1
    
    if is_regex then
        -- 正则表达式搜索
        local ok, re = pcall(require("ffi/re").new, pattern, 
            case_insensitive and "i" or "")
        if not ok then
            logger.warn("Invalid regex:", re)
            return results
        end
        
        -- 分页搜索，避免性能问题
        for page = current_page, self.ui.document:getPageCount() do
            local text = self.ui.document:getPageText(page)
            if text then
                local matches = re:matchAll(text)
                for _, match in ipairs(matches) do
                    if #results >= self.max_hits then
                        logger.warn("达到最大匹配数限制:", self.max_hits)
                        return results
                    end
                    table.insert(results, {
                        page = page,
                        text = match.text,
                        position = match.position,
                        length = #match.text,
                    })
                end
            end
        end
    else
        -- 普通文本搜索（使用字符串查找）
        for page = current_page, self.ui.document:getPageCount() do
            local text = self.ui.document:getPageText(page)
            if text then
                local search_text = case_insensitive and text:lower() or text
                local search_pattern = case_insensitive and pattern:lower() or pattern
                
                local start_pos = 1
                while true do
                    local pos = search_text:find(search_pattern, start_pos, true)
                    if not pos then break end
                    
                    if #results >= self.max_hits then
                        logger.warn("达到最大匹配数限制:", self.max_hits)
                        return results
                    end
                    
                    table.insert(results, {
                        page = page,
                        text = text:sub(pos, pos + #pattern - 1),
                        position = pos,
                        length = #pattern,
                    })
                    
                    start_pos = pos + 1
                end
            end
        end
    end
    
    return results
end
```

### 全文搜索优化

```lua
-- 搜索结果缓存
function ReaderSearch:getCachedSearchResults(query_hash)
    local cache_key = "search|" .. self.ui.document.file .. "|" .. query_hash
    return DocCache:check(cache_key)
end

function ReaderSearch:cacheSearchResults(query_hash, results)
    local cache_key = "search|" .. self.ui.document.file .. "|" .. query_hash
    DocCache:insert(cache_key, CacheItem:new{results})
end
```

---

## 内存管理算法

### 内存监控

```lua
function util.calcFreeMem()
    -- Linux 系统：读取 /proc/meminfo
    local meminfo_file = io.open("/proc/meminfo", "r")
    if not meminfo_file then return nil, nil end
    
    local memfree, memtotal
    for line in meminfo_file:lines() do
        if line:match("^MemTotal:") then
            memtotal = tonumber(line:match("%d+"))
        elseif line:match("^MemFree:") then
            memfree = tonumber(line:match("%d+"))
        elseif line:match("^Buffers:") then
            memfree = memfree + tonumber(line:match("%d+"))
        elseif line:match("^Cached:") then
            memfree = memfree + tonumber(line:match("%d+"))
        end
    end
    meminfo_file:close()
    
    return memfree * 1024, memtotal * 1024  -- 转换为字节
end
```

### 垃圾回收策略

```lua
-- 主动垃圾回收
function Cache:forceGC()
    -- 标记-清除阶段
    collectgarbage("collect")
    
    -- 完整回收
    collectgarbage()
    
    logger.dbg("强制垃圾回收完成")
end

-- 定时清理
UIManager:scheduleIn(60, function()
    Cache:memoryPressureCheck()
    
    -- 如果内存使用率高，触发垃圾回收
    local memfree, memtotal = util.calcFreeMem()
    if memtotal and memfree / memtotal < 0.30 then
        collectgarbage()
    end
end)
```

---

## 性能优化算法

### 懒加载与预加载

```lua
-- 页面预加载
function ReaderPaging:preloadAdjacentPages()
    local current = self.current_page
    local total = self.ui.document.info.number_of_pages
    
    -- 预加载前后各一页
    if current > 1 then
        self.ui.document:hintPage(current - 1)
    end
    if current < total then
        self.ui.document:hintPage(current + 1)
    end
end

-- 图片懒加载
function CreDocument:lazyLoadImages()
    -- 只加载可见区域的图片
    local viewport = self.view:getVisibleArea()
    local images = self:getImagesInArea(viewport)
    
    for _, image in ipairs(images) do
        if not image.loaded then
            self:loadImage(image)
        end
    end
end
```

### 批量更新优化

```lua
-- 合并多次更新请求
function UIManager:batchUpdates(callback)
    self._batch_mode = true
    self._batch_updates = {}
    
    local result = callback()
    
    -- 执行批量更新
    for _, update in ipairs(self._batch_updates) do
        update.func(unpack(update.args, 1, update.args.n))
    end
    
    self._batch_mode = false
    self._batch_updates = {}
    
    return result
end

-- 在批量模式中延迟更新
function Widget:setDirty(refreshtype, refreshregion)
    if UIManager._batch_mode then
        table.insert(UIManager._batch_updates, {
            func = Widget.setDirty,
            args = table.pack(self, refreshtype, refreshregion),
        })
    else
        -- 立即更新
        UIManager:setDirty(self, refreshtype, refreshregion)
    end
end
```

---

## 参考文档

- [项目架构](project-architecture.md) - 整体架构说明
- [模块说明](module-reference.md) - 各模块功能
- [数据流与交互](dataflow.md) - 事件和数据流
- [核心类说明](core-classes.md) - 核心类详解
