'use strict';
/* =====================================================================
   МИЛА • 1-4 САКУРОВЫЙ ЛЕС — платформер
   Карта: map.png (2861×768). Героиня и враги вырезаны из hero.png /
   enemies.png в assets/sprites/ (см. tools/extract_sprites.py).
   Слои при отрисовке: небо → далёкие облака/острова (параллакс 0.35–0.6)
   → карта с платформами (1.0) → лепестки сакуры трёх глубин → передний
   план (1.2). Враги патрулируют каждый свою платформу.
   ===================================================================== */

const VIEW_W = 1280, VIEW_H = 720;
const WORLD_W = 2861, WORLD_H = 768;
const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');

const $ = id => document.getElementById(id);
const ui = {
  hud: $('hud'), hearts: $('hearts'), coins: $('coins'), gems: $('gems'),
  combo: $('combo'), timer: $('timer'), energy: $('energyFill'),
  foesLeft: $('foesLeft'), progressFill: $('progressFill'), progressDot: $('progressDot'),
  toast: $('toast'), menu: $('menu'), pause: $('pauseMenu'), win: $('winMenu'),
  over: $('overMenu'), startBtn: $('startBtn'), loadHint: $('loadHint'),
  winStats: $('winStats'), overStats: $('overStats'), touch: $('touch'),
};

/* ---------------- загрузка картинок ---------------- */
const IMG = {};
function loadImage(key, src) {
  return new Promise((res, rej) => {
    const im = new Image();
    im.onload = () => { IMG[key] = im; res(); };
    im.onerror = rej;
    im.src = src;
  });
}
const ready = Promise.all([
  loadImage('map', 'map.png'),
  loadImage('idle', 'assets/sprites/hero_idle.png'),
  loadImage('run1', 'assets/sprites/hero_run1.png'),
  loadImage('run2', 'assets/sprites/hero_run2.png'),
  loadImage('jump', 'assets/sprites/hero_jump.png'),
  loadImage('shoot', 'assets/sprites/hero_shoot.png'),
  loadImage('hurt', 'assets/sprites/hero_hurt.png'),
  loadImage('slime', 'assets/sprites/enemy_slime.png'),
  loadImage('bat', 'assets/sprites/enemy_bat.png'),
  loadImage('spider', 'assets/sprites/enemy_spider.png'),
  loadImage('mushroom', 'assets/sprites/enemy_mushroom.png'),
  loadImage('spiker', 'assets/sprites/enemy_spiker.png'),
  loadImage('purple', 'assets/sprites/enemy_purple.png'),
]).then(() => {
  ui.startBtn.disabled = false;
  ui.startBtn.textContent = '▶ Играть';
  ui.loadHint.textContent = 'Всё готово! Добеги от флажка ⚑ до храма с воронкой 🌀 справа.';
}).catch(() => { ui.loadHint.textContent = 'Не удалось загрузить картинки — запустите через локальный сервер (см. README).'; });

/* ---------------- звук (синтез, без файлов) ---------------- */
let audioCtx = null, muted = false;
function beep(f0, f1, dur, type = 'square', vol = 0.05, delay = 0) {
  if (muted) return;
  try {
    audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
    const t = audioCtx.currentTime + delay;
    const o = audioCtx.createOscillator(), g = audioCtx.createGain();
    o.type = type; o.frequency.setValueAtTime(f0, t);
    o.frequency.exponentialRampToValueAtTime(Math.max(30, f1), t + dur);
    g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g).connect(audioCtx.destination); o.start(t); o.stop(t + dur + 0.02);
  } catch (e) { /* без звука */ }
}
const sfx = {
  shoot: () => beep(920, 240, 0.12, 'square', 0.035),
  jump: () => beep(300, 640, 0.14, 'sine', 0.05),
  coin: () => { beep(950, 950, 0.07, 'sine', 0.05); beep(1420, 1420, 0.12, 'sine', 0.05, 0.07); },
  gem: () => { beep(700, 1400, 0.16, 'triangle', 0.06); },
  hit: () => beep(220, 90, 0.16, 'sawtooth', 0.05),
  hurt: () => beep(420, 110, 0.25, 'sawtooth', 0.06),
  die: () => beep(520, 60, 0.5, 'triangle', 0.06),
  win: () => [523, 659, 784, 1047, 1319].forEach((f, i) => beep(f, f, 0.22, 'triangle', 0.06, i * 0.11)),
};

/* ---------------- фоновая музыка (реальные треки, бесконечное чередование) ----------------
   Как только одна дорожка заканчивается, тут же начинает играть следующая,
   по кругу: music.mp3 -> music_soft.mp3 -> music.mp3 -> ... без остановки. */
const MUSIC_TRACKS = ['music.mp3', 'music_soft.mp3'];
const MUSIC_VOLUME = 0.45;
let musicEl = null, musicStarted = false, musicTrackIndex = 0;
function playMusicTrack(i) {
  if (!musicEl) return;
  musicTrackIndex = i % MUSIC_TRACKS.length;
  musicEl.src = MUSIC_TRACKS[musicTrackIndex];
  musicEl.play().catch(() => {});
}
function startMusic() {
  if (musicStarted) return;
  musicStarted = true;
  musicEl = new Audio();
  musicEl.volume = muted ? 0 : MUSIC_VOLUME;
  musicEl.addEventListener('ended', () => playMusicTrack(musicTrackIndex + 1));
  playMusicTrack(0);
}
function setMusicVolume() {
  if (musicEl) musicEl.volume = muted ? 0 : MUSIC_VOLUME;
}

/* ---------------- уровень ----------------
   Платформы размечены по выступающим деревянным/каменным платформам
   карты map.png (x, y — верхний край, w — ширина). Все платформы
   «односторонние»: на них приземляются сверху, сквозь них можно
   прыгать снизу — так строится зигзаг-маршрут к храму. */
