import {
  S3Client,
  PutObjectCommand,
  CreateMultipartUploadCommand,
  UploadPartCommand,
  CompleteMultipartUploadCommand,
  AbortMultipartUploadCommand,
  type CompletedPart,
  type PutObjectCommandInput,
} from "@aws-sdk/client-s3";
import {
  createReadStream,
  existsSync,
  mkdirSync,
  copyFileSync,
  statSync,
} from "node:fs";
import { join, basename } from "node:path";
import { getRecordingsDir } from "./recorder.js";

// ── Configuration ──────────────────────────────────────────────────────────

function getS3Config() {
  return {
    endpoint: process.env.S3_ENDPOINT ?? "",
    bucket: process.env.S3_BUCKET ?? "memora-bot-recordings",
    region: process.env.S3_REGION ?? "us-east-1",
    accessKey: process.env.S3_ACCESS_KEY ?? "",
    secretKey: process.env.S3_SECRET_KEY ?? "",
    forcePathStyle: process.env.S3_FORCE_PATH_STYLE !== "false",
  };
}

export function isConfigured(): boolean {
  const cfg = getS3Config();
  return Boolean(cfg.endpoint && cfg.accessKey && cfg.secretKey);
}

// ── S3 Client ──────────────────────────────────────────────────────────────

let _s3Client: S3Client | null = null;

function getS3Client(): S3Client | null {
  if (!isConfigured()) return null;
  if (!_s3Client) {
    const cfg = getS3Config();
    _s3Client = new S3Client({
      endpoint: cfg.endpoint,
      region: cfg.region,
      credentials: {
        accessKeyId: cfg.accessKey,
        secretAccessKey: cfg.secretKey,
      },
      forcePathStyle: cfg.forcePathStyle,
      // Aggressive timeouts for large uploads
      requestHandler: undefined, // use default fetch handler
    });
  }
  return _s3Client;
}

// ── Multipart threshold ────────────────────────────────────────────────────

/** Files larger than this use multipart upload for reliability. */
const MULTIPART_THRESHOLD_BYTES = 5 * 1024 * 1024; // 5 MiB
const PART_SIZE = 5 * 1024 * 1024; // 5 MiB per part
const MAX_RETRIES = 3;

// ── Upload ─────────────────────────────────────────────────────────────────

/**
 * Upload an audio file to S3-compatible storage.
 *
 * Uses multipart upload for files >5 MiB for reliability with large
 * recordings.  Retries each part up to 3 times.
 *
 * Falls back to local file copy when S3 is not configured.
 */
export async function uploadAudio(
  filePath: string,
  meetingID: string
): Promise<string> {
  if (!existsSync(filePath)) {
    throw new Error(`File not found for upload: ${filePath}`);
  }

  const client = getS3Client();
  const cfg = getS3Config();
  const key = `recordings/${meetingID}/${basename(filePath)}`;
  const { size } = statSync(filePath);

  if (client) {
    try {
      if (size > MULTIPART_THRESHOLD_BYTES) {
        return await multipartUpload(client, cfg, filePath, key, size);
      }
      return await singleUpload(client, cfg, filePath, key, size);
    } catch (err: any) {
      console.error(`[Uploader] S3 upload failed, falling back to local: ${err.message}`);
    }
  }

  return uploadLocal(filePath, meetingID);
}

// ── Single-part upload ─────────────────────────────────────────────────────

async function singleUpload(
  client: S3Client,
  cfg: ReturnType<typeof getS3Config>,
  filePath: string,
  key: string,
  size: number
): Promise<string> {
  const fileStream = createReadStream(filePath);

  const params: PutObjectCommandInput = {
    Bucket: cfg.bucket,
    Key: key,
    Body: fileStream,
    ContentType: "audio/wav",
    ContentLength: size,
  };

  await client.send(new PutObjectCommand(params));
  return buildPublicURL(cfg, key);
}

// ── Multipart upload ───────────────────────────────────────────────────────

