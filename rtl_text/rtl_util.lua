local M = {}

local modifier = require("rtl_text.rtl_modifier")

-- Split text into lines while preserving empty lines
local function split_lines_keep_empty(text)
    local lines = {}
    text = text:gsub("\r\n", "\n") -- normalize Windows newlines

    local start = 1
    while true do
        local nl = text:find("\n", start, true)
        if not nl then
            table.insert(lines, text:sub(start)) -- last line (can be empty)
            break
        end
        table.insert(lines, text:sub(start, nl - 1)) -- can be empty
        start = nl + 1
    end
    return lines
end

-- RTL each line individually, preserving empty lines
function M.wrap_rtl_text(text)
    local lines = split_lines_keep_empty(text)
    for i = 1, #lines do
        if lines[i] ~= "" then
            lines[i] = modifier.modifierToArab(lines[i])
        end
        -- empty line stays empty => paragraph spacing preserved
    end
    return table.concat(lines, "\n")
end

function M.modify_multi_line_text_to_text_node(text_node, text)
    local font_name = gui.get_font(text_node)
    local font = gui.get_font_resource(font_name)
    local node_width = gui.get_size(text_node).x

    local input_lines = split_lines_keep_empty(text)
    local out_lines = {}

    for _, raw_line in ipairs(input_lines) do
        -- preserve empty lines
        if raw_line == "" then
            out_lines[#out_lines + 1] = ""
        else
            local metrics = resource.get_text_metrics(font, raw_line)

            if metrics.width > node_width then
                -- wrap this single line into multiple lines
                local wrapped = ""
                for w in raw_line:gmatch("%S+") do
                    local tmp = (wrapped == "") and w or (wrapped .. " " .. w)
                    local m = resource.get_text_metrics(font, tmp)
                    if m.width > node_width then
                        wrapped = wrapped .. "\n" .. w
                    else
                        wrapped = tmp
                    end
                end
                -- now shape each wrapped line separately
                out_lines[#out_lines + 1] = M.wrap_rtl_text(wrapped)
            else
                out_lines[#out_lines + 1] = modifier.modifierToArab(raw_line)
            end
        end
    end

    gui.set_text(text_node, table.concat(out_lines, "\n"))
end

return M
