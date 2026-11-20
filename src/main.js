/*
 * UI layer: renders the Klondike state into the board and handles input
 * (click to auto-move, drag and drop, keyboard shortcuts).
 */
(function () {
  'use strict';

  const { Klondike, SUIT_SYMBOL, RANK_LABEL, isRed } = window.Solitaire;

  const STORE_KEY = 'solitaire.game.v1';
  const PREF_KEY = 'solitaire.drawCount';
  const FAN_DOWN = 0.12; // vertical offset per face-down card, in card heights
  const FAN_UP = 0.26;   // vertical offset per face-up card
  const WASTE_FAN = 0.2; // horizontal offset in the draw-3 waste, in card widths
  const DRAG_THRESHOLD = 5;

  const $ = (id) => document.getElementById(id);
  const board = $('board');
  const piles = {
    stock: board.querySelector('[data-pile="stock"]'),
    waste: board.querySelector('[data-pile="waste"]'),
    foundation: [...board.querySelectorAll('[data-pile="foundation"]')],
    tableau: [...board.querySelectorAll('[data-pile="tableau"]')],
  };
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

  let game = loadGame() || new Klondike({ drawCount: loadPref() });
  let drag = null;
  let finishing = null;

  // ---- storage (best effort; the game works without it) -----------------

  function loadGame() {
    try { return Klondike.fromJSON(JSON.parse(localStorage.getItem(STORE_KEY))); } catch { return null; }
  }
  function saveGame() {
    try { localStorage.setItem(STORE_KEY, JSON.stringify(game)); } catch { /* ignore */ }
  }
  function loadPref() {
    try { return Number(localStorage.getItem(PREF_KEY)) === 3 ? 3 : 1; } catch { return 1; }
  }
  function savePref(n) {
    try { localStorage.setItem(PREF_KEY, String(n)); } catch { /* ignore */ }
  }

  // ---- rendering --------------------------------------------------------

  function refOf(pileEl) {
    return { type: pileEl.dataset.pile, i: Number(pileEl.dataset.index || 0) };
  }

  function makeCard(card, index) {
    const el = document.createElement('div');
    el.dataset.id = card.id;
    el.dataset.index = index;
    if (card.faceUp) {
      const rank = RANK_LABEL[card.rank];
      const suit = SUIT_SYMBOL[card.suit];
      el.className = 'card up' + (isRed(card.suit) ? ' red' : '');
      el.setAttribute('aria-label', `${rank} of ${suit}`);
      el.innerHTML =
        `<span class="corner tl">${rank}<br>${suit}</span>` +
        `<span class="pip">${suit}</span>` +
        `<span class="corner br">${rank}<br>${suit}</span>`;
    } else {
      el.className = 'card down';
    }
    return el;
  }

  // Render the top `depth` cards of a pile, stacked in place.
  function renderStack(pileEl, cards, depth) {
    const start = Math.max(0, cards.length - depth);
    for (let k = start; k < cards.length; k++) pileEl.append(makeCard(cards[k], k));
  }

  function renderWaste() {
    const w = game.waste;
    const shown = game.drawCount === 3 ? Math.min(3, w.length) : Math.min(1, w.length);
    const firstShown = w.length - shown;
    if (firstShown > 0) piles.waste.append(makeCard(w[firstShown - 1], firstShown - 1));
    for (let k = firstShown; k < w.length; k++) {
      const el = makeCard(w[k], k);
      el.style.left = `calc(var(--cw) * ${WASTE_FAN * (k - firstShown)})`;
      piles.waste.append(el);
    }
  }

  function renderTableau(pileEl, cards) {
    let offset = 0;
    cards.forEach((card, k) => {
      const el = makeCard(card, k);
      el.style.top = `calc(var(--ch) * ${offset})`;
      pileEl.append(el);
      offset += card.faceUp ? FAN_UP : FAN_DOWN;
    });
    const last = cards.length ? offset - (cards[cards.length - 1].faceUp ? FAN_UP : FAN_DOWN) : 0;
    pileEl.style.height = `calc(var(--ch) * ${1 + last})`;
  }

  function render() {
    const before = new Map();
    board.querySelectorAll('.card').forEach((el) => before.set(el.dataset.id, el.getBoundingClientRect()));

    [piles.stock, piles.waste, ...piles.foundation, ...piles.tableau].forEach((p) => p.replaceChildren());

    renderStack(piles.stock, game.stock, 1);
    const stockTop = piles.stock.lastElementChild;
    if (stockTop) stockTop.dataset.count = game.stock.length;
    piles.stock.classList.toggle('recyclable', !game.stock.length && game.waste.length > 0);

    renderWaste();
    game.foundations.forEach((cards, i) => renderStack(piles.foundation[i], cards, 2));
    game.tableau.forEach((cards, i) => renderTableau(piles.tableau[i], cards));

    updateStats();
    $('undo').disabled = !game.canUndo() || !!finishing;
    $('auto-finish').hidden = !game.canAutoFinish() || !!finishing;
    $('win').hidden = !game.won;
    if (game.won) $('win-summary').textContent = `${game.moves} moves in ${formatTime(game.elapsed)}.`;

    animateFrom(before);
    saveGame();
  }

  // FLIP: cards that moved slide from their previous position.
  function animateFrom(before) {
    if (reduceMotion.matches) return;
    board.querySelectorAll('.card').forEach((el) => {
      const prev = before.get(el.dataset.id);
      if (!prev) return;
      const now = el.getBoundingClientRect();
      const dx = prev.left - now.left;
      const dy = prev.top - now.top;
      if (Math.abs(dx) < 1 && Math.abs(dy) < 1) return;
      el.style.transition = 'none';
      el.style.transform = `translate(${dx}px, ${dy}px)`;
      el.style.zIndex = 500;
      requestAnimationFrame(() => requestAnimationFrame(() => {
        el.style.transition = 'transform 180ms ease-out';
        el.style.transform = '';
        el.addEventListener('transitionend', () => {
          el.style.transition = '';
          el.style.zIndex = '';
        }, { once: true });
      }));
    });
  }

  function formatTime(sec) {
    const m = Math.floor(sec / 60);
    const s = String(sec % 60).padStart(2, '0');
    return `${m}:${s}`;
  }

  function updateStats() {
    $('moves').textContent = game.moves;
    $('time').textContent = formatTime(game.elapsed);
  }

  function nope(els) {
    els.forEach((el) => {
      el.classList.remove('nope');
      void el.offsetWidth; // restart animation
      el.classList.add('nope');
    });
  }

  // ---- actions ----------------------------------------------------------

  function newGame(drawCount = game.drawCount) {
    stopFinishing();
    game = new Klondike({ drawCount });
    render();
  }

  function undo() {
    if (finishing) return;
    if (game.undo()) render();
  }

  function draw() {
    if (finishing) return;
    if (game.draw()) render();
  }

  function autoFinish() {
    if (finishing || !game.canAutoFinish()) return;
    finishing = setInterval(() => {
      if (!game.autoFinishStep()) stopFinishing();
      render();
    }, 110);
    render();
  }

  function stopFinishing() {
    if (finishing) clearInterval(finishing);
    finishing = null;
  }

  // ---- pointer input ----------------------------------------------------

  // Pick the legal destination pile that overlaps the dragged card the most.
  function findDropTarget(rect, from, index) {
    const candidates = [];
    const consider = (pileEl) => {
      const ref = refOf(pileEl);
      const box = pileEl.getBoundingClientRect();
      const last = pileEl.lastElementChild;
      const bottom = last ? Math.max(box.bottom, last.getBoundingClientRect().bottom) : box.bottom;
      const w = Math.min(rect.right, box.right) - Math.max(rect.left, box.left);
      const h = Math.min(rect.bottom, bottom) - Math.max(rect.top, box.top);
      if (w > 0 && h > 0) candidates.push({ ref, area: w * h });
    };
    piles.foundation.forEach(consider);
    piles.tableau.forEach(consider);
    candidates.sort((a, b) => b.area - a.area);
    const hit = candidates.find((c) => game.canMove(from, index, c.ref));
    return hit ? hit.ref : null;
  }

  board.addEventListener('pointerdown', (e) => {
    if (e.button !== 0 || finishing || drag) return;
    const pileEl = e.target.closest('.pile');
    if (!pileEl) return;
    const ref = refOf(pileEl);

    if (ref.type === 'stock') {
      e.preventDefault();
      draw();
      return;
    }

    const cardEl = e.target.closest('.card');
    if (!cardEl) return;
    const index = Number(cardEl.dataset.index);
    if (!game.canPick(ref, index)) {
      if (cardEl.classList.contains('up')) nope([cardEl]);
      return;
    }

    const els = ref.type === 'tableau'
      ? [...pileEl.querySelectorAll('.card')].filter((el) => Number(el.dataset.index) >= index)
      : [cardEl];
    drag = { ref, index, els, x0: e.clientX, y0: e.clientY, moved: false, pointerId: e.pointerId };
    board.setPointerCapture(e.pointerId);
    e.preventDefault();
  });

  board.addEventListener('pointermove', (e) => {
    if (!drag || e.pointerId !== drag.pointerId) return;
    const dx = e.clientX - drag.x0;
    const dy = e.clientY - drag.y0;
    if (!drag.moved) {
      if (Math.hypot(dx, dy) < DRAG_THRESHOLD) return;
      drag.moved = true;
      drag.els.forEach((el) => {
        el.style.transition = 'none';
        el.classList.add('dragging');
      });
    }
    drag.els.forEach((el) => { el.style.transform = `translate(${dx}px, ${dy}px)`; });
  });

  board.addEventListener('pointerup', (e) => {
    if (!drag || e.pointerId !== drag.pointerId) return;
    const d = drag;
    drag = null;
    if (!d.moved) {
      if (game.autoMove(d.ref, d.index)) render();
      else nope(d.els);
      return;
    }
    const target = findDropTarget(d.els[0].getBoundingClientRect(), d.ref, d.index);
    if (target) game.move(d.ref, d.index, target);
    render(); // either lands on the target or slides back home
  });

  board.addEventListener('pointercancel', (e) => {
    if (!drag || e.pointerId !== drag.pointerId) return;
    drag = null;
    render();
  });

  // ---- controls ---------------------------------------------------------

  $('new-game').addEventListener('click', () => newGame());
  $('play-again').addEventListener('click', () => newGame());
  $('undo').addEventListener('click', undo);
  $('auto-finish').addEventListener('click', autoFinish);

  const drawSelect = $('draw-mode');
  drawSelect.value = String(game.drawCount);
  drawSelect.addEventListener('change', () => {
    const n = Number(drawSelect.value);
    savePref(n);
    if (!game.started || confirm(`Start a new Draw ${n} game? Your current game will be lost.`)) {
      newGame(n);
    } else {
      drawSelect.value = String(game.drawCount);
    }
  });

  document.addEventListener('keydown', (e) => {
    if (e.target.closest('select, input, textarea')) return;
    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'z') {
      e.preventDefault();
      undo();
    } else if (!e.metaKey && !e.ctrlKey && !e.altKey) {
      if (e.key === 'n' || e.key === 'N') newGame();
      else if (e.key === ' ' && e.target === document.body) { e.preventDefault(); draw(); }
    }
  });

  // ---- timer ------------------------------------------------------------

  setInterval(() => {
    if (!game.started || game.won || document.hidden) return;
    game.elapsed++;
    updateStats();
    if (game.elapsed % 5 === 0) saveGame();
  }, 1000);

  window.addEventListener('pagehide', saveGame);

  render();
})();
