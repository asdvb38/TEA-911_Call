// ============================================================
// 911呼叫插件 — NUI JavaScript
// 处理聊天消息、报告显示和音频播放
// ============================================================

document.addEventListener('DOMContentLoaded', function () {
    const hintEl = document.getElementById('hint');
    const hintTextEl = hintEl.querySelector('.hint-text');
    const reportOverlay = document.getElementById('reportOverlay');
    const reportBody = document.getElementById('reportBody');
    const ttsAudio = document.getElementById('ttsAudio');
    const playAudioBtn = document.getElementById('playAudioBtn');

    // --- NUI 消息处理器 ---
    window.addEventListener('message', function (event) {
        const data = event.data;

        switch (data.action) {
            case 'showHint':
                showHint(data.text);
                break;

            case 'hideHint':
                hideHint();
                break;

            case 'showReport':
                showReport(data.report);
                break;

            case 'playAudio':
                playTTSAudio(data.audioPath, data.audioBase64);
                break;

            case 'setVisible':
                setVisible(data.visible);
                break;

            default:
                break;
        }
    });

    // --- 提示相关函数 ---
    function showHint(text) {
        hintTextEl.textContent = text;
        hintEl.classList.remove('hidden');

        setTimeout(function () {
            hintEl.classList.add('hidden');
        }, 5000);
    }

    function hideHint() {
        hintEl.classList.add('hidden');
    }

    // --- 报告相关函数 ---
    function showReport(report) {
        if (!report) return;

        reportBody.innerHTML = '';

        const rows = [
            { label: '案件编号', value: report.caseNumber || '未知' },
            { label: '类型', value: report.emergencyType || '未知' },
            { label: '地点', value: report.location || '未知' },
            { label: '报案人', value: report.callerName || '未知' },
            { label: '摘要', value: report.summary || '无详细信息' },
            { label: '涉及人员', value: report.peopleInvolved || '未说明' },
            { label: '严重程度', value: report.severity || '中' },
            { label: '优先级', value: report.priority || '中' },
            { label: '调度代码', value: report.dispatchCodes || '待定' },
            { label: '出动单位', value: report.units || '无' },
            { label: '预计响应', value: report.estimatedResponse || '待定' },
            { label: '状态', value: report.status || '活跃' },
        ];

        if (report.additionalNotes && report.additionalNotes !== '') {
            rows.push({ label: '备注', value: report.additionalNotes });
        }

        rows.forEach(function (row) {
            var rowEl = document.createElement('div');
            rowEl.className = 'report-row';

            var labelEl = document.createElement('div');
            labelEl.className = 'report-label';
            labelEl.textContent = row.label;

            var valueEl = document.createElement('div');
            valueEl.className = 'report-value';
            valueEl.textContent = row.value;

            // 严重程度/优先级颜色标记
            if ((row.label === '严重程度' || row.label === '优先级') && row.value) {
                var sev = row.value.toLowerCase();
                if (sev === '危急' || sev === 'critical') {
                    valueEl.classList.add('severity-critical');
                } else if (sev === '高' || sev === 'high') {
                    valueEl.classList.add('severity-high');
                } else if (sev === '中' || sev === 'medium') {
                    valueEl.classList.add('severity-medium');
                } else if (sev === '低' || sev === 'low') {
                    valueEl.classList.add('severity-low');
                }
            }

            rowEl.appendChild(labelEl);
            rowEl.appendChild(valueEl);
            reportBody.appendChild(rowEl);
        });

        // 显示覆盖层
        reportOverlay.classList.remove('hidden');
    }

    // --- 音频相关函数 ---
    function playTTSAudio(audioPath, audioBase64) {
        if (!audioPath && !audioBase64) return;

        if (audioBase64) {
            // 使用Base64数据直接播放
            ttsAudio.src = audioBase64;
        } else if (audioPath) {
            // 降级：尝试 nui:// 协议
            var audioUrl = 'nui://' + audioPath;
            ttsAudio.src = audioUrl;
        }

        ttsAudio.play().catch(function (err) {
            console.warn('TTS音频播放失败:', err);
        });
    }

    if (playAudioBtn) {
        playAudioBtn.addEventListener('click', function () {
            var audioPath = reportOverlay.dataset.audioPath;
            var audioBase64 = reportOverlay.dataset.audioBase64;
            if (audioPath || audioBase64) {
                playTTSAudio(audioPath, audioBase64);
            }
        });
    }

    // --- 可见性控制 ---
    function setVisible(visible) {
        if (visible) {
            reportOverlay.classList.remove('hidden');
        } else {
            reportOverlay.classList.add('hidden');
        }
    }

    // --- 全局函数（供 onclick 调用） ---
    window.dismissReport = function () {
        reportOverlay.classList.add('hidden');
        ttsAudio.pause();
        ttsAudio.currentTime = 0;
        fetch('https://binarybeaco_911call/dismiss', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({}),
        }).catch(function () { });
    };
});
