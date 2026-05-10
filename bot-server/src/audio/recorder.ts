import { spawn, execSync, type ChildProcess } from "node:child_process";
import { existsSync, mkdirSync, unlinkSync, createWriteStream } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { createAudioPreprocessor, type AudioPreprocessor } from "./preprocessor.js";

const RECORDINGS_DIR = join(tmpdir(), "memora-recordings");

// Track active recording processes so we can stop them
const activeRecordings = new Map<string, ChildProcess>();
const recordingPaths = new Map<string, string>();
const activePreprocessors = new Map<string, AudioPreprocessor>();

// Ensure recordings directory exists
if (!existsSync(RECORDINGS_DIR)) {
  mkdirSync(RECORDINGS_DIR, { recursive: true });
}

/**
 * Detect the best available audio capture backend.
 */
function detectCaptureBackend(): "ffmpeg-avfoundation" | "ffmpeg-pulse" | "arecord" | "none" {
  try {
    execSync("ffmpeg -version", { stdio: "ignore" });
    // macOS: AVFoundation
    if (process.platform === "darwin") {
      return "ffmpeg-avfoundation";
    }
    // Linux: PulseAudio
    try {
      execSync("pactl info", { stdio: "ignore" });
      return "ffmpeg-pulse";
    } catch {
      // fallthrough
    }
    // Linux: ALSA fallback
    try {
      execSync("arecord --version", { stdio: "ignore" });
      return "arecord";
    } catch {
      // fallthrough
    }
  } catch {
    // ffmpeg not available
    try {
      execSync("arecord --version", { stdio: "ignore" });
      return "arecord";
    } catch {
      // fallthrough
    }
  }
  return "none";
}

/**
 * Generate a minimal valid WAV file (16-bit PCM, mono, 16000 Hz).
 * Used as a last-resort fallback when no audio capture backend is available.
 */
function generateSilentWav(filePath: string, durationSeconds: number, sampleRate = 16000): void {
  const numSamples = sampleRate * durationSeconds;
  const numChannels = 1;
  const bitsPerSample = 16;
  const bytesPerSample = bitsPerSample / 8;
  const dataSize = numSamples * numChannels * bytesPerSample;
  const headerSize = 44;
  const buffer = Buffer.alloc(headerSize + dataSize);

  buffer.write("RIFF", 0);
  buffer.writeUInt32LE(36 + dataSize, 4);
  buffer.write("WAVE", 8);
  buffer.write("fmt ", 12);
  buffer.writeUInt32LE(16, 16);
  buffer.writeUInt16LE(1, 20);
  buffer.writeUInt16LE(numChannels, 22);
  buffer.writeUInt32LE(sampleRate, 24);
  buffer.writeUInt32LE(sampleRate * numChannels * bytesPerSample, 28);
  buffer.writeUInt16LE(numChannels * bytesPerSample, 32);
  buffer.writeUInt16LE(bitsPerSample, 34);
  buffer.write("data", 36);
  buffer.writeUInt32LE(dataSize, 40);

  require("node:fs").writeFileSync(filePath, buffer);
}

/**
 * Start recording audio for a meeting.
 *
 * Tries backends in order:
 * 1. ffmpeg + AVFoundation (macOS system audio via BlackHole / Soundflower)
 * 2. ffmpeg + PulseAudio (Linux system audio)
 * 3. arecord (ALSA direct capture)
 * 4. Silent WAV fallback (for test environments)
 *
 * Recording runs asynchronously. Call `stopRecording()` to end capture.
 */
