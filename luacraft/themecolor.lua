--- ThemeColor class, Generated internally by Luacraft
-- @classmod ThemeColor
local ThemeColor = {}
ThemeColor.__index = ThemeColor

-- @tparam string|number text
function ThemeColor:__call(text)
    print(self.color(text))
end

function create_theme_color(color, style)
    --- ThemeColor table
    -- @field color color

    --- ThemeColor table
    -- @field style style
    return setmetatable({color = color, style = style}, ThemeColor)
end

return create_theme_color