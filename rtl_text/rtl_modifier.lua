

local M = {}

local unicode = require "rtl_text.unicode"
local rev     = require "rtl_text.reverse"

local format = string.format
local byte   = string.byte
local char   = string.char

-- UTF8 char -> hex bytes (lowercase)
local function toHex(str)
    return (str:gsub(".", function(c)
        return format("%02X", byte(c))
    end)):lower()
end

-- hex bytes -> utf8 string
local function fromHex(str)
    return (str:gsub("..", function(cc)
        return char(tonumber(cc, 16))
    end))
end

-- split string into base hex chars (DO NOT MODIFY)
local function splitToHexChars(str)
    local t = {}
    local k = 1
    for c in string.gmatch(str, "[%z\1-\127\194-\244][\128-\191]*") do
        t[k] = toHex(c)
        k = k + 1
    end
    return t
end

-- UTF-8 iterator (returns full UTF-8 chars)
local function utf8_iter(s)
    local i = 1
    return function()
        if i > #s then return nil end
        local c = s:match("[%z\1-\127\194-\244][\128-\191]*", i)
        if not c then return nil end
        i = i + #c
        return c
    end
end

-- Detect if string has any Arabic/Persian letters (U+0600..U+06FF)
local function has_arabic_persian(s)
    -- UTF-8 leading bytes for Arabic block commonly: D8, D9, DA, DB
    for i = 1, #s do
        local b = s:byte(i)
        if b == 0xD8 or b == 0xD9 or b == 0xDA or b == 0xDB then
            return true
        end
    end
    return false
end


local function is_arabic_diacritic_hex(h)
    -- Arabic combining marks (harakat) are mainly:
    -- U+064B..U+065F  => UTF-8: D9 8B .. D9 9F  => hex: d98b..d99f
    -- U+0670 (dagger alif) => UTF-8: D9 B0 => hex: d9b0
    if type(h) ~= "string" or #h ~= 4 then return false end
    if h == "d9b0" then return true end
    if h:sub(1,2) == "d9" then
        local lo = tonumber(h:sub(3,4), 16)
        if lo and lo >= 0x8B and lo <= 0x9F then
            return true
        end
    end
    return false
end


local function prev_real(base, i)
    local j = i - 1
    while j >= 1 do
        local h = base[j]
        if not is_arabic_diacritic_hex(h) then
            return h
        end
        j = j - 1
    end
    return nil
end

local function next_real(base, i)
    local j = i + 1
    while j <= #base do
        local h = base[j]
        if not is_arabic_diacritic_hex(h) then
            return h
        end
        j = j + 1
    end
    return nil
end


-- boundaries
local ZWNJ_HEX = "e2808c" -- نیم‌فاصله (U+200C)

local function is_pua_placeholder_hex(h)
    -- PUA placeholders we generate are U+E000..U+E0FF => UTF-8 starts with EE 80 xx
    return type(h) == "string" and h:sub(1, 4) == "ee80"
end

-- check space / punctuation / whitespace (boundaries)
local function is_space_or_symbol(x)
    if not x then return true end

    -- Treat all ASCII control/whitespace (00..20) as boundary: tab/newline/etc
    if #x == 2 then
        local v = tonumber(x, 16)
        if v and v <= 0x20 then
            return true
        end
    end

    -- Treat ZWNJ as boundary for joining purposes
    if x == ZWNJ_HEX then
        return true
    end

    if x == unicode.space then return true end
    for _, s in ipairs(unicode.symbols) do
        if x == s then return true end
    end
    return false
end

-- letters that DO NOT connect to next letter (right-joining only)
local RIGHT_JOIN_ONLY = {
    ["d8a7"]=true, -- ا
    ["d8a2"]=true, -- آ
    ["d8a3"]=true, -- أ
    ["d8a5"]=true, -- إ
    ["d8af"]=true, -- د
    ["d8b0"]=true, -- ذ
    ["d8b1"]=true, -- ر
    ["d8b2"]=true, -- ز
    ["da98"]=true, -- ژ
    ["d988"]=true, -- و
}

local function can_prev_connect_to_curr(prev)
    if not prev then return false end
    if is_pua_placeholder_hex(prev) then return false end
    if is_space_or_symbol(prev) then return false end
    if RIGHT_JOIN_ONLY[prev] then return false end
    return true
end

