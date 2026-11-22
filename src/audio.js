// Cozy soundscape, all synthesized with WebAudio: no sample files.
//  ambience — wind, water lapping near shore, birdsong by day, crickets by night, fire crackle
//  music    — a lone Appalachian clawhammer banjo (bum-ba-ditty, the fifth-string drone ringing) in the old mountain-minor way: four short original tunes in minor and modal
//             keys (a hollow morning, a dorian waltz, a phrygian dusk, a graveside lullaby), a fiddle droning under the slow ones
//  sfx      — chop, mine, pick, tree fall, paper footsteps, jump/land, build, break, craft, eat
export class Sound {
  constructor() {
    this.ctx = null;
    this.muted = false;
    this.birdT = 2; this.cricketT = 1; this.noteT = 3; this.crackleT = 0;
    this.chord = 0;
  }

  /** Must be called from a user gesture (click/key). */
  start() {
    if (this.ctx) { if (this.ctx.state !== 'running') this.ctx.resume().catch(() => {}); return; }
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    const ctx = (this.ctx = new AC());
    // soft tanh limiter instead of a compressor (a compressor flattens paper onsets)
    const lim = ctx.createWaveShaper();
    const curve = new Float32Array(1024);
    for (let i = 0; i < curve.length; i++) {
      const x = (i / (curve.length - 1)) * 2 - 1, a = Math.abs(x);
      curve[i] = a < 0.6 ? x : Math.sign(x) * (0.6 + 0.4 * Math.tanh((a - 0.6) / 0.4));
    }
    lim.curve = curve;
    lim.connect(ctx.destination);
    this.master = gain(ctx, this.muted ? 0 : 0.85, lim);
    this.sfx = gain(ctx, 0.75, this.master);
    this.amb = gain(ctx, 0.55, this.master);
    this.music = gain(ctx, 0.32, this.master);

    // a little room so plucks and chimes bloom
    this.verb = ctx.createConvolver();
    this.verb.buffer = impulse(ctx, 2.2);
    const wet = gain(ctx, 0.28, this.master);
    this.verb.connect(wet);
    this.music.connect(this.verb);
    this.sfxVerbSend = gain(ctx, 0.15, this.verb);
    this.sfx.connect(this.sfxVerbSend);

    this.noiseBuf = noiseBuffer(ctx, 2);

    // wind: band-passed noise with a slowly wandering level and centre
    this.wind = { src: loopNoise(ctx, this.noiseBuf), f: ctx.createBiquadFilter(), g: gain(ctx, 0, this.amb) };
    this.wind.f.type = 'bandpass'; this.wind.f.frequency.value = 420; this.wind.f.Q.value = 0.6;
    this.wind.src.connect(this.wind.f).connect(this.wind.g);
    // water: low-passed noise that swells
    this.water = { src: loopNoise(ctx, this.noiseBuf), f: ctx.createBiquadFilter(), g: gain(ctx, 0, this.amb) };
    this.water.f.type = 'lowpass'; this.water.f.frequency.value = 650;
    this.water.src.connect(this.water.f).connect(this.water.g);
    // rain: a soft high hiss
    this.rainN = { src: loopNoise(ctx, this.noiseBuf), f: ctx.createBiquadFilter(), g: gain(ctx, 0, this.amb) };
    this.rainN.f.type = 'bandpass'; this.rainN.f.frequency.value = 3200; this.rainN.f.Q.value = 0.4;
    this.rainN.src.connect(this.rainN.f).connect(this.rainN.g);
    this.t0 = ctx.currentTime;
  }

  toggleMute() {
    this.muted = !this.muted;
    if (this.master) this.master.gain.setTargetAtTime(this.muted ? 0 : 0.85, this.ctx.currentTime, 0.05);
    return this.muted;
  }

  get ready() { return !!this.ctx && this.ctx.state === 'running'; }

  // ------------------------------------------------------------------ ambience & music

  update(dt, { night, nearFire, water, indoorsWind = 1, rain = 0, sheltered = false, time = 0.5, land = 'home' }) {
    if (!this.ready) return;
    const ctx = this.ctx, now = ctx.currentTime, t = now - this.t0;
    const gust = 0.5 + 0.3 * Math.sin(t * 0.21) + 0.2 * Math.sin(t * 0.57 + 1.3);
    // each land has its own wind: a dry high hiss over the red rock, a long roll across the prairie grass, a low
    // soughing in the high pines, hardly a breath in the fen
    const LW = LAND_WIND[land] || LAND_WIND.home;
    this.wind.g.gain.setTargetAtTime(0.045 * LW[0] * gust * indoorsWind, now, 1.5); // quiet: wind should barely register
    this.wind.f.frequency.setTargetAtTime(LW[1] + gust * 260, now, 1.5);
    // under a roof the hiss turns to a soft, muffled patter on the shingles
    this.rainN.g.gain.setTargetAtTime((sheltered ? 0.09 : 0.13) * rain, now, 0.6);
    this.rainN.f.frequency.setTargetAtTime(sheltered ? 900 : 3200, now, 0.4);
    const swell = 0.6 + 0.4 * Math.sin(t * 0.9);
    this.water.g.gain.setTargetAtTime(0.22 * water * swell, now, 0.3);

    // the land's own voices, now and then (never a constant bed)
    if ((this.landT = (this.landT ?? 6) - dt) <= 0) {
      this.landT = 5 + Math.random() * 9;
      if (land !== 'home' && rain < 0.5) this.landSound(land, night);
    }
    if ((this.birdT -= dt) <= 0) {
      this.birdT = (land === 'home' || land === 'hollows' ? 2 : 7) + Math.random() * 6; // fewer songbirds out in the wilds
      if (night < 0.4 && rain < 0.4) this.bird();
    }
    if ((this.cricketT -= dt) <= 0) {
      this.cricketT = 4 + Math.random() * 7; // now and then, not a constant shrill
      if (night > 0.6 && rain < 0.3) this.cricket();
    }
    if (nearFire > 0 && (this.crackleT -= dt) <= 0) {
      this.crackleT = 0.04 + Math.random() * 0.25;
      this.burst({ freq: 1500 + Math.random() * 2500, q: 2, dur: 0.02 + Math.random() * 0.04, vol: 0.12 * nearFire, bus: this.amb });
    }
    if ((this.noteT -= dt) <= 0) this.musicBox(night, time);
  }

