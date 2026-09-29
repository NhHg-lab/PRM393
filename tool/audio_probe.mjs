import fs from 'node:fs';
import { chromium } from 'file:///C:/Users/Hoang/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs';

const audioPath = process.argv[2];
if (!audioPath) {
  throw new Error('Usage: node tool/audio_probe.mjs <audio-file>');
}

const bytes = fs.readFileSync(audioPath);
const browser = await chromium.launch({ channel: 'chrome', headless: true });
try {
  const page = await browser.newPage();
  const analysis = await page.evaluate(async (base64) => {
    const binary = atob(base64);
    const data = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index++) {
      data[index] = binary.charCodeAt(index);
    }

    const context = new AudioContext();
    const audio = await context.decodeAudioData(data.buffer);
    await context.close();
    const windowSeconds = 0.02;
    const windowSamples = Math.max(1, Math.round(audio.sampleRate * windowSeconds));
    const levels = [];
    for (let start = 0; start < audio.length; start += windowSamples) {
      let sum = 0;
      let count = 0;
      const end = Math.min(audio.length, start + windowSamples);
      for (let channel = 0; channel < audio.numberOfChannels; channel++) {
        const samples = audio.getChannelData(channel);
        for (let index = start; index < end; index++) {
          sum += samples[index] * samples[index];
          count++;
        }
      }
      levels.push(Math.sqrt(sum / Math.max(1, count)));
    }

    const peak = Math.max(...levels);
    const threshold = peak * 0.08;
    const rawSegments = [];
    let segmentStart = null;
    for (let index = 0; index <= levels.length; index++) {
      const active = index < levels.length && levels[index] >= threshold;
      if (active && segmentStart === null) segmentStart = index;
      if (!active && segmentStart !== null) {
        rawSegments.push([segmentStart, index]);
        segmentStart = null;
      }
    }

    const merged = [];
    for (const segment of rawSegments) {
      const previous = merged.at(-1);
      if (previous && (segment[0] - previous[1]) * windowSeconds <= 0.18) {
        previous[1] = segment[1];
      } else {
        merged.push([...segment]);
      }
    }

    return {
      durationSeconds: audio.duration,
      sampleRate: audio.sampleRate,
      channels: audio.numberOfChannels,
      peakRms: peak,
      activityThreshold: threshold,
      segments: merged
        .filter(([start, end]) => (end - start) * windowSeconds >= 0.08)
        .map(([start, end]) => ({
          startSeconds: Number((start * windowSeconds).toFixed(3)),
          endSeconds: Number((end * windowSeconds).toFixed(3)),
        })),
    };
  }, bytes.toString('base64'));
  console.log(JSON.stringify(analysis, null, 2));
} finally {
  await browser.close();
}
