-- ============================================================
-- 911 Call Plugin - Shared Configuration (Client-readable)
-- Mirrors essential server config for client-side use
-- ============================================================

SharedConfig = {}

SharedConfig.DispatchStyle = GetResourceState('binarybeaco_911call') ~= 'missing' and GetConvar('dispatch_style', 'A') or 'A'
SharedConfig.WaitTime = 2000
SharedConfig.Language = 'en'
SharedConfig.ChatSettings = {
    OperatorPrefix = '[OPERATOR]',
    DispatcherPrefix = '[DISPATCHER]',
    SystemPrefix = '[911 SYSTEM]',
    CaseReportPrefix = '[CASE REPORT]',
}
