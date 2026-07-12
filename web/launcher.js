/* === LIL BLUNT: THE SMOKE REALM — Mobile Launcher Logic === */

const STORAGE_KEY = 'lilblunt_save';
const SETTINGS_KEY = 'lilblunt_settings';

const LOADING_TIPS = [
	"Tip: Wall-slide by holding direction against a wall mid-air",
	"Tip: Diamond Shards give you invincibility AND damage enemies",
	"Tip: Mine carts pay big wBTC — but only one cart per fork",
	"Tip: Tap JUMP twice for a double jump",
	"Tip: Hold SPRINT to run 20% faster",
	"Tip: DASH through enemies while invincible",
	"Tip: The Melt Forge burns 3 GOLD for a 10-second mega-boost",
	"Tip: Combos multiply your score — keep collecting!",
	"Tip: Gold tokens build vesting progress toward the boss arena",
	"Tip: Stay chill, Lil Blunt — the smoke is friendly"
];

const ACHIEVEMENTS = [
	{ id: 'first_step', name: 'First Step', desc: 'Complete the tutorial', icon: '👶' },
	{ id: 'coin_50', name: 'Pocket Change', desc: 'Collect 50 coins total', icon: '💰' },
	{ id: 'coin_500', name: 'High Roller', desc: 'Collect 500 coins total', icon: '💎' },
	{ id: 'combo_10', name: 'Smooth Operator', desc: 'Reach a 10x combo', icon: '🔥' },
	{ id: 'combo_25', name: 'Untouchable', desc: 'Reach a 25x combo', icon: '⚡' },
	{ id: 'level_1', name: 'Smoke Realm Clear', desc: 'Finish Level 1', icon: '🌫️' },
	{ id: 'level_2', name: 'Crystal Caverns Clear', desc: 'Finish Level 2', icon: '💠' },
	{ id: 'level_3', name: 'Gold Rush Clear', desc: 'Finish Level 3', icon: '⛏️' },
	{ id: 'boss_1', name: 'Claim Jumper Down', desc: 'Defeat the boss', icon: '👑' },
	{ id: 'streak_7', name: 'Weekly Warrior', desc: 'Play 7 days in a row', icon: '📅' },
	{ id: 'no_damage', name: 'Flawless', desc: 'Clear a level without taking damage', icon: '🛡️' },
	{ id: 'speed_run', name: 'Speed Demon', desc: 'Beat Level 1 under 90 seconds', icon: '⏱️' }
];

const CHALLENGES = [
	{ desc: 'Collect 50 gold tokens in a single run', goal: 50, reward: '+500 XP, Bonus Diamond Shard' },
	{ desc: 'Reach a 15x combo', goal: 15, reward: '+750 XP, Mystery Power-up' },
	{ desc: 'Defeat 25 enemies in one run', goal: 25, reward: '+500 XP, +1 Continue' },
	{ desc: 'Complete a level without taking damage', goal: 1, reward: '+1000 XP, Rare Skin' },
	{ desc: 'Use the Melt Forge 3 times', goal: 3, reward: '+600 XP, GOLD Boost' },
	{ desc: 'Collect 100 coins in one run', goal: 100, reward: '+800 XP, Lucky Charm' },
	{ desc: 'Wall jump 10 times', goal: 10, reward: '+400 XP, Air Boost' }
];

/* === STATE === */

const state = {
	highScore: 0,
	totalCoins: 0,
	totalDiamonds: 0,
	dailyStreak: 0,
	lastPlayDate: null,
	achievements: {},
	dailyChallenge: null,
	settings: {
		sound: true,
		music: true,
		haptics: true,
		showFps: false
	},
	gameLoaded: false,
	gameRunning: false,
	combo: 0,
	comboTimer: 0
};

/* === STORAGE === */

function loadState() {
	try {
		const saved = localStorage.getItem(STORAGE_KEY);
		if (saved) {
			Object.assign(state, JSON.parse(saved));
		}
		const settings = localStorage.getItem(SETTINGS_KEY);
		if (settings) {
			Object.assign(state.settings, JSON.parse(settings));
		}
	} catch (e) {
		console.warn('Failed to load state', e);
	}
}

