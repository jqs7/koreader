local IME = require("ui/data/keyboardlayouts/generic_ime")
local util = require("util")
local _ = require("gettext")

-- Start with the english keyboard layout
local py_keyboard = dofile("frontend/ui/data/keyboardlayouts/en_keyboard.lua")
local SETTING_NAME = "keyboard_chinese_xiaohe_settings"

local full_pinyin_map = dofile("frontend/ui/data/keyboardlayouts/zh_pinyin_data.lua")

local function mostlySingleCandidates(candi)
    if type(candi) ~= "table" or #candi == 0 then
        return false
    end
    local sample_count = math.min(#candi, 20)
    local single_char_count = 0
    for i = 1, sample_count do
        if utf8.len(candi[i] or "") == 1 then
            single_char_count = single_char_count + 1
        end
    end
    return single_char_count / sample_count >= 0.8
end

local function buildSyllableMap(code_map)
    local syllables = {}
    for code, candi in pairs(code_map) do
        if #code <= 6 and code:match("^[a-z]+$") and mostlySingleCandidates(candi) then
            syllables[code] = true
        end
    end
    return syllables
end

local function segmentPinyin(code, syllable_map)
    local n = #code
    local dp = {}
    dp[n + 1] = { count = 0, path = {} }
    for i = n, 1, -1 do
        local best
        local max_len = math.min(6, n - i + 1)
        for len = max_len, 1, -1 do
            local j = i + len - 1
            local syllable = code:sub(i, j)
            local next_state = dp[j + 1]
            if syllable_map[syllable] and next_state then
                local candidate = { count = next_state.count + 1, path = { syllable } }
                for _, item in ipairs(next_state.path) do
                    candidate.path[#candidate.path + 1] = item
                end
                if not best or candidate.count < best.count then
                    best = candidate
                end
            end
        end
        dp[i] = best
    end
    return dp[1] and dp[1].path or nil
end

local function toFlypySyllable(syllable)
    local s = syllable
    s = s:gsub("^([jqxy])u$", "%1v")
    s = s:gsub("^([aoe])([ioun])$", "%1%1%2")
    s = s:gsub("^([aoe])(ng)?$", "%1%1%2")
    s = s:gsub("iu$", "Q")
    s = s:gsub("(.)ei$", "%1W")
    s = s:gsub("uan$", "R")
    s = s:gsub("[uv]e$", "T")
    s = s:gsub("un$", "Y")
    s = s:gsub("^sh", "U")
    s = s:gsub("^ch", "I")
    s = s:gsub("^zh", "V")
    s = s:gsub("uo$", "O")
    s = s:gsub("ie$", "P")
    s = s:gsub("i?ong$", "S")
    s = s:gsub("ing$", "K")
    s = s:gsub("uai$", "K")
    s = s:gsub("(.)ai$", "%1D")
    s = s:gsub("(.)en$", "%1F")
    s = s:gsub("(.)eng$", "%1G")
    s = s:gsub("[iu]ang$", "L")
    s = s:gsub("(.)ang$", "%1H")
    s = s:gsub("ian$", "M")
    s = s:gsub("(.)an$", "%1J")
    s = s:gsub("(.)ou$", "%1Z")
    s = s:gsub("[iu]a$", "X")
    s = s:gsub("iao$", "N")
    s = s:gsub("(.)ao$", "%1C")
    s = s:gsub("ui$", "V")
    s = s:gsub("in$", "B")
    s = s:gsub("Q", "q")
    s = s:gsub("W", "w")
    s = s:gsub("R", "r")
    s = s:gsub("T", "t")
    s = s:gsub("Y", "y")
    s = s:gsub("U", "u")
    s = s:gsub("I", "i")
    s = s:gsub("O", "o")
    s = s:gsub("P", "p")
    s = s:gsub("S", "s")
    s = s:gsub("D", "d")
    s = s:gsub("F", "f")
    s = s:gsub("G", "g")
    s = s:gsub("H", "h")
    s = s:gsub("J", "j")
    s = s:gsub("K", "k")
    s = s:gsub("L", "l")
    s = s:gsub("Z", "z")
    s = s:gsub("X", "x")
    s = s:gsub("C", "c")
    s = s:gsub("V", "v")
    s = s:gsub("B", "b")
    s = s:gsub("M", "m")
    return s
end

local function buildXiaoheCodeMap(code_map)
    local syllable_map = buildSyllableMap(code_map)
    local xiaohe_map = {}
    local seen = {}
    local sorted_codes = {}

    for code, _ in pairs(code_map) do
        table.insert(sorted_codes, code)
    end
    table.sort(sorted_codes)

    for _, pinyin_code in ipairs(sorted_codes) do
        if pinyin_code:match("^[a-z]+$") then
            local syllables = segmentPinyin(pinyin_code, syllable_map)
            if syllables then
                local converted = {}
                for i, syllable in ipairs(syllables) do
                    converted[i] = toFlypySyllable(syllable)
                end
                local xiaohe_code = table.concat(converted)
                local candidates = code_map[pinyin_code]
                if xiaohe_code ~= "" and candidates then
                    if not xiaohe_map[xiaohe_code] then
                        xiaohe_map[xiaohe_code] = {}
                        seen[xiaohe_code] = {}
                    end
                    local list = type(candidates) == "table" and candidates or { candidates }
                    for _, cand in ipairs(list) do
                        if not seen[xiaohe_code][cand] then
                            table.insert(xiaohe_map[xiaohe_code], cand)
                            seen[xiaohe_code][cand] = true
                        end
                    end
                end
            end
        end
    end

    return xiaohe_map
end

local code_map = buildXiaoheCodeMap(full_pinyin_map)
local settings = G_reader_settings:readSetting(SETTING_NAME, { show_candi = true })
local ime = IME:new {
    code_map = code_map,
    partial_separators = { " " },
    show_candi_callback = function()
        return settings.show_candi
    end,
    switch_char = "→",
    switch_char_prev = "←",
}

py_keyboard.keys[4][3][2].alt_label = nil
py_keyboard.keys[4][3][1].alt_label = nil
py_keyboard.keys[3][10][2] = {
    "，",
    north = "；",
    alt_label = "；",
    northeast = "（",
    northwest = "“",
    east = "《",
    west = "？",
    south = ",",
    southeast = "【",
    southwest = "「",
    "{",
    "[",
    ";"
}

py_keyboard.keys[5][3][2] = {
    "。",
    north = "：",
    alt_label = "：",
    northeast = "）",
    northwest = "”",
    east = "…",
    west = "！",
    south = ".",
    southeast = "】",
    southwest = "」",
    "}",
    "]",
    ":"
}
py_keyboard.keys[1][2][3] = { alt_label = "「", north = "「", "‘" }
py_keyboard.keys[1][3][3] = { alt_label = "」", north = "」", "’" }
py_keyboard.keys[1][1][4] = { alt_label = "!", north = "!", "！" }
py_keyboard.keys[2][1][4] = { alt_label = "?", north = "?", "？" }
py_keyboard.keys[1][2][4] = "、"
py_keyboard.keys[2][2][4] = "——"
py_keyboard.keys[1][4][3] = { alt_label = "『", north = "『", "“" }
py_keyboard.keys[1][5][3] = { alt_label = "』", north = "』", "”" }
py_keyboard.keys[1][4][4] = { alt_label = "¥", north = "¥", "_" }
py_keyboard.keys[3][3][4] = "（"
py_keyboard.keys[3][4][4] = "）"
py_keyboard.keys[4][4][3] = "《"
py_keyboard.keys[4][5][3] = "》"

local genMenuItems = function(self)
    return {
        {
            text = _("Show character candidates"),
            checked_func = function()
                return settings.show_candi
            end,
            callback = function()
                settings.show_candi = not settings.show_candi
                G_reader_settings:saveSetting(SETTING_NAME, settings)
            end
        }
    }
end

local wrappedAddChars = function(inputbox, char)
    ime:wrappedAddChars(inputbox, char)
end

local wrappedRightChar = function(inputbox)
    if ime:hasCandidates() then
        ime:wrappedAddChars(inputbox, "→")
    else
        ime:separate(inputbox)
        inputbox.rightChar:raw_method_call()
    end
end

local wrappedLeftChar = function(inputbox)
    if ime:hasCandidates() then
        ime:wrappedAddChars(inputbox, "←")
    else
        ime:separate(inputbox)
        inputbox.leftChar:raw_method_call()
    end
end

local function separate(inputbox)
    ime:separate(inputbox)
end

local function wrappedDelChar(inputbox)
    ime:wrappedDelChar(inputbox)
end

local function clear_stack()
    ime:clear_stack()
end

local wrapInputBox = function(inputbox)
    if inputbox._py_wrapped == nil then
        inputbox._py_wrapped = true
        local wrappers = {}

        -- Wrap all of the navigation and non-single-character-input keys with
        -- a callback to finish (separate) the input status, but pass through to the
        -- original function.

        -- -- Delete text.
        table.insert(wrappers, util.wrapMethod(inputbox, "delChar", wrappedDelChar, nil))
        table.insert(wrappers, util.wrapMethod(inputbox, "delToStartOfLine", nil, clear_stack))
        table.insert(wrappers, util.wrapMethod(inputbox, "clear", nil, clear_stack))
        -- -- Navigation.
        table.insert(wrappers, util.wrapMethod(inputbox, "upLine", nil, separate))
        table.insert(wrappers, util.wrapMethod(inputbox, "downLine", nil, separate))
        -- -- Move to other input box.
        table.insert(wrappers, util.wrapMethod(inputbox, "unfocus", nil, separate))
        table.insert(wrappers, util.wrapMethod(inputbox, "onCloseKeyboard", nil, separate))
        -- -- Gestures to move cursor.
        table.insert(wrappers, util.wrapMethod(inputbox, "onTapTextBox", nil, separate))
        table.insert(wrappers, util.wrapMethod(inputbox, "onHoldTextBox", nil, separate))
        table.insert(wrappers, util.wrapMethod(inputbox, "onSwipeTextBox", nil, separate))

        table.insert(wrappers, util.wrapMethod(inputbox, "addChars", wrappedAddChars, nil))
        table.insert(wrappers, util.wrapMethod(inputbox, "leftChar", wrappedLeftChar, nil))
        table.insert(wrappers, util.wrapMethod(inputbox, "rightChar", wrappedRightChar, nil))

        return function()
            if inputbox._py_wrapped then
                for _, wrapper in ipairs(wrappers) do
                    wrapper:revert()
                end
                inputbox._py_wrapped = nil
            end
        end
    end
end

py_keyboard.wrapInputBox = wrapInputBox
py_keyboard.genMenuItems = genMenuItems
py_keyboard.keys[5][4].label = "空格"
return py_keyboard
