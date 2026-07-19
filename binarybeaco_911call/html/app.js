// ============================================================
// 911 Call Plugin - NUI JavaScript
// Handles chat messages, report display, and audio playback
// ============================================================

document.addEventListener('DOMContentLoaded', function () {
    const hintEl = document.getElementById('hint');
    const hintTextEl = hintEl.querySelector('.hint-text');
    const reportOverlay = document.getElementById('reportOverlay');
    const reportBody = document.getElementById('reportBody');
    const ttsAudio = document.getElementById('ttsAudio');
    const playAudioBtn = document.getElementById('playAudioBtn');

    // --- NUI Message Handler ---
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

    // --- Hint Functions ---
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

    // --- Report Functions ---
    function showReport(report) {
        if (!report) return;

        reportBody.innerHTML = '';

        const rows = [
            { label: 'Case Number', value: report.caseNumber || 'N/A' },
            { label: 'Type', value: report.emergencyType || 'Unknown' },
            { label: 'Location', value: report.location || 'Unknown' },
            { label: 'Caller', value: report.callerName || 'Unknown' },
            { label: 'Summary', value: report.summary || 'No details' },
            { label: 'People Involved', value: report.peopleInvolved || 'Not specified' },
            { label: 'Severity', value: report.severity || 'MEDIUM' },
            { label: 'Priority', value: report.priority || 'MEDIUM' },
            { label: 'Dispatch Codes', value: report.dispatchCodes || 'Pending' },
            { label: 'Units', value: report.units || 'None' },
            { label: 'Est. Response', value: report.estimatedResponse || 'TBD' },
            { label: 'Status', value: report.status || 'ACTIVE' },
        ];

        if (report.additionalNotes && report.additionalNotes !== '') {
            rows.push({ label: 'Notes', value: report.additionalNotes });
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

            // Color-code severity/priority
            if ((row.label === 'Severity' || row.label === 'Priority') && row.value) {
                var sev = row.value.toLowerCase();
                if (sev === 'critical') {
                    valueEl.classList.add('severity-critical');
                } else if (sev === 'high') {
                    valueEl.classList.add('severity-high');
                } else if (sev === 'medium') {
                    valueEl.classList.add('severity-medium');
                } else if (sev === 'low') {
                    valueEl.classList.add('severity-low');
                }
            }

            rowEl.appendChild(labelEl);
            rowEl.appendChild(valueEl);
            reportBody.appendChild(rowEl);
        });

        reportOverlay.classList.remove('hidden');
    }

    // --- Audio Functions ---
    function playTTSAudio(audioPath, audioBase64) {
        if (!audioPath && !audioBase64) return;

        if (audioBase64) {
            // Use base64 data directly
            ttsAudio.src = audioBase64;
        } else if (audioPath) {
            // Fallback: try nui:// protocol
            var audioUrl = 'nui://' + audioPath;
            ttsAudio.src = audioUrl;
        }

        ttsAudio.play().catch(function (err) {
            console.warn('TTS Audio playback failed:', err);
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

    // --- Visibility ---
    function setVisible(visible) {
        if (visible) {
            reportOverlay.classList.remove('hidden');
        } else {
            reportOverlay.classList.add('hidden');
        }
    }

    // --- Global functions for onclick handlers ---
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
