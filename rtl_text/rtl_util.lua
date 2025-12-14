local M = {}

local modifier = require("rtl_text.rtl_modifier")


local function wrap_rtl_text(text)
    local lines = {}
    for line in text:gmatch("[^\r\n]+") do
        table.insert(lines, modifier.modifierToArab(line))
    end
    return table.concat(lines, "\n")
end

function M.modifyMultiLineTextToTextNode(text_node, text)
    local font_name = gui.get_font(text_node)
    local font = gui.get_font_resource(font_name)



    local text_node_size = gui.get_size(text_node)
    local text_node_width = text_node_size.x


    local metrics = resource.get_text_metrics(font, text)
    print("text metrics width: " .. metrics.width)
    print("text metrics height: " .. metrics.height)

    local new_text = ""

    if metrics.width > text_node_width then
        for w in text:gmatch("%S+") do
            local tmp_text = new_text .. " " .. w
            local metrics = resource.get_text_metrics(font, tmp_text)
            if metrics.width > text_node_width then
                new_text = new_text .. "\n" .. w
            else
                new_text = tmp_text
            end
        end
        new_text = wrap_rtl_text(new_text)
    else
        new_text = modifier.modifierToArab(text)
    end



    gui.set_text(text_node, new_text)
end

return M