  /**
   * The banjo: one of four short original tunes, picked by the time of day, frailed over a low bass and a dry strum
   * (and a fiddle drone under the slow ones), then a quiet spell before the next.
   */
  musicBox(night, time = 0.5) {
    const tune = time > 0.2 && time < 0.42 ? TUNES.sunup : time < 0.7 ? TUNES.hayfield : time < 0.82 ? TUNES.porch : TUNES.lullaby;
    const ctx = this.ctx, t0 = ctx.currentTime + 0.15, beat = 60 / tune.tempo, bpb = tune.beats;
    const note = (deg, oct = 0) => { const o = Math.floor(deg / 7), i = ((deg % 7) + 7) % 7; return mtof(tune.root + tune.scale[i] + 12 * (o + oct)); };
    // the melody
    let at = 0;
    for (const [deg, beats] of tune.melody) {
      if (deg !== null) {
        const f = note(deg, 1), w = t0 + at * beat;
        if (tune.lead === 'banjo') {
          this.banjo(f, w, 0.15);
          // frailing: on a long note, the thumb catches the high drone string on the off-beat (bum-ditty)
          // frailing, the Appalachian clawhammer: bum (the melody), then the back of the nail brushing the strings, then the
          // thumb on the high fifth-string drone (bum-ba-ditty); on a long note the ditty comes round again
          if (tune.frail) for (let b = 0; b < beats; b += 1) {
            if (b > 0) this.banjo(f, w + b * beat, 0.07);
            this.brush(note(0, 1), w + (b + 0.5) * beat, 0.045);
            this.banjo(note(4, 1), w + (b + 0.75) * beat, 0.05);
          }
          // a fiddle sighing along an octave down on the long notes, sliding up into each from below
          if (tune.lament && beats >= 2) this.lament(note(deg), w + 0.04, beats * beat * 0.98, 0.016);
        }
        else if (tune.lead === 'harmonica') this.harmonica(f, w, beats * beat * 0.95, 0.05);
        else this.pluck(f, w, 0.15, 1.8 + beats * beat);
      }
      at += beats;
    }
    // the bass on the downbeat (and the third beat in common time), the chord brushed dry on the off-beats
    tune.chords.forEach((c, bar) => {
      const w = t0 + bar * bpb * beat;
      this.pluck(note(c, -1), w, 0.09, 2.4);
      if (bpb === 4) this.pluck(note(c + 4, -1), w + 2 * beat, 0.065, 2.0);
      for (const k of bpb === 4 ? [1, 3] : [1, 2]) [0, 2, 4].forEach((d, i) => this.pluck(note(c + d), w + k * beat + i * 0.03, 0.03, 0.7));
    });
    // a fiddle drone on the root and fifth, swelling in under the whole of a slow tune
    if (tune.drone) { const len = tune.chords.length * bpb * beat; this.drone(note(0, -1), t0, len, 0.014); this.drone(note(4, -1), t0 + beat, len - beat, 0.009); }
    this.noteT = (tune.chords.length * bpb) * beat + 12 + Math.random() * 14; // a quiet spell before the next tune
  }

  /** A banjo note: a bright, quick twang that dies away fast. */
  banjo(freq, when, vol = 0.12) {
    const ctx = this.ctx;
    const g = gain(ctx, 0, this.music);
    g.gain.setValueAtTime(0, when); g.gain.linearRampToValueAtTime(vol, when + 0.004); g.gain.exponentialRampToValueAtTime(0.0001, when + 1.1);
    const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.setValueAtTime(4200, when); f.frequency.exponentialRampToValueAtTime(800, when + 0.35); f.Q.value = 2.2; f.connect(g); // (the skin head's bright, nasal plunk)
    for (const [mult, type, v] of [[1, 'sawtooth', 0.5], [2, 'triangle', 0.35], [3, 'sine', 0.15]]) {
      const o = ctx.createOscillator(); o.type = type; o.frequency.value = freq * mult;
      const og = gain(ctx, v, f); o.connect(og); o.start(when); o.stop(when + 1.2);
    }
  }

  /** A brush: the back of the fingernail across three strings, a quick dry strum (the "ba" of bum-ba-ditty). */
  brush(freq, when, vol = 0.045) {
    for (const [k, m] of [[0, 1], [1, 1.335], [2, 1.5]]) this.banjo(freq * m, when + k * 0.012, vol * (1 - k * 0.2));
  }

  /** A lament: a bowed fiddle note that slides up a half step into pitch, swells, sighs with a slow vibrato and fades. */
  lament(freq, when, dur, vol = 0.025) {
    const ctx = this.ctx;
    const g = gain(ctx, 0, this.music);
    g.gain.setValueAtTime(0, when); g.gain.linearRampToValueAtTime(vol, when + Math.min(0.5, dur * 0.35)); g.gain.linearRampToValueAtTime(vol * 0.6, when + dur * 0.8); g.gain.linearRampToValueAtTime(0, when + dur);
    const f = ctx.createBiquadFilter(); f.type = 'bandpass'; f.frequency.value = Math.min(2400, freq * 3); f.Q.value = 0.9; f.connect(g);
    const o = ctx.createOscillator(); o.type = 'sawtooth';
    o.frequency.setValueAtTime(freq * 0.944, when); o.frequency.exponentialRampToValueAtTime(freq, when + 0.22); // (the slide in from below)
    const lfo = ctx.createOscillator(); lfo.frequency.value = 5.2; const lg = gain(ctx, 0, null); lg.gain.setValueAtTime(0, when); lg.gain.linearRampToValueAtTime(freq * 0.009, when + dur * 0.5); lfo.connect(lg); lg.connect(o.frequency);
    o.connect(f); o.start(when); lfo.start(when); o.stop(when + dur + 0.05); lfo.stop(when + dur + 0.05);
  }

