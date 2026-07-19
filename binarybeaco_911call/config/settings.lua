-- ============================================================
-- 911 Call Plugin - Server Configuration
-- Edit these settings according to your server setup
-- ============================================================

Config = {}

-- API Settings for agnes-ai.com
Config.APISettings = {
    URL = "https://apihub.agnes-ai.com/v1/chat/completions",
    Model = "agnes-2.0-flash",
    APIKey = "YOUR_AGNES_API_KEY_HERE",
    Timeout = 30,          -- seconds to wait for AI response
    MaxRetries = 1,        -- retry attempts on failure
}

-- TTS Settings
Config.TTSSettings = {
    Provider = "azure",    -- "azure" or "edge"
    -- Azure TTS settings
    AzureRegion = "eastus",
    AzureKey = "YOUR_AZURE_TTS_KEY_HERE",
    Voice = "en-US-AriaNeural",
    -- Edge-TTS settings (fallback)
    EdgeVoice = "en-US-AriaNeural",
}

-- Dispatch Style
Config.DispatchStyle = "A"  -- "A" = Operator then Dispatcher, "B" = Unified

-- UI Settings
Config.WaitTime = 2000    -- milliseconds before "911 whats your emergency" message

-- Language (TTS always uses English)
Config.Language = "en"

-- Chat display settings
Config.ChatSettings = {
    OperatorPrefix = "[OPERATOR]",
    DispatcherPrefix = "[DISPATCHER]",
    SystemPrefix = "[911 SYSTEM]",
    CaseReportPrefix = "[CASE REPORT]",
}

-- Enable/disable features
Config.EnableDebug = false  -- set true for verbose console logging

-- ============================================================
-- HELPER: Get config value safely
-- ============================================================
function Config:Get(key, default)
    return self[key] or default
end

function Config:Debug(msg)
    if self.EnableDebug then
        print("^3[911call DEBUG]^7 " .. msg)
    end
end
