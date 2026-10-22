-- Copyright (c) 2026 N4K LABS. Licensed under the MIT License, see LICENSE.md.
local resource = GetCurrentResourceName()
local file = 'data/blips.json'
local state
local cooldowns = {}

-- Never overwrite a store that cannot be read or validated.
local function loadState()
    local raw = LoadResourceFile(resource, file)
    assert(raw and raw ~= '', locale('storage.missing'))
    local ok, decoded = pcall(json.decode, raw)
    assert(ok and type(decoded) == 'table' and decoded.schema == 1, locale('storage.invalid_json'))
    local n = BlipValidation.number
    assert(n(decoded.nextId, 1, 2147483647, true)
        and n(decoded.revision, 0, 2147483647, true)
        and type(decoded.blips) == 'table', locale('storage.invalid_meta'))
    local ids, clean, maximum, total = {}, {}, 0, 0
    for _ in pairs(decoded.blips) do total = total + 1 end
    assert(total == #decoded.blips, locale('storage.not_sequential'))
    for index = 1, total do
        local item = decoded.blips[index]
        local entry, reason = BlipValidation.clean(item)
        assert(entry, reason)
        assert(n(item.id, 1, 2147483646, true) and not ids[item.id], locale('storage.invalid_id'))
        entry.id = item.id
        ids[item.id] = true
        maximum = math.max(maximum, item.id)
        clean[#clean + 1] = entry
    end
    assert(decoded.nextId > maximum, locale('storage.invalid_counter'))
    decoded.blips = clean
    return decoded
end

local ok, result = pcall(loadState)
if not ok then
    print(('^1[%s] %s^0'):format(resource, locale('server.startup_blocked', result)))
else
    state = result
    print(('[%s] %s'):format(resource, locale('server.loaded', #state.blips)))
end

local function allowed(player)
    return BlipBridge.hasPermission(player)
end

lib.callback.register('n4k_blipcreator:snapshot', function()
    if not state then return { ok = false, message = locale('server.store_unavailable_console') } end
    return { ok = true, state = state }
end)

lib.callback.register('n4k_blipcreator:access', function(player)
    return allowed(player)
end)

lib.callback.register('n4k_blipcreator:mutate', function(player, action, id, expectedRevision, data)
    local function fail(message) return { ok = false, message = message } end
    if not allowed(player) then return fail(locale('no_permission')) end
    if not state then return fail(locale('server.store_unavailable')) end
    local now = GetGameTimer()
    if cooldowns[player] and now - cooldowns[player] >= 0
        and now - cooldowns[player] < Config.MutationCooldown then
        return fail(locale('server.cooldown'))
    end
    cooldowns[player] = now
    if action ~= 'create' and action ~= 'update' and action ~= 'delete' then
        return fail(locale('server.invalid_action'))
    end
    if expectedRevision ~= state.revision then
        return fail(locale('server.revision_conflict'))
    end
    local index
    if action ~= 'create' then
        if not BlipValidation.number(id, 1, 2147483646, true) then return fail(locale('server.invalid_id')) end
        for i, entry in ipairs(state.blips) do if entry.id == id then index = i break end end
        if not index then return fail(locale('server.not_found')) end
    elseif #state.blips >= Config.MaxBlips then
        return fail(locale('server.limit_reached'))
    end
    local entry, reason
    if action ~= 'delete' then
        entry, reason = BlipValidation.clean(data)
        if not entry then return fail(reason) end
    end
    local nextState = { schema = 1, nextId = state.nextId, revision = state.revision + 1, blips = {} }
    for i, old in ipairs(state.blips) do nextState.blips[i] = old end
    if action == 'create' then
        if state.nextId >= 2147483647 then return fail(locale('server.id_limit')) end
        entry.id = state.nextId
        nextState.nextId = state.nextId + 1
        nextState.blips[#nextState.blips + 1] = entry
    elseif action == 'update' then
        entry.id = id
        nextState.blips[index] = entry
    else
        table.remove(nextState.blips, index)
    end
    -- No yield between revision check, write and commit.
    local encoded = json.encode(nextState)
    local previous = json.encode(state)
    if not SaveResourceFile(resource, 'data/blips.backup.json', previous, #previous) then
        return fail(locale('server.backup_failed'))
    end
    if not SaveResourceFile(resource, file, encoded, #encoded) then
        return fail(locale('server.save_failed'))
    end
    state = nextState
    TriggerClientEvent('n4k_blipcreator:sync', -1, state)
    print(('[%s] player=%d action=%s blip=%d revision=%d'):format(resource, player, action,
        entry and entry.id or id, state.revision))
    return { ok = true, state = state }
end)

AddEventHandler('playerDropped', function() cooldowns[source] = nil end)