const PLATFORMS = [
  { x: -30,  y: 488, w: 210 },   // 0  стартовая поляна с флажком ⚑
  { x: 300,  y: 548, w: 320 },   // 1
  { x: 435,  y: 455, w: 265 },   // 2
  { x: 640,  y: 368, w: 240 },   // 3
  { x: 915,  y: 276, w: 270 },   // 4  высокая
  { x: 1080, y: 415, w: 275 },   // 5
  { x: 1335, y: 565, w: 245 },   // 6
  { x: 1540, y: 455, w: 265 },   // 7
  { x: 1525, y: 264, w: 285 },   // 8  верхняя (необязательная)
  { x: 1740, y: 498, w: 220 },   // 9  сундук-чекпоинт
  { x: 1795, y: 345, w: 355 },   // 10 домик на дереве
  { x: 2140, y: 378, w: 175 },   // 11 верёвочный мост
  { x: 2295, y: 408, w: 175 },   // 12 верёвочный мост
  { x: 2330, y: 405, w: 295 },   // 13 остров с беседкой (чекпоинт)
  { x: 2445, y: 252, w: 155 },   // 14 нижняя ступень/помост храма
  { x: 2440, y: 188, w: 421 },   // 15 платформа храма с порталом 🌀
  // нижний необязательный маршрут (монеты, кристаллы, шипы)
  { x: 140,  y: 708, w: 385 },   // 16
  { x: 760,  y: 708, w: 390 },   // 17
  { x: 1240, y: 708, w: 430 },   // 18
  { x: 1745, y: 608, w: 215 },   // 19
  { x: 2245, y: 518, w: 220 },   // 20 остров с кристаллами
  { x: 2050, y: 612, w: 811 },   // 21 нижняя каменная дорога
  { x: 2675, y: 568, w: 185 },   // 22 каменный мостик справа внизу
];
const SPIKES = [ // колючие колёса, нарисованные на карте внизу
  { x: 535, y: 650, w: 215, h: 110 },
  { x: 1880, y: 625, w: 165, h: 120 },
];
const CHECKPOINTS = [
  { x: 60,   y: 488 }, { x: 1790, y: 498 }, { x: 2380, y: 405 },
];
const GOAL = { x: 2610, y: 50, w: 125, h: 145, cx: 2670, cy: 132 }; // розовая воронка храма

/* Враги: у каждого — своя платформа (plat) и свой участок патруля. */
const ENEMY_TYPES = {
  slime:    { hp: 2, speed: 46, h: 54,  score: 100 },
  bat:      { hp: 1, speed: 78, h: 60,  score: 150, fly: true },
  spider:   { hp: 2, speed: 66, h: 56,  score: 150 },
  mushroom: { hp: 2, speed: 38, h: 66,  score: 100 },
  spiker:   { hp: 3, speed: 34, h: 74,  score: 250 },
  purple:   { hp: 2, speed: 56, h: 60,  score: 150 },
};
const ENEMY_SPAWNS = [
  { type: 'slime',    plat: 1,  min: 330,  max: 560 },
  { type: 'mushroom', plat: 2,  min: 460,  max: 650 },
  { type: 'spiker',   plat: 3,  min: 665,  max: 820 },
  { type: 'bat',      plat: 4,  min: 940,  max: 1140 },
  { type: 'purple',   plat: 5,  min: 1110, max: 1300 },
  { type: 'spider',   plat: 6,  min: 1365, max: 1520 },
  { type: 'slime',    plat: 7,  min: 1570, max: 1750 },
  { type: 'mushroom', plat: 8,  min: 1560, max: 1750 },
  { type: 'spiker',   plat: 10, min: 1840, max: 2080 },
  { type: 'bat',      plat: 13, min: 2360, max: 2560 },
  { type: 'spider',   plat: 21, min: 2120, max: 2560 },
  { type: 'purple',   plat: 15, min: 2470, max: 2585 }, // страж портала
];

function makeCoins() {
  const list = [];
  const rows = [ // монеты над основными платформами маршрута
    [340, 500], [430, 500], [520, 500], [480, 408], [580, 408], [690, 320], [790, 320],
    [970, 228], [1070, 228], [1130, 367], [1230, 367], [1400, 517], [1500, 517],
    [1600, 407], [1700, 407], [1600, 216], [1700, 216], [1800, 450], [1900, 297],
    [2000, 297], [2200, 344], [2400, 357], [2520, 247], [700, 660], [900, 660],
    [1450, 660], [1800, 560], [2320, 470], [2750, 520],
  ];
  rows.forEach(([x, y], i) => list.push({ kind: 'coin', x, y, taken: false, ph: i * 0.7 }));
  [[250, 660], [1030, 660], [1830, 555], [2300, 465], [2520, 560]].forEach(([x, y], i) =>
    list.push({ kind: 'gem', x, y, taken: false, ph: i * 1.1 }));
  [[1000, 218], [2330, 455]].forEach(([x, y]) =>
    list.push({ kind: 'heart', x, y, taken: false, ph: 0 }));
  return list;
}

/* ---------------- состояние игры ---------------- */
let state = 'menu'; // menu | playing | paused | win-anim | win | over
let player, enemies, items, bullets, particles, floaters;
let camX = 0, camY = 0, prevCamX = 0, camShake = 0;
let timeSec = 0, combo = 0, comboTimer = 0, maxCombo = 0;
let coinsGot = 0, gemsGot = 0, kills = 0, shootCd = 0, energy = 100;
let warned = false, toastTimer = 0, winTimer = 0, totalCoins = 0, totalGems = 0;

