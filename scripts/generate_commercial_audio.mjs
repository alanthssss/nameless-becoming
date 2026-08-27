#!/usr/bin/env node

/**
 * Render the project's commercial-candidate sound effects and ambience loops.
 *
 * Every sample is generated from checked-in parameters and a seeded PRNG. The
 * recipes layer physical-model plucks, shaped noise, modal impacts and stereo
 * motion; none of the cues is a single sine-wave notification. No recordings,
 * sample libraries or network inputs are used.
 */

import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const defaultSourcePath = join(repositoryRoot, "scripts/commercial_audio_sources.json");
const defaultOutputDirectory = join(repositoryRoot, "godot/assets/audio/commercial");
const TAU = Math.PI * 2;

function seededRandom(seed) {
  let state = seed >>> 0;
  return () => {
    state += 0x6d2b79f5;
    let value = state;
    value = Math.imul(value ^ (value >>> 15), value | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}

function createBuffer(sampleRate, durationSeconds) {
  const frames = Math.round(sampleRate * durationSeconds);
  return { sampleRate, frames, left: new Float64Array(frames), right: new Float64Array(frames) };
}

function stereoGains(pan) {
  const position = Math.max(-1, Math.min(1, pan));
  const angle = (position + 1) * Math.PI / 4;
  return [Math.cos(angle), Math.sin(angle)];
}

function addSample(buffer, frame, sample, pan = 0) {
  if (frame < 0 || frame >= buffer.frames) return;
  const [leftGain, rightGain] = stereoGains(pan);
  buffer.left[frame] += sample * leftGain;
  buffer.right[frame] += sample * rightGain;
}

function shapedEnvelope(time, duration, attack = 0.008, release = 0.10) {
  if (time < 0 || time >= duration) return 0;
  const attackGain = Math.min(1, time / Math.max(0.0001, attack));
  const releaseGain = Math.min(1, (duration - time) / Math.max(0.0001, release));
  return Math.sin(Math.min(1, attackGain) * Math.PI / 2) * Math.sin(Math.min(1, releaseGain) * Math.PI / 2);
}

function addFilteredNoise(buffer, options) {
  const {
    start = 0,
    duration,
    amplitude,
    seed,
    panStart = 0,
    panEnd = panStart,
    color = "mid",
    attack = 0.012,
    release = 0.12,
    modulationHz = 0,
  } = options;
  const random = seededRandom(seed);
  const startFrame = Math.round(start * buffer.sampleRate);
  const frameCount = Math.round(duration * buffer.sampleRate);
  let low = 0;
  let slow = 0;
  let previous = 0;
  for (let offset = 0; offset < frameCount; offset += 1) {
    const time = offset / buffer.sampleRate;
    const white = random() * 2 - 1;
    low += 0.075 * (white - low);
    slow += 0.008 * (white - slow);
    let sample;
    if (color === "low") sample = slow * 1.8;
    else if (color === "high") sample = white - low;
    else if (color === "rustle") sample = (white - slow) * 0.72 + (low - slow) * 0.55;
    else sample = low - slow;
    const modulation = modulationHz > 0 ? 0.64 + 0.36 * Math.sin(TAU * modulationHz * time + seed * 0.017) : 1;
    const transient = color === "click" ? sample - previous : sample;
    previous = sample;
    const envelope = shapedEnvelope(time, duration, attack, release);
    const pan = panStart + (panEnd - panStart) * (offset / Math.max(1, frameCount - 1));
    addSample(buffer, startFrame + offset, transient * amplitude * envelope * modulation, pan);
  }
}

function addModalImpact(buffer, options) {
  const {
    start = 0,
    frequencies,
    weights,
    duration = 0.5,
    amplitude = 0.2,
    decay = 0.18,
    pan = 0,
    seed = 1,
    pitchDrop = 0,
  } = options;
  const random = seededRandom(seed);
  const phases = frequencies.map(() => random() * TAU);
  const startFrame = Math.round(start * buffer.sampleRate);
  const frameCount = Math.min(Math.round(duration * buffer.sampleRate), buffer.frames - startFrame);
  for (let offset = 0; offset < frameCount; offset += 1) {
    const time = offset / buffer.sampleRate;
    const attack = Math.min(1, time / 0.0025);
    const envelope = attack * Math.exp(-time / decay) * Math.min(1, (duration - time) / 0.02);
    let sample = 0;
    for (let mode = 0; mode < frequencies.length; mode += 1) {
      const frequency = frequencies[mode] * (1 - pitchDrop * Math.min(1, time / duration));
      sample += Math.sin(TAU * frequency * time + phases[mode]) * weights[mode];
    }
    addSample(buffer, startFrame + offset, sample * amplitude * envelope, pan);
  }
  addFilteredNoise(buffer, {
    start,
    duration: Math.min(0.045, duration),
    amplitude: amplitude * 0.34,
    seed: seed ^ 0x51f2,
    panStart: pan - 0.08,
    panEnd: pan + 0.08,
    color: "click",
    attack: 0.001,
    release: 0.025,
  });
}

function addPluck(buffer, options) {
  const {
    start = 0,
    frequency,
    duration = 0.7,
    amplitude = 0.18,
    damping = 0.996,
    pan = 0,
    seed = 1,
  } = options;
  const delay = Math.max(8, Math.round(buffer.sampleRate / frequency));
  const ring = new Float64Array(delay);
  const random = seededRandom(seed);
  for (let index = 0; index < delay; index += 1) ring[index] = random() * 2 - 1;
  const startFrame = Math.round(start * buffer.sampleRate);
  const frameCount = Math.min(Math.round(duration * buffer.sampleRate), buffer.frames - startFrame);
  let cursor = 0;
  let body = 0;
  for (let offset = 0; offset < frameCount; offset += 1) {
    const current = ring[cursor];
    const next = ring[(cursor + 1) % delay];
    ring[cursor] = (current * 0.48 + next * 0.52) * damping;
    cursor = (cursor + 1) % delay;
    body += 0.16 * (current - body);
    const time = offset / buffer.sampleRate;
    const envelope = Math.min(1, time / 0.002) * Math.min(1, (duration - time) / 0.04);
    addSample(buffer, startFrame + offset, (current * 0.72 + body * 0.28) * amplitude * envelope, pan);
  }
}

function addChirp(buffer, options) {
  const {
    start = 0,
    fromFrequency,
    toFrequency,
    duration,
    amplitude,
    panStart = 0,
    panEnd = panStart,
    seed = 1,
  } = options;
  const random = seededRandom(seed);
  const phaseOffset = random() * TAU;
  const startFrame = Math.round(start * buffer.sampleRate);
  const frameCount = Math.min(Math.round(duration * buffer.sampleRate), buffer.frames - startFrame);
  let phase = phaseOffset;
  for (let offset = 0; offset < frameCount; offset += 1) {
    const progress = offset / Math.max(1, frameCount - 1);
    const frequency = fromFrequency * Math.pow(toFrequency / fromFrequency, progress);
    phase += TAU * frequency / buffer.sampleRate;
    const triangle = 2 / Math.PI * Math.asin(Math.sin(phase));
    const complex = triangle * 0.68 + Math.sin(phase * 2.017 + 0.4) * 0.23 + Math.sin(phase * 3.11) * 0.09;
    const envelope = shapedEnvelope(offset / buffer.sampleRate, duration, 0.006, Math.min(0.16, duration * 0.4));
    const pan = panStart + (panEnd - panStart) * progress;
    addSample(buffer, startFrame + offset, complex * amplitude * envelope, pan);
  }
}

function addFlutter(buffer, options) {
  const { start = 0, duration, amplitude, seed, panStart = 0, panEnd = 0 } = options;
  const random = seededRandom(seed);
  const startFrame = Math.round(start * buffer.sampleRate);
  const frameCount = Math.min(Math.round(duration * buffer.sampleRate), buffer.frames - startFrame);
  let filtered = 0;
  let phase = random() * TAU;
  const wingRate = 28 + random() * 9;
  for (let offset = 0; offset < frameCount; offset += 1) {
    const time = offset / buffer.sampleRate;
    filtered += 0.18 * ((random() * 2 - 1) - filtered);
    phase += TAU * (150 + Math.sin(TAU * 2.1 * time) * 22) / buffer.sampleRate;
    const wingGate = Math.pow(Math.max(0, Math.sin(TAU * wingRate * time)), 3);
    const body = (filtered * 0.68 + Math.sin(phase) * 0.20 + Math.sin(phase * 2.37) * 0.12) * wingGate;
    const envelope = shapedEnvelope(time, duration, 0.015, 0.08);
    const pan = panStart + (panEnd - panStart) * (offset / Math.max(1, frameCount - 1));
    addSample(buffer, startFrame + offset, body * amplitude * envelope, pan);
  }
}

function renderSfx(spec, sampleRate) {
  const buffer = createBuffer(sampleRate, spec.duration_seconds);
  const seed = spec.seed;
  switch (spec.recipe) {
    case "nectar_collect":
      addFilteredNoise(buffer, { start: 0.01, duration: 0.22, amplitude: 0.34, seed, color: "low", panStart: -0.18, panEnd: 0.12, attack: 0.003, release: 0.10 });
      addModalImpact(buffer, { start: 0.055, frequencies: [620, 1015, 1690], weights: [0.62, 0.27, 0.11], duration: 0.40, amplitude: 0.24, decay: 0.13, pan: 0.08, seed: seed + 1, pitchDrop: -0.10 });
      addPluck(buffer, { start: 0.13, frequency: 910, duration: 0.34, amplitude: 0.08, damping: 0.991, pan: 0.22, seed: seed + 2 });
      break;
    case "pollination_bloom":
      addFilteredNoise(buffer, { start: 0.01, duration: 0.44, amplitude: 0.20, seed, color: "rustle", panStart: -0.42, panEnd: 0.38, attack: 0.015, release: 0.18, modulationHz: 7.2 });
      [[0.08, 660, -0.28], [0.19, 825, 0.05], [0.31, 990, 0.30]].forEach(([start, frequency, pan], index) => addPluck(buffer, { start, frequency, duration: 0.46, amplitude: 0.11, damping: 0.994, pan, seed: seed + index + 1 }));
      addModalImpact(buffer, { start: 0.30, frequencies: [410, 675, 1090], weights: [0.48, 0.34, 0.18], duration: 0.48, amplitude: 0.13, decay: 0.20, pan: 0, seed: seed + 9 });
      break;
    case "observe_rustle":
      addFilteredNoise(buffer, { start: 0.0, duration: 0.62, amplitude: 0.27, seed, color: "rustle", panStart: -0.72, panEnd: 0.68, attack: 0.04, release: 0.18, modulationHz: 3.4 });
      addModalImpact(buffer, { start: 0.14, frequencies: [520, 825, 1320], weights: [0.62, 0.25, 0.13], duration: 0.25, amplitude: 0.10, decay: 0.07, pan: -0.2, seed: seed + 1 });
      addModalImpact(buffer, { start: 0.34, frequencies: [610, 970, 1510], weights: [0.59, 0.28, 0.13], duration: 0.27, amplitude: 0.08, decay: 0.08, pan: 0.24, seed: seed + 2 });
      addFlutter(buffer, { start: 0.24, duration: 0.30, amplitude: 0.06, seed: seed + 3, panStart: 0.2, panEnd: -0.08 });
      break;
    case "evade_dart":
      addFilteredNoise(buffer, { start: 0.0, duration: 0.33, amplitude: 0.46, seed, color: "high", panStart: -0.86, panEnd: 0.84, attack: 0.004, release: 0.10, modulationHz: 18 });
      addModalImpact(buffer, { start: 0.018, frequencies: [880, 1510, 2430], weights: [0.52, 0.31, 0.17], duration: 0.18, amplitude: 0.16, decay: 0.045, pan: -0.30, seed: seed + 1 });
      addModalImpact(buffer, { start: 0.074, frequencies: [1060, 1710, 2760], weights: [0.49, 0.33, 0.18], duration: 0.18, amplitude: 0.13, decay: 0.040, pan: 0.32, seed: seed + 2 });
      addFlutter(buffer, { start: 0.03, duration: 0.28, amplitude: 0.15, seed: seed + 3, panStart: -0.48, panEnd: 0.55 });
      break;
    case "honey_loss":
      addFilteredNoise(buffer, { start: 0.02, duration: 0.58, amplitude: 0.30, seed, color: "low", panStart: 0.22, panEnd: -0.28, attack: 0.004, release: 0.20, modulationHz: 5.0 });
      addChirp(buffer, { start: 0.03, fromFrequency: 560, toFrequency: 145, duration: 0.50, amplitude: 0.22, panStart: 0.12, panEnd: -0.18, seed: seed + 1 });
      addModalImpact(buffer, { start: 0.42, frequencies: [138, 227, 391], weights: [0.66, 0.24, 0.10], duration: 0.30, amplitude: 0.26, decay: 0.12, pan: -0.12, seed: seed + 2, pitchDrop: 0.08 });
      break;
    case "repair_tap":
      addFilteredNoise(buffer, { start: 0.0, duration: 0.72, amplitude: 0.16, seed, color: "rustle", panStart: -0.35, panEnd: 0.34, attack: 0.02, release: 0.20, modulationHz: 9.0 });
      [[0.08, 0.18, -0.30], [0.30, 0.21, 0.16], [0.53, 0.24, 0.36]].forEach(([start, amplitude, pan], index) => addModalImpact(buffer, { start, frequencies: [175 + index * 18, 310 + index * 29, 590 + index * 47, 1030 + index * 71], weights: [0.48, 0.29, 0.16, 0.07], duration: 0.36, amplitude, decay: 0.10 + index * 0.012, pan, seed: seed + index + 1 }));
      break;
    case "seed_place":
      [[0.04, -0.32], [0.14, 0.18], [0.25, -0.04]].forEach(([start, pan], index) => addModalImpact(buffer, { start, frequencies: [740 + index * 95, 1320 + index * 137, 2310 + index * 181], weights: [0.55, 0.30, 0.15], duration: 0.18, amplitude: 0.13 - index * 0.012, decay: 0.038, pan, seed: seed + index }));
      addFilteredNoise(buffer, { start: 0.22, duration: 0.32, amplitude: 0.24, seed: seed + 8, color: "low", panStart: -0.18, panEnd: 0.12, attack: 0.006, release: 0.16 });
      break;
    case "seed_shell_rustle":
      addFilteredNoise(buffer, { start: 0.0, duration: 1.18, amplitude: 0.16, seed, color: "rustle", panStart: -0.42, panEnd: 0.44, attack: 0.035, release: 0.24, modulationHz: 3.1 });
      [[0.08, -0.44], [0.34, 0.02], [0.62, 0.42]].forEach(([start, pan], index) => {
        addFilteredNoise(buffer, { start, duration: 0.30, amplitude: 0.19 - index * 0.018, seed: seed + index + 1, color: "rustle", panStart: pan - 0.08, panEnd: pan + 0.08, attack: 0.01, release: 0.12, modulationHz: 8.0 + index });
        addModalImpact(buffer, { start: start + 0.10, frequencies: [238 + index * 19, 421 + index * 31, 735 + index * 47], weights: [0.54, 0.31, 0.15], duration: 0.34, amplitude: 0.10, decay: 0.11, pan, seed: seed + index + 20 });
      });
      break;
    case "warmth_link": {
      const random = seededRandom(seed);
      for (let index = 0; index < 9; index += 1) {
        const start = 0.02 + random() * 0.64;
        addFilteredNoise(buffer, { start, duration: 0.035 + random() * 0.035, amplitude: 0.08 + random() * 0.08, seed: seed + index * 17, color: "click", panStart: random() * 1.2 - 0.6, attack: 0.001, release: 0.025 });
      }
      addFilteredNoise(buffer, { start: 0.0, duration: 0.96, amplitude: 0.13, seed: seed + 100, color: "low", panStart: -0.18, panEnd: 0.18, attack: 0.08, release: 0.24, modulationHz: 1.7 });
      addModalImpact(buffer, { start: 0.10, frequencies: [220, 333, 447, 691], weights: [0.38, 0.30, 0.21, 0.11], duration: 0.94, amplitude: 0.15, decay: 0.38, pan: 0, seed: seed + 101 });
      break;
    }
    case "carry_log":
      addFilteredNoise(buffer, { start: 0.0, duration: 0.68, amplitude: 0.38, seed, color: "low", panStart: -0.42, panEnd: 0.32, attack: 0.018, release: 0.16, modulationHz: 11 });
      addModalImpact(buffer, { start: 0.34, frequencies: [112, 205, 352, 690], weights: [0.48, 0.29, 0.16, 0.07], duration: 0.46, amplitude: 0.29, decay: 0.16, pan: -0.16, seed: seed + 1 });
      addModalImpact(buffer, { start: 0.62, frequencies: [128, 237, 410, 760], weights: [0.47, 0.30, 0.16, 0.07], duration: 0.30, amplitude: 0.23, decay: 0.12, pan: 0.25, seed: seed + 2 });
      addFlutter(buffer, { start: 0.12, duration: 0.46, amplitude: 0.08, seed: seed + 3, panStart: -0.12, panEnd: 0.20 });
      break;
    case "handoff":
      addPluck(buffer, { start: 0.03, frequency: 520, duration: 0.68, amplitude: 0.16, damping: 0.995, pan: -0.42, seed });
      addPluck(buffer, { start: 0.24, frequency: 650, duration: 0.68, amplitude: 0.16, damping: 0.995, pan: 0.42, seed: seed + 1 });
      addModalImpact(buffer, { start: 0.43, frequencies: [260, 390, 520, 780], weights: [0.32, 0.29, 0.25, 0.14], duration: 0.58, amplitude: 0.14, decay: 0.24, pan: 0, seed: seed + 2 });
      addFlutter(buffer, { start: 0.35, duration: 0.44, amplitude: 0.055, seed: seed + 3, panStart: 0.48, panEnd: -0.35 });
      break;
    case "complete":
      [[0.03, 440, -0.28], [0.22, 554.4, 0.05], [0.42, 659.3, 0.28]].forEach(([start, frequency, pan], index) => addPluck(buffer, { start, frequency, duration: 0.86, amplitude: 0.145, damping: 0.996, pan, seed: seed + index }));
      addFlutter(buffer, { start: 0.48, duration: 0.56, amplitude: 0.055, seed: seed + 8, panStart: -0.4, panEnd: 0.42 });
      addModalImpact(buffer, { start: 0.64, frequencies: [165, 293, 517], weights: [0.50, 0.32, 0.18], duration: 0.62, amplitude: 0.105, decay: 0.24, pan: 0, seed: seed + 9 });
      break;
    case "pouch_full":
      addModalImpact(buffer, { start: 0.03, frequencies: [180, 312, 565], weights: [0.54, 0.30, 0.16], duration: 0.46, amplitude: 0.26, decay: 0.15, pan: -0.08, seed });
      addModalImpact(buffer, { start: 0.19, frequencies: [510, 890, 1440], weights: [0.55, 0.29, 0.16], duration: 0.30, amplitude: 0.12, decay: 0.075, pan: 0.25, seed: seed + 1 });
      addFlutter(buffer, { start: 0.12, duration: 0.36, amplitude: 0.065, seed: seed + 2, panStart: -0.22, panEnd: 0.15 });
      break;
    case "relay_drop":
      addFilteredNoise(buffer, { start: 0.0, duration: 0.28, amplitude: 0.20, seed, color: "low", panStart: -0.18, panEnd: 0.24, attack: 0.003, release: 0.10 });
      addModalImpact(buffer, { start: 0.07, frequencies: [145, 270, 520], weights: [0.57, 0.29, 0.14], duration: 0.44, amplitude: 0.22, decay: 0.14, pan: 0.12, seed: seed + 1 });
      addFlutter(buffer, { start: 0.16, duration: 0.36, amplitude: 0.09, seed: seed + 2, panStart: 0.38, panEnd: -0.26 });
      break;
    default:
      throw new Error(`Unknown SFX recipe: ${spec.recipe}`);
  }
  return buffer;
}

function addAmbientNoise(buffer, options) {
  const { seed, amplitude, smoothing, panBias = 0, modulationHz = 0.1 } = options;
  const randomLeft = seededRandom(seed);
  const randomRight = seededRandom(seed ^ 0x9e3779b9);
  let leftState = 0;
  let rightState = 0;
  for (let frame = 0; frame < buffer.frames; frame += 1) {
    const time = frame / buffer.sampleRate;
    leftState += smoothing * ((randomLeft() * 2 - 1) - leftState);
    rightState += smoothing * ((randomRight() * 2 - 1) - rightState);
    const motion = 0.72 + 0.28 * Math.sin(TAU * modulationHz * time + seed * 0.001);
    const shared = (leftState + rightState) * 0.23;
    buffer.left[frame] += (leftState * (1 - panBias) + shared) * amplitude * motion;
    buffer.right[frame] += (rightState * (1 + panBias) + shared) * amplitude * (1.44 - motion * 0.62);
  }
}

function crossfadeLoop(buffer, seconds) {
  const frames = Math.min(Math.round(seconds * buffer.sampleRate), Math.floor(buffer.frames / 3));
  for (let offset = 0; offset < frames; offset += 1) {
    const progress = (offset + 1) / (frames + 1);
    const smooth = progress * progress * (3 - 2 * progress);
    const destination = buffer.frames - frames + offset;
    buffer.left[destination] = buffer.left[destination] * (1 - smooth) + buffer.left[offset] * smooth;
    buffer.right[destination] = buffer.right[destination] * (1 - smooth) + buffer.right[offset] * smooth;
  }
  // Close the last few milliseconds with a cubic Hermite bridge. The broad
  // crossfade above matches texture; this bridge additionally makes the wrapped
  // sample value and first derivative continuous instead of merely quiet.
  const bridgeFrames = Math.min(Math.round(buffer.sampleRate * 0.012), Math.floor(frames / 4));
  const closeChannel = (channel) => {
    const bridgeStart = buffer.frames - bridgeFrames;
    const startValue = channel[bridgeStart - 1];
    const endValue = channel[0];
    const startSlope = (channel[bridgeStart - 1] - channel[bridgeStart - 2]) * bridgeFrames;
    const endSlope = (channel[1] - channel[0]) * bridgeFrames;
    for (let offset = 0; offset < bridgeFrames; offset += 1) {
      const t = (offset + 1) / bridgeFrames;
      const t2 = t * t;
      const t3 = t2 * t;
      channel[bridgeStart + offset] = (2 * t3 - 3 * t2 + 1) * startValue
        + (t3 - 2 * t2 + t) * startSlope
        + (-2 * t3 + 3 * t2) * endValue
        + (t3 - t2) * endSlope;
    }
  };
  closeChannel(buffer.left);
  closeChannel(buffer.right);
}

function renderAmbience(spec, sampleRate) {
  const buffer = createBuffer(sampleRate, spec.duration_seconds);
  const random = seededRandom(spec.seed);
  if (spec.recipe === "hive_room_loop") {
    addAmbientNoise(buffer, { seed: spec.seed, amplitude: 0.19, smoothing: 0.006, modulationHz: 0.07 });
    addAmbientNoise(buffer, { seed: spec.seed + 1, amplitude: 0.065, smoothing: 0.17, panBias: 0.12, modulationHz: 0.23 });
    for (let index = 0; index < 18; index += 1) {
      const start = random() * (spec.duration_seconds - 0.45);
      addFlutter(buffer, { start, duration: 0.16 + random() * 0.28, amplitude: 0.026 + random() * 0.025, seed: spec.seed + 20 + index, panStart: random() * 1.4 - 0.7, panEnd: random() * 1.0 - 0.5 });
    }
    for (let index = 0; index < 7; index += 1) {
      addModalImpact(buffer, { start: random() * (spec.duration_seconds - 0.6), frequencies: [96 + random() * 24, 181 + random() * 31, 338 + random() * 55], weights: [0.57, 0.29, 0.14], duration: 0.50, amplitude: 0.028, decay: 0.18, pan: random() * 1.2 - 0.6, seed: spec.seed + 100 + index });
    }
  } else if (spec.recipe === "field_day_loop") {
    addAmbientNoise(buffer, { seed: spec.seed, amplitude: 0.23, smoothing: 0.004, panBias: -0.06, modulationHz: 0.055 });
    addAmbientNoise(buffer, { seed: spec.seed + 1, amplitude: 0.090, smoothing: 0.12, panBias: 0.10, modulationHz: 0.17 });
    for (let index = 0; index < 22; index += 1) {
      const start = random() * (spec.duration_seconds - 0.38);
      addFilteredNoise(buffer, { start, duration: 0.10 + random() * 0.22, amplitude: 0.032 + random() * 0.034, seed: spec.seed + 20 + index, color: "rustle", panStart: random() * 1.6 - 0.8, panEnd: random() * 1.6 - 0.8, attack: 0.02, release: 0.06, modulationHz: 12 + random() * 9 });
    }
    for (let index = 0; index < 9; index += 1) {
      const start = random() * (spec.duration_seconds - 0.55);
      addFlutter(buffer, { start, duration: 0.18 + random() * 0.32, amplitude: 0.024 + random() * 0.022, seed: spec.seed + 100 + index, panStart: random() * 1.7 - 0.85, panEnd: random() * 1.7 - 0.85 });
    }
  } else {
    throw new Error(`Unknown ambience recipe: ${spec.recipe}`);
  }
  crossfadeLoop(buffer, spec.loop_crossfade_seconds);
  return buffer;
}

function finishBuffer(buffer, targetPeakDbfs, loop) {
  let leftMean = 0;
  let rightMean = 0;
  for (let frame = 0; frame < buffer.frames; frame += 1) {
    leftMean += buffer.left[frame];
    rightMean += buffer.right[frame];
  }
  leftMean /= buffer.frames;
  rightMean /= buffer.frames;
  let peak = 0;
  for (let frame = 0; frame < buffer.frames; frame += 1) {
    buffer.left[frame] = Math.tanh((buffer.left[frame] - leftMean) * 1.22) / Math.tanh(1.22);
    buffer.right[frame] = Math.tanh((buffer.right[frame] - rightMean) * 1.22) / Math.tanh(1.22);
    peak = Math.max(peak, Math.abs(buffer.left[frame]), Math.abs(buffer.right[frame]));
  }
  const targetPeak = 10 ** (targetPeakDbfs / 20);
  const gain = targetPeak / Math.max(peak, 1e-9);
  const edgeFrames = loop ? 0 : Math.min(Math.round(buffer.sampleRate * 0.012), Math.floor(buffer.frames / 8));
  for (let frame = 0; frame < buffer.frames; frame += 1) {
    let edgeGain = 1;
    if (edgeFrames > 0 && frame < edgeFrames) edgeGain *= Math.sin((frame / edgeFrames) * Math.PI / 2);
    if (edgeFrames > 0 && frame >= buffer.frames - edgeFrames) edgeGain *= Math.sin(((buffer.frames - 1 - frame) / edgeFrames) * Math.PI / 2);
    buffer.left[frame] *= gain * edgeGain;
    buffer.right[frame] *= gain * edgeGain;
  }
}

function encodePcm16Wave(buffer) {
  const blockAlign = 4;
  const dataSize = buffer.frames * blockAlign;
  const bytes = Buffer.alloc(44 + dataSize);
  bytes.write("RIFF", 0, "ascii");
  bytes.writeUInt32LE(36 + dataSize, 4);
  bytes.write("WAVE", 8, "ascii");
  bytes.write("fmt ", 12, "ascii");
  bytes.writeUInt32LE(16, 16);
  bytes.writeUInt16LE(1, 20);
  bytes.writeUInt16LE(2, 22);
  bytes.writeUInt32LE(buffer.sampleRate, 24);
  bytes.writeUInt32LE(buffer.sampleRate * blockAlign, 28);
  bytes.writeUInt16LE(blockAlign, 32);
  bytes.writeUInt16LE(16, 34);
  bytes.write("data", 36, "ascii");
  bytes.writeUInt32LE(dataSize, 40);
  let offset = 44;
  for (let frame = 0; frame < buffer.frames; frame += 1) {
    const left = Math.round(Math.max(-1, Math.min(1, buffer.left[frame])) * 32767);
    const right = Math.round(Math.max(-1, Math.min(1, buffer.right[frame])) * 32767);
    bytes.writeInt16LE(left, offset);
    bytes.writeInt16LE(right, offset + 2);
    offset += 4;
  }
  return bytes;
}

function validateSources(sources) {
  if (sources.schema_version !== 1 || sources.sample_rate !== 44100 || sources.channels !== 2 || sources.pcm_bits !== 16) {
    throw new Error("Commercial audio sources must use schema v1, 44.1 kHz, stereo, 16-bit PCM");
  }
  if (!Array.isArray(sources.assets) || sources.assets.length < 14) throw new Error("Commercial audio source list is incomplete");
  const ids = new Set();
  const files = new Set();
  for (const spec of sources.assets) {
    if (!spec.id || !/^[a-z0-9_]+$/u.test(spec.id) || ids.has(spec.id)) throw new Error(`Invalid or duplicate audio id: ${spec.id}`);
    if (!spec.file || !/^[a-z0-9_]+\.wav$/u.test(spec.file) || files.has(spec.file)) throw new Error(`Invalid or duplicate WAV filename: ${spec.file}`);
    if (!["sfx", "ambience"].includes(spec.kind) || !spec.recipe || !Number.isInteger(spec.seed)) throw new Error(`Incomplete audio source: ${spec.id}`);
    if (!Number.isInteger(spec.frames) || spec.frames !== Math.round(spec.duration_seconds * sources.sample_rate)) throw new Error(`Audio source has inconsistent frame count: ${spec.id}`);
    if (!(spec.duration_seconds > 0.15) || !(spec.target_peak_dbfs <= -3)) throw new Error(`Unsafe duration or peak target: ${spec.id}`);
    if (!Array.isArray(spec.design_layers) || spec.design_layers.length < 3) throw new Error(`Audio source lacks layered design: ${spec.id}`);
    if (spec.kind === "ambience" && !(spec.loop_crossfade_seconds > 0)) throw new Error(`Ambience source lacks a loop crossfade: ${spec.id}`);
    ids.add(spec.id);
    files.add(spec.file);
  }
}

export async function generateCommercialAudio({ sourcePath = defaultSourcePath, outputDirectory = defaultOutputDirectory } = {}) {
  const sourceBytes = await readFile(sourcePath);
  const sources = JSON.parse(sourceBytes.toString("utf8"));
  validateSources(sources);
  await mkdir(outputDirectory, { recursive: true });
  const assets = [];
  for (const spec of sources.assets) {
    const loop = spec.kind === "ambience";
    const buffer = loop ? renderAmbience(spec, sources.sample_rate) : renderSfx(spec, sources.sample_rate);
    finishBuffer(buffer, spec.target_peak_dbfs, loop);
    const wave = encodePcm16Wave(buffer);
    const outputPath = join(outputDirectory, spec.file);
    await writeFile(outputPath, wave);
    assets.push({
      id: spec.id,
      file: spec.file,
      kind: spec.kind,
      recipe: spec.recipe,
      source_kind: "project_owned_deterministic_synthesis",
      sample_rate: sources.sample_rate,
      channels: sources.channels,
      pcm_bits: sources.pcm_bits,
      frames: buffer.frames,
      duration_seconds: spec.duration_seconds,
      loop,
      sha256: createHash("sha256").update(wave).digest("hex"),
    });
  }
  const manifest = {
    schema_version: 1,
    generator: "scripts/generate_commercial_audio.mjs",
    generator_sha256: createHash("sha256").update(await readFile(fileURLToPath(import.meta.url))).digest("hex"),
    source_parameters: "scripts/commercial_audio_sources.json",
    source_parameters_sha256: createHash("sha256").update(sourceBytes).digest("hex"),
    candidate_status: sources.candidate_status,
    assets,
  };
  await writeFile(join(outputDirectory, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
  return { outputDirectory, manifest };
}

function parseArguments(argumentsList) {
  let outputDirectory = defaultOutputDirectory;
  for (let index = 0; index < argumentsList.length; index += 1) {
    const argument = argumentsList[index];
    if (argument === "--output-dir") {
      outputDirectory = resolve(argumentsList[index + 1] || "");
      index += 1;
    } else {
      throw new Error(`Unknown argument: ${argument}`);
    }
  }
  return { outputDirectory };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const { outputDirectory } = parseArguments(process.argv.slice(2));
  const result = await generateCommercialAudio({ outputDirectory });
  console.log(`Rendered ${result.manifest.assets.length} deterministic commercial audio candidates to ${result.outputDirectory}`);
}
