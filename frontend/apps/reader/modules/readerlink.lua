--[[--
ReaderLink is an abstraction for document-specific link interfaces.
]]

local BD = require("ui/bidi")
local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local Device = require("device")
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local LinkBox = require("ui/widget/linkbox")
local Notification = require("ui/widget/notification")
local QRMessage = require("ui/widget/qrmessage")
local UIManager = require("ui/uimanager")
local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local util = require("util")
local _ = require("gettext")
local Screen = Device.screen
local T = ffiUtil.template

local function is_wiki_page(link_url)
    if not link_url then
        return false
    end
    local wiki_lang, wiki_page = link_url:match([[https?://([^%.]+).wikipedia.org/wiki/([^/]+)]])
    if wiki_lang and wiki_page then
        -- Ask for user confirmation before launching lookup (on a
        -- wikipedia page saved as epub, full of wikipedia links, it's
        -- too easy to click on links when wanting to change page...)
        -- But first check if this wikipedia article has been saved as EPUB
        local epub_filename = wiki_page .. "."..string.upper(wiki_lang)..".epub"
        local epub_fullpath
        -- either in current book directory
        local last_file = G_reader_settings:readSetting("lastfile")
        if last_file then
            local current_book_dir = last_file:match("(.*)/")
            local safe_filename = util.getSafeFilename(epub_filename, current_book_dir):gsub("_", " ")
            local epub_path = current_book_dir .. "/" .. safe_filename
            if util.pathExists(epub_path) then
                epub_fullpath = epub_path
            end
        end
        -- or in wikipedia save directory
        if not epub_fullpath then
            local dir = G_reader_settings:readSetting("wikipedia_save_dir")
            if not dir then dir = G_reader_settings:readSetting("home_dir") end
            if not dir then dir = require("apps/filemanager/filemanagerutil").getDefaultDir() end
            if dir then
                local safe_filename = util.getSafeFilename(epub_filename, dir):gsub("_", " ")
                local epub_path = dir .. "/" .. safe_filename
                if util.pathExists(epub_path) then
                    epub_fullpath = epub_path
                end
            end
        end
        return wiki_lang, wiki_page, epub_fullpath
    else
        return false
    end
end

local ReaderLink = InputContainer:extend{
    location_stack = nil, -- table, per-instance
    forward_location_stack = nil, -- table, per-instance
    _external_link_buttons = nil,
    supported_external_schemes = nil,
    _footnote_cache = nil, -- table, per-instance, LRU cache for footnote detection + HTML
    _footnote_cache_order = nil, -- table, per-instance, tracks insertion order for eviction
}

function ReaderLink:init()
    self:registerKeyEvents()
    if Device:isTouchDevice() then
        self.ui:registerTouchZones({
            {
                id = "tap_link",
                ges = "tap",
                screen_zone = {
                    ratio_x = 0, ratio_y = 0,
                    ratio_w = 1, ratio_h = 1,
                },
                overrides = {
                    -- Tap on links have priority over everything (it can
                    -- be disabled with "Tap to follow links" menu item)
                    "readerhighlight_tap",
                    "tap_top_left_corner",
                    "tap_top_right_corner",
                    "tap_left_bottom_corner",
                    "tap_right_bottom_corner",
                    "readerfooter_tap",
                    "readerconfigmenu_ext_tap",
                    "readerconfigmenu_tap",
                    "readermenu_ext_tap",
                    "readermenu_tap",
                    "tap_forward",
                    "tap_backward",
                },
                handler = function(ges) return self:onTap(_, ges) end,
            },
            {
                id = "swipe_link",
                ges = "swipe",
                screen_zone = {
                    ratio_x = 0, ratio_y = 0,
                    ratio_w = 1, ratio_h = 1,
                },
                overrides = {
                    "paging_swipe",
                    "rolling_swipe"
                },
                handler = function(ges) return self:onSwipe(_, ges) end,
            },
        })
    end
    self.ui:registerPostInitCallback(function()
        self.ui.menu:registerToMainMenu(self)
    end)
    if G_reader_settings:isTrue("opening_page_location_stack") then
        -- Add location at book opening to stack
        self.ui:registerPostReaderReadyCallback(function()
            self:addCurrentLocationToStack()
        end)
    end
    -- Pre-warm font caches and footnote detection right after initial
    -- document setup, before ReaderReady. Keep a short delay to avoid
    -- competing with first paint on slower devices.
    self.ui:registerPostInitCallback(function()
        UIManager:scheduleIn(0.1, function()
            self:_warmFootnotePopupCaches()
        end)
    end)
    -- For relative local file links
    local directory, filename = util.splitFilePathName(self.document.file) -- luacheck: no unused
    self.document_dir = directory
    -- Migrate these old settings to the new common one
    if G_reader_settings:isTrue("tap_link_footnote_popup")
            or G_reader_settings:isTrue("swipe_link_footnote_popup") then
        G_reader_settings:saveSetting("tap_link_footnote_popup", nil)
        G_reader_settings:saveSetting("swipe_link_footnote_popup", nil)
        G_reader_settings:saveSetting("footnote_link_in_popup", true)
    end

    -- delegate gesture listener to readerui, NOP our own
    self.ges_events = nil

    -- Set always supported external link schemes
    self.supported_external_schemes = {"http", "https"}

    -- Set up buttons for alternative external link handling methods
    self._external_link_buttons = {}
    self._external_link_buttons["10_copy"] = function(this, link_url)
        return {
            text = _("Copy"),
            callback = function()
                Device.input.setClipboardText(link_url)
                UIManager:close(this.external_link_dialog)
            end,
        }
    end
    self._external_link_buttons["20_qrcode"] = function(this, link_url)
        return {
            text = _("Show QR code"),
            callback = function()
                UIManager:close(this.external_link_dialog)
                UIManager:show(QRMessage:new{
                    text = link_url,
                    width = Device.screen:getWidth(),
                    height = Device.screen:getHeight()
                })
            end
        }
    end
    self._external_link_buttons["30_browser"] = function(this, link_url)
        return {
            text = _("Open in browser"),
            callback = function()
                UIManager:close(this.external_link_dialog)
                Device:openLink(link_url)
            end,
            show_in_dialog_func = function()
                if Device:canOpenLink() then
                    return true
                end
            end
        }
    end
    self._external_link_buttons["40_wiki_lookup"] = function(this, link_url)
        return {
            text = _("Read online"),
            callback = function()
                UIManager:nextTick(function()
                    UIManager:close(this.external_link_dialog)
                    local wiki_lang, wiki_page = is_wiki_page(link_url)
                    self.ui:handleEvent(Event:new("LookupWikipedia", wiki_page, true, false, true, wiki_lang))
                end)
            end,
            show_in_dialog_func = function()
                local wiki_lang, wiki_page = is_wiki_page(link_url)
                if wiki_lang and wiki_page then
                    logger.dbg("Wikipedia link:", wiki_lang, wiki_page)
                    local text = T(_("Would you like to read this Wikipedia %1 article?\n\n%2\n"), wiki_lang:upper(), wiki_page:gsub("_", " "))
                    return true, text
                else
                    return false
                end
            end
        }
    end
    self._external_link_buttons["45_wiki_saved"] = function(this, link_url)
        return {
            text = _("Read EPUB"),
            callback = function()
                UIManager:scheduleIn(0.1, function()
                    UIManager:close(this.external_link_dialog)
                    local _, _, wiki_epub_fullpath = is_wiki_page(link_url)
                    self.ui:switchDocument(wiki_epub_fullpath)
                end)
            end,
            show_in_dialog_func = function()
                local wiki_lang, wiki_page, wiki_epub_fullpath = is_wiki_page(link_url)
                if wiki_lang and wiki_page and wiki_epub_fullpath then
                    local text = T(_("This article has previously been saved as EPUB. You may wish to read the saved EPUB instead."))
                    return true, text
                end
            end
        }
    end
    self._external_link_buttons["90_cancel"] = function(this, link_url)
        return {
            text = _("Cancel"),
            callback = function()
                UIManager:close(this.external_link_dialog)
            end,
        }
    end
end

-- Register URL scheme. The external link dialog will be brought up when a URL
-- with a registered scheme is followed; this also applies to schemeless
-- (including relative) URLs if the empty scheme ("") is registered,
-- overriding the default behaviour of treating these as filepaths.
-- Registering the "file" scheme also overrides its default handling.
-- Registered schemes are reset on each initialisation of ReaderLink.
function ReaderLink:registerScheme(scheme)
    table.insert(self.supported_external_schemes, scheme)
end

function ReaderLink:onGesture() end

function ReaderLink:registerKeyEvents()
    if Device:hasScreenKB() or Device:hasSymKey() then
        self.key_events.GotoSelectedPageLink = { { "Press" }, event = "GotoSelectedPageLink" }
        if Device:hasKeyboard() then
            self.key_events.AddCurrentLocationToStackNonTouch = { { "Shift", "Press" } }
            self.key_events.SelectNextPageLink = { { "Shift", "LPgFwd" }, event = "SelectNextPageLink" }
            self.key_events.SelectPrevPageLink = { { "Shift", "LPgBack" }, event = "SelectPrevPageLink" }
        else
            self.key_events.AddCurrentLocationToStackNonTouch = { { "ScreenKB", "Press" } }
            self.key_events.SelectNextPageLink = { { "ScreenKB", "LPgFwd" }, event = "SelectNextPageLink" }
            self.key_events.SelectPrevPageLink = { { "ScreenKB", "LPgBack" }, event = "SelectPrevPageLink" }
        end
    elseif Device:hasKeys() then
        self.key_events = {
            SelectNextPageLink = {
                { "Tab" },
                event = "SelectNextPageLink",
            },
            SelectPrevPageLink = {
                { "Shift", "Tab" },
                event = "SelectPrevPageLink",
            },
            GotoSelectedPageLink = {
                { "Press" },
                event = "GotoSelectedPageLink",
            },
            -- "Back" is handled by ReaderBack, which will call our onGoBackLink()
            -- when G_reader_settings:readSetting("back_in_reader") == "previous_location"
        }
    end
end

ReaderLink.onPhysicalKeyboardConnected = ReaderLink.registerKeyEvents

function ReaderLink:onReadSettings(config)
    -- called when loading new document
    self:onClearLocationStack()
end

local function isTapToFollowLinksOn()
    return G_reader_settings:nilOrTrue("tap_to_follow_links")
end

local function isLargerTapAreaToFollowLinksEnabled()
    return G_reader_settings:isTrue("larger_tap_area_to_follow_links")
end

local function isTapIgnoreExternalLinksEnabled()
    return G_reader_settings:isTrue("tap_ignore_external_links")
end

local function isFootnoteLinkInPopupEnabled()
    return G_reader_settings:isTrue("footnote_link_in_popup")
end

local function isTapLinkHighlightEnabled()
    return G_reader_settings:nilOrTrue("tap_link_highlight")
end

local function isPreferFootnoteEnabled()
    return G_reader_settings:isTrue("link_prefer_footnote")
end

local function computeFootnoteDetectionFlags(trust_source_xpointer)
    local flags = 0
    if isPreferFootnoteEnabled() then
        flags = flags + 0x0001
    end
    if trust_source_xpointer then
        flags = flags + 0x0002
    end
    flags = flags + 0x0004 -- trust role=/epub:type=
    flags = flags + 0x0008 -- FB2 footnotes
    flags = flags + 0x0010 -- target must have #anchor
    if not isPreferFootnoteEnabled() then
        flags = flags + 0x0020 -- target must come after source
    end
    flags = flags + 0x0040 -- target not a TOC entry
    flags = flags + 0x0100 -- source not empty / not sole content
    flags = flags + 0x0200 -- source vertical-align
    flags = flags + 0x0400 -- source is numeric
    flags = flags + 0x0800 -- source is 1-2 letters
    flags = flags + 0x1000 -- target not in H1..H6
    flags = flags + 0x4000 -- try to extend footnote
    flags = flags + 0x8000 -- extended text size limit
    return flags
end

local function isSwipeToGoBackEnabled()
    return G_reader_settings:isTrue("swipe_to_go_back")
end

local function isSwipeToFollowNearestLinkEnabled()
    return G_reader_settings:isTrue("swipe_to_follow_nearest_link")
end

local function isSwipeIgnoreExternalLinksEnabled()
    return G_reader_settings:nilOrTrue("swipe_ignore_external_links")
end

local function isSwipeToJumpToLatestBookmarkEnabled()
    return G_reader_settings:isTrue("swipe_to_jump_to_latest_bookmark")
end

function ReaderLink:getFootnoteSettingsMenuTable()
    local menu_items = {
        {
            text = _("Show footnotes in popup"),
            enabled_func = function()
                return isTapToFollowLinksOn() or isSwipeToFollowNearestLinkEnabled()
            end,
            checked_func = isFootnoteLinkInPopupEnabled,
            callback = function()
                local new_value = not isFootnoteLinkInPopupEnabled()
                G_reader_settings:saveSetting("footnote_link_in_popup", new_value)
                if new_value then
                    self:_scheduleFootnoteCacheWarmup()
                end
            end,
            help_text = _([[
Show internal link target content in a footnote popup when it looks like it might be a footnote, instead of following the link.

Note that depending on the book quality, footnote detection may not always work correctly.
The footnote content may be empty, truncated, or include other footnotes.

From the footnote popup, you can jump to the footnote location in the book by tapping the "Go to footnote" link at the bottom-left corner, or close it by swiping left, right, or down.]]),
        },
        {
            text = _("Highlight tapped links"),
            enabled_func = function()
                return isFootnoteLinkInPopupEnabled() and isTapToFollowLinksOn()
            end,
            checked_func = isTapLinkHighlightEnabled,
            callback = function()
                G_reader_settings:saveSetting("tap_link_highlight",
                    not isTapLinkHighlightEnabled())
            end,
            help_text = _([[Highlight the tapped source link while a footnote popup is shown.]]),
        },
    }

    local function subItemTable()
        local temp_menu_items = {
            {
                text = _("Show more links as footnotes"),
                enabled_func = function()
                    return isFootnoteLinkInPopupEnabled() and
                        (isTapToFollowLinksOn() or isSwipeToFollowNearestLinkEnabled())
                end,
                checked_func = isPreferFootnoteEnabled,
                callback = function()
                    G_reader_settings:saveSetting("link_prefer_footnote",
                        not isPreferFootnoteEnabled())
                    self:_footnoteCacheClear()
                    self:_scheduleFootnoteCacheWarmup()
                end,
                help_text = _([[Loosen footnote detection rules to show more links as footnotes.]]),
                separator = Device:isTouchDevice() and true or false,
            },
            {
                text = _("Use book font in popups"),
                enabled_func = function()
                    return isFootnoteLinkInPopupEnabled() and
                        (isTapToFollowLinksOn() or isSwipeToFollowNearestLinkEnabled())
                end,
                checked_func = function()
                    return G_reader_settings:isTrue("footnote_popup_use_book_font")
                end,
                callback = function()
                    G_reader_settings:flipNilOrFalse("footnote_popup_use_book_font")
                    local FootnoteWidget = require("ui/widget/footnotewidget")
                    FootnoteWidget.clearBookFontCssCache()
                    self:_scheduleFootnoteCacheWarmup()
                end,
                help_text = _([[Display the footnote popup text with the configured document font (the book text may still render with a different font if the book uses embedded fonts).]]),
            },
            {
                text = _("Footnote popup font size"),
                enabled_func = function()
                    return isFootnoteLinkInPopupEnabled() and
                        (isTapToFollowLinksOn() or isSwipeToFollowNearestLinkEnabled())
                end,
                keep_menu_open = true,
                callback = function()
                    local spin_widget
                    local get_font_size_widget
                    get_font_size_widget = function(show_absolute_font_size_widget)
                        local SpinWidget = require("ui/widget/spinwidget")
                        if show_absolute_font_size_widget then
                            spin_widget = SpinWidget:new{
                                width = math.floor(Screen:getWidth() * 0.75),
                                value = G_reader_settings:readSetting("footnote_popup_absolute_font_size")
                                                or Screen:scaleBySize(self.document.configurable.font_size),
                                value_min = 12,
                                value_max = 255,
                                precision = "%d",
                                ok_text = _("Set font size"),
                                title_text =  _("Set footnote popup font size"),
                                info_text = _([[
The footnote popup font can adjust to the font size you've set for the document, but you can specify here a fixed absolute font size to be used instead.]]),
                                callback = function(spin)
                                    G_reader_settings:delSetting("footnote_popup_relative_font_size")
                                    G_reader_settings:saveSetting("footnote_popup_absolute_font_size", spin.value)
                                end,
                                extra_text = _("Set a relative font size instead"),
                                extra_callback = function()
                                    UIManager:close(spin_widget)
                                    spin_widget = get_font_size_widget(false)
                                    UIManager:show(spin_widget)
                                end,
                            }
                        else
                            spin_widget = SpinWidget:new{
                                width = math.floor(Screen:getWidth() * 0.75),
                                value = G_reader_settings:readSetting("footnote_popup_relative_font_size") or -2,
                                value_min = -10,
                                value_max = 5,
                                precision = "%+d",
                                ok_text = _("Set font size"),
                                title_text =  _("Set footnote popup font size"),
                                info_text = _([[
The footnote popup font adjusts to the font size you've set for the document.
You can specify here how much smaller or larger it should be relative to the document font size.
A negative value will make it smaller, while a positive one will make it larger.
The recommended value is -2.]]),
                                callback = function(spin)
                                    G_reader_settings:delSetting("footnote_popup_absolute_font_size")
                                    G_reader_settings:saveSetting("footnote_popup_relative_font_size", spin.value)
                                end,
                                extra_text = _("Set an absolute font size instead"),
                                extra_callback = function()
                                    UIManager:close(spin_widget)
                                    spin_widget = get_font_size_widget(true)
                                    UIManager:show(spin_widget)
                                end,
                            }
                        end
                        return spin_widget
                    end
                    local show_absolute_font_size_widget = G_reader_settings:has("footnote_popup_absolute_font_size")
                    spin_widget = get_font_size_widget(show_absolute_font_size_widget)
                    UIManager:show(spin_widget)
                end,
                help_text = _([[
The footnote popup font adjusts to the font size you've set for the document.
This allows you to specify how much smaller or larger it should be relative to the document font size.]]),
            },
            {
                text = _("Footnote popup height"),
                enabled_func = function()
                    return isFootnoteLinkInPopupEnabled() and
                        (isTapToFollowLinksOn() or isSwipeToFollowNearestLinkEnabled())
                end,
                keep_menu_open = true,
                callback = function()
                    local SpinWidget = require("ui/widget/spinwidget")
                    local spin_widget = SpinWidget:new{
                        width = math.floor(Screen:getWidth() * 0.75),
                        value = G_reader_settings:readSetting("footnote_popup_height_percent") or 33,
                        value_min = 20,
                        value_max = 80,
                        precision = "%d%%",
                        ok_text = _("Set height"),
                        title_text = _("Set footnote popup height"),
                        info_text = _([[
The footnote popup height is specified as a percentage of screen height.
The default is 33% (one third of the screen).]]),
                        callback = function(spin)
                            G_reader_settings:saveSetting("footnote_popup_height_percent", spin.value)
                        end,
                    }
                    UIManager:show(spin_widget)
                end,
                help_text = _([[
The footnote popup height is specified as a percentage of screen height.
You can adjust it to show more or less content at once.]]),
            },
        }
        return temp_menu_items
    end

    if not Device:isTouchDevice() then
        -- on NT devices, add all settings directly to the parent menu_items, to avoid unnecessary sub_menus
        local items = subItemTable()
        for _, item in ipairs(items) do
            table.insert(menu_items, item)
        end
    else
        table.insert(menu_items, {
            text = _("Footnote popup settings"),
            enabled_func = function()
                return isFootnoteLinkInPopupEnabled() and
                    (isTapToFollowLinksOn() or isSwipeToFollowNearestLinkEnabled())
            end,
            separator = true,
            sub_item_table = subItemTable(),
        })
    end
    return menu_items
end

function ReaderLink:addToMainMenu(menu_items)
    -- insert table to main reader menu
    menu_items.go_to_previous_location = {
        text = _("Go back to previous location"),
        enabled_func = function() return self.location_stack and #self.location_stack > 0 end,
        callback = function() self:onGoBackLink() end,
        hold_callback = function(touchmenu_instance)
            UIManager:show(ConfirmBox:new{
                text = _("Clear location history?"),
                ok_text = _("Clear"),
                ok_callback = function()
                    self:onClearLocationStack()
                    touchmenu_instance:closeMenu()
                end,
            })
        end,
    }
    menu_items.go_to_next_location = {
        text = _("Go forward to next location"),
        enabled_func = function() return self.forward_location_stack and #self.forward_location_stack > 0 end,
        callback = function() self:onGoForwardLink() end,
        hold_callback = function(touchmenu_instance)
            UIManager:show(ConfirmBox:new{
                text = _("Clear forward location history?"),
                ok_text = _("Clear"),
                ok_callback = function()
                    self:onClearForwardLocationStack()
                    touchmenu_instance:closeMenu()
                end,
            })
        end,
    }
    if not Device:isTouchDevice() then
        if self.ui.rolling then
            -- Add footnote settings to the selection_text menu (readerhighlight)
            local footnote_items = self:getFootnoteSettingsMenuTable()
            menu_items.typesetfootnotes = {
                text = _("Footnotes and links"),
                sorting_hint = "selection_text",
                sub_item_table = footnote_items,
            }
        end
        return
    end
    menu_items.follow_links = {
        text = _("Links"),
        sub_item_table = {
            {
                text = _("Tap to follow links"),
                checked_func = isTapToFollowLinksOn,
                callback = function()
                    G_reader_settings:saveSetting("tap_to_follow_links",
                        not isTapToFollowLinksOn())
                end,
                help_text = _([[Tap on links to follow them.]]),
            },
            {
                text = _("Ignore external links on tap"),
                enabled_func = isTapToFollowLinksOn,
                checked_func = isTapIgnoreExternalLinksEnabled,
                callback = function()
                    G_reader_settings:saveSetting("tap_ignore_external_links",
                        not isTapIgnoreExternalLinksEnabled())
                end,
                help_text = _([[
Ignore taps on external links. Useful with Wikipedia EPUBs to make page turning easier.
You can still follow them from the dictionary window or the selection menu after holding on them.]]),
                separator = true,
            },
            {
                text = _("Swipe to go back"),
                checked_func = isSwipeToGoBackEnabled,
                callback = function()
                    G_reader_settings:saveSetting("swipe_to_go_back",
                        not isSwipeToGoBackEnabled())
                end,
                help_text = _([[Swipe to the right to go back to the previous location after you have followed a link. When the location stack is empty, swiping to the right takes you to the previous page.]]),
            },
            {
                text = _("Swipe to follow nearest link"),
                checked_func = isSwipeToFollowNearestLinkEnabled,
                callback = function()
                    G_reader_settings:saveSetting("swipe_to_follow_nearest_link",
                        not isSwipeToFollowNearestLinkEnabled())
                end,
                help_text = _([[Swipe to the left to follow the link nearest to where you started the swipe. This is useful when a small font is used and tapping on small links is tedious.]]),
            },
            {
                text = _("Ignore external links on swipe"),
                enabled_func = isSwipeToFollowNearestLinkEnabled,
                checked_func = isSwipeIgnoreExternalLinksEnabled,
                callback = function()
                    G_reader_settings:saveSetting("swipe_ignore_external_links",
                        not isSwipeIgnoreExternalLinksEnabled())
                end,
                help_text = _([[
Ignore external links near swipe. Useful with Wikipedia EPUBs to follow only footnotes with swipe.
You can still follow external links from the dictionary window or the selection menu after holding on them.]]),
                separator = true,
            },
            {
                text = _("Swipe to jump to latest bookmark"),
                checked_func = isSwipeToJumpToLatestBookmarkEnabled,
                callback = function()
                    G_reader_settings:saveSetting("swipe_to_jump_to_latest_bookmark",
                        not isSwipeToJumpToLatestBookmarkEnabled())
                end,
                help_text = _([[
Swipe to the left to go the most recently bookmarked page.
This can be useful to quickly swipe back and forth between what you are reading and some reference page (for example notes, a map or a characters list).
If any of the other Swipe to follow link options is enabled, this will work only when the current page contains no link.]]),
            },
        }
    }
    -- Insert other items that are (for now) only supported with CreDocuments
    -- (They could be supported nearly as-is, but given that there is a lot
    -- less visual feedback on PDF document of what is a link, or that we just
    -- followed a link, than on EPUB, it's safer to not use them on PDF documents
    -- even if the user enabled these features for EPUB documents).
    if self.ui.rolling then
        -- Tap section
        table.insert(menu_items.follow_links.sub_item_table, 2, {
            text = _("Allow larger tap area around links"),
            enabled_func = isTapToFollowLinksOn,
            checked_func = isLargerTapAreaToFollowLinksEnabled,
            callback = function()
                G_reader_settings:saveSetting("larger_tap_area_to_follow_links",
                    not isLargerTapAreaToFollowLinksEnabled())
            end,
            help_text = _([[Extends the tap area around internal links. Useful with a small font where tapping on small footnote links may be tedious.]]),
        })

        -- Insert footnote settings as 4th and 5th items in the submenu
        local footnote_items = self:getFootnoteSettingsMenuTable()
        for i = 1, #footnote_items do
            table.insert(menu_items.follow_links.sub_item_table, i+3, footnote_items[i])
        end
    end
end

--- Check if a xpointer to <a> node really points to itself
function ReaderLink:isXpointerCoherent(a_xpointer)
    -- Get screen coordinates of xpointer
    local screen_y, screen_x = self.document:getScreenPositionFromXPointer(a_xpointer)
    -- Get again link and a_xpointer from this position
    local re_link_xpointer, re_a_xpointer = self.document:getLinkFromPosition({x = screen_x, y = screen_y}) -- luacheck: no unused
    -- We should get the same a_xpointer. If not, crengine has messed up
    -- and we should not trust this xpointer to get back to this link.
    if re_a_xpointer ~= a_xpointer then
        -- Try it again with screen_x+1 (in the rare cases where screen_x
        -- fails, screen_x+1 usually works - probably something in crengine,
        -- but easier to workaround here that way)
        re_link_xpointer, re_a_xpointer = self.document:getLinkFromPosition({x = screen_x+1, y = screen_y}) -- luacheck: no unused
        if re_a_xpointer ~= a_xpointer then
            logger.info("noncoherent a_xpointer:", a_xpointer)
            return false
        end
    end
    return true
end

--- Gets link from gesture.
-- `Document:getLinkFromPosition()` behaves differently depending on
-- document type, so this function provides a wrapper.
function ReaderLink:getLinkFromGes(ges)
    if self.ui.paging then
        local pos = self.view:screenToPageTransform(ges.pos)
        if pos then
            -- link box in native page
            local link, lbox = self.document:getLinkFromPosition(pos.page, pos)
            if link and lbox then
                return {
                    link = link,
                    lbox = lbox,
                    pos = pos,
                }
            end
        end
    else
        local link_xpointer, a_xpointer = self.document:getLinkFromPosition(ges.pos)
        logger.dbg("ReaderLink:getLinkFromPosition @", ges.pos.x, ges.pos.y, "from a_xpointer:", a_xpointer, "to link_xpointer:", link_xpointer)

        -- On some documents, crengine may sometimes give a wrong a_xpointer
        -- (in some Wikipedia saved as EPUB, it would point to some other <A>
        -- element in the same paragraph). If followed then back, we could get
        -- to a different page. Defer the coherence check to when it's actually
        -- needed for back-navigation, so footnote popup path can skip it.
        local from_xpointer = a_xpointer

        if link_xpointer and link_xpointer ~= "" then
            -- This link's source xpointer is more precise than a classic
            -- xpointer to top of a page: we can show a marker at its
            -- y-position in target page
            -- (keep a_xpointer even if noncoherent, might be needed for
            -- footnote detection (better than nothing if noncoherent)
            return {
                xpointer = link_xpointer,
                marker_xpointer = link_xpointer,
                from_xpointer = from_xpointer,
                from_xpointer_unchecked = from_xpointer ~= nil,
                a_xpointer = a_xpointer,
                -- tap y-position should be a good approximation of link y
                -- (needed to keep its highlight a bit more time if it was
                -- hidden by the footnote popup)
                link_y = ges.pos.y
            }
        end
    end
end

--- Highlights a linkbox if available and goes to it.
function ReaderLink:showLinkBox(link, allow_footnote_popup)
    if link and link.lbox then -- pdfdocument
        -- screen box that holds the link
        local sbox = self.view:pageToScreenTransform(link.pos.page,
            self.document:nativeToPageRectTransform(link.pos.page, link.lbox))
        if sbox then
            UIManager:show(LinkBox:new{
                box = sbox,
                timeout = G_defaults:readSetting("FOLLOW_LINK_TIMEOUT"),
                callback = function()
                    self:onGotoLink(link.link, false, allow_footnote_popup)
                end
            })
            return true
        end
    elseif link and link.xpointer ~= "" then -- credocument
        return self:onGotoLink(link, false, allow_footnote_popup)
    end
end

function ReaderLink:onTap(_, ges)
    if not isTapToFollowLinksOn() then return end
    if self.ui.paging then
        -- (footnote popup and larger tap area are not supported with non-CreDocuments)
        local link = self:getLinkFromGes(ges)
        if link then
            if link.link and link.link.uri and isTapIgnoreExternalLinksEnabled() then
                return
            end
            return self:showLinkBox(link)
        end
        return
    end
    -- For CreDocuments only from now on
    local allow_footnote_popup = isFootnoteLinkInPopupEnabled()
    -- If tap_ignore_external_links, skip precise tap detection to really
    -- ignore a tap on an external link, and allow using onGoToPageLink()
    -- to find the nearest internal link
    if not isTapIgnoreExternalLinksEnabled() then
        local link = self:getLinkFromGes(ges)
        if link then
            return self:showLinkBox(link, allow_footnote_popup)
        end
    end
    if isLargerTapAreaToFollowLinksEnabled() or isTapIgnoreExternalLinksEnabled() then
        local max_distance = 0 -- used when only isTapIgnoreExternalLinksEnabled()
        if isLargerTapAreaToFollowLinksEnabled() then
            -- If no link found exactly at the tap position,
            -- try to find any link in page around that tap position.
            -- With "Ignore external links", onGoToPageLink() will grab
            -- only internal links, which is nice as url links are usually
            -- longer - so this give more chance to catch a small link to
            -- footnote stuck to a longer Wikipedia article name link.
            --
            -- 30px on a reference 167 dpi screen makes 0.45cm, which
            -- seems fine (on a 300dpi device, this will be scaled
            -- to 54px (which makes 1/20th of screen width on a GloHD)
            -- Trust Screen.dpi (which may not be the real device
            -- screen DPI if the user has set another one).
            max_distance = Screen:scaleByDPI(30)
        end
        return self:onGoToPageLink(ges, isTapIgnoreExternalLinksEnabled(), max_distance)
    end
end

function ReaderLink:onToggleTapLinks()
    G_reader_settings:flipNilOrTrue("tap_to_follow_links")
    local tap_links_status = isTapToFollowLinksOn() and _("on") or _("off")
    UIManager:show(Notification:new{
        text = T(_("Tap to follow links: %1"), tap_links_status),
    })
    return true
end

function ReaderLink:getCurrentLocation()
    return self.ui.paging and self.ui.paging:getBookLocation()
                           or {xpointer = self.ui.rolling:getBookLocation()}
end

-- Returns true, current_location if the current location is the same as the
-- saved_location on the top of the stack.
-- Otherwise returns false, current_location
function ReaderLink:compareLocationToCurrent(saved_location)
    local current_location = self:getCurrentLocation()
    if self.ui.rolling and saved_location.xpointer and saved_location.xpointer == current_location.xpointer then
        return true, current_location
    end
    if self.ui.paging and saved_location[1] and current_location[1] and current_location[1].page == saved_location[1].page then
        return true, current_location
    end
    return false, current_location
end

function ReaderLink:onAddCurrentLocationToStack(show_notification)
    self:addCurrentLocationToStack()
    if show_notification then
        Notification:notify(_("Current location added to history."))
    end
    return true
end

function ReaderLink:onAddCurrentLocationToStackNonTouch()
    self:addCurrentLocationToStack()
    Notification:notify(_("Current location added to history."), Notification.SOURCE_ALWAYS_SHOW)
    return true
end

-- Remember current location so we can go back to it
function ReaderLink:addCurrentLocationToStack(loc)
    local location = loc and loc or self:getCurrentLocation()
    self:onClearForwardLocationStack()
    table.insert(self.location_stack, location)
end

function ReaderLink:popFromLocationStack()
    return table.remove(self.location_stack)
end

function ReaderLink:onClearLocationStack(show_notification)
    self.location_stack = {}
    self:onClearForwardLocationStack()
    if show_notification then
        UIManager:show(Notification:new{
            text = _("Location history cleared."),
        })
    end
    return true
end

function ReaderLink:onClearForwardLocationStack()
    self.forward_location_stack = {}
    return true
end

function ReaderLink:getLocationPages(forward_location)
    local location_stack = forward_location and self.forward_location_stack or self.location_stack
    local location_pages = {}
    if #location_stack > 0 then
        if self.ui.rolling then
            for i, location in ipairs(location_stack) do
                if location.xpointer then
                    location_pages[self.document:getPageFromXPointer(location.xpointer)] = i
                end
            end
        else
            for i, location in ipairs(location_stack) do
                if location[1] and location[1].page then
                    location_pages[location[1].page] = i
                end
            end
        end
    end
    return location_pages
end

--- Goes to link.
-- (This is called by other modules (highlight, search) to jump to a xpointer,
-- they should not provide allow_footnote_popup=true)
function ReaderLink:onGotoLink(link, neglect_current_location, allow_footnote_popup)
    local link_url
    if self.ui.paging then
        -- internal pdf links have a "page" attribute, while external ones have an "uri" attribute
        if link.page then -- Internal link
            logger.dbg("ReaderLink:onGotoLink: Internal link:", link)
            if not neglect_current_location then
                self:addCurrentLocationToStack()
            end
            local page = self.ui.paging.current_page
            self.ui:handleEvent(Event:new("GotoPage", link.page + 1, link.pos))
            Notification:notify(T(_("Link from page %1"), page), Notification.SOURCE_OTHER)
            return true
        end
        link_url = link.uri -- external link
    else
        -- For crengine, internal links may look like :
        --   #_doc_fragment_0_Organisation (link from anchor)
        --   /body/DocFragment/body/ul[2]/li[5]/text()[3].16 (xpointer from full-text search)
        -- If the XPointer does not exist (or is a full url), we will jump to page 1
        -- Best to check that this link exists in document with the following,
        -- which accepts both of the above legitimate xpointer as input.
        if link.xpointer and self.document:isXPointerInDocument(link.xpointer) then
            logger.dbg("ReaderLink:onGotoLink: Internal link:", link)
            if allow_footnote_popup then
                if self:showAsFootnotePopup(link, neglect_current_location) then
                    return true
                end
                -- if it fails for any reason, fallback to following link
            end
            if not neglect_current_location then
                -- Deferred coherence check: validate from_xpointer before
                -- using it for back-navigation (skipped earlier for perf)
                if link.from_xpointer and link.from_xpointer_unchecked then
                    if not self:isXpointerCoherent(link.from_xpointer) then
                        link.from_xpointer = nil
                    end
                    link.from_xpointer_unchecked = nil
                end
                if link.from_xpointer then
                    -- We have a more precise xpointer than the xpointer to top of
                    -- current page that addCurrentLocationToStack() would give, and
                    -- we may be able to show a marker when back
                    local saved_location
                    if self.view.view_mode == "scroll" then
                        -- In scroll mode, we still use the top of page as the
                        -- xpointer to go back to, so we get back to the same view.
                        -- We can still show the marker at the link position
                        saved_location = {
                            xpointer = self.ui.rolling:getBookLocation(),
                            marker_xpointer = link.from_xpointer,
                        }
                    else
                        -- In page mode, we use the same for go to and for marker,
                        -- as 'page mode' ensures we get back to the same view.
                        saved_location = {
                            xpointer = link.from_xpointer,
                            marker_xpointer = link.from_xpointer,
                        }
                    end
                    self:addCurrentLocationToStack(saved_location)
                else
                    self:addCurrentLocationToStack()
                end
            end
            self.ui:handleEvent(Event:new("GotoXPointer", link.xpointer, link.marker_xpointer))
            return true
        end
        link_url = link.xpointer -- external link
    end
    logger.dbg("ReaderLink:onGotoLink: External link:", link_url)

    local scheme = link_url:match("^(%w[%w+%-.]*):") or ""
    local is_supported_external_link = util.arrayContains(self.supported_external_schemes, scheme:lower())
    if is_supported_external_link and self:onGoToExternalLink(link_url) then
        return true
    end

    -- Check if it is a link to a local file
    if self:openFileFromLink(link_url) then
        return true
    end

    -- Not supported
    UIManager:show(InfoMessage:new{
        text = T(_("Invalid or external link:\n%1"), BD.url(link_url)),
        -- no timeout to allow user to type that link in his web browser
    })
    -- don't propagate, user will notice and tap elsewhere if he wants to change page
    return true
end

function ReaderLink:openFileFromLink(link_url)
    local linked_filename, anchor, after_open_callback
    if link_url:find("?") then -- remove any query string (including any following anchor)
        linked_filename, anchor = link_url:match("^(.-)(%?.*)$")
        if anchor then
            -- If anchor contains position (page number or xpointer),
            -- go to the position after opening the document
            local pn_xp, count = anchor:gsub("^?pos=", "")
            if count > 0 then
                after_open_callback = function(ui)
                    ui.link:addCurrentLocationToStack()
                    if ui.rolling then
                        ui.rolling:onGotoXPointer(pn_xp, pn_xp)
                    else
                        pn_xp = tonumber(pn_xp)
                        if pn_xp then
                            ui.paging:onGotoPage(pn_xp)
                        end
                    end
                end
            end
        end
    elseif link_url:find("#") then -- remove any anchor
        linked_filename, anchor = link_url:match("^(.-)(#.*)$")
    else
        linked_filename = link_url
    end
    linked_filename = linked_filename:gsub("^file:", "") -- remove local file protocol if any
    local __, slash_nb = linked_filename:find("^/*") -- 0...3 leading slashes
    linked_filename = linked_filename:gsub("^//", "") -- keep 1 slash for absolute path
    if slash_nb == 0 or slash_nb == 2 then -- relative path
        linked_filename = ffiUtil.joinPath(self.document_dir, linked_filename)
    end
    linked_filename = ffiUtil.realpath(linked_filename) -- clean full path from ./ or ../
    if linked_filename and lfs.attributes(linked_filename, "mode") == "file" then
        local display_filename = linked_filename
        if anchor and after_open_callback == nil then
            -- Display filename with anchor or query string, so the user gets
            -- this information and can manually go to the appropriate place
            display_filename = display_filename .. anchor
        end
        UIManager:show(ConfirmBox:new{
            text = T(_("Would you like to read this local document?\n\n%1\n"), BD.filepath(display_filename)),
            ok_callback = function()
                UIManager:scheduleIn(0.1, function()
                    self.ui:switchDocument(linked_filename, nil, after_open_callback)
                end)
            end,
        })
        return true
    end
end

function ReaderLink:onGoToExternalLink(link_url)
    local buttons, title = self:getButtonsForExternalLinkDialog(link_url)
    self.external_link_dialog = ButtonDialog:new{
        title = title,
        buttons = buttons,
    }
    UIManager:show(self.external_link_dialog)
    return true
end

--- Goes back to previous location.
function ReaderLink:onGoBackLink(show_notification_if_empty)
    local saved_location = table.remove(self.location_stack)
    if saved_location then
        local same_page, current_location = self:compareLocationToCurrent(saved_location)
        -- If there are no forward items
        if #self.forward_location_stack == 0 then
            -- If we are not on the same page as the current item,
            -- then add our current location to the forward stack
            if not same_page then
                table.insert(self.forward_location_stack, current_location)
            end
        end
        if same_page then
            -- If we are on the same page pass through to the next location
            table.insert(self.forward_location_stack, saved_location)
            saved_location = table.remove(self.location_stack)
        end
    end

    if saved_location then
        table.insert(self.forward_location_stack, saved_location)
        logger.dbg("GoBack: restoring:", saved_location)
        self.ui:handleEvent(Event:new('RestoreBookLocation', saved_location))
        return true
    elseif show_notification_if_empty then
        UIManager:show(Notification:new{
            text = _("Location history is empty."),
        })
    end
end

--- Goes to next location.
function ReaderLink:onGoForwardLink()
    local saved_location = table.remove(self.forward_location_stack)
    if saved_location then
        local same_page = self:compareLocationToCurrent(saved_location)
        if same_page then
            -- If we are on the same page pass through to the next location
            table.insert(self.location_stack, saved_location)
            saved_location = table.remove(self.forward_location_stack)
        end
    end

    if saved_location then
        table.insert(self.location_stack, saved_location)
        logger.dbg("GoForward: restoring:", saved_location)
        self.ui:handleEvent(Event:new('RestoreBookLocation', saved_location))
        return true
    end
end

function ReaderLink:onSwipe(arg, ges)
    local direction = BD.flipDirectionIfMirroredUILayout(ges.direction)
    if direction == "east" then
        if isSwipeToGoBackEnabled() then
            if #self.location_stack > 0 then
                -- Remember if location stack is going to be empty, so we
                -- can stop the propagation of next swipe back: so the user
                -- knows it is empty and that next swipe back will get him
                -- to previous page (and not to previous location)
                self.swipe_back_resist = #self.location_stack == 1
                return self:onGoBackLink()
            elseif self.swipe_back_resist then
                self.swipe_back_resist = false
                -- Make that gesture don't do anything, and show a Notification
                -- so the user knows why
                UIManager:show(Notification:new{
                    text = _("Location history is empty."),
                })
                return true
            end
        end
    elseif direction == "west" then
        local ret = false
        if isSwipeToFollowNearestLinkEnabled() then
            ret = self:onGoToPageLink(ges, isSwipeIgnoreExternalLinksEnabled())
        end
        -- If no link found, or no follow link option enabled,
        -- jump to latest bookmark (if enabled)
        if not ret and isSwipeToJumpToLatestBookmarkEnabled() then
            ret = self:onGoToLatestBookmark(ges)
        end
        return ret
    end
end

--- Goes to link nearest to the gesture (or first link in page)
function ReaderLink:onGoToPageLink(ges, internal_links_only, max_distance)
    local selected_link, selected_distance2
    -- We use squared distances throughout the computations,
    -- no need to math.sqrt() anything for comparisons.
    if self.ui.paging then
        local pos = self.view:screenToPageTransform(ges.pos)
        if not pos then
            return
        end
        local links = self.document:getPageLinks(pos.page)
        if not links or #links == 0 then
            return
        end
        -- DEBUG("PDF Page links : ", links)
        -- We may get multiple links: internal ones (with "page" key)
        -- that we're interested in, but also external links (no "page", but
        -- a "uri" key) that we don't care about.
        --     [2] = {
        --         ["y1"] = 107.88977050781,
        --         ["x1"] = 176.60360717773,
        --         ["y0"] = 97.944396972656,
        --         ["x0"] = 97,
        --         ["page"] = 347
        --     },
        local pos_x, pos_y = pos.x, pos.y
        local shortest_dist
        for _, link in ipairs(links) do
            if not internal_links_only or link.page then
                local start_dist = (link.x0 - pos_x)^2 + (link.y0 - pos_y)^2
                local end_dist = (link.x1 - pos_x)^2 + (link.y1 - pos_y)^2
                local min_dist = math.min(start_dist, end_dist)
                if shortest_dist == nil or min_dist < shortest_dist then
                    -- onGotoLink()'s GotoPage event needs the link
                    -- itself, and will use its "page" value
                    selected_link = link
                    shortest_dist = min_dist
                end
            end
        end
        if shortest_dist then
            selected_distance2 = shortest_dist
            if max_distance and selected_distance2 > max_distance^2 then
                selected_link = nil
            end
        end
    else
        -- Getting segments on a page with many internal links is a bit expensive.
        -- With larger_tap_area_to_follow_links, this is done on every tap, page turn or not.
        -- getPageLinks goes through the CRe call cache, so at least repeat calls are cheaper.
        -- If we only care about internal links, we only request those.
        -- That expensive segments work is always skipped on external links.
        local links = self.document:getPageLinks(internal_links_only)
        if not links or #links == 0 then
            return
        end
        -- DEBUG("CRE Page links : ", links)
        -- We may get multiple links: internal ones (they have a "section" key)
        -- that we're interested in, but also external links (no "section", but
        -- a "uri" key) that we don't care about.
        --     [1] = {
        --         ["end_x"] = 825,
        --         ["uri"] = "",
        --         ["end_y"] = 333511,
        --         ["start_x"] = 90,
        --         ["start_y"] = 333511
        --     },
        --     [2] = {
        --         ["end_x"] = 366,
        --         ["section"] = "#_doc_fragment_19_ftn_fn6",
        --         ["end_y"] = 1201,
        --         ["start_x"] = 352,
        --         ["start_y"] = 1201
        --         ["a_xpointer"] = "/body/DocFragment/body/div/p[12]/sup[3]/a[3].0",
        --     },
        -- and when segments requested (example for a multi-lines link):
        --     [3] = {
        --         ["section"] = "#_doc_fragment_0_ Man_of_letters",
        --         ["a_xpointer"] = "/body/DocFragment/body/div/div[4]/ul/li[3]/ul/li[2]/ul/li[1]/ul/li[3]/a.0",
        --         ["start_x"] = 101,
        --         ["start_y"] = 457,
        --         ["end_x"] = 176,
        --         ["end_y"] = 482,,
        --         ["segments"] = {
        --             [1] = {
        --                  ["x0"] = 101,
        --                  ["y0"] = 457,
        --                  ["x1"] = 590,
        --                  ["y1"] = 482,
        --             },
        --             [2] = {
        --                  ["x0"] = 101,
        --                  ["y0"] = 482,
        --                  ["x1"] = 177,
        --                  ["y1"] = 507,
        --             }
        --         },
        --     },
        -- Note: with some documents and some links, crengine may give wrong
        -- coordinates, and our code below may miss or give the wrong first
        -- or nearest link...
        local pos_x, pos_y = ges.pos.x, ges.pos.y
        local shortest_dist
        for _, link in ipairs(links) do
            -- link.uri may be an empty string with some invalid links: ignore them
            if link.section or (link.uri and link.uri ~= "") then
                -- Note: we may get segments empty in some conditions (in which
                -- case we'll fallback to the 'else' branch and using x/y)
                if link.segments and #link.segments > 0 then
                    -- With segments, each is a horizontal segment, with start_x < end_x,
                    -- and we should compute the distance from gesture position to
                    -- each segment.
                    local segments_max_y = -1
                    local link_is_shortest = false
                    local segments = link.segments
                    for i=1, #segments do
                        local segment = segments[i]
                        local segment_dist
                        -- Distance here is kept squared (d^2 = diff_x^2 + diff_y^2),
                        -- and we compute each part individually
                        -- First, vertical distance (squared)
                        if pos_y < segment.y0 then -- above the segment height
                            segment_dist = (segment.y0 - pos_y)^2
                        elseif pos_y > segment.y1 then -- below the segment height
                            segment_dist = (pos_y - segment.y1)^2
                        else -- gesture pos is on the segment height, no vertical distance
                            segment_dist = 0
                        end
                        -- Next, horizontal distance (squared)
                        if pos_x < segment.x0 then -- on the left of segment: calc dist to x0
                            segment_dist = segment_dist + (segment.x0 - pos_x)^2
                        elseif pos_x > segment.x1 then -- on the right of segment : calc dist to x1
                            segment_dist = segment_dist + (pos_x - segment.x1)^2
                        -- else -- gesture pos is in the segment width, no horizontal distance
                        end
                        if shortest_dist == nil or segment_dist < shortest_dist then
                            selected_link = link
                            shortest_dist = segment_dist
                            link_is_shortest = true
                        end
                        if segment.y1 > segments_max_y then
                            segments_max_y = segment.y1
                        end
                    end
                    if link_is_shortest then
                        -- update the selected_link we just set with its lower segment y
                        selected_link.link_y = segments_max_y
                    end
                else
                    -- Before "segments" were available, we did this:
                    -- We'd only get a horizontal segment if the link is on a single line.
                    -- When it is multi-lines, we can't do much calculation...
                    -- We used to just check distance from start_x and end_x, and
                    -- we could miss a tap in the middle of a long link.
                    -- (also start_y = end_y = the top of the rect for a link on a single line)
                    local start_dist = (link.start_x - pos_x)^2 + (link.start_y - pos_y)^2
                    local end_dist = (link.end_x - pos_x)^2 + (link.end_y - pos_y)^2
                    local min_dist = math.min(start_dist, end_dist)
                    if shortest_dist == nil or min_dist < shortest_dist then
                        selected_link = link
                        selected_link.link_y = link.end_y
                        shortest_dist = min_dist
                    end
                end
            end
        end
        if shortest_dist then
            selected_distance2 = shortest_dist
            if max_distance and selected_distance2 > max_distance^2 then
                logger.dbg("nearest link is further than max distance, ignoring it")
                selected_link = nil
            else
                logger.dbg("nearest selected_link", selected_link)
                -- Check if a_xpointer is coherent, use it as from_xpointer only if it is
                local from_xpointer = nil
                if selected_link.a_xpointer and self:isXpointerCoherent(selected_link.a_xpointer) then
                    from_xpointer = selected_link.a_xpointer
                end
                -- Make it a link as expected by onGotoLink
                selected_link = {
                    xpointer = selected_link.section or selected_link.uri,
                    marker_xpointer = selected_link.section,
                    from_xpointer = from_xpointer,
                    -- (keep a_xpointer even if noncoherent, might be needed for
                    -- footnote detection (better than nothing if noncoherent)
                    a_xpointer = selected_link.a_xpointer,
                    -- keep the link y position, so we can keep its highlight shown
                    -- a bit more time if it was hidden by the footnote popup
                    link_y = selected_link.link_y,
                }
            end
        end
    end

    if selected_link then
        return self:onGotoLink(selected_link, false, isFootnoteLinkInPopupEnabled())
    end
end

function ReaderLink:onGoToInternalPageLink(ges)
    self:onGoToPageLink(ges, true)
end

function ReaderLink:onSelectNextPageLink()
    return self:selectRelPageLink(1)
end

function ReaderLink:onSelectPrevPageLink()
    return self:selectRelPageLink(-1)
end

function ReaderLink:selectRelPageLink(rel)
    if self.ui.paging then
        -- not implemented for now (see at doing like in showLinkBox()
        -- to highlight the link before jumping to it)
        return
    end
    -- Follow swipe_ignore_external_links setting to allow
    -- skipping external links when using keys
    local links = self.document:getPageLinks(isSwipeIgnoreExternalLinksEnabled())
    if not links or #links == 0 then
        return
    end
    if self.cur_selected_page_link_num then
        self.cur_selected_page_link_num = self.cur_selected_page_link_num + rel
        -- When reaching end of list, don't immediately jump to
        -- the other side: allow one step with no link selected
        if self.cur_selected_page_link_num > #links then
            self.cur_selected_page_link_num = nil
        elseif self.cur_selected_page_link_num <= 0 then
            self.cur_selected_page_link_num = nil
        end
    else
        if rel > 0 then
            self.cur_selected_page_link_num = 1
        elseif rel < 0 then
            self.cur_selected_page_link_num = #links
        end
    end
    if not self.cur_selected_page_link_num then
        self.cur_selected_link = nil
        self.document:highlightXPointer()
        UIManager:setDirty(self.dialog, "ui")
        return
    end
    local selected_link = links[self.cur_selected_page_link_num]
    logger.dbg("selected_link", selected_link)
    -- Check a_xpointer is coherent, use it as from_xpointer only if it is
    local from_xpointer = nil
    if selected_link.a_xpointer and self:isXpointerCoherent(selected_link.a_xpointer) then
        from_xpointer = selected_link.a_xpointer
    end
    local link_y
    if selected_link.segments and #selected_link.segments > 0 then
        link_y = selected_link.segments[#selected_link.segments].y1
    else
        link_y = selected_link.end_y
    end
    -- Make it a link as expected by onGotoLink
    self.cur_selected_link = {
        xpointer = selected_link.section or selected_link.uri,
        marker_xpointer = selected_link.section,
        from_xpointer = from_xpointer,
        -- (keep a_xpointer even if noncoherent, might be needed for
        -- footnote detection (better than nothing if noncoherent)
        a_xpointer = selected_link.a_xpointer,
        -- keep the link y position, so we can keep its highlight shown
        -- a bit more time if it was hidden by the footnote popup
        link_y = link_y,
    }
    self.document:highlightXPointer() -- clear any previous one
    self.document:highlightXPointer(self.cur_selected_link.from_xpointer)
    UIManager:setDirty(self.dialog, "ui")
    return true
end

function ReaderLink:onGotoSelectedPageLink()
    if self.cur_selected_link then
        return self:onGotoLink(self.cur_selected_link, false, isFootnoteLinkInPopupEnabled())
    end
end

function ReaderLink:onPageUpdate()
    if self.cur_selected_link then
        self.document:highlightXPointer()
        self.cur_selected_page_link_num = nil
        self.cur_selected_link = nil
    end
    self:_scheduleFootnoteCacheWarmup()
end

function ReaderLink:onPosUpdate()
    if self.cur_selected_link then
        self.document:highlightXPointer()
        self.cur_selected_page_link_num = nil
        self.cur_selected_link = nil
    end
    self:_scheduleFootnoteCacheWarmup()
end

function ReaderLink:onDocumentRerendered()
    self:_cancelFootnoteCacheWarmup()
    self:_footnoteCacheClear()
    -- Font may have changed; invalidate book font CSS and re-warm.
    local FootnoteWidget = require("ui/widget/footnotewidget")
    FootnoteWidget.clearBookFontCssCache()
    UIManager:nextTick(function()
        self:_warmFootnotePopupCaches()
    end)
end

function ReaderLink:_canWarmFootnotePopupCaches()
    return self.ui.rolling and not self.ui.paging and isFootnoteLinkInPopupEnabled()
end

function ReaderLink:_warmFootnotePopupCaches()
    if not self:_canWarmFootnotePopupCaches() then
        return
    end
    self:_cancelFootnoteCacheWarmup()
    local FootnoteWidget = require("ui/widget/footnotewidget")
    FootnoteWidget.warmFontCaches(self.ui.font and self.ui.font.font_face)
    self:_warmFootnoteCacheForPage()
end

function ReaderLink:_cancelFootnoteCacheWarmup()
    if self._footnote_warmup_action then
        UIManager:unschedule(self._footnote_warmup_action)
        self._footnote_warmup_action = nil
    end
    self._footnote_warmup_cancelled = true
    self._footnote_warmup_links = nil
    self._footnote_warmup_next_index = nil
    self._footnote_warmup_stats = nil
    self._footnote_warmup_max_text_size = nil
    self._footnote_warmup_flags_trusted = nil
    self._footnote_warmup_flags_untrusted = nil
    self._footnote_warmup_in_progress = nil
end

function ReaderLink:_finishFootnoteCacheWarmup()
    self._footnote_warmup_action = nil
    self._footnote_warmup_links = nil
    self._footnote_warmup_next_index = nil
    self._footnote_warmup_stats = nil
    self._footnote_warmup_max_text_size = nil
    self._footnote_warmup_flags_trusted = nil
    self._footnote_warmup_flags_untrusted = nil
    self._footnote_warmup_in_progress = nil
    self._footnote_warmup_cancelled = nil
end

function ReaderLink:_warmFootnoteCacheLink(link, max_text_size, flags_trusted, flags_untrusted)
    if not link.section then
        return
    end
    local source_xp = link.a_xpointer
    local target_xp = link.section
    local flags = source_xp and flags_trusted or flags_untrusted
    local cache_key = (source_xp or "") .. "\0" .. target_xp .. "\0" .. tostring(flags)
    if self._footnote_cache and self._footnote_cache[cache_key] then
        return
    end
    local ok, is_footnote, _reason, _extStopReason, extStartXP, extEndXP =
            pcall(self.document.isLinkToFootnote, self.document, source_xp or target_xp, target_xp, flags, max_text_size)
    if not ok then
        return
    end
    local html
    if is_footnote then
        if extStartXP and extEndXP then
            ok, html = pcall(self.document.getHTMLFromXPointers, self.document, extStartXP, extEndXP, 0x1001)
        else
            ok, html = pcall(self.document.getHTMLFromXPointer, self.document, target_xp, 0x1001, true)
        end
        if not ok then
            return
        end
    end
    self:_footnoteCachePut(cache_key, { is_footnote = is_footnote, html = html })
end

local FOOTNOTE_WARMUP_BATCH_SIZE = 3
local FOOTNOTE_WARMUP_BATCH_DELAY_S = 0.01
local FOOTNOTE_WARMUP_VISIBLE_MARGIN_DP = 20

function ReaderLink:_getFootnoteWarmupLinkY(link)
    if link.segments and #link.segments > 0 then
        local segment = link.segments[#link.segments]
        if segment.y1 then
            return segment.y1
        end
        return segment.y0
    end
    if link.end_y then
        return link.end_y
    end
    return link.start_y
end

function ReaderLink:_getPrioritizedFootnoteWarmupLinks(links)
    local screen_h = Screen:getHeight()
    local margin = Screen:scaleBySize(FOOTNOTE_WARMUP_VISIBLE_MARGIN_DP)
    local near_visible = {}
    local after_visible = {}
    local before_visible = {}
    local unknown = {}
    for idx, link in ipairs(links) do
        local y = self:_getFootnoteWarmupLinkY(link)
        if y == nil then
            table.insert(unknown, { idx = idx, link = link })
        elseif y > screen_h + margin then
            table.insert(after_visible, { idx = idx, y = y, link = link })
        elseif y < -margin then
            table.insert(before_visible, { idx = idx, y = y, link = link })
        else
            table.insert(near_visible, { idx = idx, y = y, link = link })
        end
    end
    table.sort(near_visible, function(a, b)
        if a.y == b.y then
            return a.idx < b.idx
        end
        return a.y < b.y
    end)
    table.sort(after_visible, function(a, b)
        if a.y == b.y then
            return a.idx < b.idx
        end
        return a.y < b.y
    end)
    -- "Before visible" should prioritize links nearest to the viewport top.
    table.sort(before_visible, function(a, b)
        if a.y == b.y then
            return a.idx < b.idx
        end
        return a.y > b.y
    end)
    local prioritized = {}
    for _, item in ipairs(near_visible) do
        table.insert(prioritized, item.link)
    end
    for _, item in ipairs(after_visible) do
        table.insert(prioritized, item.link)
    end
    for _, item in ipairs(before_visible) do
        table.insert(prioritized, item.link)
    end
    for _, item in ipairs(unknown) do
        table.insert(prioritized, item.link)
    end
    return prioritized, {
        near_visible = #near_visible,
        after_visible = #after_visible,
        before_visible = #before_visible,
        unknown = #unknown,
    }
end

function ReaderLink:_warmFootnoteCacheBatch()
    if not self:_canWarmFootnotePopupCaches() or self._footnote_warmup_cancelled then
        self:_finishFootnoteCacheWarmup()
        return
    end
    local links = self._footnote_warmup_links
    local index = self._footnote_warmup_next_index or 1
    if not links or index > #links then
        self:_finishFootnoteCacheWarmup()
        return
    end
    local max_text_size = self._footnote_warmup_max_text_size or 10000
    local flags_trusted = self._footnote_warmup_flags_trusted
    local flags_untrusted = self._footnote_warmup_flags_untrusted
    if flags_trusted == nil or flags_untrusted == nil then
        flags_trusted = computeFootnoteDetectionFlags(true)
        flags_untrusted = computeFootnoteDetectionFlags(false)
    end
    local processed = 0
    while index <= #links and processed < FOOTNOTE_WARMUP_BATCH_SIZE do
        self:_warmFootnoteCacheLink(links[index], max_text_size, flags_trusted, flags_untrusted)
        index = index + 1
        processed = processed + 1
    end
    if index > #links then
        self:_finishFootnoteCacheWarmup()
        return
    end
    self._footnote_warmup_next_index = index
    self._footnote_warmup_action = function()
        self._footnote_warmup_action = nil
        self:_warmFootnoteCacheBatch()
    end
    UIManager:scheduleIn(FOOTNOTE_WARMUP_BATCH_DELAY_S, self._footnote_warmup_action)
end

function ReaderLink:_scheduleFootnoteCacheWarmup()
    if not self:_canWarmFootnotePopupCaches() then
        return
    end
    self:_cancelFootnoteCacheWarmup()
    self._footnote_warmup_cancelled = nil
    self._footnote_warmup_action = function()
        self._footnote_warmup_action = nil
        self:_warmFootnoteCacheForPage()
    end
    -- Delay warmup to avoid interfering with rapid page turns
    UIManager:scheduleIn(0.3, self._footnote_warmup_action)
end

function ReaderLink:_warmFootnoteCacheForPage()
    if not self:_canWarmFootnotePopupCaches() then
        return
    end
    -- Prevent concurrent warmup
    if self._footnote_warmup_in_progress then
        return
    end
    self._footnote_warmup_in_progress = true
    self._footnote_warmup_cancelled = nil
    local links = self.document:getPageLinks(true)
    if not links or #links == 0 then
        self:_finishFootnoteCacheWarmup()
        return
    end
    self._footnote_warmup_links, self._footnote_warmup_stats =
            self:_getPrioritizedFootnoteWarmupLinks(links)
    self._footnote_warmup_max_text_size = 10000
    self._footnote_warmup_flags_trusted = computeFootnoteDetectionFlags(true)
    self._footnote_warmup_flags_untrusted = computeFootnoteDetectionFlags(false)
    logger.dbg("Footnote warmup priority near/after/before/unknown:",
            self._footnote_warmup_stats.near_visible,
            self._footnote_warmup_stats.after_visible,
            self._footnote_warmup_stats.before_visible,
            self._footnote_warmup_stats.unknown)
    self._footnote_warmup_next_index = 1
    self:_warmFootnoteCacheBatch()
end

function ReaderLink:onGoToLatestBookmark(ges)
    local latest_bookmark = self.ui.bookmark:getLatestBookmark()
    if latest_bookmark then
        if self.ui.paging then
            -- self:onGotoLink() needs something with a page attribute.
            -- we need to subtract 1 to bookmark page, as links start from 0
            -- and onGotoLink will add 1 - we need a fake_link (with a single
            -- page attribute) so we don't touch the bookmark itself
            local fake_link = {}
            fake_link.page = latest_bookmark.page - 1
            return self:onGotoLink(fake_link)
        else
            -- Make it a link as expected by onGotoLink
            local link
            if latest_bookmark.pos0 then -- text highlighted, precise xpointer
                link = {
                    xpointer = latest_bookmark.pos0,
                    marker_xpointer = latest_bookmark.pos0,
                }
            else -- page bookmarked, 'page' is a xpointer to top of page
                link = {
                    xpointer = latest_bookmark.page,
                }
            end
            return self:onGotoLink(link)
        end
    end
end

function ReaderLink:showAsFootnotePopup(link, neglect_current_location)
    if self.ui.paging then
        return false -- not supported
    end

    local source_xpointer = link.from_xpointer or link.a_xpointer
    local target_xpointer = link.xpointer
    if not source_xpointer or not target_xpointer then
        return false
    end
    local trust_source_xpointer = link.from_xpointer ~= nil

    local flags = computeFootnoteDetectionFlags(trust_source_xpointer)
    local max_text_size = 10000 -- nb of chars

    local cache_key = source_xpointer .. "\0" .. target_xpointer .. "\0" .. tostring(flags)
    local cached = self._footnote_cache and self._footnote_cache[cache_key]
    local is_footnote, html
    if cached then
        is_footnote = cached.is_footnote
        html = cached.html
        logger.dbg("Footnote cache hit for:", target_xpointer)
    else
        logger.dbg("Checking if link is to a footnote:", flags, source_xpointer, target_xpointer)
        local reason, extStopReason, extStartXP, extEndXP
        is_footnote, reason, extStopReason, extStartXP, extEndXP =
                self.document:isLinkToFootnote(source_xpointer, target_xpointer, flags, max_text_size)
        if is_footnote then
            logger.dbg("is a footnote:", reason)
            if extStartXP then
                logger.dbg("  extended until:", extStopReason)
                logger.dbg(extStartXP)
                logger.dbg(extEndXP)
            else
                logger.dbg("  not extended because:", extStopReason)
            end
            if extStartXP and extEndXP then
                html = self.document:getHTMLFromXPointers(extStartXP, extEndXP, 0x1001)
            else
                html = self.document:getHTMLFromXPointer(target_xpointer, 0x1001, true)
            end
        else
            logger.dbg("not a footnote:", reason)
        end
        self:_footnoteCachePut(cache_key, { is_footnote = is_footnote, html = html })
    end
    if not is_footnote then
        return false
    end
    if not html then
        logger.info("failed getting HTML for xpointer:", target_xpointer)
        return false
    end

    -- if false then -- for debug, to display html
    --     UIManager:show( require("ui/widget/textviewer"):new{text = html})
    --     return true
    -- end

    -- As we stay on the current page, we can highlight the selected link
    -- (which might not be seen when covered by FootnoteWidget)
    local close_callback = nil
    local should_highlight_tapped_link = link.from_xpointer and isTapLinkHighlightEnabled()
    if should_highlight_tapped_link then -- coherent xpointer
        self.document:highlightXPointer() -- clear any previous one
        self.document:highlightXPointer(link.from_xpointer)
        -- Don't let a previous footnote popup clear our highlight
        self._footnote_popup_discard_previous_close_callback = true
        close_callback = function(footnote_height)
            -- remove this highlight (actually all) on close
            local highlight_page = self.document:getCurrentPage()
            local clear_highlight = function()
                self.document:highlightXPointer()
                -- Only refresh if we stayed on the same page, otherwise
                -- this could remove too early a marker on the target page
                -- after this footnote is followed
                if self.document:getCurrentPage() == highlight_page then
                    UIManager:setDirty(self.dialog, "ui")
                end
            end
            if footnote_height then
                -- If the link was hidden by the footnote popup,
                -- delay a bit its clearing, so the user can see
                -- it and know where to start reading again
                local footnote_top_y = Screen:getHeight() - footnote_height
                if link.link_y > footnote_top_y then
                    UIManager:scheduleIn(G_defaults:readSetting("DELAY_CLEAR_HIGHLIGHT_S"), clear_highlight)
                else
                    clear_highlight()
                end
            else
                clear_highlight()
            end
        end
    end

    -- We give FootnoteWidget the document margins and font size, so
    -- it can base its own values on them (note that this can look
    -- misaligned when floating punctuation is enabled, as margins then
    -- don't have a fixed size)
    local FootnoteWidget = require("ui/widget/footnotewidget")
    local popup
    local ok, err = pcall(function()
        popup = FootnoteWidget:new{
            html = html,
            doc_font_name = self.ui.font.font_face,
            doc_font_size = Screen:scaleBySize(self.document.configurable.font_size),
            doc_margins = self.document:getPageMargins(),
            close_callback = close_callback,
            follow_callback = function() -- follow the link on swipe west
                UIManager:close(popup)
                self:onGotoLink(link, neglect_current_location)
            end,
            on_tap_close_callback = function(arg, ges, footnote_height)
                self._footnote_popup_discard_previous_close_callback = nil
                -- On tap outside, see if we are tapping on another footnote,
                -- and display it if we do (avoid the need for 2 taps)
                self:onTap(arg, ges)
                -- If onTap() did show another FootnoteWidget, and it
                -- has already cleared our highlight, avoid calling our
                -- close_callback so we do not clear the new highlight
                if not self._footnote_popup_discard_previous_close_callback then
                    if close_callback then -- not set if xpointer not coherent
                        close_callback(footnote_height)
                    end
                end
                self._footnote_popup_discard_previous_close_callback = nil
            end,
            dialog = self.dialog,
        }
    end)
    if not ok then
        logger.warn("FootnoteWidget init error:", err)
        return false
    end
    UIManager:show(popup)
    -- Refresh the full dialog area once for both the source link highlight
    -- and the popup, instead of doing two separate refreshes.
    if should_highlight_tapped_link then
        UIManager:setDirty(self.dialog, "ui")
    end
    return true
end

function ReaderLink:addToExternalLinkDialog(idx, fn_button)
    self._external_link_buttons[idx] = fn_button
end

local FOOTNOTE_CACHE_MAX = 30

function ReaderLink:_footnoteCachePut(key, value)
    if not self._footnote_cache then
        self._footnote_cache = {}
        self._footnote_cache_order = {}
    end
    if not self._footnote_cache[key] then
        if #self._footnote_cache_order >= FOOTNOTE_CACHE_MAX then
            local oldest = table.remove(self._footnote_cache_order, 1)
            self._footnote_cache[oldest] = nil
        end
        table.insert(self._footnote_cache_order, key)
    end
    self._footnote_cache[key] = value
end

function ReaderLink:_footnoteCacheClear()
    self._footnote_cache = nil
    self._footnote_cache_order = nil
end

function ReaderLink:removeFromExternalLinkDialog(idx)
    local button = self._external_link_buttons[idx]
    self._external_link_buttons[idx] = nil
    return button
end

function ReaderLink:getButtonsForExternalLinkDialog(link_url)
    local buttons = {{}}
    local columns = 2

    local default_title =  T(_("External link:\n\n%1"), BD.url(link_url))
    local title = default_title

    for idx, fn_button in ffiUtil.orderedPairs(self._external_link_buttons) do
        local button = fn_button(self, link_url)
        local show, button_title

        if button.show_in_dialog_func then
            show, button_title = button.show_in_dialog_func(link_url)
        else
            -- If the button doesn't have the show_in_dialog_func, then assume that the button
            -- should be shown. Default buttons (which are always shown) will be like this.
            show = true
        end
        if show then
            -- Add button to the buttons table
            if #buttons[#buttons] >= columns then
                table.insert(buttons, {})
            end
            table.insert(buttons[#buttons], button)
            logger.dbg("ReaderLink", idx..": line "..#buttons..", col "..#buttons[#buttons])
        end
        if button_title then
            -- Create the title for the button
            if title == default_title then
                -- The default title is replaced by the first non-default button title.
                title = button_title
            else
                -- Every other button title value is appended to the title.
                title = title .. "\n\n" .. button_title
            end
        end
    end

    return buttons, title
end

return ReaderLink