function saveState() {
	try {
		localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
		localStorage.setItem(SETTINGS_KEY, JSON.stringify(state.settings));
	} catch (e) {
		console.warn('Failed to save state', e);
	}
}

/* === DAILY === */

function checkDailyStreak() {
	const today = new Date().toDateString();
	if (state.lastPlayDate !== today) {
		const yesterday = new Date();
		yesterday.setDate(yesterday.getDate() - 1);
		if (state.lastPlayDate === yesterday.toDateString()) {
			state.dailyStreak++;
		} else if (state.lastPlayDate) {
			state.dailyStreak = 1;
		} else {
			state.dailyStreak = 1;
		}
		state.lastPlayDate = today;

		// Pick a new daily challenge deterministic by date
		const dayHash = Math.abs(hashCode(today));
		const challenge = CHALLENGES[dayHash % CHALLENGES.length];
		state.dailyChallenge = { ...challenge, progress: 0, completed: false };

		saveState();

		if (state.dailyStreak >= 7) unlockAchievement('streak_7');
	}
}

function hashCode(str) {
	let hash = 0;
	for (let i = 0; i < str.length; i++) {
		hash = ((hash << 5) - hash) + str.charCodeAt(i);
		hash |= 0;
	}
	return hash;
}

function updateChallengeTimer() {
	const now = new Date();
	const tomorrow = new Date(now);
	tomorrow.setDate(tomorrow.getDate() + 1);
	tomorrow.setHours(0, 0, 0, 0);
	const diff = tomorrow - now;
	const h = String(Math.floor(diff / 3600000)).padStart(2, '0');
	const m = String(Math.floor((diff % 3600000) / 60000)).padStart(2, '0');
	const s = String(Math.floor((diff % 60000) / 1000)).padStart(2, '0');
	document.getElementById('challengeTimer').textContent = `${h}:${m}:${s}`;
}

/* === UI === */

function updateUI() {
	document.getElementById('highScore').textContent = state.highScore.toLocaleString();
	document.getElementById('dailyStreak').textContent = state.dailyStreak;
	document.getElementById('totalDiamonds').textContent = state.totalDiamonds;

	if (state.dailyChallenge) {
		document.getElementById('challengeDesc').textContent = state.dailyChallenge.desc;
		const pct = Math.min(100, (state.dailyChallenge.progress / state.dailyChallenge.goal) * 100);
		document.getElementById('challengeBar').style.width = pct + '%';
	}

	const hasSave = state.gameLoaded;
	document.getElementById('continueBtn').style.display = hasSave ? 'flex' : 'none';
}

/* === ACHIEVEMENTS === */

function unlockAchievement(id) {
	if (state.achievements[id]) return;
	const achievement = ACHIEVEMENTS.find(a => a.id === id);
	if (!achievement) return;
	state.achievements[id] = Date.now();
	saveState();
	showToast(achievement.name, achievement.desc, achievement.icon);
	if (state.settings.haptics && navigator.vibrate) {
		navigator.vibrate([100, 50, 100]);
	}
}

function showToast(title, desc, icon = '🏆') {
	const toast = document.getElementById('achievementToast');
	document.getElementById('toastTitle').textContent = title;
	document.getElementById('toastDesc').textContent = desc;
	toast.querySelector('.toast-icon').textContent = icon;
	toast.classList.add('show');
	setTimeout(() => toast.classList.remove('show'), 4000);
}

/* === MODAL === */

function openModal(html) {
	document.getElementById('modalContent').innerHTML = html;
	document.getElementById('modalOverlay').style.display = 'flex';
}

function closeModal() {
	document.getElementById('modalOverlay').style.display = 'none';
}