  /** A fiddle drone: a low bowed note that swells in and fades away, rosin-rough, with a slow uneasy vibrato. */
  drone(freq, when, dur, vol = 0.02) {
    const ctx = this.ctx;
    const g = gain(ctx, 0, this.music);
    g.gain.setValueAtTime(0, when); g.gain.linearRampToValueAtTime(vol, when + Math.min(3, dur * 0.25)); g.gain.setValueAtTime(vol, when + dur * 0.75); g.gain.linearRampToValueAtTime(0, when + dur);
    const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 900; f.Q.value = 0.8; f.connect(g);
    const o = ctx.createOscillator(); o.type = 'sawtooth'; o.frequency.value = freq;
    const lfo = ctx.createOscillator(); lfo.frequency.value = 4.6; const lg = gain(ctx, freq * 0.006, null); lfo.connect(lg); lg.connect(o.frequency);
    o.connect(f); o.start(when); lfo.start(when); o.stop(when + dur + 0.05); lfo.stop(when + dur + 0.05);
  }

  /** A harmonica note: reedy, breathed in softly, with a little wobble. */
  harmonica(freq, when, dur, vol = 0.05) {
    const ctx = this.ctx;
    const g = gain(ctx, 0, this.music);
    g.gain.setValueAtTime(0, when); g.gain.linearRampToValueAtTime(vol, when + 0.08); g.gain.setValueAtTime(vol, when + Math.max(0.1, dur - 0.12)); g.gain.linearRampToValueAtTime(0, when + dur);
    const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 1500; f.Q.value = 1.2; f.connect(g);
    const o = ctx.createOscillator(); o.type = 'square'; o.frequency.value = freq;
    const lfo = ctx.createOscillator(); lfo.frequency.value = 5; const lg = gain(ctx, freq * 0.008, null); lfo.connect(lg); lg.connect(o.frequency);
    const og = gain(ctx, 0.6, f); o.connect(og);
    o.start(when); lfo.start(when); o.stop(when + dur + 0.05); lfo.stop(when + dur + 0.05);
  }

  pluck(freq, when, vol = 0.15, decay = 2.2) {
    const ctx = this.ctx;
    const g = gain(ctx, 0, this.music);
    g.gain.setValueAtTime(0, when);
    g.gain.linearRampToValueAtTime(vol, when + 0.008);
    g.gain.exponentialRampToValueAtTime(0.0001, when + decay);
    for (const [mult, type, v] of [[1, 'triangle', 1], [2, 'sine', 0.35], [3.01, 'sine', 0.12]]) {
      const o = ctx.createOscillator();
      o.type = type; o.frequency.value = freq * mult;
      const og = gain(ctx, v, g);
      o.connect(og);
      o.start(when); o.stop(when + decay + 0.1);
    }
  }

  bird() {
    const ctx = this.ctx, now = ctx.currentTime;
    const notes = 2 + Math.floor(Math.random() * 4), base = 2400 + Math.random() * 1600;
    const pan = ctx.createStereoPanner(); pan.pan.value = Math.random() * 1.6 - 0.8; pan.connect(this.amb);
    for (let i = 0; i < notes; i++) {
      const w = now + i * (0.09 + Math.random() * 0.06);
      const o = ctx.createOscillator(); o.type = 'sine';
      const f = base * (0.9 + Math.random() * 0.3);
      o.frequency.setValueAtTime(f, w);
      o.frequency.exponentialRampToValueAtTime(f * (1.2 + Math.random() * 0.4), w + 0.07);
      const g = env(ctx, w, 0.005, 0.08, 0.05, pan);
      o.connect(g); o.start(w); o.stop(w + 0.12);
    }
  }

