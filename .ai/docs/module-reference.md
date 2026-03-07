# KOReader 模块说明文档

> 本文档详细介绍 KOReader 各个模块的功能和职责。

## 目录

1. [Frontend 模块](#frontend-模块)
2. [Apps 模块](#apps-模块)
3. [UI 框架模块](#ui-框架模块)
4. [Device 模块](#device-模块)
5. [Document 模块](#document-模块)
6. [基础工具模块](#基础工具模块)
7. [Plugins 模块](#plugins-模块)

---

## Frontend 模块

`frontend/` 目录包含所有的 Lua 前端代码，是 KOReader 的核心业务逻辑层。

### 目录结构

```
frontend/
├── apps/              # 应用程序（阅读器、文件管理器）
├── device/            # 设备抽象层
├── document/          # 文档处理引擎
├── ui/                # UI 框架和组件
├── cache.lua          # 缓存管理
├── cacheitem.lua      # 缓存项定义
├── datetime.lua       # 日期时间工具
├── dbg.lua            # 调试工具
├── depgraph.lua       # 依赖图工具
├── dispatcher.lua     # 事件分发器
├── docsettings.lua    # 文档设置管理
├── dump.lua           # 调试输出
├── ffi/               # FFI 绑定
├── fontlist.lua       # 字体列表管理
├── httpclient.lua     # HTTP 客户端
├── languagesupport.lua # 语言支持
├── logger.lua         # 日志系统
├── luadata.lua        # Lua 数据持久化
├── luadefaults.lua    # 默认设置
├── luasettings.lua    # Lua 设置管理
├── optmath.lua        # 数学工具
├── persist.lua        # 持久化工具
├── pluginloader.lua   # 插件加载器
├── pluginshare.lua    # 插件共享数据
├── provider.lua       # 内容提供者
├── random.lua         # 随机数工具
├── readcollection.lua # 阅读集合
├── readhistory.lua    # 阅读历史
├── socketutil.lua     # Socket 工具
├── userpatch.lua      # 用户补丁
└── util.lua           # 通用工具
```

---

## Apps 模块

`frontend/apps/` 包含 KOReader 的主要应用程序界面。

### Reader (阅读器)

**路径**: `frontend/apps/reader/`

阅读器是 KOReader 的核心应用，用于阅读各种格式的电子书。

#### 核心文件

| 文件 | 说明 |
|------|------|
| `readerui.lua` | 阅读器主界面，协调所有阅读器模块 |

#### 阅读器模块 (modules/)

阅读器采用模块化设计，每个模块负责特定功能：

| 模块 | 功能 | 关键事件 |
|------|------|----------|
| `readerview.lua` | 视图渲染，负责页面绘制 | `PaintTo`, `SetDirty` |
| `readerrolling.lua` | 滚动模式（EPUB） | `PosUpdate`, `UpdatePos` |
| `readerpaging.lua` | 翻页模式（PDF/DJVU） | `PageUpdate`, `GotoPage` |
| `readertoc.lua` | 目录/大纲 | `ShowToc`, `GotoPage` |
| `readerbookmark.lua` | 书签管理 | `AddBookmark`, `RemoveBookmark` |
| `readerannotation.lua` | 标注管理 | `AddAnnotation`, `UpdateAnnotation` |
| `readerhighlight.lua` | 文本高亮 | `Highlight`, `Unhighlight` |
| `readerlink.lua` | 链接处理（内部/外部） | `GotoLink`, `OpenLink` |
| `readersearch.lua` | 搜索功能 | `FindText`, `FindNext` |
| `readerfont.lua` | 字体设置 | `ChangeFont`, `SetFontSize` |
| `readertypeset.lua` | 排版设置 | `SetStyle`, `UpdatePos` |
| `readertypography.lua` | 字体排印 | `Hyphenation`, `LineSpace` |
| `readerconfig.lua` | 底部配置面板 | `ShowConfigPanel` |
| `readermenu.lua` | 顶部菜单 | `ShowMenu` |
| `readerfooter.lua` | 底部状态栏 | `UpdateFooter` |
| `readerzooming.lua` | 缩放控制 | `SetZoom`, `ZoomIn`, `ZoomOut` |
| `readercropping.lua` | 页面裁剪 | `CropPage`, `SetCrop` |
| `readerpanning.lua` | 平移控制 | `Pan`, `SetPan` |
| `readerscrolling.lua` | 滚动控制 | `Scroll`, `SetScroll` |
| `readerflipping.lua` | 快速翻页 | `FlipPage` |
| `readerdogear.lua` | 页角标记 | `ShowDogEar` |
| `readerthumbnail.lua` | 缩略图 | `ShowThumbnail` |
| `readerpagemap.lua` | 页码映射 | `UpdatePageMap` |
| `readerhandmade.lua` | 自定义目录/隐藏流 | `SetHandmadeToc` |
| `readergoto.lua` | 跳转页面 | `ShowGotoDialog` |
| `readerback.lua` | 返回导航 | `Back`, `Forward` |
| `readerstatus.lua` | 阅读状态 | `ShowStatus`, `UpdateStatus` |
| `readerdictionary.lua` | 字典查询 | `LookupWord`, `ShowDict` |
| `readerwikipedia.lua` | Wikipedia 查询 | `WikiLookup` |
| `readerhinting.lua` | 渲染提示 | `HintPage` |
| `readercoptlistener.lua` | CRE 引擎监听 | `OnReadSettings` |
| `readerkoptlistener.lua` | KOPT 引擎监听 | `OnReadSettings` |
| `readerdevicestatus.lua` | 设备状态 | `BatteryLow`, `StorageLow` |
| `readeruserhyph.lua` | 用户自定义断字 | `SetUserHyph` |
| `readeractivityindicator.lua` | 活动指示器 | `ShowIndicator` |

### FileManager (文件管理器)

**路径**: `frontend/apps/filemanager/`

文件管理器用于浏览文件系统、管理书籍和集合。

| 文件 | 功能 |
|------|------|
| `filemanager.lua` | 文件管理器主界面 |
| `filemanagermenu.lua` | 文件管理器菜单 |
| `filemanagerbookinfo.lua` | 书籍信息显示/编辑 |
| `filemanagerhistory.lua` | 阅读历史管理 |
| `filemanagercollection.lua` | 书籍集合管理 |
| `filemanagerfilesearcher.lua` | 文件搜索 |
| `filemanagershortcuts.lua` | 文件夹快捷方式 |
| `filemanagerconverter.lua` | 格式转换 |
| `filemanagersetdefaults.lua` | 默认设置管理 |
| `filemanagerutil.lua` | 文件管理器工具函数 |
| `lib/md.lua` | Markdown 解析库 |

### CloudStorage (云存储)

**路径**: `frontend/apps/cloudstorage/`

| 文件 | 功能 |
|------|------|
| `cloudstorage.lua` | 云存储主界面 |
| `dropbox.lua` | Dropbox 集成 |
| `dropboxapi.lua` | Dropbox API |
| `ftp.lua` | FTP 支持 |
| `ftpapi.lua` | FTP API |
| `webdav.lua` | WebDAV 支持 |
| `webdavapi.lua` | WebDAV API |
| `syncservice.lua` | 同步服务 |

---

## UI 框架模块

`frontend/ui/` 包含完整的 UI 框架，采用面向对象设计。

### 核心组件

| 文件 | 功能 |
|------|------|
| `uimanager.lua` | UI 管理器，负责事件循环和窗口栈 |
| `event.lua` | 事件定义 |
| `geometry.lua` | 几何计算（Geom 类） |
| `time.lua` | 时间管理 |
| `bidi.lua` | 双向文本支持 |
| `hook_container.lua` | 事件钩子容器 |

### Widget 组件 (ui/widget/)

#### 基础 Widget

| 文件 | 功能 | 继承关系 |
|------|------|----------|
| `eventlistener.lua` | 事件监听基类 | 所有 widget 的基类 |
| `widget.lua` | Widget 基类 | EventListener |
| `textwidget.lua` | 文本显示 | Widget |
| `fixedtextwidget.lua` | 固定大小文本 | TextWidget |
| `imagewidget.lua` | 图片显示 | Widget |
| `lineWidget.lua` | 线条绘制 | Widget |
| `rectangle.lua` | 矩形绘制 | Widget |
| `progresswidget.lua` | 进度条 | Widget |
| `buttonprogresswidget.lua` | 按钮式进度条 | Widget |
| `checkbox.lua` | 复选框 | Widget |
| `checkmark.lua` | 勾选标记 | Widget |
| `checkbutton.lua` | 勾选按钮 | Widget |

#### 交互 Widget

| 文件 | 功能 |
|------|------|
| `button.lua` | 按钮 |
| `buttontable.lua` | 按钮表格 |
| `buttondialog.lua` | 按钮对话框 |
| `buttondialogtitle.lua` | 带标题的按钮对话框 |
| `confirmbox.lua` | 确认对话框 |
| `infomessage.lua` | 信息提示框 |
| `notification.lua` | 通知提示 |
| `inputdialog.lua` | 输入对话框 |
| `login_dialog.lua` | 登录对话框 |
| `openwithdialog.lua` | 打开方式对话框 |
| `radiobuttonwidget.lua` | 单选按钮组 |
| `spinwidget.lua` | 数值选择器 |
| `doublespinwidget.lua` | 双数值选择器 |
| `datetimeWidget.lua` | 日期时间选择器 |
| `sortwidget.lua` | 排序选项 |
| `multicheckboxwidget.lua` | 多选框组 |
| `multiconfirmbox.lua` | 多重确认对话框 |

#### 布局容器 (ui/widget/container/)

| 文件 | 功能 |
|------|------|
| `widgetcontainer.lua` | 容器基类 |
| `inputcontainer.lua` | 输入容器（处理手势） |
| `framecontainer.lua` | 带边框的容器 |
| `centercontainer.lua` | 居中容器 |
| `underlinecontainer.lua` | 下划线容器 |
| `overlapgroup.lua` | 重叠组 |
| `horizontalgroup.lua` | 水平布局组 |
| `verticalgroup.lua` | 垂直布局组 |
| `horizontalSpan.lua` | 水平间距 |
| `verticalSpan.lua` | 垂直间距 |

#### 阅读相关 Widget

| 文件 | 功能 |
|------|------|
| `booklist.lua` | 书籍列表 |
| `bookstatuswidget.lua` | 书籍状态面板 |
| `bookmapwidget.lua` | 书籍地图/缩略图 |
| `bookmarkbrowser.lua` | 书签浏览器 |
| `dictquicklookup.lua` | 字典快速查询 |
| `footnotewidget.lua` | 脚注显示 |
| `pagebrowser.lua` | 页面浏览器 |
| `skimtowidget.lua` | 快速跳转 |
| `screensaver.lua` | 屏保 |
| `screenshoter.lua` | 截图工具 |

#### 菜单和对话框

| 文件 | 功能 |
|------|------|
| `menu.lua` | 通用菜单 |
| `touchmenu.lua` | 触摸菜单 |
| `configdialog.lua` | 配置对话框 |
| `filechooser.lua` | 文件选择器 |
| `titlebar.lua` | 标题栏 |
| `footerwidget.lua` | 底部小部件 |
| `frontlightwidget.lua` | 前光控制 |
| `sortwidget.lua` | 排序控件 |
| `textboxwidget.lua` | 文本框 |
| `textviewer.lua` | 文本查看器 |
| `htmlviewer.lua` | HTML 查看器 |

### 数据 (ui/data/)

| 文件 | 功能 |
|------|------|
| `optionsutil.lua` | 选项工具 |
| `koptoptions.lua` | KOPT 引擎选项 |
| `dictionaries.lua` | 字典数据 |
| `css_tweaks.lua` | CSS 调整 |
| `onetime_migration.lua` | 一次性迁移 |
| `ocr.lua` | OCR 数据 |
| `settings_migration.lua` | 设置迁移 |
| `keyboardlayouts/` | 键盘布局 |

### 网络 (ui/network/)

| 文件 | 功能 |
|------|------|
| `networklistener.lua` | 网络状态监听 |
| `managewifi.lua` | WiFi 管理 |
| `ota_update.lua` | OTA 更新 |

---

## Device 模块

`frontend/device/` 提供设备抽象层，屏蔽不同平台的差异。

### 核心文件

| 文件 | 功能 |
|------|------|
| `device.lua` | 设备入口，自动检测平台 |
| `generic/device.lua` | 通用设备基类 |
| `input.lua` | 输入处理（触摸、按键） |
| `gesturedetector.lua` | 手势检测 |
| `devicelistener.lua` | 设备事件监听 |
| `key.lua` | 按键定义 |
| `wakeupmgr.lua` | 唤醒管理 |
| `sysfs_light.lua` | 系统背光控制 |
| `thirdparty.lua` | 第三方工具 |

### 平台实现

| 目录 | 平台 | 说明 |
|------|------|------|
| `kindle/` | Amazon Kindle | Kindle 设备支持 |
| `kobo/` | Kobo | Kobo 设备支持 |
| `pocketbook/` | PocketBook | PocketBook 设备支持 |
| `remarkable/` | reMarkable | reMarkable 设备支持 |
| `cervantes/` | BQ Cervantes | Cervantes 设备支持 |
| `sony-prstux/` | Sony PRS-TUX | Sony 设备支持 |
| `android/` | Android | Android 设备支持 |
| `sdl/` | SDL | 模拟器/桌面平台 |
| `dummy/` | Dummy | 测试用虚拟设备 |

### 设备能力检测

`generic/device.lua` 定义了设备能力检测函数：

```lua
-- 硬件能力
hasBattery()          -- 是否有电池
hasKeyboard()         -- 是否有物理键盘
hasKeys()             -- 是否有按键
hasDPad()             -- 是否有方向键
hasTouchDevice()      -- 是否支持触摸
hasFrontlight()       -- 是否有前光
hasEinkScreen()       -- 是否是 E-ink 屏幕
hasWifiToggle()       -- 是否支持 WiFi 切换
canSuspend()          -- 是否支持休眠
canReboot()           -- 是否支持重启
canPowerOff()         -- 是否支持关机

-- 平台检测
isAndroid()           -- Android 平台
isKindle()            -- Kindle 设备
isKobo()              -- Kobo 设备
isSDL()               -- SDL/模拟器
```

---

## Document 模块

`frontend/document/` 提供文档抽象层，支持多种文档格式。

### 核心文件

| 文件 | 功能 |
|------|------|
| `document.lua` | 文档基类 |
| `documentregistry.lua` | 文档类型注册表 |
| `doccache.lua` | 文档缓存管理 |
| `tilecacheitem.lua` | 瓦片缓存项 |
| `canvascontext.lua` | 画布上下文 |
| `koptinterface.lua` | KOPT 引擎接口 |

### 文档格式支持

| 文件 | 格式 | 引擎 |
|------|------|------|
| `credocument.lua` | EPUB, FB2, HTML, TXT | CREngine |
| `pdfdocument.lua` | PDF | MuPDF |
| `djvudocument.lua` | DJVU | DjVuLibre |
| `picdocument.lua` | JPG, PNG, GIF, TIFF, WEBP | 各种库 |

### 文档注册表

`documentregistry.lua` 管理文档格式和渲染引擎的映射关系：

```lua
-- 注册 EPUB 支持
DocumentRegistry:addProvider("epub", "application/epub+zip", CreDocument)
-- 注册 PDF 支持  
DocumentRegistry:addProvider("pdf", "application/pdf", PdfDocument)
```

---

## 基础工具模块

### 缓存系统

| 文件 | 功能 |
|------|------|
| `cache.lua` | 通用缓存管理 |
| `cacheitem.lua` | 缓存项基类 |
| `doccache.lua` | 文档专用缓存 |
| `tilecacheitem.lua` | 瓦片缓存项 |

### 设置管理

| 文件 | 功能 |
|------|------|
| `luasettings.lua` | Lua 格式设置文件 |
| `docsettings.lua` | 文档设置（sidecar） |
| `luadefaults.lua` | 默认设置 |
| `luadata.lua` | 数据持久化 |
| `persist.lua` | 持久化工具 |

### 调试和日志

| 文件 | 功能 |
|------|------|
| `logger.lua` | 日志系统 |
| `dbg.lua` | 调试工具 |
| `dump.lua` | 变量打印 |

### 其他工具

| 文件 | 功能 |
|------|------|
| `util.lua` | 通用工具函数 |
| `optmath.lua` | 数学工具 |
| `datetime.lua` | 日期时间处理 |
| `ffi/util.lua` | FFI 工具 |
| `socketutil.lua` | Socket 工具 |
| `httpclient.lua` | HTTP 客户端 |

---

## Plugins 模块

`plugins/` 目录包含所有插件，每个插件是一个 `.koplugin` 目录。

### 插件结构

```
plugins/<name>.koplugin/
├── _meta.lua          # 插件元数据
├── main.lua           # 插件入口
└── ...                # 其他文件
```

### 常用内置插件

| 插件名 | 功能 |
|--------|------|
| `autosuspend.koplugin` | 自动休眠 |
| `autoturn.koplugin` | 自动翻页 |
| `backgroundrunner.koplugin` | 后台任务 |
| `batterystat.koplugin` | 电池统计 |
| `bookshortcuts.koplugin` | 书籍快捷方式 |
| `calibre.koplugin` | Calibre 集成 |
| `coverbrowser.koplugin` | 封面浏览 |
| `coverimage.koplugin` | 封面图片 |
| `exporter.koplugin` | 标注导出 |
| `gestures.koplugin` | 手势管理 |
| `kosync.koplugin` | 阅读进度同步 |
| `movetoarchive.koplugin` | 归档移动 |
| `newsdownloader.koplugin` | 新闻下载 |
| `opds.koplugin` | OPDS 目录 |
| `patchmanagement.koplugin` | 补丁管理 |
| `profiles.koplugin` | 配置文件 |
| `qrclipboard.koplugin` | 剪贴板二维码 |
| `readtimer.koplugin` | 阅读计时器 |
| `send2ebook.koplugin` | 发送到设备 |
| `statistics.koplugin` | 阅读统计 |
| `systemstat.koplugin` | 系统状态 |
| `texteditor.koplugin` | 文本编辑器 |
| `vocabbuilder.koplugin` | 生词本 |
| `wallabag.koplugin` | Wallabag 集成 |
| `zsync.koplugin` | Zsync 同步 |

---

## Base 模块

`base/` 目录包含 C/C++ 底层库和 FFI 绑定。

### 主要组件

| 目录/文件 | 说明 |
|-----------|------|
| `ffi/` | FFI 绑定（blitbuffer, mupdf, crengine 等） |
| `thirdparty/` | 第三方库源码 |
| `build/` | 构建输出 |

### FFI 绑定

| 文件 | 绑定库 |
|------|--------|
| `blitbuffer.lua` | 位图缓冲区操作 |
| `drawcontext.lua` | 绘制上下文 |
| `mupdf.lua` | MuPDF 引擎 |
| `crengine.lua` | CREngine 引擎 |
| `koptcontext.lua` | KOPT 上下文 |
| `jpeg.lua` | JPEG 处理 |
| `png.lua` | PNG 处理 |
| `lodepng.lua` | LodePNG |
| `freetype.lua` | FreeType 字体 |
| `harfbuzz.lua` | HarfBuzz 排版 |
| `utf8proc.lua` | UTF-8 处理 |
| `lfs.lua` | LuaFileSystem |
| `sqlite3.lua` | SQLite |
| `zmq.lua` | ZeroMQ |
| `zsync.lua` | Zsync |

---

## Platform 模块

`platform/` 目录包含平台特定的代码和工具。

### 子目录

| 目录 | 内容 |
|------|------|
| `android/` | Android 特定代码 |
| `appimage/` | AppImage 打包 |
| `cervantes/` | Cervantes 特定代码 |
| `debian/` | Debian 打包 |
| `darwin/` | macOS 特定代码 |
| `dmg/` | DMG 打包 |
| `fonts/` | 字体文件 |
| `remarkable/` | reMarkable 特定代码 |

---

## 模块依赖关系

### 阅读器启动流程

```
reader.lua
    └─▶ UIManager:init()
        └─▶ Device:init()
        └─▶ ReaderUI:new{document = Document}
            └─▶ registerModule() 各阅读器模块
                ├─▶ ReaderView
                ├─▶ ReaderRolling/ReaderPaging
                ├─▶ ReaderToc
                ├─▶ ReaderBookmark
                └─▶ ... 其他模块
```

### 文档打开流程

```
FileManager/ReaderUI
    └─▶ DocumentRegistry:openDocument(file)
        └─▶ 根据扩展名选择 Document 子类
            ├─▶ CreDocument (EPUB/FB2/HTML)
            ├─▶ PdfDocument (PDF)
            ├─▶ DjvuDocument (DJVU)
            └─▶ PicDocument (图片)
```

### 渲染流程

```
UIManager:run() 事件循环
    └─▶ ReaderView:paintTo()
        └─▶ document:drawPage()
            ├─▶ 检查 DocCache
            └─▶ 未命中则调用 renderPage()
                └─▶ _document:openPage():draw()
```

---

## 参考文档

- [项目架构](project-architecture.md) - 整体架构说明
- [数据流与交互](dataflow.md) - 事件和数据流
- [核心类说明](core-classes.md) - 核心类详解
- [开发指南](development-guide.md) - 开发环境设置
- [代码风格](code-style.md) - 编码规范