function showAchievements() {
	const items = ACHIEVEMENTS.map(a => {
		const unlocked = state.achievements[a.id];
		return `
			<div class="achievement-item ${unlocked ? 'unlocked' : 'locked'}">
				<div class="achievement-item-icon">${a.icon}</div>
				<div class="achievement-item-info">
					<div class="achievement-item-name">${a.name}</div>
					<div class="achievement-item-desc">${a.desc}</div>
				</div>
				${unlocked ? '<div style="color: #ffd700; font-size: 18px;">✓</div>' : ''}
			</div>
		`;
	}).join('');

	const unlockedCount = Object.keys(state.achievements).length;
	openModal(`
		<h3>🎖️ Achievements (${unlockedCount}/${ACHIEVEMENTS.length})</h3>
		${items}
	`);
}

function showLeaderboard() {
	const localScores = [
		{ name: 'You', score: state.highScore },
		{ name: 'CloudWalker', score: 28450 },
		{ name: 'Mr_Blunt', score: 24100 },
		{ name: 'SmokeKing', score: 19800 },
		{ name: 'DiamondHands', score: 15300 },
		{ name: 'GoldRusher', score: 12750 },
		{ name: 'WallJumper', score: 9200 }
	].sort((a, b) => b.score - a.score);

	const items = localScores.map((s, i) => `
		<div class="leaderboard-item">
			<div class="leaderboard-rank">#${i + 1}</div>
			<div class="leaderboard-name">${s.name}</div>
			<div class="leaderboard-score">${s.score.toLocaleString()}</div>
		</div>
	`).join('');

	openModal(`
		<h3>📊 Leaderboard</h3>
		${items}
		<div style="text-align: center; margin-top: 16px; font-size: 11px; color: rgba(255,255,255,0.5);">
			Top scores update when online play is enabled
		</div>
	`);
}

function showSettings() {
	const s = state.settings;
	openModal(`
		<h3>⚙️ Settings</h3>
		<div class="settings-row">
			<div class="settings-label">🔊 Sound Effects</div>
			<div class="toggle ${s.sound ? 'on' : ''}" data-setting="sound">
				<div class="toggle-knob"></div>
			</div>
		</div>
		<div class="settings-row">
			<div class="settings-label">🎵 Music</div>
			<div class="toggle ${s.music ? 'on' : ''}" data-setting="music">
				<div class="toggle-knob"></div>
			</div>
		</div>
		<div class="settings-row">
			<div class="settings-label">📳 Haptic Feedback</div>
			<div class="toggle ${s.haptics ? 'on' : ''}" data-setting="haptics">
				<div class="toggle-knob"></div>
			</div>
		</div>
		<div class="settings-row">
			<div class="settings-label">📈 Show FPS</div>
			<div class="toggle ${s.showFps ? 'on' : ''}" data-setting="showFps">
				<div class="toggle-knob"></div>
			</div>
		</div>
		<div style="margin-top: 20px; display: flex; gap: 8px;">
			<button class="btn btn-secondary" style="flex: 1; padding: 12px;" id="resetBtn">RESET SAVE</button>
		</div>
		<div style="text-align: center; margin-top: 12px; font-size: 11px; color: rgba(255,255,255,0.4);">
			Build v1.0.0 — Mobile First
		</div>
	`);

	document.querySelectorAll('.toggle').forEach(t => {
		t.addEventListener('click', () => {
			const key = t.dataset.setting;
			state.settings[key] = !state.settings[key];
			t.classList.toggle('on');
			saveState();
		});
	});

	document.getElementById('resetBtn').addEventListener('click', () => {
		if (confirm('Reset all save data? This cannot be undone.')) {
			localStorage.removeItem(STORAGE_KEY);
			location.reload();
		}
	});
}

/* === GAME LAUNCH === */

function showLoading(msg) {
	document.getElementById('launcher').style.display = 'none';
	document.getElementById('loadingScreen').style.display = 'flex';
	document.getElementById('loadingText').textContent = msg || 'Entering the Smoke Realm...';
	document.getElementById('loadingTip').textContent =
		LOADING_TIPS[Math.floor(Math.random() * LOADING_TIPS.length)];
}

function updateLoadingProgress(pct) {
	document.getElementById('loadingBar').style.width = pct + '%';
}

