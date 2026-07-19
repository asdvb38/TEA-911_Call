fx_version 'cerulean'
game 'gta5'

author 'BinaryBeaco'
description '911紧急呼叫系统 - AI驱动调度与语音广播'
version '1.0.0'

shared_scripts {
    'shared/config.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/main.lua',
    'client/audio.lua',
    'client/ui.lua',
}

server_scripts {
    'server/main.lua',
    'server/ai.lua',
    'server/tts.lua',
    'server/report.lua',
    'server/dispatch.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'config/triggerwords.json',
}

lua54 'yes'
