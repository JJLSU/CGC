// Keyboard / mouse state with pointer lock.
export class Input {
  constructor(canvas) {
    this.canvas = canvas;
    this.keys = new Set();
    this.pressed = new Set(); // keys pressed this frame
    this.dx = 0; this.dy = 0; this.wheel = 0;
    this.clicked = false;
    this.mouseDown = false;
    this.locked = false;
    this.onLockChange = null;

    addEventListener('keydown', (e) => {
      if (!this.keys.has(e.code)) this.pressed.add(e.code);
      this.keys.add(e.code);
      if (this.locked && ['Space', 'Tab'].includes(e.code)) e.preventDefault();
      if (e.code === 'F3') e.preventDefault(); // the game's debug badge, not the browser's find bar
      if (e.target instanceof HTMLButtonElement && e.code === 'Space') e.preventDefault();
    });
    addEventListener('keyup', (e) => this.keys.delete(e.code));
    addEventListener('blur', () => this.keys.clear());
    addEventListener('mousemove', (e) => {
      if (!this.locked) return;
      this.dx += e.movementX; this.dy += e.movementY;
    });
    addEventListener('mousedown', (e) => {
      if (!this.locked || e.button !== 0) return;
      this.clicked = true; this.mouseDown = true;
    });
    addEventListener('mousedown', (e) => {
      if (this.locked && e.button === 2) { this.rightClicked = true; this.rightDown = true; }
    });
    addEventListener('mouseup', (e) => { if (e.button === 2) this.rightDown = false; });
    addEventListener('contextmenu', (e) => { if (this.locked) e.preventDefault(); });
    addEventListener('mouseup', (e) => { if (e.button === 0) this.mouseDown = false; });
    addEventListener('wheel', (e) => { if (this.locked) this.wheel += Math.sign(e.deltaY); }, { passive: true });
    document.addEventListener('pointerlockchange', () => {
      this.locked = document.pointerLockElement === this.canvas;
      if (!this.locked) { this.keys.clear(); this.mouseDown = false; this.rightDown = false; }
      if (this.onLockChange) this.onLockChange(this.locked);
    });
  }

  lock() { try { this.canvas.requestPointerLock?.()?.catch?.(() => {}); } catch { /* the browser refused: the pause card stays up */ } }

  down(code) { return this.keys.has(code); }
  hit(code) { return this.pressed.has(code); }

  endFrame() {
    this.pressed.clear();
    this.dx = 0; this.dy = 0; this.wheel = 0;
    this.clicked = false;
    this.rightClicked = false;
  }

  unlock() { if (document.pointerLockElement) document.exitPointerLock(); }
}
