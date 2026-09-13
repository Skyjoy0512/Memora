import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { MemoraNativeModule } from '../MemoraNative.types';

import { audioFiles } from '../../mocks/memoraData';

const nativeState = vi.hoisted(() => ({
  os: 'web',
}));

vi.mock('react-native', () => ({
  Platform: {
    get OS() {
      return nativeState.os;
    },
  },
}));

function useWebFallback() {
  nativeState.os = 'web';
  delete (globalThis as typeof globalThis & { __memoraNativeModuleForTests?: unknown })
    .__memoraNativeModuleForTests;
}

function useNativeStub(stub: Record<string, unknown>) {
  nativeState.os = 'ios';
  (globalThis as typeof globalThis & { __memoraNativeModuleForTests?: unknown })
    .__memoraNativeModuleForTests = stub;
}

beforeEach(() => {
  vi.clearAllMocks();
  useWebFallback();
});

// モジュール内の fallback 状態（生成ファイル等）をテスト間で分離するため、
// 毎回モジュールを再評価してファサードを取り直す。
async function newMemoraNative(): Promise<MemoraNativeModule> {
  vi.resetModules();
  const loaded = await import('../MemoraNative');
  return loaded.MemoraNative;
}

describe('native モジュール不在（web/デモ）', () => {
  it('listAudioFiles はモック一覧へフォールバックする', async () => {
    useWebFallback();
    const MemoraNative = await newMemoraNative();
    await expect(MemoraNative.listAudioFiles()).resolves.toEqual(audioFiles);
  });

  it('startRecording はサンプルセッションを返す（デモ継続）', async () => {
    useWebFallback();
    const MemoraNative = await newMemoraNative();
    const session = await MemoraNative.startRecording();
    expect(session).toMatchObject({ source: 'iPhone' });
    expect(session.id.startsWith('recording-')).toBe(true);
    expect(Number.isNaN(Date.parse(session.startedAt))).toBe(false);
  });

  it('stopRecording / importAudio はサンプルファイルを返す（デモ継続）', async () => {
    useWebFallback();
    const MemoraNative = await newMemoraNative();
    const saved = await MemoraNative.stopRecording('demo-session');
    const imported = await MemoraNative.importAudio('file:///demo/audio.m4a');
    expect(saved.id.startsWith('import-')).toBe(true);
    expect(imported.id.startsWith('import-')).toBe(true);
    expect(imported.title).toBe('audio.m4a');
  });
});

describe('native 実処理の失敗は呼び出し元へ伝搬する', () => {
  it('startRecording の失敗は reject されサンプルセッションへ置換されない', async () => {
    const nativeStub: Record<string, unknown> = {};
    useNativeStub(nativeStub);
    nativeStub.startRecording = vi.fn().mockRejectedValue(new Error('recorder unavailable'));
    const MemoraNative = await newMemoraNative();
    await expect(MemoraNative.startRecording()).rejects.toThrow('recorder unavailable');
  });

  it('stopRecording の失敗は reject されサンプルファイルへ置換されない', async () => {
    const nativeStub: Record<string, unknown> = {};
    useNativeStub(nativeStub);
    nativeStub.stopRecording = vi.fn().mockRejectedValue(new Error('save failed'));
    const MemoraNative = await newMemoraNative();
    await expect(MemoraNative.stopRecording('session-1')).rejects.toThrow('save failed');
  });

  it('importAudio の失敗は reject されサンプルファイルへ置換されない', async () => {
    const nativeStub: Record<string, unknown> = {};
    useNativeStub(nativeStub);
    nativeStub.importAudio = vi.fn().mockRejectedValue(new Error('import failed'));
    const MemoraNative = await newMemoraNative();
    await expect(MemoraNative.importAudio('file:///tmp/a.m4a')).rejects.toThrow('import failed');
  });

  it('withNative 経由の listAudioFiles / deleteAudioFile も throw を伝搬する', async () => {
    const nativeStub: Record<string, unknown> = {};
    useNativeStub(nativeStub);
    nativeStub.listAudioFiles = vi.fn().mockRejectedValue(new Error('store error'));
    nativeStub.deleteAudioFile = vi.fn().mockRejectedValue(new Error('delete error'));

    const MemoraNative = await newMemoraNative();
    await expect(MemoraNative.listAudioFiles()).rejects.toThrow('store error');
    await expect(MemoraNative.deleteAudioFile('file-1')).rejects.toThrow('delete error');
  });
});

describe('native モジュールがあるがメソッド未定義', () => {
  it('startRecording はサンプルセッションではなくエラーにする', async () => {
    const nativeStub: Record<string, unknown> = {};
    useNativeStub(nativeStub);
    const MemoraNative = await newMemoraNative();
    await expect(MemoraNative.startRecording()).rejects.toThrow();
  });

  it('withNative 経由の呼び出しは undefined となり従来どおりフォールバックする', async () => {
    const nativeStub: Record<string, unknown> = {};
    useNativeStub(nativeStub);
    const MemoraNative = await newMemoraNative();
    const files = await MemoraNative.listAudioFiles();
    expect(files).toEqual(audioFiles);
  });
});

describe('native 成功時は実結果を返す', () => {
  it('空配列は有効な実データとして返しモックへ置換しない', async () => {
    const nativeStub: Record<string, unknown> = {};
    useNativeStub(nativeStub);
    nativeStub.listAudioFiles = vi.fn().mockResolvedValue([]);
    const MemoraNative = await newMemoraNative();
    await expect(MemoraNative.listAudioFiles()).resolves.toEqual([]);
  });

  it('startRecording / stopRecording は native の結果をそのまま返す', async () => {
    const nativeStub: Record<string, unknown> = {};
    useNativeStub(nativeStub);
    const session = { id: 'native-session-1', startedAt: '2026-09-09T00:00:00Z', source: 'iPhone' };
    const file = { ...audioFiles[0] };
    nativeStub.startRecording = vi.fn().mockResolvedValue(session);
    nativeStub.stopRecording = vi.fn().mockResolvedValue(file);

    const MemoraNative = await newMemoraNative();
    await expect(MemoraNative.startRecording()).resolves.toBe(session);
    await expect(MemoraNative.stopRecording('native-session-1')).resolves.toBe(file);
  });
});