async function multipartUpload(
  client: S3Client,
  cfg: ReturnType<typeof getS3Config>,
  filePath: string,
  key: string,
  size: number
): Promise<string> {
  console.log(`[Uploader] Starting multipart upload: ${basename(filePath)} (${(size / 1024 / 1024).toFixed(1)} MiB)`);

  const totalParts = Math.ceil(size / PART_SIZE);

  // Create multipart upload
  const createResp = await client.send(
    new CreateMultipartUploadCommand({
      Bucket: cfg.bucket,
      Key: key,
      ContentType: "audio/wav",
    })
  );
  const uploadId = createResp.UploadId;
  if (!uploadId) throw new Error("Multipart upload: no UploadId returned");

  const completedParts: CompletedPart[] = [];

  try {
    // Upload parts sequentially to avoid overwhelming the network,
    // but with retry per part for reliability.
    for (let partNumber = 1; partNumber <= totalParts; partNumber++) {
      const start = (partNumber - 1) * PART_SIZE;
      const end = Math.min(start + PART_SIZE, size);
      const partSize = end - start;

      const part = await uploadPartWithRetry(
        client,
        cfg,
        filePath,
        key,
        uploadId,
        partNumber,
        start,
        partSize
      );

      completedParts.push({ PartNumber: partNumber, ETag: part.ETag });
      console.log(
        `[Uploader] Part ${partNumber}/${totalParts} uploaded (${(partSize / 1024).toFixed(0)} KiB)`
      );
    }

    // Complete
    await client.send(
      new CompleteMultipartUploadCommand({
        Bucket: cfg.bucket,
        Key: key,
        UploadId: uploadId,
        MultipartUpload: { Parts: completedParts },
      })
    );

    console.log(`[Uploader] Multipart upload complete: ${basename(filePath)}`);
    return buildPublicURL(cfg, key);
  } catch (err) {
    // Abort on failure
    try {
      await client.send(
        new AbortMultipartUploadCommand({
          Bucket: cfg.bucket,
          Key: key,
          UploadId: uploadId,
        })
      );
    } catch (abortErr: any) {
      console.error(`[Uploader] Failed to abort multipart upload: ${abortErr.message}`);
    }
    throw err;
  }
}

async function uploadPartWithRetry(
  client: S3Client,
  cfg: ReturnType<typeof getS3Config>,
  filePath: string,
  key: string,
  uploadId: string,
  partNumber: number,
  start: number,
  partSize: number
): Promise<{ ETag?: string }> {
  let lastError: Error | undefined;

  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      const fileStream = createReadStream(filePath, { start, end: start + partSize - 1 });

      const resp = await client.send(
        new UploadPartCommand({
          Bucket: cfg.bucket,
          Key: key,
          UploadId: uploadId,
          PartNumber: partNumber,
          Body: fileStream,
          ContentLength: partSize,
        })
      );

      return { ETag: resp.ETag };
    } catch (err: any) {
      lastError = err;
      if (attempt < MAX_RETRIES) {
        const delay = Math.min(1000 * Math.pow(2, attempt), 8000);
        console.warn(
          `[Uploader] Part ${partNumber} attempt ${attempt} failed, retrying in ${delay}ms: ${err.message}`
        );
        await new Promise((r) => setTimeout(r, delay));
      }
    }
  }

  throw new Error(
    `Part ${partNumber} failed after ${MAX_RETRIES} attempts: ${lastError?.message}`
  );
}

// ── URL helpers ────────────────────────────────────────────────────────────

function buildPublicURL(
  cfg: ReturnType<typeof getS3Config>,
  key: string
): string {
  const endpoint = cfg.endpoint.replace(/\/+$/, "");
  return `${endpoint}/${cfg.bucket}/${key}`;
}

// ── Local fallback ─────────────────────────────────────────────────────────

const LOCAL_UPLOADS_DIR = join(getRecordingsDir(), "..", "memora-uploads");

function uploadLocal(filePath: string, meetingID: string): string {
  if (!existsSync(LOCAL_UPLOADS_DIR)) {
    mkdirSync(LOCAL_UPLOADS_DIR, { recursive: true });
  }

  const dest = join(LOCAL_UPLOADS_DIR, `${meetingID}-${basename(filePath)}`);
  copyFileSync(filePath, dest);

  const url = `file://${dest}`;
  console.log(`[Uploader] Stored locally: ${url}`);
  return url;
}
