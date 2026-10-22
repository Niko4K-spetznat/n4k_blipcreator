fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'n4k_blipcreator'
author 'N4K LABS'
description 'In-game blip creator and manager built on ox_lib (ESX, QBCore, Qbox)'
version '1.3.0'
license 'MIT'

dependency 'ox_lib'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/locale.lua',
    'shared/catalog.lua',
    'shared/validation.lua'
}

client_script 'client/main.lua'

server_scripts {
    'server/bridge.lua',
    'server/main.lua'
}

files { 'locales/*.json' }
