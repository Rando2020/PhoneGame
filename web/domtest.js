/* A DOM shim just rich enough to load and drive the real bundle in node,
   so runtime errors surface without a browser. */
function mkClassList(node) {
  const set = new Set();
  return {
    add: (...c) => c.forEach((x) => x && set.add(x)),
    remove: (...c) => c.forEach((x) => set.delete(x)),
    toggle: (c, on) => (on === undefined ? (set.has(c) ? set.delete(c) : set.add(c))
                                         : (on ? set.add(c) : set.delete(c))),
    contains: (c) => set.has(c),
    get _set() { return set; },
  };
}
function mkNode(tag) {
  const n = {
    tagName: (tag || "div").toUpperCase(), children: [], childNodes: [], parentNode: null,
    style: new Proxy({ setProperty() {}, removeProperty() {} }, { get: (t, k) => t[k] ?? "", set: (t, k, v) => (t[k] = v, true) }),
    dataset: {}, _text: "", _html: "", attributes: {},
    get textContent() { return this._text; },
    set textContent(v) { this._text = String(v); },
    get innerHTML() { return this._html; },
    set innerHTML(v) { this._html = String(v); if (v === "") this.children = []; },
    get firstChild() { return this.children[0] || null; },
    get lastChild() { return this.children[this.children.length - 1] || null; },
    get offsetWidth() { return 100; },
    get offsetHeight() { return 40; },
    append(...ns) { for (const c of ns) if (c && typeof c === "object") { c.parentNode = this; this.children.push(c); } },
    appendChild(c) { this.append(c); return c; },
    remove() { const p = this.parentNode; if (p) p.children = p.children.filter((x) => x !== p && x !== this); },
    removeChild(c) { this.children = this.children.filter((x) => x !== c); return c; },
    setAttribute(k, v) { this.attributes[k] = v; },
    getAttribute(k) { return this.attributes[k]; },
    addEventListener() {}, removeEventListener() {},
    getBoundingClientRect: () => ({ left: 10, top: 10, width: 60, height: 90, bottom: 100, right: 70 }),
    animate: () => ({ finished: Promise.resolve(), cancel() {} }),
    querySelector(sel) { return this._find(sel)[0] || null; },
    querySelectorAll(sel) { return this._find(sel); },
    _find(sel) {
      const out = [];
      const want = String(sel).replace(/^[.#]/, "").split(/[ .#\[]/)[0];
      const walk = (node) => {
        for (const c of node.children || []) {
          if (c.classList && c.classList.contains(want)) out.push(c);
          if (c.id === want) out.push(c);
          walk(c);
        }
      };
      walk(this);
      return out;
    },
  };
  n.classList = mkClassList(n);
  return n;
}
const document = {
  body: mkNode("body"),
  head: mkNode("head"),
  createElement: (t) => mkNode(t),
  createTextNode: (t) => ({ _text: t }),
  addEventListener() {},
  getElementById(id) {
    const walk = (n) => {
      for (const c of n.children || []) { if (c.id === id) return c; const r = walk(c); if (r) return r; }
      return null;
    };
    return walk(document.body);
  },
  querySelector(s) { return document.body.querySelector(s); },
  querySelectorAll(s) { return document.body.querySelectorAll(s); },
};
const app = mkNode("div"); app.id = "app"; document.body.append(app);

const store = {};
const localStorage = {
  getItem: (k) => (k in store ? store[k] : null),
  setItem: (k, v) => (store[k] = String(v)),
  removeItem: (k) => delete store[k],
};
/* Enough WebAudio to let the real synth run without making noise. */
const param = () => ({ value: 0, setValueAtTime() { return this; },
  linearRampToValueAtTime() { return this; }, exponentialRampToValueAtTime() { return this; },
  cancelScheduledValues() { return this; } });
const nodeStub = () => ({ connect() { return nodeStub(); }, disconnect() {},
  start() {}, stop() {}, frequency: param(), detune: param(), gain: param(),
  Q: param(), delayTime: param(), threshold: param(), ratio: param(),
  attack: param(), release: param(), type: "square", buffer: null, loop: false });
class AudioContextStub {
  constructor() { this.currentTime = 0; this.sampleRate = 44100; this.state = "running";
    this.destination = nodeStub(); }
  createGain() { return nodeStub(); }
  createOscillator() { return nodeStub(); }
  createBiquadFilter() { return nodeStub(); }
  createDelay() { return nodeStub(); }
  createDynamicsCompressor() { return nodeStub(); }
  createBufferSource() { return nodeStub(); }
  createBuffer() { return { getChannelData: () => new Float32Array(16) }; }
  resume() {}
}
const window = {
  innerWidth: 390, innerHeight: 844,
  addEventListener() {}, AudioContext: AudioContextStub, webkitAudioContext: AudioContextStub,
  requestAnimationFrame: (f) => setTimeout(() => f(Date.now()), 0),
};
const navigator = { clipboard: { writeText() {} } };
const performance = { now: () => Date.now() };
const requestAnimationFrame = window.requestAnimationFrame;
const getComputedStyle = () => ({ getPropertyValue: () => "" });

module.exports = { document, window, localStorage, navigator, performance,
                   requestAnimationFrame, getComputedStyle, app, AudioContext: AudioContextStub };