async function launchGame() {
	showLoading();

	// Animate loading bar
	let progress = 0;
	const loadInterval = setInterval(() => {
		progress = Math.min(95, progress + Math.random() * 8);
		updateLoadingProgress(progress);
	}, 150);

	// Check if Godot game files exist
	const godotExists = await checkGodotFiles();

	clearInterval(loadInterval);
	updateLoadingProgress(100);

	setTimeout(() => {
		document.getElementById('loadingScreen').style.display = 'none';
		if (godotExists) {
			startGodotGame();
		} else {
			showGameNotBuiltMessage();
		}
	}, 400);
}

async function checkGodotFiles() {
	try {
		const res = await fetch('game/index.js', { method: 'HEAD', cache: 'no-store' });
		if (!res.ok) return false;
		// Hosts with SPA fallbacks return index.html (200) for missing paths —
		// only treat the game as present if the response is actually JavaScript.
		const type = res.headers.get('content-type') || '';
		return !type.includes('text/html');
	} catch {
		return false;
	}
}

function startGodotGame() {
	const container = document.getElementById('gameContainer');
	container.style.display = 'flex';
	state.gameRunning = true;

	// Load Godot's own generated boot page in a same-origin iframe — it owns
	// engine startup, canvas sizing, workers, and audio. Rebuilding that boot
	// by hand is how the old PLAY button broke.
	let frame = document.getElementById('gameFrame');
	if (!frame) {
		frame = document.createElement('iframe');
		frame.id = 'gameFrame';
		frame.allow = 'autoplay; fullscreen; gamepad';
		frame.setAttribute('tabindex', '0');
		container.insertBefore(frame, container.firstChild);
	}
	frame.src = 'game/index.html';
	frame.addEventListener('load', () => frame.focus(), { once: true });

	requestFullscreen();
	startComboSystem();
}

function showGameNotBuiltMessage() {
	document.getElementById('launcher').style.display = 'flex';
	openModal(`
		<h3>🛠️ Game Not Yet Exported</h3>
		<p style="margin-bottom: 12px;">The Godot game needs to be exported to web format.</p>
		<div style="background: rgba(255,255,255,0.05); padding: 16px; border-radius: 12px; margin: 12px 0; font-family: monospace; font-size: 12px;">
			1. Open the project in Godot 4.3<br>
			2. Project → Export → Add "Web" preset<br>
			3. Export Project → save to <b>web/game/index.html</b><br>
			4. Refresh this page
		</div>
		<p style="font-size: 12px; color: rgba(255,255,255,0.6);">
			The launcher and UI are fully built. Just need to export the engine bundle once and your client gets the full experience.
		</p>
	`);
}

/* === COMBO SYSTEM === */

function startComboSystem() {
	const indicator = document.getElementById('comboIndicator');

	// Listen for Godot postMessage events (game will send these)
	window.addEventListener('message', (e) => {
		// Only the same-origin game iframe may drive state — reject forged
		// events from any other window (security audit finding #3).
		if (e.origin !== window.location.origin) return;
		if (e.data?.type === 'combo') {
			handleCombo(e.data.value);
		} else if (e.data?.type === 'score') {
			if (e.data.value > state.highScore) {
				state.highScore = e.data.value;
				saveState();
			}
		} else if (e.data?.type === 'achievement') {
			unlockAchievement(e.data.id);
		} else if (e.data?.type === 'coins') {
			state.totalCoins += e.data.value;
			if (state.totalCoins >= 50) unlockAchievement('coin_50');
			if (state.totalCoins >= 500) unlockAchievement('coin_500');
			saveState();
		} else if (e.data?.type === 'diamond') {
			state.totalDiamonds += e.data.value;
			saveState();
		}
	});

	let comboInterval = setInterval(() => {
		if (state.combo > 0) {
			state.comboTimer -= 100;
			if (state.comboTimer <= 0) {
				state.combo = 0;
				indicator.classList.remove('active');
			} else {
				const pct = (state.comboTimer / 3000) * 100;
				document.getElementById('comboBarFill').style.width = pct + '%';
			}
		}
	}, 100);
}

