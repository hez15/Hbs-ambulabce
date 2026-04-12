'use strict';

// Resource name set by Lua via 'init' message — used for NUI callbacks
let _resourceName = 'hbs-ambulabce';

// ── NUI message router ────────────────────────────────────────────────────────

window.addEventListener('message', function (e) {
    const data = e.data;
    if (!data || !data.action) return;

    switch (data.action) {
        case 'showHUD':
        case 'showHud':        showHUD();                              break;
        case 'hideHUD':
        case 'hideHud':        hideHUD();                             break;
        case 'updateHealth':   updateHealth(data.value);              break;
        case 'updateStress':   updateStress(data.value);              break;
        case 'updateAddiction':updateAddiction(data.value);           break;
        case 'updateInjuries': updateInjuries(data.injuries);         break;
        case 'startMinigame': startMinigame(data);        break;
        case 'minigamePress': minigamePress();             break;
        case 'stopMinigame':  stopMinigame(false);         break;
        case 'updateHud':
            if (data.health    !== undefined) updateHealth(data.health);
            if (data.stress    !== undefined) updateStress(data.stress);
            if (data.addiction !== undefined) updateAddiction(data.addiction);
            if (data.injuries  !== undefined) updateInjuries(data.injuries);
            if (data.inPain    !== undefined) setIcon('pain', data.inPain);
            if (data.bloodloss !== undefined) setIcon('bloodloss', data.bloodloss);
            break;
        case 'withdrawalActive': setIcon('withdrawal', true);           break;
        case 'withdrawalEnded':  setIcon('withdrawal', false);          break;
        case 'showResearchTerminal': showResearchTerminal(data);       break;
        case 'hideResearchTerminal': hideResearchTerminal();           break;
        case 'updateResearch':       rtUpdateResearch(data.research);  break;
        case 'showKnockoutScreen': showKnockoutScreen(data.duration || 5000); break;
        case 'hideKnockoutScreen': hideKnockoutScreen();                     break;
        case 'showDeathScreen':showDeathScreen(data.bleedoutMs, data.resourceName); break;
        case 'hideDeathScreen':hideDeathScreen();                     break;
        case 'callEMSResult':  onCallEMSResult(data.success, data.cooldown); break;
        case 'updateTimer':    updateTimer(data.ms);                  break;
        case 'showForceRespawn': showForceRespawn();                  break;
        case 'setIcon':        setIcon(data.icon, data.visible);      break;
    }
});

// ── HUD visibility ────────────────────────────────────────────────────────────

function showHUD() {
    document.getElementById('medical-hud').classList.remove('hidden');
}

function hideHUD() {
    document.getElementById('medical-hud').classList.add('hidden');
}

// ── Medical Minigame ──────────────────────────────────────────────────────────

const MG_THEMES = {
    defib:   { color: '#e03030', icon: '⚡', label: 'Defibrillator',    mode: 'bar'   },
    treat:   { color: '#22c55e', icon: '🩹', label: 'Treating Wounds',  mode: 'bar'   },
    suture:  { color: '#22c55e', icon: '🩺', label: 'Suturing Wound',   mode: 'bar'   },
    detox:   { color: '#7c3aed', icon: '💉', label: 'Administer Detox', mode: 'bar'   },
    surgery: { color: '#0ea5e9', icon: '🔬', label: 'Surgery',          mode: 'bar'   },
    cpr:     { color: '#f97316', icon: '💓', label: 'CPR Compressions', mode: 'press' },
};

const MG_DIFF = {
    easy:   { speed: 48,  zoneSize: 30, rounds: 1 },
    medium: { speed: 78,  zoneSize: 20, rounds: 2 },
    hard:   { speed: 110, zoneSize: 13, rounds: 3 },
};

let mg = null;  // active minigame state
let mgRaf = null;

