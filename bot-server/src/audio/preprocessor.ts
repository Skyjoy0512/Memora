import { spawn, execSync } from "node:child_process";
import { existsSync } from "node:fs";

export interface AudioPreprocessor {
  /** Process a raw audio file and write the optimized output. */
  process(inputPath: string, outputPath: string): Promise<void>;
}

/**
 * Create an audio preprocessor that:
 * 1. Normalizes loudness (EBU R128, -23 LUFS target)
 * 2. Applies high-pass filter (80 Hz) to remove rumble
 * 3. Applies low-pass filter (8 kHz) to focus on speech range
 * 4. Resamples to 16kHz mono 16-bit PCM (optimal for STT engines)
 * 5. Removes leading/trailing silence
 *
 * Falls back gracefully when ffmpeg is unavailable.
 */
export function createAudioPreprocessor(): AudioPreprocessor {
  return new FfmpegAudioPreprocessor();
}

class FfmpegAudioPreprocessor implements AudioPreprocessor {
  private ffmpegAvailable: boolean;

  constructor() {
    this.ffmpegAvailable = this.checkFfmpeg();
  }

  private checkFfmpeg(): boolean {
    try {
      execSync("ffmpeg -version", { stdio: "ignore" });
      return true;
    } catch {
      return false;
    }
  }

  async process(inputPath: string, outputPath: string): Promise<void> {
    if (!existsSync(inputPath)) {
      throw new Error(`Input file not found: ${inputPath}`);
    }

    if (!this.ffmpegAvailable) {
      // No ffmpeg — copy the file as-is
      console.warn("[Preprocessor] ffmpeg not available, skipping preprocessing");
      require("node:fs").copyFileSync(inputPath, outputPath);
      return;
    }

    await this.processWithFfmpeg(inputPath, outputPath);
  }

  private async processWithFfmpeg(
    inputPath: string,
    outputPath: string
  ): Promise<void> {
    // Single-pass audio processing chain optimized for speech-to-text:
    //
    // - highpass=80  : remove sub-bass rumble (HVAC, traffic)
    // - lowpass=8000 : keep only speech-range frequencies
    // - loudnorm     : EBU R128 normalization (-23 LUFS, consistent volume)
    // - silenceremove: strip leading/trailing silence >0.5s at -50dB threshold
    // - aresample    : resample to 16kHz for STT model compatibility
    // - ac 1         : collapse to mono
    // - sample_fmt s16 : 16-bit PCM output
    //
    return new Promise<void>((resolve, reject) => {
      const args = [
        "-i", inputPath,
        "-af",
        [
          "highpass=f=80",
          "lowpass=f=8000",
          "loudnorm=I=-23:LRA=7:TP=-1",
          "silenceremove=stop_periods=-1:stop_duration=0.5:stop_threshold=-50dB",
          "aresample=16000",
        ].join(","),
        "-ac", "1",
        "-sample_fmt", "s16",
        "-ar", "16000",
        "-y",
        outputPath,
      ];

      const child = spawn("ffmpeg", args, {
        stdio: ["ignore", "pipe", "pipe"],
      });

      let stderr = "";

      child.stderr?.on("data", (data: Buffer) => {
        stderr += data.toString();
      });

      child.on("exit", (code) => {
        if (code === 0) {
          resolve();
        } else {
          const lastLine = stderr.trim().split("\n").pop() || `exit code ${code}`;
          reject(new Error(`ffmpeg preprocessing failed: ${lastLine}`));
        }
      });

      child.on("error", (err) => {
        reject(new Error(`ffmpeg preprocessing error: ${err.message}`));
      });
    });
  }
}
