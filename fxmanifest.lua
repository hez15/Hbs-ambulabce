fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'hbs_ambulance'
description 'HBS Ambulance — Advanced Medical System built on qbx_ambulancejob'
version '1.0.0'
author 'HBS Development'

ox_lib 'locale'

dependencies {
    'qbx_core',
    'qbx_medical',
    'ox_lib',
    'ox_inventory',
    'ox_target',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config/config.lua',
    'shared/sh_utils.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    -- HBS bootstrap (must load before other HBS files)
    'client/cl_main.lua',
    -- HBS custom systems
    'client/cl_hud.lua',
    'client/cl_injury.lua',
    'client/cl_items.lua',
    'client/cl_stress.lua',
    'client/cl_addiction.lua',
    'client/cl_ems.lua',
    'client/cl_crafting.lua',
    -- qbx_ambulancejob original files
    'client/main.lua',
    'client/hospital.lua',
    'client/job.lua',
    'client/laststand.lua',
    'client/setdownedstate.lua',
    'client/wounding.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    -- HBS server files
    'server/sv_database.lua',
    'server/sv_main_hbs.lua',
    'server/sv_injury.lua',
    'server/sv_ems.lua',
    'server/sv_items.lua',
    'server/sv_stress.lua',
    'server/sv_addiction.lua',
    'server/sv_crafting.lua',
    -- qbx_ambulancejob original files
    'server/main.lua',
    'server/hospital.lua',
}

ui_page 'ui/index.html'

files {
    'locales/*.json',
    'config/client.lua',
    'config/shared.lua',
    'ui/index.html',
    'ui/style.css',
    'ui/script.js',
}
