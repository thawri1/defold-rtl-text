local M = {}

local unicode = require "rtl_text.unicode"
local rev     = require "rtl_text.reverse"

local format = string.format
local byte   = string.byte
local char   = string.char

-- UTF8 char -> hex bytes
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

-- check space / punctuation (boundaries)
local function is_space_or_symbol(x)
    if not x then return true end
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


local function is_pua_placeholder_hex(h)
  -- PUA placeholders we generate are U+E000..U+E0FF
  -- UTF-8 for that starts with: EE 80 xx  (hex: "ee80..")
  return type(h) == "string" and h:sub(1,4) == "ee80"
end

local function can_prev_connect_to_curr(prev)
    if not prev then return false end
    if is_space_or_symbol(prev) then return false end
    if RIGHT_JOIN_ONLY[prev] then return false end
    return true
end

local function can_curr_connect_to_next(curr, nextc)
    if RIGHT_JOIN_ONLY[curr] then return false end
    if not nextc then return false end

    -- NEW: treat placeholder as a boundary
    if is_pua_placeholder_hex(nextc) then return false end

    if is_space_or_symbol(nextc) then return false end
    return true
end

-- Identify ASCII LTR char (English/digits and common separators)
local function is_ltr_char(c)
    local b = c:byte()
    if not b then return false end
    return (b >= 48 and b <= 57)   -- 0-9
        or (b >= 65 and b <= 90)   -- A-Z
        or (b >= 97 and b <= 122)  -- a-z
        or c == "." or c == "_" or c == "-" or c == "+" or c == ":" or c == "/" or c == "%" -- common
end

-- We need placeholders that survive shaping/reverse:
-- Use Private Use Area U+E000.. to mark LTR phrases
local function pua_char(n)
    -- create utf8 for U+E000 + n (n >= 1)
    local code = 0xE000 + n
    -- UTF-8 encode manually (no utf8 dependency):
    -- U+E000..U+FFFF => 3-byte: 1110xxxx 10xxxxxx 10xxxxxx
    local b1 = 0xE0 + math.floor(code / 0x1000)
    local b2 = 0x80 + (math.floor(code / 0x40) % 0x40)
    local b3 = 0x80 + (code % 0x40)
    return string.char(b1, b2, b3)
end

-- Extract LTR phrases and replace them with PUA placeholders.
-- Also expands the LTR phrase to include adjacent spaces ONLY if it is
-- sandwiched inside RTL text, to keep "FPS: 60" together.
local function extract_ltr_phrases(s)
    local phrases = {}
    local out = {}

    local i = 1
    while i <= #s do
        local c = s:sub(i, i)

        if is_ltr_char(c) then
            local j = i
            while j <= #s and is_ltr_char(s:sub(j, j)) do
                j = j + 1
            end

            -- include spaces between LTR chunks like "FPS:" + " " + "60"
            -- keep consuming sequences of: spaces + LTR
            local k = j
            while k <= #s do
                local cc = s:sub(k, k)
                if cc == " " then
                    local t = k + 1
                    if t <= #s and is_ltr_char(s:sub(t, t)) then
                        -- consume space
                        k = t
                        -- consume next LTR run
                        while k <= #s and is_ltr_char(s:sub(k, k)) do
                            k = k + 1
                        end
                    else
                        break
                    end
                else
                    break
                end
            end

            local phrase = s:sub(i, k - 1)
            phrases[#phrases + 1] = phrase
            out[#out + 1] = pua_char(#phrases)

            i = k
        else
            out[#out + 1] = c
            i = i + 1
        end
    end

    return table.concat(out), phrases
end

local function restore_ltr_phrases(s, phrases)
    if not phrases or #phrases == 0 then return s end
    for idx, phrase in ipairs(phrases) do
        local ph = pua_char(idx)
        -- plain replace (PUA placeholder is unique)
        s = s:gsub(ph, phrase)
    end
    return s
end

function M.modifierToArab(str)
    if type(str) ~= "string" then return str end

    -- If pure LTR, do nothing (prevents "Version 1.2.3" => "1.2.3 Version")
    if not has_arabic_persian(str) then
        return str
    end

    -- Protect LTR phrases in mixed text
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
            local prev = base[i - 1]
            local nextc = base[i + 1]

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