  /** One of a wild land's sounds: frogs and drips in the fen, a hawk over the breaks, a meadowlark... */
  landSound(land, night) {
    const day = night < 0.4, r = Math.random();
    if (land === 'fen') { if (r < 0.6) this.frog(night > 0.5); else this.plink(); }
    else if (land === 'breaks') { if (day && r < 0.45) this.hawk(); else this.pebbles(); }
    else if (land === 'prairie') { if (day && r < 0.5) this.meadowlark(); else if (day) this.grasshopper(); else this.cricket(); }
    else if (land === 'pines') { if (!day && r < 0.5) this.hoot(); else if (r < 0.55) this.woodpecker(); else this.raven(); }
    else if (land === 'hollows') { if (day && r < 0.55) this.thrush(); else this.twig(); }
  }
  /** A small bus for a far-off creature: panned to one side and softened with distance. */
  far(cut = 2500, pan = Math.random() * 1.6 - 0.8) {
    const ctx = this.ctx, p = ctx.createStereoPanner(); p.pan.value = pan; p.connect(this.amb);
    const lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = cut; lp.connect(p);
    return lp;
  }
  frog(bull) { // a green frog's "gunk", or at night a bullfrog's deep "jug-o-rum"
    const ctx = this.ctx, now = ctx.currentTime, bus = this.far(bull ? 500 : 900), n = bull ? 3 : 2;
    for (let k = 0; k < n; k++) {
      const w = now + k * (bull ? 0.32 : 0.15), f = (bull ? 70 : 120) + Math.random() * 25;
      const o = ctx.createOscillator(); o.type = 'sawtooth'; o.frequency.setValueAtTime(f * 1.15, w); o.frequency.exponentialRampToValueAtTime(f, w + 0.1);
      const g = env(ctx, w, 0.012, bull ? 0.22 : 0.09, 0.06, bus); o.connect(g); o.start(w); o.stop(w + 0.3);
    }
  }
  plink() { this.tone({ freq: 1500 + Math.random() * 500, to: 800, dur: 0.12, vol: 0.025, bus: this.far(4000) }); } // a drip into black water
  hawk() { // a red-tail's scream, high and hoarse, falling away
    const bus = this.far(5000);
    this.tone({ freq: 3000, to: 1700, type: 'triangle', dur: 1.0, vol: 0.018, attack: 0.08, bus });
    this.burst({ freq: 2600, q: 3, dur: 0.9, vol: 0.02, attack: 0.08, sweepTo: 1500, bus });
  }
  pebbles() { const bus = this.far(6000); for (let i = 0; i < 6; i++) this.burst({ freq: 3000 + Math.random() * 3000, q: 5, dur: 0.02, vol: 0.03, when: i * 0.07 + Math.random() * 0.06, bus }); } // a trickle of grit down a rock face
  meadowlark() { // a flute-clear tumbling phrase
    const bus = this.far(6000);
    [2700, 2300, 3000, 2500, 2100, 1800].forEach((f, i) => this.tone({ freq: f, to: f * 0.92, dur: 0.12, vol: 0.026, attack: 0.01, when: i * 0.13, bus }));
  }
  grasshopper() { const bus = this.far(7000); for (let i = 0; i < 3; i++) this.burst({ freq: 5200, q: 6, dur: 0.35, vol: 0.012, attack: 0.05, when: i * 0.5, bus }); }
  woodpecker() { const bus = this.far(1800); for (let i = 0; i < 14; i++) this.burst({ freq: 1100, q: 4, dur: 0.018, vol: 0.06 * (1 - i / 20), when: i * 0.045, bus }); } // a drumroll on a far snag
  raven() { const bus = this.far(1600); for (let i = 0; i < 2; i++) this.tone({ freq: 430, to: 340, type: 'sawtooth', dur: 0.24, vol: 0.016, attack: 0.02, when: i * 0.42, bus }); }
  thrush() { // a wood thrush: "ee-o-lay", and a silvery trill
    const bus = this.far(6000);
    [1300, 1700, 2500].forEach((f, i) => this.tone({ freq: f, to: f * 1.04, dur: 0.18, vol: 0.026, attack: 0.02, when: i * 0.2, bus }));
    for (let i = 0; i < 6; i++) this.tone({ freq: 3400 + (i % 2) * 300, dur: 0.04, vol: 0.012, when: 0.65 + i * 0.045, bus });
  }
  twig() { // a twig snapping somewhere close behind you... and then nothing
    const bus = this.far(3500, Math.random() < 0.5 ? -0.9 : 0.9);
    this.burst({ freq: 1800, q: 6, dur: 0.03, vol: 0.07, bus });
    this.burst({ freq: 1300, q: 5, dur: 0.04, vol: 0.05, when: 0.09, bus });
  }

  cricket() {
    // one far-off cricket: a soft trill of tiny pulses, low and muffled, well under the music
    const ctx = this.ctx, now = ctx.currentTime;
    const pan = ctx.createStereoPanner(); pan.pan.value = Math.random() * 1.4 - 0.7;
    const lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 3000; lp.Q.value = 0.3;
    lp.connect(pan); pan.connect(this.amb);
    const f = 2500 + Math.random() * 300, trills = 1 + Math.floor(Math.random() * 2);
    for (let k = 0; k < trills; k++) for (let i = 0; i < 4; i++) {
      const w = now + k * 0.45 + i * 0.035;
      const o = ctx.createOscillator(); o.type = 'sine'; o.frequency.value = f;
      const g = env(ctx, w, 0.006, 0.022, 0.006, lp);
      o.connect(g); o.start(w); o.stop(w + 0.04);
    }
  }

  // ------------------------------------------------------------------ one-shot building blocks

  /** Filtered noise burst. */
  burst({ freq = 2000, q = 1, type = 'bandpass', dur = 0.08, vol = 0.2, attack = 0.002, when = 0, sweepTo = 0, bus = null }) {
    if (!this.ready) return;
    const ctx = this.ctx, w = ctx.currentTime + when;
    const src = ctx.createBufferSource(); src.buffer = this.noiseBuf;
    src.playbackRate.value = 0.8 + Math.random() * 0.4;
    const f = ctx.createBiquadFilter(); f.type = type; f.frequency.setValueAtTime(freq, w); f.Q.value = q;
    if (sweepTo) f.frequency.exponentialRampToValueAtTime(sweepTo, w + dur);
    const g = env(ctx, w, attack, dur, vol, bus || this.sfx);
    src.connect(f).connect(g);
    src.start(w, Math.random() * 1.5); src.stop(w + dur + 0.05);
  }

  /** Pitched tone with a pitch drop. */
  tone({ freq = 200, to = 0, type = 'sine', dur = 0.15, vol = 0.3, attack = 0.003, when = 0, bus = null }) {
    if (!this.ready) return;
    const ctx = this.ctx, w = ctx.currentTime + when;
    const o = ctx.createOscillator(); o.type = type;
    o.frequency.setValueAtTime(freq, w);
    if (to) o.frequency.exponentialRampToValueAtTime(to, w + dur);
    const g = env(ctx, w, attack, dur, vol, bus || this.sfx);
    o.connect(g); o.start(w); o.stop(w + dur + 0.05);
  }

  // ------------------------------------------------------------------ game sounds

  chop() {
    this.tone({ freq: 190, to: 75, dur: 0.16, vol: 0.45 });
    this.tone({ freq: 430, to: 300, type: 'triangle', dur: 0.07, vol: 0.18 });
    this.burst({ freq: 1400, q: 1.2, dur: 0.06, vol: 0.3 });
  }

