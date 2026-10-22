-- Copyright (c) 2026 N4K LABS. Licensed under the MIT License, see LICENSE.md.
BlipValidation = {}

function BlipValidation.number(value, minimum, maximum, integer)
    return type(value) == 'number' and value == value
        and value >= minimum and value <= maximum
        and (not integer or value % 1 == 0)
end

function BlipValidation.clean(data)
    if type(data) ~= 'table' then return nil, locale('validation.invalid_data') end
    if type(data.name) ~= 'string' or #data.name > 64 or data.name:find('[%c~]') then
        return nil, locale('validation.invalid_name')
    end
    local name = data.name:match('^%s*(.-)%s*$')
    if name == '' then return nil, locale('validation.empty_name') end
    local n = BlipValidation.number
    if not n(data.sprite, 0, 10000, true) or not BlipCatalog.sprites[data.sprite] then
        return nil, locale('validation.invalid_sprite')
    end
    if not n(data.colour, 0, 1000, true) or not BlipCatalog.colours[data.colour] then
        return nil, locale('validation.invalid_colour')
    end
    if not n(data.scale, 0.1, 5.0) or not n(data.alpha, 0, 255, true) then
        return nil, locale('validation.invalid_scale_alpha')
    end
    if data.display ~= 2 and data.display ~= 3 and data.display ~= 5 then
        return nil, locale('validation.invalid_display')
    end
    if type(data.shortRange) ~= 'boolean' or type(data.enabled) ~= 'boolean' then
        return nil, locale('validation.invalid_visibility')
    end
    local c = data.coords
    if type(c) ~= 'table' or not n(c.x, -20000, 20000)
        or not n(c.y, -20000, 20000) or not n(c.z, -2000, 10000) then
        return nil, locale('validation.invalid_coords')
    end
    return {
        name = name, sprite = data.sprite, colour = data.colour, scale = data.scale,
        display = data.display, alpha = data.alpha, shortRange = data.shortRange,
        enabled = data.enabled, coords = { x = c.x, y = c.y, z = c.z }
    }
end
