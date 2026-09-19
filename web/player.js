/* Global Module is shared with the generated game.js preload script. */
var canvas = document.getElementById('canvas');
var overlay = document.getElementById('overlay');
var statusText = document.getElementById('status');
var startButton = document.getElementById('start');
var failed = false;
var started = false;

function showError(message) {
  failed = true;
  overlay.hidden = false;
  startButton.hidden = true;
  statusText.textContent = message;
  console.error(message);
}

// Scale the real canvas rectangle, preserving pointer coordinate mapping.
// LÖVE still draws at the size configured in game/project.lua.
function fitCanvas() {
  var scale = Math.min(window.innerWidth / canvas.width, window.innerHeight / canvas.height);
  canvas.style.width = Math.max(1, Math.floor(canvas.width * scale)) + 'px';
  canvas.style.height = Math.max(1, Math.floor(canvas.height * scale)) + 'px';
}

// Kept for compatibility with love.js fullscreen hooks.
function FullScreenHook() { fitCanvas(); }

var Module = {
  arguments: ['./game.love'],
  INITIAL_MEMORY: __INITIAL_MEMORY__,
  canvas: canvas,
  print: function (text) { console.log(text); },
  printErr: function (text) { console.error(text); },
  setStatus: function (text) {
    if (!failed && !started && text) statusText.textContent = text;
  },
  monitorRunDependencies: function (remaining) {
    if (remaining) this.setStatus('Preparing game…');
  },
  onAbort: function () { showError('The game could not start. Check the browser console, then reload.'); },
  postRun: [function () {
    if (failed) return;
    // Wait for a user gesture before the first Lua frame and audio startup.
    Module.pauseMainLoop();
    statusText.textContent = 'Ready when you are.';
    startButton.hidden = false;
    fitCanvas();
  }]
};

function bootGame() {
  if (failed) return;
  try {
    Love(Module).catch(function (error) { showError('Could not initialize the game: ' + error); });
  } catch (error) {
    showError('Could not initialize the game: ' + error);
  }
}

startButton.addEventListener('click', function () {
  started = true;
  overlay.hidden = true;
  canvas.focus();
  Module.resumeMainLoop();
});
canvas.addEventListener('pointerdown', function () { canvas.focus(); });
canvas.addEventListener('contextmenu', function (event) { event.preventDefault(); });
canvas.addEventListener('webglcontextlost', function (event) {
  event.preventDefault();
  showError('The graphics context was lost. Reload the page to continue.');
});
window.addEventListener('keydown', function (event) {
  if (document.activeElement === canvas && ['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(event.code)) {
    event.preventDefault();
  }
});
window.addEventListener('resize', fitCanvas);
document.addEventListener('fullscreenchange', fitCanvas);
new MutationObserver(fitCanvas).observe(canvas, { attributes: true, attributeFilter: ['width', 'height'] });
document.getElementById('fullscreen').addEventListener('click', async function () {
  try {
    if (document.fullscreenElement) await document.exitFullscreen();
    else if (document.documentElement.requestFullscreen) await document.documentElement.requestFullscreen();
    canvas.focus();
  } catch (error) { console.warn('Fullscreen is unavailable in this embed.', error); }
});
window.addEventListener('error', function (event) {
  if (event.message) showError('The game stopped unexpectedly. Check the browser console, then reload.');
});
fitCanvas();