function resetGame() {
  player = {
    x: 62, y: PLATFORMS[0].y - 78, w: 42, h: 78, vx: 0, vy: 0,
    face: 1, hp: 5, grounded: false, jumps: 0, coyote: 0, jbuffer: 0,
    invuln: 0, shootAnim: 0, hurtAnim: 0, runTime: 0, dead: false,
    respawn: { x: 62, y: PLATFORMS[0].y - 78 }, lastSafe: null, safeTimer: 0,
  };
  enemies = ENEMY_SPAWNS.map((s, i) => {
    const t = ENEMY_TYPES[s.type], p = PLATFORMS[s.plat];
    return {
      ...s, ...t, img: s.type, maxHp: t.hp,
      x: (s.min + s.max) / 2, baseY: p.y, dir: i % 2 ? -1 : 1,
      w: 52, dead: false, flash: 0, t: Math.random() * 6,
    };
  });
  items = makeCoins();
  totalCoins = items.filter(i => i.kind === 'coin').length;
  totalGems = items.filter(i => i.kind === 'gem').length;
  bullets = []; particles = [];
  camX = 0; camY = 0; prevCamX = 0; camShake = 0;
  timeSec = 0; combo = 0; comboTimer = 0; maxCombo = 0;
  coinsGot = 0; gemsGot = 0; kills = 0; shootCd = 0; energy = 100;
  warned = false; toastTimer = 0; winTimer = 0;
  updateHUD();
}

/* ---------------- ввод ---------------- */
const keys = { left: false, right: false, jump: false, shoot: false };
let jumpPressed = false;
const KEYMAP = {
  ArrowLeft: 'left', KeyA: 'left', ArrowRight: 'right', KeyD: 'right',
  ArrowUp: 'jump', KeyW: 'jump', Space: 'jump',
  KeyZ: 'shoot', KeyX: 'shoot', KeyJ: 'shoot',
};
addEventListener('keydown', e => {
  if (['ArrowLeft', 'ArrowRight', 'ArrowUp', 'Space'].includes(e.code)) e.preventDefault();
  const k = KEYMAP[e.code];
  if (k) { if (k === 'jump' && !keys.jump) jumpPressed = true; keys[k] = true; }
  if (e.code === 'KeyM') toggleMute();
  if ((e.code === 'KeyP' || e.code === 'Escape')) {
    if (state === 'playing') pauseGame(); else if (state === 'paused') resumeGame();
  }
  if (e.code === 'KeyR' && ['playing', 'paused', 'win', 'over'].includes(state)) startGame();
  if (e.code === 'Enter' && state === 'menu') startGame();
});
addEventListener('keyup', e => { const k = KEYMAP[e.code]; if (k) keys[k] = false; });
canvas.addEventListener('pointerdown', e => {
  if (state !== 'playing') return;
  const r = canvas.getBoundingClientRect();
  const mx = (e.clientX - r.left) / r.width * VIEW_W;
  player.face = (player.x + player.w / 2 - camX) < mx ? 1 : -1;
  keys.shoot = true;
});
addEventListener('pointerup', () => { if (!touchActive) keys.shoot = false; });

let touchActive = false;
if (matchMedia('(pointer: coarse)').matches) { ui.touch.hidden = false; touchActive = true; }
document.querySelectorAll('.touch-btn').forEach(btn => {
  const k = btn.dataset.k;
  const on = e => { e.preventDefault(); if (k === 'jump' && !keys.jump) jumpPressed = true; keys[k] = true; btn.classList.add('on'); };
  const off = e => { e.preventDefault(); keys[k] = false; btn.classList.remove('on'); };
  btn.addEventListener('pointerdown', on);
  btn.addEventListener('pointerup', off);
  btn.addEventListener('pointerleave', off);
  btn.addEventListener('pointercancel', off);
});

/* ---------------- частицы и лепестки ---------------- */
function burst(x, y, n, colors, speed = 260) {
  for (let i = 0; i < n; i++) {
    const a = Math.random() * Math.PI * 2, s = (0.3 + Math.random() * 0.7) * speed;
    particles.push({
      x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s - 60,
      life: 0.5 + Math.random() * 0.5, max: 1, size: 3 + Math.random() * 5,
      color: colors[(Math.random() * colors.length) | 0], star: Math.random() < 0.4, rot: Math.random() * 6,
    });
  }
}
function addFloater(x, y, text, color) {
  floaters.push({ x, y, text, color, life: 1 });
}
/* Лепестки сакуры: три глубины -> разная скорость падения и разный
   сдвиг от камеры (параллакс переднего/среднего/заднего плана). */
const petals = [];
for (let i = 0; i < 80; i++) {
  const depth = [0.55, 0.85, 1.25][i % 3];
  petals.push({
    x: Math.random() * VIEW_W, y: Math.random() * VIEW_H,
    size: (4 + Math.random() * 5) * depth, depth,
    fall: 26 + Math.random() * 30, sway: Math.random() * Math.PI * 2,
    swaySpeed: 0.6 + Math.random() * 1.1, rot: Math.random() * Math.PI,
    spin: (Math.random() - 0.5) * 2.2, alpha: 0.45 + depth * 0.3,
  });
}
/* Далёкие облака и парящие островки для параллакс-слоя за картой */
const clouds = [];
for (let i = 0; i < 16; i++) {
  clouds.push({
    x: i * 260 + Math.random() * 120, y: 26 + Math.random() * 210,
    s: 0.7 + Math.random() * 1.1, f: i % 2 ? 0.55 : 0.35, a: 0.35 + Math.random() * 0.3,
  });
}
floaters = [];

/* ---------------- физика и логика ---------------- */
const GRAV = 1750, SPEED = 265, JUMP_V = 775;
const overlap = (a, b) => a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;

