fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'norte_staff'
description 'Comandos de staff do Norte Roleplay. Só funcionam com o modo de desenvolvedor do WHIP ligado (/w).'
version '1.0.0'

dependency 'whip_core'
whip_requires '1.0'

shared_scripts {
    '@whip_core/lib/satellite.lua',
    'config.lua',
    'settings.lua',
}

client_script 'client.lua'
server_script 'server.lua'