function startMinigame(cfg) {
    const diff   = MG_DIFF[cfg.difficulty] || MG_DIFF.medium;
    const theme  = MG_THEMES[cfg.theme]    || MG_THEMES.treat;
    const rounds = cfg.rounds || diff.rounds;
    const pressTarget = cfg.pressTarget || 12;

    mg = {
        theme, diff,
        rounds, current: 0, results: [],
        cursor: 0, dir: 1,
        zoneStart: randomZone(diff.zoneSize),
        lastTs: null,
        mode: theme.mode || 'bar',
        pressTarget, pressCount: 0,
    };

    // Apply theme colour and header
    const el = document.getElementById('minigame');
    el.style.setProperty('--mg-color', theme.color);
    document.getElementById('mg-icon').textContent  = theme.icon;
    document.getElementById('mg-label').textContent = theme.label;

    if (mg.mode === 'press') {
        // CPR press mode
        document.getElementById('mg-track-wrap').classList.add('hidden');
        document.getElementById('mg-press-wrap').classList.remove('hidden');
        document.getElementById('mg-press-cur').textContent = '0';
        document.getElementById('mg-press-max').textContent = pressTarget;
        document.getElementById('mg-press-bar-fill').style.width = '0%';
        document.getElementById('mg-hint').textContent = 'Press [E] repeatedly for compressions';
        document.getElementById('mg-rounds').classList.add('hidden');
    } else {
        // Precision bar mode
        document.getElementById('mg-track-wrap').classList.remove('hidden');
        document.getElementById('mg-press-wrap').classList.add('hidden');
        document.getElementById('mg-zone').style.borderColor = hexToRgba(theme.color, 0.65);
        document.getElementById('mg-zone').style.background  = hexToRgba(theme.color, 0.22);
        document.getElementById('mg-cursor').style.background = '#ffffff';
        document.getElementById('mg-cursor').style.boxShadow  = '0 0 6px rgba(255,255,255,0.8)';
        document.getElementById('mg-cursor').className = '';
        document.getElementById('mg-hint').textContent = 'Press [E] when the marker is inside the zone';
        document.getElementById('mg-rounds').classList.remove('hidden');
        applyZone();
        updateRoundCounter();
        if (mgRaf) cancelAnimationFrame(mgRaf);
        mgRaf = requestAnimationFrame(mgTick);
    }

    el.classList.remove('hidden');
}

function mgTick(ts) {
    if (!mg) return;
    const delta = mg.lastTs ? (ts - mg.lastTs) / 1000 : 0;
    mg.lastTs = ts;

    mg.cursor += mg.dir * mg.diff.speed * delta;
    if (mg.cursor >= 100) { mg.cursor = 100; mg.dir = -1; }
    if (mg.cursor <= 0)   { mg.cursor = 0;   mg.dir =  1; }

    document.getElementById('mg-cursor').style.left = mg.cursor + '%';
    mgRaf = requestAnimationFrame(mgTick);
}

function minigamePress() {
    if (!mg) return;

    if (mg.mode === 'press') {
        // CPR compression tap
        mg.pressCount++;
        const pct = Math.min(100, (mg.pressCount / mg.pressTarget) * 100);
        document.getElementById('mg-press-cur').textContent = mg.pressCount;
        document.getElementById('mg-press-bar-fill').style.width = pct + '%';

        // Bounce the counter to give tactile feel
        const countEl = document.getElementById('mg-press-count');
        countEl.style.transform = 'scale(1.18)';
        setTimeout(() => { countEl.style.transform = 'scale(1)'; }, 80);

        if (mg.pressCount >= mg.pressTarget) {
            setTimeout(() => stopMinigame(true), 250);
        }
        return;
    }

    // Precision bar mode
    const pos = mg.cursor;
    const hit = pos >= mg.zoneStart && pos <= (mg.zoneStart + mg.diff.zoneSize);

    const cursor = document.getElementById('mg-cursor');
    cursor.className = hit ? 'hit' : 'miss';
    setTimeout(() => { cursor.className = ''; cursor.style.background = '#ffffff'; }, 280);

    mg.results.push(hit);
    mg.current++;

    if (mg.current >= mg.rounds) {
        const allGood = mg.results.every(Boolean);
        setTimeout(() => stopMinigame(allGood), 320);
    } else {
        mg.zoneStart = randomZone(mg.diff.zoneSize);
        applyZone();
        updateRoundCounter();
    }
}