local function can_curr_connect_to_next(curr, nextc)
    if RIGHT_JOIN_ONLY[curr] then return false end
    if not nextc then return false end
    if is_pua_placeholder_hex(nextc) then return false end
    if is_space_or_symbol(nextc) then return false end
    return true
end

-- ---- Mixed RTL/LTR handling ----

-- PUA placeholder generator (no utf8 dependency)
local function pua_char(n)
    local code = 0xE000 + n
    local b1 = 0xE0 + math.floor(code / 0x1000)
    local b2 = 0x80 + (math.floor(code / 0x40) % 0x40)
    local b3 = 0x80 + (code % 0x40)
    return string.char(b1, b2, b3)
end

-- Decide if a UTF-8 char should be treated as part of an LTR phrase:
-- English letters, ASCII digits, separators, PLUS Persian/Arabic digits.
local function is_ltr_char_utf8(ch)
    local h = toHex(ch)

    -- ASCII byte
    if #h == 2 then
        local b = tonumber(h, 16)
        if (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) then
            return true
        end
        if ch == "." or ch == "_" or ch == "-" or ch == "+" or ch == ":" or ch == "/" or ch == "%" then
            return true
        end
        return false
    end

    -- Persian digits ۰..۹ : DBB0..DBB9
    if h:match("^dbb[0-9]$") then
    return true
end

    -- Arabic-Indic digits ٠..٩ : D9A0..D9A9
    if h:sub(1, 3) == "d9a" then
        local last = tonumber(h:sub(4, 4), 16)
        if last and last >= 0 and last <= 9 then return true end
    end

    return false
end

-- Extract LTR phrases (including Persian/Arabic digits) and replace with placeholders
local function extract_ltr_phrases(s)
    local phrases = {}
    local out = {}

    -- Build UTF-8 char array
    local chars = {}
    for ch in utf8_iter(s) do
        chars[#chars + 1] = ch
    end

    local i = 1
    while i <= #chars do
        local ch = chars[i]

        if is_ltr_char_utf8(ch) then
            local j = i
            while j <= #chars and is_ltr_char_utf8(chars[j]) do
                j = j + 1
            end

            -- include spaces between LTR chunks like "FPS:" + " " + "60" OR "۱۰ روز"
            local k = j
            while k <= #chars do
                if chars[k] == " " then
                    local t = k + 1
                    if t <= #chars and is_ltr_char_utf8(chars[t]) then
                        k = t
                        while k <= #chars and is_ltr_char_utf8(chars[k]) do
                            k = k + 1
                        end
                    else
                        break
                    end
                else
                    break
                end
            end

            local phrase_parts = {}
            for p = i, k - 1 do
                phrase_parts[#phrase_parts + 1] = chars[p]
            end
            local phrase = table.concat(phrase_parts)

            phrases[#phrases + 1] = phrase
            out[#out + 1] = pua_char(#phrases)

            i = k
        else
            out[#out + 1] = ch
            i = i + 1
        end
    end

    return table.concat(out), phrases
end

local function restore_ltr_phrases(s, phrases)
    if not phrases or #phrases == 0 then return s end
    for idx, phrase in ipairs(phrases) do
        local ph = pua_char(idx)
        s = s:gsub(ph, phrase)
    end
    return s
end

-- ---- Main ----
function M.get_rtl_text(str)
    if type(str) ~= "string" then return str end

    -- If pure LTR, do nothing
    if not has_arabic_persian(str) then
        return str
    end

    -- Protect LTR phrases in mixed text (English + numbers + Persian/Arabic digits)
    local protected, phrases = extract_ltr_phrases(str)

    -- Shape RTL (two-pass)
    local base = splitToHexChars(protected)
    local out  = {}

    for i = 1, #base do
        local curr = base[i]
        local map  = unicode.hex[curr]

        if not map then
            out[i] = curr
        else
            local prev  = prev_real(base, i)
            local nextc = next_real(base, i)

            local join_prev = can_prev_connect_to_curr(prev)
            local join_next = can_curr_connect_to_next(curr, nextc)

            if join_prev and join_next then
                out[i] = map.middle
            elseif join_prev and not join_next then
                out[i] = map.last
            elseif not join_prev and join_next then
                out[i] = map.first
            else
                out[i] = map.isolated
            end
        end
    end

    local hex = ""
    for i = 1, #out do
        hex = hex .. out[i]
    end

    local shaped = rev.utf8reverse(fromHex(hex))

    -- Restore LTR phrases after reversing
    shaped = restore_ltr_phrases(shaped, phrases)

    return shaped
end

return M
