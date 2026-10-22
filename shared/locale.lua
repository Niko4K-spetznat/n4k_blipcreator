-- Copyright (c) 2026 N4K LABS. Licensed under the MIT License, see LICENSE.md.
-- Loads locales/<language>.json (en is always the fallback). Afterwards locale('key', ...) is available.
local requested = Config.Locale
if type(requested) ~= 'string' or requested == '' or requested == 'auto' then
    requested = GetConvar('ox:locale', 'en')
end
requested = requested:lower():gsub('[^%w_%-]', '')

local resource = GetCurrentResourceName()
if requested ~= 'en' and not LoadResourceFile(resource, ('locales/%s.json'):format(requested)) then
    print(('^3[%s] locales/%s.json not found, falling back to en.^0'):format(resource, requested))
    requested = 'en'
end

lib.locale(requested)