function stopMinigame(success) {
    if (!mg) return;
    cancelAnimationFrame(mgRaf);
    mgRaf = null;
    // Reset both mode sections so they're ready for next use
    document.getElementById('mg-track-wrap').classList.remove('hidden');
    document.getElementById('mg-press-wrap').classList.add('hidden');
    document.getElementById('minigame').classList.add('hidden');
    mg = null;

    fetch(`https://${_resourceName}/minigameResult`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ success: success === true }),
    }).catch(() => {});
}

function applyZone() {
    const zone = document.getElementById('mg-zone');
    zone.style.left  = mg.zoneStart + '%';
    zone.style.width = mg.diff.zoneSize + '%';
}

function updateRoundCounter() {
    document.getElementById('mg-round-cur').textContent = mg.current + 1;
    document.getElementById('mg-round-max').textContent = mg.rounds;
}

function randomZone(size) {
    return 8 + Math.random() * (84 - size);
}

function hexToRgba(hex, alpha) {
    const r = parseInt(hex.slice(1,3), 16);
    const g = parseInt(hex.slice(3,5), 16);
    const b = parseInt(hex.slice(5,7), 16);
    return `rgba(${r},${g},${b},${alpha})`;
}

// ── Research Terminal ─────────────────────────────────────────────────────────

const RT_ABILITY_ICONS = {
    hands_only_revive:  '🖐',
    rapid_revive:       '⚡',
    patient_examine:    '🔍',
    trauma_splint:      '🦴',
    iv_therapy:         '💉',
    addiction_therapy:  '💊',
    adrenaline_revive:  '💥',
    full_detox:         '🧪',
    full_surgery:       '🔬',
    mass_casualty:      '📡',
};

// ── Research Terminal ─────────────────────────────────────────────────────────

let _rtDiseases = [];   // cached disease list for analyze actions

function rtSwitchTab(tab) {
    document.getElementById('rt-content-abilities').classList.toggle('hidden', tab !== 'abilities');
    document.getElementById('rt-content-diseases').classList.toggle('hidden', tab !== 'diseases');
    document.getElementById('rt-tab-abilities').classList.toggle('rt-tab-active', tab === 'abilities');
    document.getElementById('rt-tab-diseases').classList.toggle('rt-tab-active', tab === 'diseases');
}

function rtBuildDiseaseList(diseases) {
    _rtDiseases = diseases || [];
    const list = document.getElementById('rt-disease-list');
    list.innerHTML = '';
    if (!_rtDiseases.length) {
        list.innerHTML = '<div class="rt-disease-empty">No disease data available.</div>';
        return;
    }
    _rtDiseases.forEach(d => {
        const pct      = Math.min(100, Math.round((d.researched / d.researchTarget) * 100));
        const full     = d.researched >= d.researchTarget;
        const debufStr = d.debuffs && d.debuffs.length ? d.debuffs.join(' · ') : 'None';
        const card = document.createElement('div');
        card.className = 'rt-disease-card' + (full ? ' rt-disease-full' : '');
        card.dataset.disease = d.id;
        card.innerHTML = `
            <div class="rt-disease-top">
                <div class="rt-disease-name">${d.label}</div>
                <div class="rt-disease-outbreak ${d.outbreak > 0 ? 'active' : ''}">
                    ${d.outbreak > 0 ? '⚠ ' + d.outbreak + ' infected' : 'No active cases'}
                </div>
            </div>
            <div class="rt-disease-meta">
                <span>Stages: ${d.stages}</span>
                <span>${d.spreads ? '· Contagious' : '· Non-contagious'}</span>
                <span>· Treat: ${d.treatItem}</span>
            </div>
            <div class="rt-disease-debuffs">Debuffs: ${debufStr}</div>
            <div class="rt-disease-progress-row">
                <div class="rt-disease-progress-bg">
                    <div class="rt-disease-progress-fill" style="width:${pct}%"></div>
                </div>
                <span class="rt-disease-progress-label">${d.researched} / ${d.researchTarget}</span>
            </div>
            <button class="rt-analyze-btn" onclick="rtAnalyzeSample('${d.id}')" ${full ? 'disabled' : ''}>
                ${full ? '✓ Fully Researched' : '🔬 Analyze Sample'}
            </button>
        `;
        list.appendChild(card);
    });
}