  /** A stamp mill's stamp falling on the quartz: a dull wooden thud with a crunch under it. */
  stamp(v = 1) {
    this.tone({ freq: 95, to: 48, dur: 0.18, vol: 0.35 * v });
    this.burst({ freq: 700, q: 0.9, dur: 0.07, vol: 0.12 * v });
  }

  mine() {
    const f = 1100 + Math.random() * 300;
    this.tone({ freq: f, type: 'square', dur: 0.22, vol: 0.07 });
    this.tone({ freq: f * 1.47, type: 'triangle', dur: 0.3, vol: 0.08 });
    this.tone({ freq: 140, to: 70, dur: 0.1, vol: 0.3 });
    this.burst({ freq: 4000, q: 0.8, type: 'highpass', dur: 0.05, vol: 0.25 });
  }

  pick() {
    this.burst({ freq: 3200, q: 0.9, dur: 0.14, vol: 0.18 });
    this.tone({ freq: 880, to: 1320, dur: 0.09, vol: 0.12, when: 0.05 });
  }

  treeFall() {
    // the fibres giving way: a quickening crackle of dry splits (no low tones: a low buzzy creak read as rude),
    // a whoosh of leaves through the air, then a soft, papery thud on the ground and a last rustle
    if (!this.ready) return;
    let at = 0;
    for (let i = 0; i < 9; i++) { at += 0.11 - i * 0.008; this.burst({ freq: 1300 + Math.random() * 900, q: 7, dur: 0.025, vol: 0.05 + i * 0.006, when: at }); }
    this.burst({ freq: 2600, q: 0.6, dur: 0.6, vol: 0.09, attack: 0.25, sweepTo: 700, when: 0.55 });        // the crown sweeping down
    this.burst({ freq: 260, type: 'lowpass', dur: 0.22, vol: 0.32, attack: 0.004, when: 1.08 });           // the thud: toneless, soft
    this.burst({ freq: 900, q: 0.8, dur: 0.12, vol: 0.12, when: 1.09 });                                   // paper slapping flat
    this.burst({ freq: 3600, q: 0.7, dur: 0.45, vol: 0.08, attack: 0.03, when: 1.12 });                   // leaves settling
  }

  step(surface = 'grass') {
    if (surface === 'water') { // a soft slosh
      this.burst({ freq: 700 + Math.random() * 300, q: 0.7, dur: 0.18, vol: 0.05, sweepTo: 350, attack: 0.02 });
      this.burst({ freq: 2400, q: 1.5, dur: 0.06, vol: 0.015, when: 0.05 });
      return;
    }
    if (surface === 'snow') { // a soft, packed crunch: low and muffled, a few granular crackles squeezed together
      this.burst({ freq: 520 + Math.random() * 120, q: 0.6, dur: 0.12, vol: 0.04, attack: 0.015, sweepTo: 300 });
      for (let i = 0; i < 3; i++) this.burst({ freq: 2600 + Math.random() * 1800, q: 2.5, dur: 0.02, vol: 0.012, when: 0.02 + i * 0.025 });
      return;
    }
    if (surface === 'wood') {
      // hollow knock on boards
      this.tone({ freq: 540 + Math.random() * 40, to: 420, type: 'triangle', dur: 0.05, vol: 0.05 });
      this.burst({ freq: 800, q: 1.2, type: 'bandpass', dur: 0.05, vol: 0.05 });
    } else {
      // paper crinkle
      // soft paper scuff: low-ish band, ~16 dB under the action sounds
      this.burst({ freq: 1100 * (0.9 + Math.random() * 0.25), q: 1.1, dur: 0.06, vol: 0.032 });
      this.burst({ freq: 1700, q: 1.6, dur: 0.03, vol: 0.018, when: 0.012 });
    }
  }

  jump() { this.burst({ freq: 800, q: 0.7, dur: 0.18, vol: 0.08, sweepTo: 2400, attack: 0.03 }); }
  land() { this.tone({ freq: 110, to: 60, dur: 0.12, vol: 0.25 }); this.burst({ freq: 1800, dur: 0.06, vol: 0.1 }); }
  splash() { this.burst({ freq: 1200, q: 0.5, dur: 0.35, vol: 0.18, sweepTo: 400 }); }

  place() {
    this.burst({ freq: 1200, q: 0.8, dur: 0.12, vol: 0.14, sweepTo: 4200, attack: 0.02 }); // paper fold "fwip"
    this.tone({ freq: 260, to: 180, type: 'triangle', dur: 0.08, vol: 0.25, when: 0.1 });
    this.tone({ freq: 520, to: 400, type: 'sine', dur: 0.05, vol: 0.08, when: 0.1 });
  }

  tear() { this.burst({ freq: 1500, q: 2.5, dur: 0.28, vol: 0.22, sweepTo: 6000, attack: 0.01 }); this.burst({ freq: 700, dur: 0.15, vol: 0.12 }); }

