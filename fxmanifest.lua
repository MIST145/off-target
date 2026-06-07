fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'off-target'
author 'OffSey'
description 'Right-click context menu with ox_target and qtarget compatibility layers'
version '2.0.0'

provide 'ox_target'
provide 'qtarget'

shared_script 'shared/shared.lua'

client_scripts {
    'client/core/keys.lua',
    'client/core/contextmenu.lua',
    'client/convert/_utils.lua',
    'client/convert/target.lua',
    'client/convert/ox_target.lua',
    'client/convert/qtarget.lua',
}

ui_page 'web/build/index.html'

files {
    'web/build/index.html',
    'web/build/assets/*.js',
    'web/build/assets/*.css',
    'web/build/assets/**',
}
