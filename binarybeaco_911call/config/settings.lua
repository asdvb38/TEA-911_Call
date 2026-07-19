-- ============================================================
-- 911呼叫插件 — 服务器配置
-- 根据服务器环境修改以下设置
-- ============================================================

Config = {}

-- agnes-ai.com API 设置
Config.APISettings = {
    URL = "https://apihub.agnes-ai.com/v1/chat/completions",
    Model = "agnes-2.0-flash",
    APIKey = "YOUR_AGNES_API_KEY_HERE",
    Timeout = 30,          -- AI响应等待时间（秒）
    MaxRetries = 1,        -- 失败重试次数
}

-- TTS（文字转语音）设置
Config.TTSSettings = {
    Provider = "edge",    -- "azure" 或 "edge"（edge为免费方案）
    -- Azure TTS 设置
    AzureRegion = "eastus",
    AzureKey = "YOUR_AZURE_TTS_KEY_HERE",
    Voice = "en-US-AriaNeural",
    -- Edge-TTS 设置（免费备选）
    EdgeVoice = "en-US-AriaNeural",
}

-- 调度风格
Config.DispatchStyle = "B"  -- "A" = 接线员→调度员，"B" = 统一处理

-- UI 设置
Config.WaitTime = 2000    -- 显示"911 请描述您的紧急情况"前的等待时间（毫秒）

-- 语言（TTS 始终使用英文播报）
Config.Language = "en"

-- 聊天显示设置
Config.ChatSettings = {
    OperatorPrefix = "[接线员]",
    DispatcherPrefix = "[调度员]",
    SystemPrefix = "[911系统]",
    CaseReportPrefix = "[案件报告]",
}

-- 调试开关
Config.EnableDebug = false  -- 设为 true 可在控制台查看详细日志

-- ============================================================
-- 辅助方法
-- ============================================================
function Config:Get(key, default)
    return self[key] or default
end

function Config:Debug(msg)
    if self.EnableDebug then
        print("^3[911呼叫 调试]^7 " .. msg)
    end
end
