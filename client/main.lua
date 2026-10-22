-- Copyright (c) 2026 N4K LABS. Licensed under the MIT License, see LICENSE.md.
local snapshot = { revision = -1, blips = {} }
local handles, preview = {}, nil
local busy = false
local openMain, openList, openDetail, editBlip

local function notify(message, kind)
    lib.notify({ title = locale('title'), description = message, type = kind or 'inform' })
end

local function request(name, ...)
    local ok, result = pcall(lib.callback.await, 'n4k_blipcreator:' .. name, false, ...)
    if not ok then notify(locale('server_unreachable'), 'error') return nil end
    return result
end

local function removePreview()
    if preview and DoesBlipExist(preview) then RemoveBlip(preview) end
    preview = nil
end

local function makeBlip(data, isPreview)
    local c = data.coords
    local handle = AddBlipForCoord(c.x + 0.0, c.y + 0.0, c.z + 0.0)
    SetBlipSprite(handle, data.sprite)
    SetBlipColour(handle, data.colour)
    SetBlipScale(handle, data.scale + 0.0)
    SetBlipDisplay(handle, data.display)
    SetBlipAlpha(handle, data.alpha)
    SetBlipAsShortRange(handle, data.shortRange)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName((isPreview and locale('preview_prefix') or '') .. data.name)
    EndTextCommandSetBlipName(handle)
    return handle
end

local function applyState(data)
    if type(data) ~= 'table' or type(data.revision) ~= 'number' or data.revision <= snapshot.revision then return end
    for _, handle in pairs(handles) do if DoesBlipExist(handle) then RemoveBlip(handle) end end
    handles = {}
    snapshot = data
    for _, entry in ipairs(data.blips) do
        if entry.enabled then handles[entry.id] = makeBlip(entry) end
    end
end

RegisterNetEvent('n4k_blipcreator:sync', function(data)
    if source ~= 65535 then return end -- only events coming from the server
    applyState(data)
end)

local function refresh()
    local result = request('snapshot')
    if not result then return false end
    if not result.ok then notify(result.message, 'error') return false end
    applyState(result.state)
    return true
end

local function mutate(action, id, revision, data)
    local result = request('mutate', action, id, revision, data)
    if not result then return false end
    if not result.ok then notify(result.message, 'error') refresh() return false end
    applyState(result.state)
    notify(locale('saved'), 'success')
    return true
end

local function currentCoords()
    local c = GetEntityCoords(PlayerPedId())
    return { x = c.x, y = c.y, z = c.z }
end

