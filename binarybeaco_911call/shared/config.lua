-- ============================================================
-- 911呼叫插件 — 共享配置（客户端可读）
-- 与服务端配置同步，供客户端使用
-- ============================================================

SharedConfig = {}

SharedConfig.DispatchStyle = GetResourceState('binarybeaco_911call') ~= 'missing' and GetConvar('dispatch_style', 'B') or 'B'
SharedConfig.WaitTime = 2000
SharedConfig.Language = 'en'
SharedConfig.ChatSettings = {
    OperatorPrefix = '[OPERATOR]',
    DispatcherPrefix = '[DISPATCHER]',
    SystemPrefix = '[911 SYSTEM]',
    CaseReportPrefix = '[CASE REPORT]',
}