function rtAnalyzeSample(disease) {
    fetch(`https://${_resourceName}/analyzeSample`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ disease }),
    }).catch(() => {});
}

function rtUpdateResearch(research) {
    // Update progress bars on open cards without a full rebuild
    _rtDiseases.forEach(d => {
        if (research[d.id] !== undefined) {
            d.researched = research[d.id];
        }
    });
    const list = document.getElementById('rt-disease-list');
    if (!list) return;
    _rtDiseases.forEach(d => {
        const card = list.querySelector(`[data-disease="${d.id}"]`);
        if (!card) return;
        const pct  = Math.min(100, Math.round((d.researched / d.researchTarget) * 100));
        const full = d.researched >= d.researchTarget;
        const fill = card.querySelector('.rt-disease-progress-fill');
        const lbl  = card.querySelector('.rt-disease-progress-label');
        const btn  = card.querySelector('.rt-analyze-btn');
        if (fill) fill.style.width = pct + '%';
        if (lbl)  lbl.textContent  = d.researched + ' / ' + d.researchTarget;
        if (btn) {
            btn.disabled    = full;
            btn.textContent = full ? '✓ Fully Researched' : '🔬 Analyze Sample';
        }
        card.classList.toggle('rt-disease-full', full);
    });
}

function showResearchTerminal(data) {
    const { tier, xp, nextTier, nextXP, tierLabel, nextLabel, abilities, diseases } = data;

    document.getElementById('rt-tier-badge').textContent = 'TIER ' + tier;
    document.getElementById('rt-tier-label').textContent = tierLabel || 'EMT';

    if (nextXP) {
        document.getElementById('rt-xp-text').textContent    = 'XP: ' + xp + ' / ' + nextXP;
        document.getElementById('rt-next-label').textContent = '→ ' + (nextLabel || '');
        const pct = Math.max(0, Math.min(100, (xp / nextXP) * 100));
        document.getElementById('rt-xp-bar-fill').style.width = pct + '%';
    } else {
        document.getElementById('rt-xp-text').textContent    = 'XP: ' + xp + '  (Max Tier)';
        document.getElementById('rt-next-label').textContent = '✓ Mastered';
        document.getElementById('rt-xp-bar-fill').style.width = '100%';
    }

    // Build ability rows
    const list = document.getElementById('rt-abilities-list');
    list.innerHTML = '';
    if (abilities) {
        abilities.forEach(ab => {
            const row = document.createElement('div');
            row.className = 'rt-ability ' + (ab.unlocked ? 'unlocked' : 'locked');
            const icon     = RT_ABILITY_ICONS[ab.id] || '🔒';
            const badgeText = ab.unlocked ? 'UNLOCKED' : ('TIER ' + ab.requiredTier);
            row.innerHTML = `
                <div class="rt-ability-icon">${icon}</div>
                <div class="rt-ability-body">
                    <div class="rt-ability-name">${ab.label}</div>
                    <div class="rt-ability-desc">${ab.desc || ''}</div>
                </div>
                <div class="rt-ability-badge">${badgeText}</div>
            `;
            list.appendChild(row);
        });
    }

    // Build disease tab
    rtBuildDiseaseList(diseases);

    // Always open on Abilities tab
    rtSwitchTab('abilities');

    document.getElementById('research-terminal').classList.remove('hidden');
}

function hideResearchTerminal() {
    document.getElementById('research-terminal').classList.add('hidden');
    fetch(`https://${_resourceName}/closeResearchTerminal`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
    }).catch(() => {});
}

function closeResearchTerminal() {
    hideResearchTerminal();
}

// ── Health bar ────────────────────────────────────────────────────────────────

