'use strict';

// ══════════════════════════════════════════════════════════
// State
// ══════════════════════════════════════════════════════════

const state = {
    injuries:   {},
    stress:     0,
    isDowned:   false,
    inPain:     false,
    bloodloss:  false,
    addiction:  {},
};

// ══════════════════════════════════════════════════════════
// DOM helpers
// ══════════════════════════════════════════════════════════

const $ = id => document.getElementById(id);

// ══════════════════════════════════════════════════════════
// Body diagram
// ══════════════════════════════════════════════════════════

const PARTS = ['head', 'torso', 'left_arm', 'right_arm', 'left_leg', 'right_leg'];

function renderBodyParts(injuries) {
    PARTS.forEach(part => {
        const el  = $('bp-' + part);
        if (!el) return;
        const sev = injuries[part];
        if (sev) {
            el.setAttribute('data-severity', sev);
        } else {
            el.removeAttribute('data-severity');
        }
    });
}

// ══════════════════════════════════════════════════════════
// Stress bar
// ══════════════════════════════════════════════════════════

function renderStress(stress) {
    const pct = Math.min(100, Math.max(0, stress));
    $('stress-fill').style.width = pct + '%';
    $('stress-val').textContent  = Math.round(pct);
}

// ══════════════════════════════════════════════════════════
// Addiction bar
// ══════════════════════════════════════════════════════════

function renderAddiction(addiction) {
    let highest = 0;
    if (addiction && typeof addiction === 'object') {
        Object.values(addiction).forEach(lvl => {
            if (lvl > highest) highest = lvl;
        });
    }

    const row  = $('addiction-row');
    const fill = $('addiction-fill');
    const val  = $('addiction-val');

    if (highest > 0) {
        row.classList.remove('hidden');
        fill.style.width    = (highest / 4 * 100) + '%';
        val.textContent     = highest;
    } else {
        row.classList.add('hidden');
    }
}

// ══════════════════════════════════════════════════════════
// Status icons
// ══════════════════════════════════════════════════════════

function renderIcons(bloodloss, inPain, withdrawal) {
    $('icon-bloodloss').classList.toggle('hidden', !bloodloss);
    $('icon-pain').classList.toggle('hidden',      !inPain);
    $('icon-withdraw').classList.toggle('hidden',  !withdrawal);
}

// Check if any withdrawal is active
function hasWithdrawal(addiction) {
    return false; // withdrawal state is pushed from Lua directly
}

// ══════════════════════════════════════════════════════════
// HUD full render
// ══════════════════════════════════════════════════════════

function renderHUD() {
    renderBodyParts(state.injuries);
    renderStress(state.stress);
    renderAddiction(state.addiction);
    renderIcons(state.bloodloss, state.inPain, state.withdrawalActive);
}

// ══════════════════════════════════════════════════════════
// Death screen
// ══════════════════════════════════════════════════════════

function formatTime(secs) {
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function showDeathScreen(timeRemaining, canRespawn) {
    $('death-screen').classList.remove('hidden');
    $('timer-value').textContent   = formatTime(timeRemaining || 300);
    $('timer-block').style.display = '';
    $('force-block').classList.add('hidden');
    // Only show the respawn button if no EMS is online
    $('btn-block').style.display   = canRespawn ? '' : 'none';
    $('death-sub').textContent     = canRespawn
        ? 'No EMS available — you may respawn at the hospital'
        : 'Wait for EMS to revive you';
    // Clear last words field
    if ($('will-input')) $('will-input').value = '';
}

function hideDeathScreen() {
    $('death-screen').classList.add('hidden');
}

function showForceRespawn() {
    $('timer-block').style.display = 'none';
    $('btn-block').style.display   = 'none';
    $('force-block').classList.remove('hidden');
}

function onRespawn() {
    const will = $('will-input') ? $('will-input').value.trim() : '';
    fetch(`https://hbs_ambulance/respawn`, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({ will }),
    }).then(() => {
        hideDeathScreen();
    }).catch(() => {
        hideDeathScreen();
    });
}

// ══════════════════════════════════════════════════════════
// NUI Message Router
// ══════════════════════════════════════════════════════════

window.addEventListener('message', function (event) {
    const d = event.data;
    if (!d || !d.action) return;

    switch (d.action) {

        case 'showHud':
            $('medical-hud').classList.remove('hidden');
            break;

        case 'hideHud':
            $('medical-hud').classList.add('hidden');
            break;

        case 'updateHud':
            if (d.injuries  !== undefined) state.injuries  = d.injuries  || {};
            if (d.stress    !== undefined) state.stress    = d.stress    || 0;
            if (d.isDowned  !== undefined) state.isDowned  = d.isDowned  || false;
            if (d.inPain    !== undefined) state.inPain    = d.inPain    || false;
            if (d.bloodloss !== undefined) state.bloodloss = d.bloodloss || false;
            if (d.addiction !== undefined) state.addiction = d.addiction || {};
            renderHUD();
            break;

        case 'updateStress':
            state.stress = d.stress || 0;
            renderStress(state.stress);
            break;

        case 'updateAddiction':
            state.addiction = d.addiction || {};
            renderAddiction(state.addiction);
            break;

        case 'showDeathScreen':
            showDeathScreen(d.timeRemaining, d.canRespawn);
            break;

        case 'hideDeathScreen':
            hideDeathScreen();
            break;

        case 'updateTimer':
            $('timer-value').textContent = formatTime(d.timeRemaining || 0);
            break;

        case 'forceRespawn':
            showForceRespawn();
            break;

        case 'withdrawalActive':
            state.withdrawalActive = true;
            renderIcons(state.bloodloss, state.inPain, true);
            break;

        case 'withdrawalEnded':
            state.withdrawalActive = false;
            renderIcons(state.bloodloss, state.inPain, false);
            break;
    }
});