function damagePlayer(fromX) {
  if (player.invuln > 0 || state !== 'playing') return;
  player.hp--; player.invuln = 1.3; player.hurtAnim = 0.35;
  player.vx = (player.x + player.w / 2 < fromX ? -1 : 1) * 240;
  player.vy = -320; combo = 0;
  camShake = 7; sfx.hurt();
  burst(player.x + player.w / 2, player.y + 30, 10, ['#ff5f9e', '#ffd7ec', '#fff'], 200);
  updateHUD();
  if (player.hp <= 0) gameOver();
}
function respawnAt(p) {
  player.x = p.x; player.y = p.y; player.vx = 0; player.vy = 0; player.invuln = 1.5;
}
function gameOver() {
  state = 'over'; sfx.die();
  ui.overStats.innerHTML = statsHTML();
  ui.over.hidden = false;
}
function statsHTML() {
  const mm = String((timeSec / 60) | 0).padStart(2, '0'), ss = String((timeSec | 0) % 60).padStart(2, '0');
  return `<div>⏱ Время<b>${mm}:${ss}</b></div>
          <div>⭐ Монеты<b>${coinsGot} / ${totalCoins}</b></div>
          <div>♦ Кристаллы<b>${gemsGot} / ${totalGems}</b></div>
          <div>💥 Врагов побеждено<b>${kills} / ${ENEMY_SPAWNS.length}</b></div>
          <div>★ Макс. комбо<b>×${maxCombo}</b></div>`;
}