local sprites, colours = {}, {}
for id, name in pairs(BlipCatalog.sprites) do
    sprites[#sprites + 1] = { value = tostring(id), label = ('%d - %s'):format(id, name) }
end
for id, name in pairs(BlipCatalog.colours) do
    colours[#colours + 1] = { value = tostring(id), label = ('%d - %s'):format(id, name) }
end
local function byId(a, b) return tonumber(a.value) < tonumber(b.value) end
table.sort(sprites, byId)
table.sort(colours, byId)

editBlip = function(existing, revision)
    local editingId = existing and existing.id
    local draft = existing or {
        name = '', sprite = Config.Default.sprite, colour = Config.Default.colour,
        scale = Config.Default.scale, display = Config.Default.display,
        alpha = Config.Default.alpha, shortRange = Config.Default.shortRange,
        enabled = Config.Default.enabled, coords = currentCoords()
    }
    while true do
        local input = lib.inputDialog(editingId and locale('form.edit_title') or locale('form.create_title'), {
            { type = 'input', label = locale('form.name'), required = true, max = 64, default = draft.name },
            { type = 'select', label = locale('form.sprite'), required = true,
                searchable = true, options = sprites, default = tostring(draft.sprite) },
            { type = 'select', label = locale('form.colour'), required = true,
                searchable = true, options = colours, default = tostring(draft.colour) },
            { type = 'number', label = locale('form.scale'), required = true, min = 0.1, max = 5,
                precision = 2, step = 0.1, default = draft.scale },
            { type = 'select', label = locale('form.display'), required = true, default = tostring(draft.display),
                options = { { value = '2', label = locale('form.display_both') },
                    { value = '3', label = locale('form.display_map') },
                    { value = '5', label = locale('form.display_minimap') } } },
            { type = 'number', label = locale('form.alpha'), required = true,
                min = 0, max = 255, default = draft.alpha },
            { type = 'checkbox', label = locale('form.short_range'), checked = draft.shortRange },
            { type = 'checkbox', label = locale('form.enabled'), checked = draft.enabled },
            { type = 'number', label = locale('form.x'), required = true, precision = 3, default = draft.coords.x },
            { type = 'number', label = locale('form.y'), required = true, precision = 3, default = draft.coords.y },
            { type = 'number', label = locale('form.z'), required = true, precision = 3, default = draft.coords.z }
        }, { size = 'lg' })
        if not input then removePreview() openMain() return end
        local clean, reason = BlipValidation.clean({ name = input[1], sprite = tonumber(input[2]),
            colour = tonumber(input[3]), scale = input[4], display = tonumber(input[5]), alpha = input[6],
            shortRange = input[7] == true, enabled = input[8] == true,
            coords = { x = input[9], y = input[10], z = input[11] } })
        if clean then
            draft = clean
            local function showReview()
                lib.registerContext({ id = 'bc_review', title = locale('review.title', draft.name),
                    onExit = removePreview, options = {
                        { title = locale('review.save'), icon = 'floppy-disk', onSelect = function()
                            removePreview()
                            mutate(editingId and 'update' or 'create', editingId, revision, draft)
                            openMain()
                        end },
                        { title = locale('review.preview'), icon = 'eye',
                            description = locale('review.preview_desc'),
                            onSelect = function()
                                removePreview()
                                preview = makeBlip(draft, true)
                                busy = true
                                notify(locale('review.preview_notify'))
                                SetTimeout(15000, function()
                                    removePreview()
                                    busy = false
                                    showReview()
                                end)
                            end },
                        { title = locale('review.edit_fields'), icon = 'pen', onSelect = function()
                            removePreview()
                            draft.id = editingId
                            -- Keeps the original ID and revision while the fields are reviewed.
                            editBlip(draft, revision)
                        end },
                        { title = locale('review.cancel'), icon = 'xmark', onSelect = function() removePreview() openMain() end }
                    } })
                lib.showContext('bc_review')
            end
            showReview()
            return
        else
            notify(reason, 'error')
            -- Keep what the player typed so the dialog reopens with their values.
            draft = { id = editingId, name = type(input[1]) == 'string' and input[1] or draft.name,
                sprite = tonumber(input[2]) or draft.sprite, colour = tonumber(input[3]) or draft.colour,
                scale = input[4] or draft.scale, display = tonumber(input[5]) or draft.display,
                alpha = input[6] or draft.alpha, shortRange = input[7] == true, enabled = input[8] == true,
                coords = { x = input[9] or draft.coords.x, y = input[10] or draft.coords.y,
                    z = input[11] or draft.coords.z } }
        end
    end
end

openDetail = function(entry, revision)
    lib.registerContext({ id = 'bc_detail', title = ('#%d - %s'):format(entry.id, entry.name),
        menu = 'bc_list', options = {
            { title = locale('detail.edit'), icon = 'pen', onSelect = function() editBlip(entry, revision) end },
            { title = locale('detail.move_here'), icon = 'location-dot', onSelect = function()
                local copy = {}
                for k, v in pairs(entry) do copy[k] = v end
                copy.coords = currentCoords()
                mutate('update', entry.id, revision, copy)
                openMain()
            end },
            { title = entry.enabled and locale('detail.deactivate') or locale('detail.activate'), icon = 'power-off', onSelect = function()
                local copy = {}
                for k, v in pairs(entry) do copy[k] = v end
                copy.enabled = not entry.enabled
                mutate('update', entry.id, revision, copy)
                openMain()
            end },
            { title = locale('detail.waypoint'), icon = 'route', onSelect = function()
                SetNewWaypoint(entry.coords.x, entry.coords.y)
                notify(locale('detail.waypoint_set'))
            end },
            { title = locale('detail.delete'), icon = 'trash', iconColor = '#ef4444', onSelect = function()
                local answer = lib.alertDialog({ header = locale('detail.delete_header'),
                    content = locale('detail.delete_content', entry.id, entry.name), centered = true, cancel = true,
                    labels = { confirm = locale('detail.delete_confirm'), cancel = locale('detail.cancel') } })
                if answer == 'confirm' then mutate('delete', entry.id, revision) end
                openMain()
            end }
        } })
    lib.showContext('bc_detail')
end

openList = function(page, query)
    local entries, revision = {}, snapshot.revision
    for _, entry in ipairs(snapshot.blips) do
        if not query or entry.name:lower():find(query:lower(), 1, true) or tostring(entry.id) == query then
            entries[#entries + 1] = entry
        end
    end
    table.sort(entries, function(a, b) return a.id < b.id end)
    local pages = math.max(1, math.ceil(#entries / Config.PageSize))
    page = math.min(page, pages)
    local options = {}
    for i = (page - 1) * Config.PageSize + 1, math.min(page * Config.PageSize, #entries) do
        local entry = entries[i]
        options[#options + 1] = { title = ('#%d - %s'):format(entry.id, entry.name), icon = 'map-pin',
            description = locale('list.item_desc',
                entry.enabled and locale('list.active') or locale('list.inactive'), entry.sprite, entry.colour,
                entry.coords.x, entry.coords.y, entry.coords.z),
            onSelect = function() openDetail(entry, revision) end }
    end
    if #entries == 0 then options[#options + 1] = { title = locale('list.none'), disabled = true } end
    if page > 1 then options[#options + 1] = { title = locale('list.prev'), onSelect = function() openList(page - 1, query) end } end
    if page < pages then options[#options + 1] = { title = locale('list.next'), onSelect = function() openList(page + 1, query) end } end
    lib.registerContext({ id = 'bc_list', title = locale('list.title', #entries, page, pages),
        menu = 'bc_main', options = options })
    lib.showContext('bc_list')
end

openMain = function()
    if not refresh() then return end
    lib.registerContext({ id = 'bc_main', title = locale('title'), options = {
        { title = locale('main.create'), icon = 'plus', onSelect = function() editBlip(nil, snapshot.revision) end },
        { title = locale('main.manage', #snapshot.blips), icon = 'list', onSelect = function() openList(1) end },
        { title = locale('main.search'), icon = 'magnifying-glass', onSelect = function()
            local input = lib.inputDialog(locale('main.search_title'), { { type = 'input', label = locale('main.search_label'), required = true } })
            if input then openList(1, input[1]) else openMain() end
        end }
    } })
    lib.showContext('bc_main')
end

RegisterCommand(Config.Command, function()
    if busy or lib.getOpenContextMenu() or IsNuiFocused() then return end
    busy = true
    local access = request('access')
    if access then openMain() elseif access == false then notify(locale('no_permission'), 'error') end
    busy = false
end, false)

CreateThread(function()
    Wait(1000)
    for _ = 1, 5 do
        if refresh() then return end
        Wait(5000)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    removePreview()
    for _, handle in pairs(handles) do if DoesBlipExist(handle) then RemoveBlip(handle) end end
    local context = lib.getOpenContextMenu()
    if context and context:sub(1, 3) == 'bc_' then lib.hideContext(false) end
end)
