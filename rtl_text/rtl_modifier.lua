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

-- check space / punctuation
local function is_space_or_symbol(x)
    if not x then return true end
    if x == unicode.space then return true end
    for _, s in ipairs(unicode.symbols) do
        if x == s then return true end
    end
    return false
end

-- letters that DO NOT connect to next letter
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
    if is_space_or_symbol(prev) then return false end
    if RIGHT_JOIN_ONLY[prev] then return false end
    return true
end

local function can_curr_connect_to_next(curr, nextc)
    if RIGHT_JOIN_ONLY[curr] then return false end
    if not nextc then return false end
    if is_space_or_symbol(nextc) then return false end
    return true
end

function M.modifierToArab(str)
    if type(str) ~= "string" then return str end

    local base = splitToHexChars(str) -- base characters
    local out  = {}                  -- shaped output

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

    return rev.utf8reverse(fromHex(hex))
end

return M