  /** the locomotive's steam whistle: a two-note chord, swelling and dying away, long-short (vol 0..1 by distance) */
  whistle(vol = 1) {
    if (!this.ready || this.muted) return;
    const bus = this.far(2400, 0), v = 0.035 * vol;
    for (const [when, dur] of [[0, 0.9], [1.05, 0.45]]) for (const f of [440, 554, 659]) this.tone({ freq: f, to: f * 0.985, type: 'triangle', dur, vol: v, attack: 0.08, when, bus });
  }
  /** a chuff of steam from the stack: a soft breathy burst (vol 0..1 by distance) */
  chuff(vol = 1) { if (!this.ready || this.muted) return; this.burst({ freq: 700 + Math.random() * 200, q: 0.5, dur: 0.16, vol: 0.05 * vol, attack: 0.01, sweepTo: 350, bus: this.far(2600, 0) }); }
  /** a mallard's quack: two or three nasal, falling honks (vol 0..1 by distance) */
  quack(vol = 1) {
    if (!this.ready || this.muted) return;
    const bus = this.far(2000, (Math.random() - 0.5)), v = 0.035 * vol, n = 2 + Math.floor(Math.random() * 2);
    for (let i = 0; i < n; i++) this.tone({ freq: 420 - i * 15, to: 300, type: 'sawtooth', dur: 0.13, vol: v, attack: 0.01, when: i * 0.19, bus });
  }
  /** a wild turkey's gobble: a quick bubbling run of throaty warbles, falling away (vol 0..1 by distance) */
  gobble(vol = 1) {
    if (!this.ready || this.muted) return;
    const bus = this.far(1600, (Math.random() - 0.5) * 1.2), v = 0.04 * vol, base = 480 + Math.random() * 60;
    for (let i = 0; i < 8; i++) this.tone({ freq: base * (1 - i * 0.035) * (i % 2 ? 1.12 : 1), to: base * (1 - i * 0.035) * 0.86, type: 'square', dur: 0.06, vol: v * (1 - i * 0.07), attack: 0.005, when: i * 0.055, bus });
  }
  /** the stage guard's coach horn: two long brassy calls, the second higher (vol 0..1 by distance) */
  horn(vol = 1) {
    if (!this.ready || this.muted) return;
    const bus = this.far(1800, -0.2), v = 0.045 * vol;
    [[349, 0, 0.55], [466, 0.65, 0.8]].forEach(([f, when, dur]) => { this.tone({ freq: f, type: 'square', dur, vol: v, attack: 0.05, when, bus }); this.tone({ freq: f * 2, type: 'sawtooth', dur, vol: v * 0.3, attack: 0.06, when, bus }); });
  }
  /** the rooster's crow at sunup: cock-a-doodle-doo, four reedy calls, the last long and falling (vol 0..1 by distance) */
  crow(vol = 1) {
    if (!this.ready || this.muted) return;
    const bus = this.far(2600, 0.2), v = 0.05 * vol;
    [[620, 760, 0, 0.16], [700, 720, 0.2, 0.12], [760, 680, 0.36, 0.14], [900, 640, 0.56, 0.7]].forEach(([f, to, when, dur]) => this.tone({ freq: f, to, type: 'sawtooth', dur, vol: v, attack: 0.02, when, bus }));
  }
  /** a coyote's howl from the rise: a rising, wavering cry that falls away into a couple of yips; `answer` is another,
   *  further off and lower, replying */
  howl(vol = 1, answer = false) {
    if (!this.ready || this.muted) return;
    const ctx = this.ctx, w = ctx.currentTime, bus = this.far(answer ? 1400 : 2400, answer ? -0.6 : 0.3), v = (answer ? 0.025 : 0.05) * vol, base = answer ? 380 : 470;
    const o = ctx.createOscillator(); o.type = 'triangle';
    o.frequency.setValueAtTime(base, w); o.frequency.exponentialRampToValueAtTime(base * 1.75, w + 0.7); o.frequency.setValueAtTime(base * 1.75, w + 1.5); o.frequency.exponentialRampToValueAtTime(base * 1.15, w + 2.4);
    const lfo = ctx.createOscillator(); lfo.frequency.value = 6; const lg = ctx.createGain(); lg.gain.value = base * 0.02; lfo.connect(lg); lg.connect(o.frequency);
    const g = ctx.createGain(); g.gain.setValueAtTime(0, w); g.gain.linearRampToValueAtTime(v, w + 0.35); g.gain.setValueAtTime(v, w + 1.7); g.gain.linearRampToValueAtTime(0, w + 2.5);
    o.connect(g); g.connect(bus); o.start(w); lfo.start(w); o.stop(w + 2.6); lfo.stop(w + 2.6);
    if (!answer) for (const k of [2.7, 2.95]) this.tone({ freq: base * 1.6, to: base * 1.1, type: 'triangle', dur: 0.14, vol: v * 0.8, when: k, bus }); // (yip, yip)
  }
  /** a firework bursting far off: a soft papery pop and a low thump, then a fizzle (vol 0..1 by distance) */
  pop(vol = 1) { const bus = this.far(2200); this.burst({ freq: 900, q: 0.6, dur: 0.18, vol: 0.12 * vol, bus }); this.tone({ freq: 70, to: 45, dur: 0.3, vol: 0.18 * vol, bus }); this.burst({ freq: 5000, q: 1.5, dur: 0.6, vol: 0.02 * vol, attack: 0.15, when: 0.08, bus }); }
  bang(big = false) { this.burst({ freq: 2600, q: 0.7, dur: 0.05, vol: 0.22 }); this.burst({ freq: 700, q: 0.5, dur: big ? 0.55 : 0.35, vol: 0.2, sweepTo: 160 }); this.tone({ freq: big ? 80 : 100, to: 38, dur: big ? 0.45 : 0.3, vol: 0.26 }); }
  knock() { this.tone({ freq: 240, to: 160, type: 'triangle', dur: 0.09, vol: 0.3 }); this.burst({ freq: 1700, dur: 0.05, vol: 0.15 }); }

  craft() {
    if (!this.ready) return;
    const now = this.ctx.currentTime;
    [72, 76, 79, 84].forEach((m, i) => this.pluck(mtof(m), now + i * 0.09, 0.18, 1.6));
  }

  eat() { for (let i = 0; i < 3; i++) this.burst({ freq: 1800 + Math.random() * 1500, q: 1.5, dur: 0.05, vol: 0.18, when: i * 0.11 }); }

  denied() { this.tone({ freq: 220, to: 180, type: 'triangle', dur: 0.12, vol: 0.15 }); this.tone({ freq: 185, to: 150, type: 'triangle', dur: 0.14, vol: 0.12, when: 0.1 }); }

  /** the hound's bark: a gruff double woof */
  woof() { for (const w of [0, 0.22]) { this.tone({ freq: 180, to: 110, type: 'sawtooth', dur: 0.12, vol: 0.06, when: w }); this.burst({ freq: 600, q: 1.2, dur: 0.1, vol: 0.1, when: w }); } }

