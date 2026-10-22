-- Copyright (c) 2026 N4K LABS. Licensed under the MIT License, see LICENSE.md.
BlipBridge = {}
local resourceName = GetCurrentResourceName()
local lastError

local function fail(message)
    error(message, 0) -- level 0: no file:line prefix in the console message
end

local function resolve()
    local resources = Config.FrameworkResources
    local selected = Config.Framework
    if type(selected) ~= 'string' then
        fail(locale('bridge.framework_not_string'))
    end
    selected = selected:match('^%s*(.-)%s*$'):lower()
    local aliases = { qbx = 'qbox', qbx_core = 'qbox', ['qb-core'] = 'qbcore', es_extended = 'esx' }
    selected = aliases[selected] or selected
    if type(resources) ~= 'table' then fail(locale('bridge.missing_resources')) end
    local function status(framework)
        local name = resources[framework]
        if type(name) ~= 'string' or name == '' then
            fail(locale('bridge.missing_resource_name', framework))
        end
        return GetResourceState(name)
    end
    if selected == 'auto' then
        local esxState, qboxState, qbState = status('esx'), status('qbox'), status('qbcore')
        local esx, qbox, qb = esxState == 'started', qboxState == 'started', qbState == 'started'
        if esx and (qbox or qb) then
            fail(locale('bridge.multiple_frameworks'))
        end
        -- Qbox before qb-core: it may expose the QB compatibility bridge.
        selected = qbox and 'qbox' or qb and 'qbcore' or esx and 'esx' or nil
        if not selected then
            fail(locale('bridge.no_framework',
                resources.esx, esxState, resources.qbox, qboxState, resources.qbcore, qbState))
        end
    end
    if selected ~= 'esx' and selected ~= 'qbcore' and selected ~= 'qbox' then
        fail(locale('bridge.invalid_framework', selected))
    end
    local resource = resources[selected]
    local resourceState = status(selected)
    if resourceState ~= 'started' then
        fail(locale('bridge.framework_not_started', selected, resource, resourceState))
    end
    return selected, resource
end

local function check(player)
    local framework, resource = resolve()
    local permissions = Config.Permissions[framework]
    if type(permissions) ~= 'table' or #permissions == 0 then return false end
    if framework == 'esx' then
        local core = exports[resource]:getSharedObject()
        local xPlayer = core.GetPlayerFromId(player)
        if not xPlayer then return false end
        local group = xPlayer.getGroup()
        for _, permission in ipairs(permissions) do
            if type(permission) == 'string' and group == permission then return true end
        end
    elseif framework == 'qbcore' then
        local core = exports[resource]:GetCoreObject()
        if not core.Functions.GetPlayer(player) then return false end
        for _, permission in ipairs(permissions) do
            if type(permission) == 'string' and core.Functions.HasPermission(player, permission) then return true end
        end
    else
        if not exports[resource]:GetPlayer(player) then return false end
        -- Qbox deprecated HasPermission in v1.8.0: use the official ACE system.
        for _, permission in ipairs(permissions) do
            if type(permission) == 'string' and IsPlayerAceAllowed(player, permission) then return true end
        end
    end
    return false
end

function BlipBridge.hasPermission(player)
    if type(player) ~= 'number' or player <= 0 or player % 1 ~= 0 then return false end
    -- Permissions are never cached: revocation, logout and source reuse take effect immediately.
    local ok, result = pcall(check, player)
    if not ok then
        if lastError ~= tostring(result) then
            print(('^1[%s] %s^0'):format(resourceName, locale('bridge.denied', result)))
            lastError = tostring(result)
        end
        return false
    end
    lastError = nil
    return result == true
end