export async function startRecording(
  meetingID: string,
  durationMinutes: number
): Promise<void> {
  const filePath = join(RECORDINGS_DIR, `${meetingID}.wav`);
  if (existsSync(filePath)) unlinkSync(filePath);

  recordingPaths.set(meetingID, filePath);

  const backend = detectCaptureBackend();
  const preprocessor = createAudioPreprocessor();
  activePreprocessors.set(meetingID, preprocessor);

  const durationSeconds = durationMinutes * 60;

  switch (backend) {
    case "ffmpeg-avfoundation": {
      console.log(`[Recorder] Using ffmpeg AVFoundation for meeting ${meetingID}`);
      // AVFoundation audio capture — uses BlackHole or default input
      const child = spawn("ffmpeg", [
        "-f", "avfoundation",
        "-i", ":0",           // default audio input (BlackHole virtual device preferred)
        "-ac", "1",           // mono
        "-ar", "16000",       // 16kHz for STT
        "-sample_fmt", "s16",
        "-t", String(durationSeconds),
        "-y",
        filePath,
      ], { stdio: ["ignore", "pipe", "pipe"] });

      activeRecordings.set(meetingID, child);
      attachRecorderListeners(meetingID, child);
      break;
    }

    case "ffmpeg-pulse": {
      console.log(`[Recorder] Using ffmpeg PulseAudio for meeting ${meetingID}`);
      const child = spawn("ffmpeg", [
        "-f", "pulse",
        "-i", "default",      // default PulseAudio source
        "-ac", "1",
        "-ar", "16000",
        "-sample_fmt", "s16",
        "-t", String(durationSeconds),
        "-y",
        filePath,
      ], { stdio: ["ignore", "pipe", "pipe"] });

      activeRecordings.set(meetingID, child);
      attachRecorderListeners(meetingID, child);
      break;
    }

    case "arecord": {
      console.log(`[Recorder] Using arecord for meeting ${meetingID}`);
      const child = spawn("arecord", [
        "-f", "S16_LE",
        "-r", "16000",
        "-c", "1",
        "-d", String(durationSeconds),
        filePath,
      ], { stdio: ["ignore", "pipe", "pipe"] });

      activeRecordings.set(meetingID, child);
      attachRecorderListeners(meetingID, child);
      break;
    }

    default: {
      console.log(`[Recorder] No capture backend — using silent WAV for meeting ${meetingID}`);
      // Generate a silent placeholder for test environments
      generateSilentWav(filePath, durationSeconds);
      break;
    }
  }
}

function attachRecorderListeners(meetingID: string, child: ChildProcess): void {
  child.stderr?.on("data", (data: Buffer) => {
    // ffmpeg outputs progress on stderr
    const msg = data.toString().trim();
    if (msg.includes("time=") || msg.includes("speed=")) {
      // Progress line — log at debug level
      console.debug(`[Recorder:${meetingID}] ${msg.slice(0, 120)}`);
    }
  });

  child.on("exit", (code) => {
    activeRecordings.delete(meetingID);
    if (code !== 0 && code !== null) {
      console.error(`[Recorder] Capture exited code ${code} for ${meetingID}`);
    }
  });

  child.on("error", (err) => {
    activeRecordings.delete(meetingID);
    console.error(`[Recorder] Capture error for ${meetingID}: ${err.message}`);
  });
}

/**
 * Stop an active recording, run audio preprocessing, and return the output path.
 */
export async function stopRecording(meetingID: string): Promise<string> {
  const rawPath = recordingPaths.get(meetingID);
  if (!rawPath) {
    throw new Error(`No recording found for meeting ${meetingID}`);
  }

  // Kill capture process if running
  const child = activeRecordings.get(meetingID);
  if (child) {
    child.kill("SIGTERM");
    activeRecordings.delete(meetingID);
    await waitForProcessExit(child);
  }

  recordingPaths.delete(meetingID);

  if (!existsSync(rawPath)) {
    throw new Error(`Recording file missing: ${rawPath} for ${meetingID}`);
  }

  // ── Audio preprocessing ──────────────────────────────────────────
  const preprocessor = activePreprocessors.get(meetingID);
  if (preprocessor) {
    try {
      const processedPath = join(RECORDINGS_DIR, `${meetingID}_processed.wav`);
      await preprocessor.process(rawPath, processedPath);
      activePreprocessors.delete(meetingID);
      console.log(`[Recorder] Preprocessing complete: ${processedPath}`);
      return processedPath;
    } catch (err: any) {
      console.warn(`[Recorder] Preprocessing failed, using raw: ${err.message}`);
      activePreprocessors.delete(meetingID);
      return rawPath;
    }
  }

  return rawPath;
}

async function waitForProcessExit(child: ChildProcess): Promise<void> {
  if (child.killed || child.exitCode !== null) return;
  await new Promise<void>((resolve) => {
    child.once("exit", () => resolve());
    setTimeout(resolve, 5_000);
  });
}

export function getRecordingsDir(): string {
  return RECORDINGS_DIR;
}
