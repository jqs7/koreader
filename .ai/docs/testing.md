# KOReader 测试指南

## 测试框架

- **Busted** - Lua 单元测试框架
- **Meson test runner** - 并行测试执行

## 测试位置

```
koreader/
├── spec/
│   └── unit/              # 前端单元测试（80+ 文件）
│       ├── readerbookmark_spec.lua
│       ├── readerhighlight_spec.lua
│       └── ...
├── base/
│   └── spec/
│       └── unit/          # Base 层测试
└── test/                  # 测试数据（子模块）
```

## 运行测试

```bash
# 运行所有测试
./kodev test

# 仅前端测试
./kodev test front

# 仅 base 测试
./kodev test base

# 运行单个测试文件
./kodev test front readerbookmark_spec.lua

# 运行特定 base 测试
./kodev test base util

# 列出所有可用测试
./kodev test -l

# 查看完整帮助
./kodev test -h
```

## 编写测试

### 基本结构

```lua
-- spec/unit/mymodule_spec.lua
describe("MyModule", function()
    local MyModule
    
    setup(function()
        -- 在所有测试前执行一次
        require("commonrequire")
        MyModule = require("mymodule")
    end)
    
    teardown(function()
        -- 在所有测试后执行一次
    end)
    
    before_each(function()
        -- 在每个测试前执行
    end)
    
    after_each(function()
        -- 在每个测试后执行
    end)
    
    describe("feature A", function()
        it("should do something", function()
            local result = MyModule:doSomething()
            assert.is_true(result)
        end)
        
        it("should handle edge case", function()
            assert.has_error(function()
                MyModule:doSomething(nil)
            end)
        end)
    end)
end)
```

### 常用断言

```lua
-- 相等性
assert.are.equal(expected, actual)
assert.are.same(expected_table, actual_table)  -- 深度比较

-- 布尔值
assert.is_true(value)
assert.is_false(value)
assert.is_nil(value)
assert.is_not_nil(value)

-- 类型检查
assert.is_string(value)
assert.is_number(value)
assert.is_table(value)
assert.is_function(value)

-- 错误检查
assert.has_error(function() ... end)
assert.has_no_error(function() ... end)

-- 包含检查
assert.truthy(value)
assert.falsy(value)
```

### 测试辅助函数

测试文件可以使用以下全局函数（在 `.luacheckrc` 中定义）：

```lua
-- 禁用插件
disable_plugins()

-- 加载特定插件
load_plugin("statistics")

-- 快进 UI 事件
fastforward_ui_events()

-- 截图
screenshot()
```

### 模拟和存根

```lua
describe("with mocks", function()
    local mock_device
    
    before_each(function()
        -- 创建模拟对象
        mock_device = {
            screen = {
                getWidth = function() return 600 end,
                getHeight = function() return 800 end,
            }
        }
        
        -- 替换全局对象
        package.loaded["device"] = mock_device
    end)
    
    after_each(function()
        -- 恢复
        package.loaded["device"] = nil
    end)
end)
```

## 测试数据

测试数据位于 `test/` 子模块，包含：
- 示例电子书文件
- 测试用图片
- 配置文件样本

## CI/CD 集成

测试在以下 CI 环境中运行：
- GitHub Actions (`.github/workflows/`)
- CircleCI (`.circleci/`)

代码覆盖率配置：`.codecov.yml`

## 最佳实践

1. **测试命名**：使用描述性名称，说明测试的行为
2. **独立性**：每个测试应该独立运行，不依赖其他测试的状态
3. **清理**：使用 `after_each` 清理测试产生的副作用
4. **边界条件**：测试边界情况和错误处理
5. **快速反馈**：保持测试快速，避免不必要的 I/O 操作
