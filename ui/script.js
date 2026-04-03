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
        case 'showDeathScreen':showDeathScreen(data.bleedoutMs, data.resourceName); break;
        case 'hideDeathScreen':hideDeathScreen();                     break;
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
