fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'off-target'
author 'OffSey'
description 'Right-click context menu with an ox_target compatibility layer'
version '1.0.0'

provide 'ox_target'
provide 'qtarget'
shared_script 'shared/shared.lua'

client_scripts {
    'client/keys.lua',
    'client/contextmenu.lua',
    'client/ox_target.lua',
    'client/qtarget.lua',
}

ui_page 'web/build/index.html'

files {
    'web/build/index.html',
    'web/build/assets/*.js',
    'web/build/assets/*.css',
    'web/build/assets/**',
}