  /** a barn owl's soft two-note hoot, from somewhere off in the dark */
  hoot() {
    if (!this.ctx) return;
    const now = this.ctx.currentTime;
    for (const [w, f, d] of [[0, 392, 0.35], [0.5, 370, 0.6]]) this.tone({ freq: f, to: f * 0.92, type: 'sine', dur: d, vol: 0.07, attack: 0.06, when: w });
  }

  /** a three-note lullaby as you tuck in, then a soft morning chime */
  lullaby() {
    if (!this.ctx) return;
    const now = this.ctx.currentTime;
    [523, 440, 392, 330].forEach((f, i) => this.pluck(f, now + i * 0.32, 0.1, 2.6));
    [392, 494, 587].forEach((f, i) => this.pluck(f, now + 1.9 + i * 0.16, 0.08, 1.8));
  }
  /** the bobber ducks: a small wet plip */
  bite() { this.tone({ freq: 900, to: 380, dur: 0.09, vol: 0.18 }); this.burst({ freq: 2400, q: 2, dur: 0.05, vol: 0.08, when: 0.04 }); }
  /** one bowed fiddle note for the barn dance: a soft, filtered saw with a little vibrato, on the music bus */
  /** A hymn note from the meeting: a wheezy pump organ under a soft hum of voices (a sine, its octave, a low triangle
   *  a fifth beneath the bass, all through a warm low-pass), swelling in slowly and dying away. */
  hymn(freq, dur = 0.8, vol = 1, bass = 0) {
    if (!this.ready || this.muted || vol <= 0.01) return;
    const ctx = this.ctx, w = ctx.currentTime;
    const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 1100; f.Q.value = 0.5;
    const g = ctx.createGain(); g.gain.setValueAtTime(0, w); g.gain.linearRampToValueAtTime(0.045 * vol, w + 0.12); g.gain.setValueAtTime(0.045 * vol, w + dur * 0.75); g.gain.linearRampToValueAtTime(0, w + dur + 0.15);
    f.connect(g); g.connect(this.music);
    for (const [fr, type, lv] of [[freq, 'sine', 1], [freq * 2, 'sine', 0.3], [freq * 1.5, 'triangle', 0.22], ...(bass ? [[bass, 'triangle', 0.55]] : [])]) {
      const o = ctx.createOscillator(); o.type = type; o.frequency.value = fr; o.detune.value = (Math.random() - 0.5) * 8; // (a congregation is never quite in tune)
      const og = ctx.createGain(); og.gain.value = lv; o.connect(og); og.connect(f); o.start(w); o.stop(w + dur + 0.2);
    }
  }
  fiddle(freq, dur = 0.22, vol = 1) {
    if (!this.ready || this.muted) return;
    const ctx = this.ctx, w = ctx.currentTime;
    const o = ctx.createOscillator(); o.type = 'sawtooth'; o.frequency.setValueAtTime(freq, w);
    const lfo = ctx.createOscillator(); lfo.frequency.value = 5.5; const lg = ctx.createGain(); lg.gain.value = freq * 0.006; lfo.connect(lg); lg.connect(o.frequency);
    const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 1600; f.Q.value = 0.7;
    const g = ctx.createGain(); g.gain.setValueAtTime(0, w); g.gain.linearRampToValueAtTime(0.06 * vol, w + 0.04); g.gain.setValueAtTime(0.06 * vol, w + dur * 0.7); g.gain.linearRampToValueAtTime(0, w + dur);
    o.connect(f); f.connect(g); g.connect(this.music);
    o.start(w); lfo.start(w); o.stop(w + dur + 0.05); lfo.stop(w + dur + 0.05);
  }
  /** thunder: a crack, then a long low roll that grumbles away (louder when the strike is near) */
  thunder(vol = 1) { this.burst({ freq: 700, q: 0.6, dur: 0.25, vol: 0.12 * vol }); for (let k = 0; k < 9; k++) this.burst({ freq: 90 + Math.random() * 70, q: 0.9, type: 'lowpass', dur: 0.5 + Math.random() * 0.4, vol: 0.16 * vol * (1 - k / 10), when: 0.08 + k * 0.28 + Math.random() * 0.1 }); }
  /** a calf bawling for its mother: a short, rising-then-falling low moo */
  moo(vol = 1) { this.tone({ freq: 190, to: 150, type: 'sawtooth', dur: 0.55, vol: 0.035 * vol, attack: 0.06 }); this.tone({ freq: 380, to: 300, type: 'sine', dur: 0.5, vol: 0.02 * vol, attack: 0.05 }); }
  /** a crunchy rustle of dry leaves */
  rustle() { for (let k = 0; k < 6; k++) this.burst({ freq: 2600 + Math.random() * 2400, q: 0.8, dur: 0.07 + Math.random() * 0.06, vol: 0.06, when: k * 0.04 + Math.random() * 0.03 }); }
  /** a barn cat's purr: a soft low rumble that swells and settles */
  purr() { for (let k = 0; k < 14; k++) this.burst({ freq: 110 + (k % 2) * 30, q: 1.2, type: 'lowpass', dur: 0.07, vol: 0.05 * Math.sin((k / 13) * Math.PI) + 0.01, when: k * 0.085 }); }
  /** a pond frog: a low, rubbery two-pulse croak (quiet) */
  croak(vol = 1) { for (const w of [0, 0.13]) { this.tone({ freq: 150, to: 120, type: 'sawtooth', dur: 0.09, vol: 0.03 * vol, when: w }); this.burst({ freq: 420, q: 6, dur: 0.08, vol: 0.04 * vol, when: w }); } }
  /** a frog hitting the water: a small plop */
  honk() { for (const w of [0, 0.2]) { this.tone({ freq: 360, to: 310, type: 'sawtooth', dur: 0.11, vol: 0.018, when: w }); this.burst({ freq: 900, q: 4, dur: 0.1, vol: 0.03, when: w }); } } // distant geese
  plop() { this.tone({ freq: 620, to: 220, dur: 0.08, vol: 0.12 }); this.burst({ freq: 1800, q: 1.5, dur: 0.06, vol: 0.05, when: 0.02 }); }
  /** a crow's rough caw, twice */
  caw() { for (const w of [0, 0.32]) { this.burst({ freq: 1100, q: 5, dur: 0.16, vol: 0.12, when: w, sweepTo: 700 }); this.tone({ freq: 520, to: 380, type: 'sawtooth', dur: 0.15, vol: 0.035, when: w }); } }
  /** a low growl as a guardian winds up */
  growl() { this.tone({ freq: 110, to: 80, type: 'sawtooth', dur: 0.4, vol: 0.05 }); this.burst({ freq: 300, q: 1.5, dur: 0.35, vol: 0.08 }); }
  click() { this.tone({ freq: 1400, to: 900, dur: 0.03, vol: 0.08 }); }
}

