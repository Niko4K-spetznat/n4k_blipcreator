-- Copyright (c) 2026 N4K LABS. Licensed under the MIT License, see LICENSE.md.
Config = {}

-- Chat command that opens the blip manager.
Config.Command = 'blipcreator'

-- Language of all texts: name of a file in locales/ (e.g. 'it', 'en').
-- 'auto' follows the ox_lib convar `setr ox:locale xx`. Missing keys fall back to 'en'.
Config.Locale = 'auto'

-- Server framework: 'auto', 'esx', 'qbcore' or 'qbox'.
-- 'auto' detects the started framework and stops if more than one is running.
Config.Framework = 'auto'
Config.FrameworkResources = {
    esx = 'es_extended', qbcore = 'qb-core', qbox = 'qbx_core'
}

-- Who can open the command and create/edit/delete blips.
-- One matching group/permission is enough. An empty list denies everyone.
-- Permissions are checked on the server at every request, with no license whitelist.
-- Restart the resource after editing.
Config.Permissions = {
    esx = { 'admin', 'superadmin' }, -- xPlayer.getGroup()
    qbcore = { 'admin', 'god' },     -- QBCore.Functions.HasPermission
    qbox = { 'admin' },              -- ACE object of the framework, not 'group.admin'
}

Config.MaxBlips = 300
Config.MutationCooldown = 750 -- milliseconds, enforced on the server
Config.PageSize = 15          -- blips per page in the manage list

-- Default values of the "create blip" form.
Config.Default = {
    sprite = 1, colour = 0, scale = 0.8, display = 2,
    alpha = 255, shortRange = false, enabled = true
}