function updateHealth(value) {
    const clamped = Math.max(0, Math.min(100, value));
    const fill = document.getElementById('health-fill');
    fill.style.width = clamped + '%';
    document.getElementById('health-val').textContent = Math.round(clamped);
    if (clamped <= 25) {
        fill.classList.add('low');
    } else {
        fill.classList.remove('low');
    }
}

// ── Stress bar ────────────────────────────────────────────────────────────────

function updateStress(value) {
    const clamped = Math.max(0, Math.min(100, value));
    document.getElementById('stress-fill').style.width = clamped + '%';
    document.getElementById('stress-val').textContent  = Math.round(clamped);
}

// ── Addiction bar ─────────────────────────────────────────────────────────────

function updateAddiction(addictionTable) {
    // addictionTable: { morphine: 2, painkiller: 1, ... } — values are plain numbers
    let maxLevel = 0;
    if (addictionTable && typeof addictionTable === 'object') {
        for (const sub in addictionTable) {
            const lvl = typeof addictionTable[sub] === 'number' ? addictionTable[sub] : 0;
            if (lvl > maxLevel) maxLevel = lvl;
        }
    }

    const row = document.getElementById('addiction-row');
    if (maxLevel > 0) {
        row.classList.remove('hidden');
        const pct = (maxLevel / 4) * 100;
        document.getElementById('addiction-fill').style.width = pct + '%';
        document.getElementById('addiction-val').textContent  = maxLevel;
    } else {
        row.classList.add('hidden');
    }
}

// ── Body diagram injuries ─────────────────────────────────────────────────────

const SEV_CLASSES = ['sev-scratch', 'sev-minor', 'sev-fracture', 'sev-critical'];

// Maps HBS part names → SVG element IDs
const PART_IDS = {
    head:      'bp-head',
    torso:     'bp-torso',
    left_arm:  'bp-left_arm',
    right_arm: 'bp-right_arm',
    left_leg:  'bp-left_leg',
    right_leg: 'bp-right_leg',
};

function updateInjuries(injuries) {
    // injuries: { head: 'scratch', torso: 'critical', ... } or {}
    for (const part in PART_IDS) {
        const el = document.getElementById(PART_IDS[part]);
        if (!el) continue;
        SEV_CLASSES.forEach(c => el.classList.remove(c));
        const sev = injuries && injuries[part];
        if (sev) {
            el.classList.add('sev-' + sev);
        }
    }
}

// ── Status icons ──────────────────────────────────────────────────────────────

function setIcon(icon, visible) {
    const el = document.getElementById('icon-' + icon);
    if (!el) return;
    if (visible) {
        el.classList.remove('hidden');
    } else {
        el.classList.add('hidden');
    }
}

// ── Death screen ──────────────────────────────────────────────────────────────

// ── Knockout Screen ───────────────────────────────────────────────────────────

let koTimer = null;

function showKnockoutScreen(durationMs) {
    const screen = document.getElementById('knockout-screen');
    screen.classList.remove('hidden');

    // Reset bar
    const fill = document.getElementById('ko-bar-fill');
    fill.style.transition = 'none';
    fill.style.width = '0%';

    // Animate fill over duration using rAF for smooth progress
    if (koTimer) clearInterval(koTimer);
    const startTs  = performance.now();
    const endTs    = startTs + durationMs;

    function koTick() {
        const now  = performance.now();
        const pct  = Math.min(100, ((now - startTs) / durationMs) * 100);
        fill.style.width = pct + '%';
        if (now < endTs) {
            koTimer = requestAnimationFrame(koTick);
        } else {
            fill.style.width = '100%';
            // Auto-hide after bar completes
            hideKnockoutScreen();
        }
    }

    koTimer = requestAnimationFrame(koTick);
}

function hideKnockoutScreen() {
    if (koTimer) { cancelAnimationFrame(koTimer); koTimer = null; }
    document.getElementById('knockout-screen').classList.add('hidden');
}

// ── Death Screen ──────────────────────────────────────────────────────────────

let bleedoutTimer = null;
let bleedoutEnd   = null;