// ------------------------------------------------------------------ helpers

function gain(ctx, v, dest) {
  const g = ctx.createGain();
  g.gain.value = v;
  if (dest) g.connect(dest);
  return g;
}

function env(ctx, when, attack, dur, vol, dest) {
  const g = ctx.createGain();
  g.gain.setValueAtTime(0.0001, when);
  g.gain.exponentialRampToValueAtTime(Math.max(0.0002, vol), when + attack);
  g.gain.exponentialRampToValueAtTime(0.0001, when + attack + dur);
  if (dest) g.connect(dest);
  return g;
}

function noiseBuffer(ctx, seconds) {
  const b = ctx.createBuffer(1, ctx.sampleRate * seconds, ctx.sampleRate);
  const d = b.getChannelData(0);
  for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  return b;
}

function loopNoise(ctx, buf) {
  const s = ctx.createBufferSource();
  s.buffer = buf; s.loop = true;
  s.start();
  return s;
}

function impulse(ctx, seconds) {
  const len = ctx.sampleRate * seconds, b = ctx.createBuffer(2, len, ctx.sampleRate);
  for (let c = 0; c < 2; c++) {
    const d = b.getChannelData(c);
    for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 3);
  }
  return b;
}

const mtof = (m) => 440 * Math.pow(2, (m - 69) / 12);
// each land's wind: [loudness, band centre Hz]
const LAND_WIND = { home: [1, 320], hollows: [1.1, 360], breaks: [1.9, 620], fen: [0.6, 300], prairie: [1.7, 260], pines: [1.6, 200] };
const MAJOR = [0, 2, 4, 5, 7, 9, 11], MINOR = [0, 2, 3, 5, 7, 8, 10];
const DORIAN = [0, 2, 3, 5, 7, 9, 10], PHRYGIAN = [0, 1, 3, 5, 7, 8, 10];
// American gothic: one banjo, frailed clawhammer-style (a melody note, then the thumb on the high drone string), in
// the minor and modal keys of the old mountain ballads, over a low bass and a dry strum; the slow tunes have a
// fiddle drone under them. Every tune is original.
const TUNES = {
  // morning: "Hollow Morning", a slow frailed tune in G mountain minor, cold and grey
  sunup: { root: 55, scale: MINOR, tempo: 88, beats: 4, lead: 'banjo', frail: true, drone: true, lament: true, chords: [0, 0, 5, 6, 0, 3, 6, 0],
    melody: [[4, 1], [3, .5], [2, .5], [0, 1], [0, .5], [-1, .5], [0, 1], [2, 1], [3, 2], [4, 1], [5, .5], [4, .5], [3, 1], [2, 1], [0, 2], [-1, 1], [-3, 1],
      [4, 1], [3, .5], [2, .5], [0, 1], [2, 1], [3, .5], [4, .5], [3, .5], [2, .5], [0, 2], [-1, 1], [0, .5], [-1, .5], [-3, 1], [-2, 1], [0, 4]] },
  // afternoon: "Long Field", a dorian waltz in D, plodding in the heat
  hayfield: { root: 50, scale: DORIAN, tempo: 76, beats: 3, lead: 'banjo', frail: true, drone: true, lament: true, chords: [0, 0, 3, 0, 0, 6, 3, 0],
    melody: [[0, 1], [2, 1], [3, 1], [4, 2], [5, 1], [4, 1], [3, 1], [2, 1], [0, 3], [2, 1], [3, 1], [4, 1], [6, 2], [5, 1], [4, 1], [3, 1], [1, 1], [0, 3]] },
  // dusk: "Crow's Lament", slow and bare in E phrygian, the flat second aching against the drone
  porch: { root: 52, scale: PHRYGIAN, tempo: 58, beats: 4, lead: 'banjo', frail: true, drone: true, lament: true, chords: [0, 1, 0, 0, 3, 1, 6, 0],
    melody: [[0, 2], [1, 1], [0, 1], [-1, 3], [null, 1], [0, 1], [1, 1], [3, 1], [1, 1], [0, 4], [4, 2], [3, 1], [1, 1], [3, 2], [1, 1], [0, 1], [1, 1], [0, 1], [-1, 1], [-2, 1], [0, 4]] },
  // night: "Hush, the Lantern's Low", a graveside lullaby in A minor, the banjo slow over a long fiddle drone
  lullaby: { root: 45, scale: MINOR, tempo: 54, beats: 3, lead: 'banjo', frail: true, drone: true, lament: true, chords: [0, 0, 6, 0, 0, 3, 4, 0],
    melody: [[4, 2], [3, 1], [2, 2], [0, 1], [1, 1], [2, 1], [-1, 1], [0, 3], [4, 2], [5, 1], [4, 1], [3, 1], [2, 1], [1, 2], [-1, 1], [0, 3]] },
};