function update(dt) {
  timeSec += dt;
  if (comboTimer > 0) { comboTimer -= dt; if (comboTimer <= 0) combo = 0; }
  if (shootCd > 0) shootCd -= dt;
  if (player.invuln > 0) player.invuln -= dt;
  if (player.hurtAnim > 0) player.hurtAnim -= dt;
  if (player.shootAnim > 0) player.shootAnim -= dt;
  energy = Math.min(100, energy + 26 * dt);

  /* --- движение героини --- */
  const p = player;
  const move = (keys.right ? 1 : 0) - (keys.left ? 1 : 0);
  if (move) { p.face = move; p.runTime += dt; }
  p.vx = move * SPEED;
  p.x += p.vx * dt;
  p.x = Math.max(-18, Math.min(WORLD_W - p.w + 10, p.x));

  if (p.grounded) { p.coyote = 0.09; p.jumps = 0; } else if (p.coyote > 0) p.coyote -= dt;
  if (jumpPressed) { p.jbuffer = 0.12; jumpPressed = false; } else if (p.jbuffer > 0) p.jbuffer -= dt;
  if (p.jbuffer > 0 && (p.coyote > 0 || p.jumps < 1)) {
    const dbl = p.coyote <= 0;
    p.vy = dbl ? -715 : -JUMP_V;
    if (dbl) { p.jumps++; burst(p.x + p.w / 2, p.y + p.h, 8, ['#ffd7ec', '#ff9ecb'], 130); }
    p.jbuffer = 0; p.coyote = 0; sfx.jump();
  }
  p.vy = Math.min(980, p.vy + GRAV * dt);
  const prevBottom = p.y + p.h;
  p.y += p.vy * dt;

  // односторонние платформы: приземление только при падении сверху
  p.grounded = false;
  if (p.vy >= 0) {
    for (const pl of PLATFORMS) {
      if (p.x + p.w > pl.x + 4 && p.x < pl.x + pl.w - 4 &&
          prevBottom <= pl.y + 9 && p.y + p.h >= pl.y) {
        p.y = pl.y - p.h; p.vy = 0; p.grounded = true; p.jumps = 0;
        break;
      }
    }
  }
  if (p.grounded) { // запоминаем безопасное место и чекпоинты
    p.safeTimer += dt;
    if (p.safeTimer > 0.4) { p.lastSafe = { x: p.x, y: p.y }; p.safeTimer = 0; }
    for (const c of CHECKPOINTS) if (p.x > c.x - 40) p.respawn = { x: c.x, y: c.y - p.h };
  } else p.safeTimer = 0;

  // падение в пропасть
  if (p.y > WORLD_H + 60) {
    p.hp--; updateHUD(); sfx.hurt();
    if (p.hp <= 0) { gameOver(); return; }
    respawnAt(p.respawn);
  }
  // шипы
  const pbox = { x: p.x + 6, y: p.y + 8, w: p.w - 12, h: p.h - 8 };
  for (const s of SPIKES) {
    if (overlap(pbox, s) && p.invuln <= 0) {
      damagePlayer(s.x + s.w / 2);
      if (state === 'playing' && p.lastSafe) respawnAt(p.lastSafe);
      break;
    }
  }

  /* --- стрельба: звёздочки из бластера --- */
  if (keys.shoot && shootCd <= 0 && energy >= 7) {
    shootCd = 0.21; energy -= 7; p.shootAnim = 0.22;
    const bx = p.x + p.w / 2 + p.face * 34, by = p.y + 30;
    bullets.push({ x: bx, y: by, vx: p.face * 660, life: 1.1, rot: 0 });
    burst(bx, by, 3, ['#ff8ce8', '#fff0fa'], 90);
    sfx.shoot(); updateHUD();
  }
  for (const b of bullets) {
    b.x += b.vx * dt; b.life -= dt; b.rot += dt * 9;
    if (Math.random() < 0.6) particles.push({
      x: b.x, y: b.y, vx: (Math.random() - 0.5) * 30, vy: (Math.random() - 0.5) * 30,
      life: 0.3, max: 0.3, size: 2.5, color: '#ff9ede', star: true, rot: Math.random() * 6,
    });
  }
  bullets = bullets.filter(b => b.life > 0 && b.x > camX - 60 && b.x < camX + VIEW_W + 60);

  /* --- враги: каждый патрулирует свою платформу --- */
  let foesAlive = 0;
  for (const e of enemies) {
    if (e.dead) continue;
    foesAlive++;
    e.t += dt; if (e.flash > 0) e.flash -= dt;
    e.x += e.dir * e.speed * dt;
    if (e.x < e.min) { e.x = e.min; e.dir = 1; }
    if (e.x > e.max) { e.x = e.max; e.dir = -1; }
    const ey = e.fly ? e.baseY - 96 + Math.sin(e.t * 2.4) * 13 : e.baseY - e.h + Math.abs(Math.sin(e.t * 6)) * -3;
    e.drawY = ey;
    const ebox = { x: e.x - e.w / 2, y: ey + 6, w: e.w, h: e.h - 8 };
    // попадание звёздочек
    for (const b of bullets) {
      if (b.life > 0 && Math.abs(b.x - e.x) < e.w / 2 + 8 && Math.abs(b.y - (ey + e.h / 2)) < e.h / 2 + 8) {
        b.life = 0; e.hp--; e.flash = 0.14; sfx.hit();
        burst(b.x, b.y, 7, ['#ff8ce8', '#ffe066', '#fff'], 220);
        if (e.hp <= 0) {
          e.dead = true; kills++;
          combo++; comboTimer = 4; maxCombo = Math.max(maxCombo, combo);
          burst(e.x, ey + e.h / 2, 22, ['#ff8fc4', '#ffd94d', '#c9a6ff', '#fff'], 320);
          addFloater(e.x, ey - 8, `+${e.score} ★×${combo}`, '#ffd94d');
          if (Math.random() < 0.45) items.push({ kind: 'coin', x: e.x, y: ey + 10, taken: false, ph: Math.random() * 6 });
          sfx.die();
        }
        updateHUD(); break;
      }
    }
    if (e.dead) { foesAlive--; continue; }
    // касание героини
    if (overlap(pbox, ebox)) damagePlayer(e.x);
    // предупреждение
    if (!warned && Math.abs(e.x - (p.x + p.w / 2)) < 360) {
      warned = true; toastTimer = 2.4; ui.toast.hidden = false;
    }
  }
  ui.foesLeft.textContent = foesAlive;
  if (toastTimer > 0) { toastTimer -= dt; if (toastTimer <= 0) ui.toast.hidden = true; }

  /* --- предметы --- */
  for (const it of items) {
    if (it.taken) continue;
    const bobY = it.y + Math.sin(timeSec * 2.4 + it.ph) * 5;
    it.drawY = bobY;
    if (Math.abs(it.x - (p.x + p.w / 2)) < 40 && Math.abs(bobY - (p.y + p.h / 2)) < 52) {
      it.taken = true;
      if (it.kind === 'coin') { coinsGot++; sfx.coin(); addFloater(it.x, bobY - 14, '+1 ⭐', '#ffd94d'); }
      if (it.kind === 'gem') { gemsGot++; sfx.gem(); addFloater(it.x, bobY - 14, '+1 ♦', '#7fe3ff'); }
      if (it.kind === 'heart') {
        if (player.hp < 5) { player.hp++; addFloater(it.x, bobY - 14, '+1 ❤', '#ff8fc4'); }
        else { coinsGot += 3; addFloater(it.x, bobY - 14, '+3 ⭐', '#ffd94d'); }
        sfx.coin();
      }
      burst(it.x, bobY, 8, ['#fff3b0', '#ff9ede'], 150);
      updateHUD();
    }
  }

  /* --- частицы --- */
  for (const pt of particles) {
    pt.life -= dt; pt.x += pt.vx * dt; pt.y += pt.vy * dt; pt.vy += 300 * dt; pt.rot += dt * 6;
  }
  particles = particles.filter(pt => pt.life > 0);
  for (const f of floaters) { f.life -= dt * 0.8; f.y -= 34 * dt; }
  floaters = floaters.filter(f => f.life > 0);

  /* --- финал: вход в воронку храма --- */
  const pc = { x: p.x + 4, y: p.y + 4, w: p.w - 8, h: p.h - 4 };
  if (overlap(pc, GOAL)) {
    state = 'win-anim'; winTimer = 0; sfx.win();
    burst(GOAL.cx, GOAL.cy, 36, ['#ff8ce8', '#ffd94d', '#c9a6ff', '#fff'], 380);
  }

  /* --- камера --- */
  prevCamX = camX;
  const targetX = Math.max(0, Math.min(WORLD_W - VIEW_W, p.x + p.w / 2 - VIEW_W * 0.38));
  const targetY = Math.max(0, Math.min(WORLD_H - VIEW_H, p.y + p.h / 2 - VIEW_H * 0.55));
  camX += (targetX - camX) * Math.min(1, dt * 6);
  camY += (targetY - camY) * Math.min(1, dt * 6);
  if (camShake > 0) camShake = Math.max(0, camShake - dt * 26);
  updateHUDLight();
}

/* ---------------- HUD ---------------- */
function updateHUD() {
  ui.hearts.innerHTML = [0, 1, 2, 3, 4].map(i =>
    `<span class="${i < player.hp ? '' : 'off'}">❤</span>`).join('');
  ui.coins.textContent = coinsGot;
  ui.gems.textContent = gemsGot;
  updateHUDLight();
}
function updateHUDLight() {
  ui.combo.textContent = combo;
  ui.energy.style.width = energy.toFixed(0) + '%';
  ui.energy.classList.toggle('low', energy < 25);
  const mm = String((timeSec / 60) | 0).padStart(2, '0'), ss = String((timeSec | 0) % 60).padStart(2, '0');
  ui.timer.textContent = `${mm}:${ss}`;
  const prog = Math.max(0, Math.min(1, (player.x - 40) / (GOAL.cx - 120)));
  ui.progressFill.style.width = (prog * 100).toFixed(1) + '%';
  ui.progressDot.style.left = (prog * 100).toFixed(1) + '%';
}