function handleCombo(value) {
	state.combo = value;
	state.comboTimer = 3000;
	const indicator = document.getElementById('comboIndicator');
	document.getElementById('comboNum').textContent = 'x' + value;
	indicator.classList.add('active');

	if (value >= 10) unlockAchievement('combo_10');
	if (value >= 25) unlockAchievement('combo_25');

	if (state.settings.haptics && navigator.vibrate) {
		navigator.vibrate(20);
	}
}

/* === FULLSCREEN === */

function requestFullscreen() {
	const el = document.documentElement;
	if (el.requestFullscreen) el.requestFullscreen().catch(() => {});
	else if (el.webkitRequestFullscreen) el.webkitRequestFullscreen();
}

function toggleFullscreen() {
	if (document.fullscreenElement) {
		document.exitFullscreen?.();
	} else {
		requestFullscreen();
	}
}

/* === ORIENTATION === */

function checkOrientation() {
	const isMobile = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);
	const isLandscape = window.innerWidth > window.innerHeight;
	// Allow both orientations; just hint at landscape on small screens
	const lock = document.getElementById('orientationLock');
	if (isMobile && !isLandscape && window.innerWidth < 400 && state.gameRunning) {
		// Optionally show rotate hint — for now we support both
		lock.style.display = 'none';
	} else {
		lock.style.display = 'none';
	}
}

/* === PWA INSTALL === */

let deferredPrompt = null;

window.addEventListener('beforeinstallprompt', (e) => {
	e.preventDefault();
	deferredPrompt = e;
	document.getElementById('installBtn').style.display = 'flex';
});

function installPWA() {
	if (!deferredPrompt) return;
	deferredPrompt.prompt();
	deferredPrompt.userChoice.then(() => {
		deferredPrompt = null;
		document.getElementById('installBtn').style.display = 'none';
	});
}

/* === INIT === */

function init() {
	loadState();
	checkDailyStreak();
	updateUI();
	updateChallengeTimer();
	setInterval(updateChallengeTimer, 1000);

	document.getElementById('playBtn').addEventListener('click', launchGame);
	document.getElementById('continueBtn').addEventListener('click', launchGame);
	document.getElementById('achievementsBtn').addEventListener('click', showAchievements);
	document.getElementById('leaderboardBtn').addEventListener('click', showLeaderboard);
	document.getElementById('settingsBtn').addEventListener('click', showSettings);
	document.getElementById('installBtn').addEventListener('click', installPWA);
	document.getElementById('modalClose').addEventListener('click', closeModal);
	document.getElementById('modalOverlay').addEventListener('click', (e) => {
		if (e.target.id === 'modalOverlay') closeModal();
	});

	document.getElementById('pauseBtn')?.addEventListener('click', () => {
		window.postMessage({ type: 'pause' }, '*');
	});
	document.getElementById('muteBtn')?.addEventListener('click', () => {
		state.settings.sound = !state.settings.sound;
		state.settings.music = !state.settings.music;
		saveState();
		window.postMessage({ type: 'mute', value: !state.settings.sound }, '*');
		document.getElementById('muteBtn').textContent = state.settings.sound ? '🔊' : '🔇';
	});
	document.getElementById('fullscreenBtn')?.addEventListener('click', toggleFullscreen);
	document.getElementById('exitBtn')?.addEventListener('click', () => {
		if (confirm('Exit game and return to menu?')) location.reload();
	});

	// Service worker for offline play
	if ('serviceWorker' in navigator) {
		navigator.serviceWorker.register('service-worker.js').catch(() => {});
	}

	// Prevent zoom on double-tap
	let lastTouchEnd = 0;
	document.addEventListener('touchend', (e) => {
		const now = Date.now();
		if (now - lastTouchEnd <= 300) e.preventDefault();
		lastTouchEnd = now;
	}, { passive: false });

	window.addEventListener('resize', checkOrientation);
	checkOrientation();
}

document.addEventListener('DOMContentLoaded', init);