function showDeathScreen(bleedoutMs, resourceName) {
    if (resourceName) _resourceName = resourceName;
    const screen = document.getElementById('death-screen');
    screen.classList.remove('hidden');

    document.getElementById('force-block').classList.add('hidden');
    document.getElementById('btn-block').classList.remove('hidden');

    // Button locked until timer expires
    const btn = document.getElementById('btn-respawn');
    if (btn) btn.disabled = true;

    if (bleedoutMs && bleedoutMs > 0) {
        bleedoutEnd = Date.now() + bleedoutMs;
        startTimer();
    } else {
        document.getElementById('timer-block').classList.add('hidden');
    }
}

function hideDeathScreen() {
    document.getElementById('death-screen').classList.add('hidden');
    stopTimer();
}

function showForceRespawn() {
    // Hide countdown button block, show force-respawn block with danger button
    document.getElementById('btn-block').classList.add('hidden');
    document.getElementById('force-block').classList.remove('hidden');
    stopTimer();
    document.getElementById('timer-value').textContent = '0:00';

    // Re-enable any button in force-block
    document.querySelectorAll('#force-block .death-btn').forEach(b => b.disabled = false);
}

function startTimer() {
    stopTimer();
    document.getElementById('timer-block').classList.remove('hidden');
    updateTimer();
    bleedoutTimer = setInterval(updateTimer, 500);
}

function stopTimer() {
    if (bleedoutTimer) {
        clearInterval(bleedoutTimer);
        bleedoutTimer = null;
    }
}

function updateTimer(remainingMs) {
    let ms;
    if (remainingMs !== undefined) {
        ms = remainingMs;
        bleedoutEnd = Date.now() + ms;
    } else {
        ms = bleedoutEnd ? Math.max(0, bleedoutEnd - Date.now()) : 0;
    }

    const totalSec = Math.ceil(ms / 1000);
    const m = Math.floor(totalSec / 60);
    const s = totalSec % 60;
    document.getElementById('timer-value').textContent =
        m + ':' + String(s).padStart(2, '0');

    if (ms <= 0) {
        stopTimer();
        showForceRespawn();
    }
}

// ── Call EMS button ───────────────────────────────────────────────────────────

let emsCallTimer = null;

function callEMS() {
    const btn = document.getElementById('btn-call-ems');
    if (!btn || btn.disabled) return;

    btn.disabled = true;
    btn.textContent = '🚨 Calling...';

    fetch(`https://${_resourceName}/callEMS`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
    }).catch(() => {});
}

function onCallEMSResult(success, cooldownSec) {
    const btn = document.getElementById('btn-call-ems');
    if (!btn) return;

    if (success) {
        btn.textContent = '✓ EMS Notified';
        btn.classList.add('ems-notified');
        // Re-enable after cooldown
        if (emsCallTimer) clearTimeout(emsCallTimer);
        emsCallTimer = setTimeout(() => {
            btn.disabled = false;
            btn.textContent = '🚨 Call EMS';
            btn.classList.remove('ems-notified');
        }, (cooldownSec || 120) * 1000);
    } else {
        // On cooldown — show remaining time then re-enable
        const remaining = cooldownSec || 120;
        btn.textContent = `⏳ Cooldown (${remaining}s)`;
        if (emsCallTimer) clearTimeout(emsCallTimer);
        emsCallTimer = setTimeout(() => {
            btn.disabled = false;
            btn.textContent = '🚨 Call EMS';
            btn.classList.remove('ems-notified');
        }, remaining * 1000);
    }
}

// ── Respawn button ────────────────────────────────────────────────────────────

function onRespawn() {
    const will = document.getElementById('will-input').value.trim();

    // Hide immediately — don't wait on fetch
    hideDeathScreen();

    // Notify Lua for server-side respawn logic
    fetch(`https://${_resourceName}/respawn`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ lastWords: will }),
    }).catch(() => {
        // Fetch failed — post a plain window message as fallback
        window.dispatchEvent(new MessageEvent('message', {
            data: { action: 'respawnFallback' }
        }));
    });
}
