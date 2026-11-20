/*
 * Klondike solitaire rules engine. No DOM access — pure game state.
 * Pile references look like { type: 'tableau' | 'foundation' | 'waste' | 'stock', i: number }.
 */
(function (global) {
  'use strict';

  const SUITS = ['S', 'H', 'D', 'C'];
  const SUIT_SYMBOL = { S: '♠', H: '♥', D: '♦', C: '♣' };
  const RANK_LABEL = ['', 'A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
  const MAX_HISTORY = 200;

  const isRed = (suit) => suit === 'H' || suit === 'D';

  // True when `card` may sit on top of `onto` in the tableau.
  const stacksOn = (card, onto) =>
    onto.rank === card.rank + 1 && isRed(onto.suit) !== isRed(card.suit);

  const sameRef = (a, b) => a.type === b.type && (a.i || 0) === (b.i || 0);

  function createDeck() {
    const deck = [];
    for (const suit of SUITS) {
      for (let rank = 1; rank <= 13; rank++) {
        deck.push({ id: suit + rank, suit, rank, faceUp: false });
      }
    }
    return deck;
  }

  function shuffle(arr, rng = Math.random) {
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(rng() * (i + 1));
      [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    return arr;
  }

  class Klondike {
    constructor({ drawCount = 1 } = {}) {
      this.drawCount = drawCount === 3 ? 3 : 1;
      this.deal();
    }

    deal() {
      const deck = shuffle(createDeck());
      this.tableau = Array.from({ length: 7 }, () => []);
      for (let col = 0; col < 7; col++) {
        for (let row = 0; row <= col; row++) {
          const card = deck.pop();
          card.faceUp = row === col;
          this.tableau[col].push(card);
        }
      }
      this.stock = deck;
      this.waste = [];
      this.foundations = [[], [], [], []];
      this.moves = 0;
      this.elapsed = 0;
      this.started = false;
      this.won = false;
      this.history = [];
    }

    pile(ref) {
      switch (ref.type) {
        case 'stock': return this.stock;
        case 'waste': return this.waste;
        case 'foundation': return this.foundations[ref.i];
        case 'tableau': return this.tableau[ref.i];
        default: return null;
      }
    }

    // ---- history -------------------------------------------------------

    record() {
      this.history.push(JSON.stringify({
        stock: this.stock,
        waste: this.waste,
        foundations: this.foundations,
        tableau: this.tableau,
        moves: this.moves,
      }));
      if (this.history.length > MAX_HISTORY) this.history.shift();
      this.started = true;
    }

    canUndo() {
      return this.history.length > 0 && !this.won;
    }

    undo() {
      if (!this.canUndo()) return false;
      Object.assign(this, JSON.parse(this.history.pop()));
      return true;
    }

    // ---- moves ---------------------------------------------------------

    // Flip from stock to waste, or recycle the waste when the stock is empty.
    draw() {
      if (this.won) return false;
      if (this.stock.length) {
        this.record();
        const n = Math.min(this.drawCount, this.stock.length);
        for (let k = 0; k < n; k++) {
          const card = this.stock.pop();
          card.faceUp = true;
          this.waste.push(card);
        }
      } else if (this.waste.length) {
        this.record();
        this.stock = this.waste.reverse();
        this.stock.forEach((c) => { c.faceUp = false; });
        this.waste = [];
      } else {
        return false;
      }
      this.moves++;
      return true;
    }

    canPick(ref, index) {
      if (ref.type === 'stock') return false;
      const pile = this.pile(ref);
      const card = pile && pile[index];
      if (!card || !card.faceUp) return false;
      if (ref.type !== 'tableau') return index === pile.length - 1;
      for (let k = index; k < pile.length - 1; k++) {
        if (!stacksOn(pile[k + 1], pile[k])) return false;
      }
      return true;
    }

    canPlace(cards, ref) {
      const pile = this.pile(ref);
      if (!pile || !cards.length) return false;
      const first = cards[0];
      const top = pile[pile.length - 1];
      if (ref.type === 'foundation') {
        if (cards.length !== 1) return false;
        return top ? top.suit === first.suit && first.rank === top.rank + 1 : first.rank === 1;
      }
      if (ref.type === 'tableau') {
        return top ? top.faceUp && stacksOn(first, top) : first.rank === 13;
      }
      return false;
    }

    canMove(from, index, to) {
      if (sameRef(from, to) || !this.canPick(from, index)) return false;
      return this.canPlace(this.pile(from).slice(index), to);
    }

    move(from, index, to) {
      if (this.won || !this.canMove(from, index, to)) return false;
      this.record();
      const src = this.pile(from);
      const cards = src.splice(index);
      this.pile(to).push(...cards);
      const exposed = src[src.length - 1];
      if (from.type === 'tableau' && exposed && !exposed.faceUp) exposed.faceUp = true;
      this.moves++;
      this.won = this.foundations.every((f) => f.length === 13);
      return true;
    }

    // Best destination for a click: foundation first, then a non-empty
    // tableau column, then an empty column (unless it would be pointless).
    findAutoTarget(from, index) {
      const count = this.pile(from).length - index;
      if (count === 1) {
        for (let i = 0; i < 4; i++) {
          const to = { type: 'foundation', i };
          if (this.canMove(from, index, to)) return to;
        }
      }
      const alreadyAtColumnBase = from.type === 'tableau' && index === 0;
      let empty = null;
      for (let i = 0; i < 7; i++) {
        const to = { type: 'tableau', i };
        if (!this.canMove(from, index, to)) continue;
        if (this.tableau[i].length) return to;
        if (!empty && !alreadyAtColumnBase) empty = to;
      }
      return empty;
    }

    autoMove(from, index) {
      const to = this.findAutoTarget(from, index);
      return to ? this.move(from, index, to) : false;
    }

    // Once everything is face up and the stock is spent, the game is solved.
    canAutoFinish() {
      return !this.won && this.stock.length === 0 && this.waste.length === 0 &&
        this.tableau.every((col) => col.every((c) => c.faceUp));
    }

    autoFinishStep() {
      let best = null;
      for (let i = 0; i < 7; i++) {
        const col = this.tableau[i];
        if (!col.length) continue;
        const top = col[col.length - 1];
        if (best && best.card.rank <= top.rank) continue;
        for (let f = 0; f < 4; f++) {
          if (this.canMove({ type: 'tableau', i }, col.length - 1, { type: 'foundation', i: f })) {
            best = { card: top, from: { type: 'tableau', i }, index: col.length - 1, to: { type: 'foundation', i: f } };
            break;
          }
        }
      }
      return best ? this.move(best.from, best.index, best.to) : false;
    }

    // ---- persistence ---------------------------------------------------

    toJSON() {
      return {
        v: 1,
        drawCount: this.drawCount,
        stock: this.stock,
        waste: this.waste,
        foundations: this.foundations,
        tableau: this.tableau,
        moves: this.moves,
        elapsed: this.elapsed,
        started: this.started,
        won: this.won,
        history: this.history.slice(-100),
      };
    }

    static fromJSON(data) {
      if (!data || data.v !== 1) return null;
      const total = data.stock.length + data.waste.length +
        data.foundations.reduce((n, p) => n + p.length, 0) +
        data.tableau.reduce((n, p) => n + p.length, 0);
      if (total !== 52) return null;
      const game = Object.create(Klondike.prototype);
      Object.assign(game, data);
      delete game.v;
      return game;
    }
  }

  global.Solitaire = { Klondike, SUIT_SYMBOL, RANK_LABEL, isRed };
})(typeof window !== 'undefined' ? window : globalThis);