/* ---------------- отрисовка ---------------- */
function drawStar(x, y, r, rot, color) {
  ctx.save(); ctx.translate(x, y); ctx.rotate(rot); ctx.fillStyle = color;
  ctx.beginPath();
  for (let i = 0; i < 10; i++) {
    const rr = i % 2 ? r * 0.45 : r, a = i * Math.PI / 5 - Math.PI / 2;
    ctx[i ? 'lineTo' : 'moveTo'](Math.cos(a) * rr, Math.sin(a) * rr);
  }
  ctx.closePath(); ctx.fill(); ctx.restore();
}
function drawPetalShape(x, y, s, rot, alpha) {
  ctx.save(); ctx.translate(x, y); ctx.rotate(rot); ctx.globalAlpha = alpha;
  ctx.fillStyle = '#ff9ec7';
  ctx.beginPath(); ctx.moveTo(0, -s);
  ctx.bezierCurveTo(s * 0.9, -s * 0.5, s * 0.7, s * 0.7, 0, s);
  ctx.bezierCurveTo(-s * 0.7, s * 0.7, -s * 0.9, -s * 0.5, 0, -s);
  ctx.fill();
  ctx.fillStyle = 'rgba(255,255,255,.55)';
  ctx.beginPath(); ctx.ellipse(-s * 0.2, -s * 0.25, s * 0.22, s * 0.4, 0.4, 0, 7); ctx.fill();
  ctx.restore();
}
function drawCloud(x, y, s, a) {
  ctx.save(); ctx.globalAlpha = a; ctx.fillStyle = '#fff';
  for (const [dx, dy, r] of [[0, 0, 34], [30, 6, 26], [-32, 8, 24], [8, -14, 24]]) {
    ctx.beginPath(); ctx.ellipse(x + dx * s, y + dy * s, r * s, r * 0.62 * s, 0, 0, 7); ctx.fill();
  }
  ctx.restore();
}
/* Крутящаяся розовая воронка портала поверх храма на карте */
function drawPortal(t) {
  const { cx, cy } = GOAL;
  if (cx - camX < -160 || cx - camX > VIEW_W + 160) return;
  const x = cx - camX, y = cy - camY;
  ctx.save(); ctx.translate(x, y);
  const pulse = 1 + Math.sin(t * 2.4) * 0.05;
  ctx.scale(pulse, pulse);
  const glow = ctx.createRadialGradient(0, 0, 4, 0, 0, 78);
  glow.addColorStop(0, 'rgba(255,190,240,.95)');
  glow.addColorStop(0.55, 'rgba(255,90,200,.55)');
  glow.addColorStop(1, 'rgba(180,80,255,0)');
  ctx.fillStyle = glow; ctx.beginPath(); ctx.arc(0, 0, 78, 0, 7); ctx.fill();
  // вращающиеся спиральные рукава
  for (let arm = 0; arm < 3; arm++) {
    ctx.save(); ctx.rotate(t * 1.9 + arm * Math.PI * 2 / 3);
    ctx.strokeStyle = arm % 2 ? 'rgba(255,220,250,.9)' : 'rgba(255,120,220,.85)';
    ctx.lineWidth = 6 - arm; ctx.lineCap = 'round';
    ctx.beginPath();
    for (let a = 0; a < Math.PI * 1.5; a += 0.15) {
      const r = 6 + a * 9.5, px = Math.cos(a) * r, py = Math.sin(a) * r * 0.92;
      a === 0 ? ctx.moveTo(px, py) : ctx.lineTo(px, py);
    }
    ctx.stroke(); ctx.restore();
  }
  ctx.fillStyle = '#fff';
  ctx.beginPath(); ctx.arc(0, 0, 9 + Math.sin(t * 5) * 2, 0, 7); ctx.fill();
  // звёздочки на орбите
  for (let i = 0; i < 6; i++) {
    const a = t * 2.6 + i * Math.PI / 3, r = 52 + Math.sin(t * 3 + i) * 7;
    drawStar(Math.cos(a) * r, Math.sin(a) * r * 0.9, 6, a * 2, i % 2 ? '#ffd94d' : '#ffe3f7');
  }
  ctx.restore();
}
function drawHero(t) {
  const p = player;
  let img = IMG.idle, h = 106;
  if (state === 'win-anim') img = IMG.jump;
  else if (p.hurtAnim > 0) img = IMG.hurt;
  else if (p.shootAnim > 0) { img = IMG.shoot; h = 100; }
  else if (!p.grounded) img = IMG.jump;
  else if (Math.abs(p.vx) > 10) img = ((p.runTime * 7) | 0) % 2 ? IMG.run1 : IMG.run2;
  if (!img) return;
  const w = h * img.width / img.height;
  const cx = p.x + p.w / 2 - camX, bottom = p.y + p.h - camY;
  ctx.save();
  ctx.translate(cx, bottom);
  // воронка затягивает героиню
  if (state === 'win-anim') {
    const k = Math.min(1, winTimer / 1.4);
    ctx.translate((GOAL.cx - camX - cx) * k * k, (GOAL.cy - camY - bottom) * k * k + Math.sin(k * 9) * 8);
    ctx.rotate(k * 4.5); ctx.scale(1 - k * 0.85, 1 - k * 0.85);
  }
  if (p.invuln > 0 && state === 'playing' && ((t * 14) | 0) % 2) ctx.globalAlpha = 0.35;
  ctx.scale(p.face, 1);
  ctx.shadowColor = 'rgba(60,0,40,.35)'; ctx.shadowBlur = 0; ctx.shadowOffsetY = 3;
  ctx.drawImage(img, -w / 2, -h, w, h);
  ctx.restore();
  // тень на платформе
  if (p.grounded && state !== 'win-anim') {
    ctx.save(); ctx.fillStyle = 'rgba(50,10,40,.22)';
    ctx.beginPath(); ctx.ellipse(cx, bottom + 4 - 0, 26, 6, 0, 0, 7); ctx.fill(); ctx.restore();
  }
}
function draw(t) {
  ctx.clearRect(0, 0, VIEW_W, VIEW_H);
  const shX = camShake ? (Math.random() - 0.5) * camShake : 0;
  const shY = camShake ? (Math.random() - 0.5) * camShake : 0;
  ctx.save(); ctx.translate(shX, shY);

  // 1) небо
  const sky = ctx.createLinearGradient(0, 0, 0, VIEW_H);
  sky.addColorStop(0, '#79c7f2'); sky.addColorStop(0.6, '#bfe6fb'); sky.addColorStop(1, '#ffe9f4');
  ctx.fillStyle = sky; ctx.fillRect(-10, -10, VIEW_W + 20, VIEW_H + 20);

  // 2) ПАРАЛЛАКС: далёкие облака и островки (0.35 / 0.55 от камеры)
  for (const c of clouds) {
    const span = WORLD_W * c.f + 500;
    let x = (c.x - camX * c.f) % span; if (x < -220) x += span;
    drawCloud(x, c.y - camY * 0.3, c.s, c.a);
  }
  ctx.save(); ctx.globalAlpha = 0.5; ctx.fillStyle = '#ffb9d9';
  for (let i = 0; i < 7; i++) { // далёкие сакуровые кроны
    const f = 0.45, span = WORLD_W * f + 600;
    let x = (i * 620 + 180 - camX * f) % span; if (x < -200) x += span;
    ctx.beginPath(); ctx.ellipse(x, 120 + (i % 3) * 60 - camY * 0.3, 90, 34, 0, 0, 7); ctx.fill();
  }
  ctx.restore();

  // 3) карта мира (платформы, флаг, храм) — слой 1.0
  if (IMG.map) ctx.drawImage(IMG.map, camX, camY, VIEW_W, VIEW_H, 0, 0, VIEW_W, VIEW_H);

  // стартовая подсказка у флажка
  if (camX < 300) {
    ctx.save(); ctx.font = '800 19px "Segoe UI",sans-serif'; ctx.textAlign = 'center';
    ctx.fillStyle = 'rgba(43,22,48,.78)';
    const tw = ctx.measureText('СТАРТ ⚑ → беги вправо!').width + 30;
    ctx.beginPath(); ctx.roundRect(58 - camX + 40, 400 - camY, tw, 34, 17); ctx.fill();
    ctx.fillStyle = '#ffd7ec'; ctx.fillText('СТАРТ ⚑ → беги вправо!', 58 - camX + 40 + tw / 2, 423 - camY);
    ctx.restore();
  }

  // 4) крутящаяся воронка портала
  drawPortal(t);

  // 5) предметы
  for (const it of items) {
    if (it.taken) continue;
    const x = it.x - camX, y = (it.drawY ?? it.y) - camY;
    if (x < -40 || x > VIEW_W + 40) continue;
    if (it.kind === 'coin') {
      ctx.save(); ctx.translate(x, y);
      ctx.scale(Math.abs(Math.cos(t * 3 + it.ph)) * 0.7 + 0.3, 1);
      ctx.fillStyle = '#ffd94d'; ctx.strokeStyle = '#d99600'; ctx.lineWidth = 2.5;
      ctx.beginPath(); ctx.arc(0, 0, 13, 0, 7); ctx.fill(); ctx.stroke();
      drawStar(0, 0, 7, t * 2, '#fff3b0'); ctx.restore();
    } else if (it.kind === 'gem') {
      ctx.save(); ctx.translate(x, y); ctx.rotate(Math.sin(t * 2 + it.ph) * 0.25);
      ctx.fillStyle = '#6ee7ff'; ctx.strokeStyle = '#1d9dc4'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(0, -15); ctx.lineTo(11, 0); ctx.lineTo(0, 17); ctx.lineTo(-11, 0);
      ctx.closePath(); ctx.fill(); ctx.stroke(); ctx.restore();
    } else {
      ctx.save(); ctx.translate(x, y); ctx.scale(1 + Math.sin(t * 4) * 0.1, 1 + Math.sin(t * 4) * 0.1);
      ctx.fillStyle = '#ff5f9e'; ctx.strokeStyle = '#c2266b'; ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(0, 12); ctx.bezierCurveTo(-20, -4, -9, -17, 0, -7);
      ctx.bezierCurveTo(9, -17, 20, -4, 0, 12); ctx.fill(); ctx.stroke(); ctx.restore();
    }
  }

  // 6) враги (каждый на своей платформе)
  for (const e of enemies) {
    if (e.dead) continue;
    const img = IMG[e.img]; if (!img) continue;
    const y = (e.drawY ?? e.baseY - e.h), x = e.x - camX;
    if (x < -120 || x > VIEW_W + 120) continue;
    const w = e.h * img.width / img.height;
    ctx.save(); ctx.translate(x, y - camY);
    if (e.dir < 0) ctx.scale(-1, 1);
    if (e.flash > 0) { ctx.shadowColor = '#ff4040'; ctx.shadowBlur = 18; }
    ctx.drawImage(img, -w / 2, 0, w, e.h);
    ctx.restore();
    if (e.hp < e.maxHp) { // полоска HP врага
      ctx.save();
      ctx.fillStyle = 'rgba(30,5,25,.65)'; ctx.fillRect(x - 22, y - camY - 11, 44, 6);
      ctx.fillStyle = '#ff5f9e'; ctx.fillRect(x - 21, y - camY - 10, 42 * e.hp / e.maxHp, 4);
      ctx.restore();
    }
  }

  // 7) звёздочки-снаряды
  for (const b of bullets) drawStar(b.x - camX, b.y - camY, 13, b.rot, '#ff4fd8'),
    drawStar(b.x - camX, b.y - camY, 6, -b.rot, '#fff');

  // 8) частицы взрывов
  for (const pt of particles) {
    ctx.save(); ctx.globalAlpha = Math.max(0, pt.life / pt.max);
    if (pt.star) drawStar(pt.x - camX, pt.y - camY, pt.size + 2, pt.rot, pt.color);
    else { ctx.fillStyle = pt.color; ctx.beginPath(); ctx.arc(pt.x - camX, pt.y - camY, pt.size, 0, 7); ctx.fill(); }
    ctx.restore();
  }
  // всплывающие очки
  ctx.save(); ctx.font = '800 17px "Segoe UI",sans-serif'; ctx.textAlign = 'center';
  for (const f of floaters) {
    ctx.globalAlpha = Math.max(0, f.life);
    ctx.fillStyle = f.color; ctx.strokeStyle = 'rgba(60,0,40,.6)'; ctx.lineWidth = 3;
    ctx.strokeText(f.text, f.x - camX, f.y - camY); ctx.fillText(f.text, f.x - camX, f.y - camY);
  }
  ctx.restore();

  // 9) героиня
  drawHero(t);

  // 10) ПАРАЛЛАКС переднего плана: лепестки трёх глубин поверх мира
  const camDelta = camX - prevCamX;
  for (const pt of petals) {
    pt.y += pt.fall * pt.depth * 0.016;
    pt.sway += pt.swaySpeed * 0.016;
    pt.x += Math.sin(pt.sway) * 0.7 - camDelta * (pt.depth - 0.8) * 0.9;
    pt.rot += pt.spin * 0.016;
    if (pt.y > VIEW_H + 18) { pt.y = -14; pt.x = Math.random() * VIEW_W; }
    if (pt.x < -20) pt.x += VIEW_W + 40; if (pt.x > VIEW_W + 20) pt.x -= VIEW_W + 40;
    drawPetalShape(pt.x, pt.y, pt.size, pt.rot, pt.alpha);
  }
  // веточки сакуры по углам кадра (самый близкий слой)
  ctx.save(); ctx.globalAlpha = 0.85;
  const swayFg = Math.sin(t * 0.8) * 5 - (camX % 40) * 0.12;
  ctx.fillStyle = '#5b2a3d';
  ctx.fillRect(-8 + swayFg, -6, 150, 13); ctx.fillRect(-6, -8, 13, 105);
  ctx.fillRect(VIEW_W - 140 + swayFg, -6, 150, 13);
  for (const [bx, by] of [[24, 16], [66, 10], [112, 20], [VIEW_W - 34, 14], [VIEW_W - 82, 10], [VIEW_W - 124, 22]]) {
    ctx.fillStyle = '#ff9ec7';
    for (let i = 0; i < 6; i++) {
      const a = i * 1.05 + bx;
      ctx.beginPath(); ctx.ellipse(bx + Math.cos(a) * 11, by + Math.sin(a) * 8, 10, 7, a, 0, 7); ctx.fill();
    }
    ctx.fillStyle = '#ffc7de'; ctx.beginPath(); ctx.arc(bx, by, 5.5, 0, 7); ctx.fill();
  }
  ctx.restore();
  ctx.restore();
}

