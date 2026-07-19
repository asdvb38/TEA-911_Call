// ============================================================
// 911呼叫插件 — NUI JavaScript（仅音频播放，无视觉UI）
// ============================================================

document.addEventListener('DOMContentLoaded', function () {
    const ttsAudio = document.getElementById('ttsAudio');

    window.addEventListener('message', function (event) {
        const data = event.data;

        if (data.action === 'playAudio') {
            if (data.audioBase64) {
                ttsAudio.src = data.audioBase64;
            } else if (data.audioPath) {
                ttsAudio.src = 'nui://' + data.audioPath;
            }
            ttsAudio.play().catch(function (err) {
                console.warn('TTS音频播放失败:', err);
            });
        }
    });
});
