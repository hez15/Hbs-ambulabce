fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hbs_ambulance'
description 'HBS Ambulance - Advanced Medical System'
version '1.0.0'
author 'HBS Development'

shared_scripts {
    '@ox_lib/init.lua',
    'config/config.lua',
    'shared/sh_utils.lua',
    'locales/en.lua',
}

client_scripts {
    'client/cl_main.lua',
    'client/cl_hud.lua',
    'client/cl_death.lua',
    'client/cl_injury.lua',
    'client/cl_ems.lua',
    'client/cl_ems_research.lua',
    'client/cl_ems_terminal.lua',
    'client/cl_hospital.lua',
    'client/cl_items.lua',
    'client/cl_stress.lua',
    'client/cl_addiction.lua',
    'client/cl_vehicle.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_database.lua',
    'server/sv_main.lua',
    'server/sv_death.lua',
    'server/sv_injury.lua',
    'server/sv_ems.lua',
    'server/sv_ems_research.lua',
    'server/sv_hospital.lua',
    'server/sv_items.lua',
    'server/sv_stress.lua',
    'server/sv_addiction.lua',
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js',
}

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'oxmysql',
}