/* ---------------- главный цикл ---------------- */
let lastTs = 0;
function loop(ts) {
  requestAnimationFrame(loop);
  const dt = Math.min(0.033, (ts - lastTs) / 1000 || 0.016);
  lastTs = ts;
  const t = ts / 1000;
  if (state === 'playing') update(dt);
  else if (state === 'win-anim') {
    winTimer += dt;
    for (const pt of particles) { pt.life -= dt; pt.x += pt.vx * dt; pt.y += pt.vy * dt; pt.rot += dt * 6; }
    particles = particles.filter(pt => pt.life > 0);
    if (winTimer > 1.45) {
      state = 'win';
      ui.winStats.innerHTML = statsHTML();
      ui.win.hidden = false; ui.hud.hidden = true;
    }
  }
  draw(t);
}

/* ---------------- управление экранами ---------------- */
function startGame() {
  resetGame();
  state = 'playing';
  ui.menu.hidden = true; ui.win.hidden = true; ui.over.hidden = true; ui.pause.hidden = true;
  ui.hud.hidden = false;
  if (touchActive) ui.touch.hidden = false;
  try { audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)(); audioCtx.resume(); } catch (e) {}
  startMusic();
}
function pauseGame() { if (state !== 'playing') return; state = 'paused'; ui.pause.hidden = false; }
function resumeGame() { if (state !== 'paused') return; state = 'playing'; ui.pause.hidden = true; }
function toggleMute() {
  muted = !muted;
  $('soundBtn').textContent = muted ? '🔇' : '🔊';
  setMusicVolume();
}
$('startBtn').addEventListener('click', startGame);
$('againBtn').addEventListener('click', startGame);
$('retryBtn').addEventListener('click', startGame);
$('restartBtn2').addEventListener('click', startGame);
$('resumeBtn').addEventListener('click', resumeGame);
$('pauseBtn').addEventListener('click', () => state === 'playing' ? pauseGame() : resumeGame());
$('soundBtn').addEventListener('click', toggleMute);

resetGame();
player.hp = 5;
requestAnimationFrame(loop);
