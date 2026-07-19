-- ============================================================
-- 911呼叫插件 — 共享配置（客户端可读）
-- 与服务端配置同步，供客户端UI使用
-- ============================================================

SharedConfig = {}

SharedConfig.DispatchStyle = GetResourceState('binarybeaco_911call') ~= 'missing' and GetConvar('dispatch_style', 'A') or 'A'
SharedConfig.WaitTime = 2000
SharedConfig.Language = 'en'
SharedConfig.ChatSettings = {
    OperatorPrefix = '[接线员]',
    DispatcherPrefix = '[调度员]',
    SystemPrefix = '[911系统]',
    CaseReportPrefix = '[案件报告]',
}
