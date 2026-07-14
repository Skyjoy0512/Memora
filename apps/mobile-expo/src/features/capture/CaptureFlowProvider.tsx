import { AppIcon as Ionicons } from '../../components/AppIcon';
import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import {
  ActivityIndicator,
  Alert,
  Modal,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { colors, radius } from '../../design/tokens';
import { MemoraNative } from '../../native/MemoraNative';
import type { SummaryOptionsDTO } from '../../native/MemoraNative.types';
import type { AudioFile } from '../../types/memora';

type CaptureMode = 'idle' | 'recording' | 'generate' | 'generating';
type GenerationPhase = 'analyzing' | 'transcribing' | 'summarizing' | 'completed' | 'failed';

type CaptureFlow = {
  discardRecording: () => Promise<void>;
  importAudio: (uri: string) => Promise<void>;
  isRecordingActive: boolean;
  latestFile?: AudioFile;
  mode: CaptureMode;
  openRecording: () => Promise<void>;
  pauseRecording: () => Promise<void>;
  resumeRecording: () => Promise<void>;
  stopRecording: () => Promise<void>;
};

const CaptureFlowContext = createContext<CaptureFlow | undefined>(undefined);

export function CaptureFlowProvider({ children }: { children: ReactNode }) {
  const [mode, setMode] = useState<CaptureMode>('idle');
  const [sessionId, setSessionId] = useState<string>();
  const [isPaused, setIsPaused] = useState(false);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const [highlightCount, setHighlightCount] = useState(0);
  const [latestFile, setLatestFile] = useState<AudioFile>();
  const [generationPhase, setGenerationPhase] = useState<GenerationPhase>('analyzing');
  const [generationProgress, setGenerationProgress] = useState(0);
  const [generationError, setGenerationError] = useState<string>();
  const [showCompletionSnackbar, setShowCompletionSnackbar] = useState(false);

  useEffect(() => {
    if (!sessionId || isPaused) return;
    const timer = setInterval(() => setElapsedSeconds((seconds) => seconds + 1), 1000);
    return () => clearInterval(timer);
  }, [isPaused, sessionId]);

  useEffect(() => {
    const isFinished = generationPhase === 'completed' || generationPhase === 'failed';
    if (mode !== 'idle' || !isFinished) return;
    setShowCompletionSnackbar(true);
    const timer = setTimeout(() => setShowCompletionSnackbar(false), 3000);
    return () => clearTimeout(timer);
  }, [generationPhase, mode]);

  const flow = useMemo<CaptureFlow>(() => ({
    async discardRecording() {
      if (sessionId) await MemoraNative.discardRecording(sessionId);
      setSessionId(undefined);
      setIsPaused(false);
      setElapsedSeconds(0);
      setHighlightCount(0);
      setMode('idle');
    },
    async importAudio(uri: string) {
      const file = await MemoraNative.importAudio(uri);
      setLatestFile(file);
    },
    isRecordingActive: Boolean(sessionId),
    latestFile,
    mode,
    async openRecording() {
      if (sessionId) {
        setMode('recording');
        return;
      }
      const session = await MemoraNative.startRecording();
      setSessionId(session.id);
      setIsPaused(false);
      setElapsedSeconds(0);
      setHighlightCount(0);
      setMode('recording');
    },
    async pauseRecording() {
      if (!sessionId) return;
      await MemoraNative.pauseRecording(sessionId);
      setIsPaused(true);
    },
    async resumeRecording() {
      if (!sessionId) return;
      await MemoraNative.resumeRecording(sessionId);
      setIsPaused(false);
    },
    async stopRecording() {
      if (!sessionId) return;
      const file = await MemoraNative.stopRecording(sessionId);
      setLatestFile(file);
      setSessionId(undefined);
      setIsPaused(false);
      setGenerationError(undefined);
      setGenerationPhase('analyzing');
      setGenerationProgress(0);
      setShowCompletionSnackbar(false);
      setMode('generate');
    },
  }), [latestFile, mode, sessionId]);

  function startGeneration(file: AudioFile, request: { name?: string; options: SummaryOptionsDTO }) {
    const nextName = request.name?.trim();
    if (nextName && nextName !== file.title) {
      setLatestFile({ ...file, title: nextName });
      void MemoraNative.renameAudioFile(file.id, nextName).catch(() => {});
    }
    setGenerationError(undefined);
    setGenerationPhase('analyzing');
    setGenerationProgress(0.1);
    setMode('generating');
    void runGeneration(file, request.options, setGenerationError, setGenerationPhase, setGenerationProgress);
  }

  return (
    <CaptureFlowContext.Provider value={flow}>
      {children}
      <Modal animationType="slide" onRequestClose={() => setMode('idle')} presentationStyle="fullScreen" transparent={false} visible={mode !== 'idle'}>
        {mode === 'recording' ? (
          <RecordingOverlay
            elapsedSeconds={elapsedSeconds}
            highlightCount={highlightCount}
            isPaused={isPaused}
            onDiscard={() => void flow.discardRecording()}
            onHighlight={() => setHighlightCount((count) => count + 1)}
            onMinimize={() => setMode('idle')}
            onTogglePause={() => void (isPaused ? flow.resumeRecording() : flow.pauseRecording())}
            onStop={() => void flow.stopRecording()}
          />
        ) : mode === 'generate' ? (
          <GenerateOverlay
            defaultName={latestFile?.title ?? '新しい録音'}
            onBack={() => setMode('idle')}
            onGenerate={(request) => { if (latestFile) startGeneration(latestFile, request); }}
            onSkip={(options) => { if (latestFile) startGeneration(latestFile, { options }); }}
          />
        ) : (
          <GenerationOverlay
            error={generationError}
            onClose={() => {
              setMode('idle');
              if (generationPhase === 'completed' || generationPhase === 'failed') {
                setGenerationPhase('analyzing');
                setGenerationProgress(0);
                setGenerationError(undefined);
              }
            }}
            phase={generationPhase}
            progress={generationProgress}
          />
        )}
      </Modal>
      <DynamicIslandPill
        elapsedSeconds={elapsedSeconds}
        generationLabel={generationLabel(generationPhase)}
        hasBackgroundGeneration={mode === 'idle' && generationProgress > 0 && generationPhase !== 'completed' && generationPhase !== 'failed'}
        isPaused={isPaused}
        isRecordingActive={Boolean(sessionId) && mode !== 'recording'}
        onOpenGeneration={() => setMode('generating')}
        onOpenRecording={() => setMode('recording')}
        onDismissSnackbar={() => setShowCompletionSnackbar(false)}
        snackbarError={generationPhase === 'failed'}
        showSnackbar={showCompletionSnackbar}
      />
    </CaptureFlowContext.Provider>
  );
}

export function useCaptureFlow() {
  const context = useContext(CaptureFlowContext);
  if (!context) throw new Error('useCaptureFlow must be used inside CaptureFlowProvider');
  return context;
}

async function runGeneration(
  file: AudioFile,
  options: SummaryOptionsDTO,
  setError: (message: string | undefined) => void,
  setPhase: (phase: GenerationPhase) => void,
  setProgress: (progress: number) => void,
) {
  try {
    await delay(450);
    setPhase('transcribing');
    setProgress(0.45);
    await MemoraNative.startTranscription(file.id);
    await delay(650);
    setPhase('summarizing');
    setProgress(0.8);
    await MemoraNative.generateSummary({
      audioFileId: file.id,
      options,
    });
    await delay(450);
    setPhase('completed');
    setProgress(1);
  } catch {
    setError('生成に失敗しました。ファイルは保存されています。');
    setPhase('failed');
    setProgress(0);
  }
}

function RecordingOverlay({
  elapsedSeconds,
  highlightCount,
  isPaused,
  onDiscard,
  onHighlight,
  onMinimize,
  onStop,
  onTogglePause,
}: {
  elapsedSeconds: number;
  highlightCount: number;
  isPaused: boolean;
  onDiscard: () => void;
  onHighlight: () => void;
  onMinimize: () => void;
  onStop: () => void;
  onTogglePause: () => void;
}) {
  const [showDiscardConfirm, setShowDiscardConfirm] = useState(false);
  const waveform = Array.from({ length: 18 }, (_, index) => 6 + ((elapsedSeconds * 11 + index * 17) % 55));

  return (
    <SafeAreaView style={styles.modalScreen}>
        <View style={styles.recordingHeader}>
          <RoundIcon accessibilityLabel="録音を最小化" color={colors.textSubtle} icon="chevron-down" onPress={onMinimize} />
          <RoundIcon accessibilityLabel="録音を破棄" color={colors.textSubtle} icon="close" onPress={() => setShowDiscardConfirm(true)} />
        </View>

        <View style={styles.recordingContent}>
          <Text style={styles.recordingStatus}>{isPaused ? '一時停止中' : '録音中'}</Text>
          <Text style={styles.recordingTime}>{formatElapsed(elapsedSeconds)}</Text>
          <View style={styles.waveform}>
            {waveform.map((height, index) => <View key={index} style={[styles.wave, { backgroundColor: isPaused ? '#D6D6DB' : colors.text, height }]} />)}
          </View>
          <View style={styles.transcriptPreview}>
            <Text style={styles.transcriptText}>録音を停止すると自動で文字起こしされます。</Text>
          </View>
          <View style={styles.recordingControls}>
            <RoundIcon accessibilityLabel={isPaused ? '録音を再開' : '録音を一時停止'} icon={isPaused ? 'play' : 'pause'} onPress={onTogglePause} size="medium" />
            <Pressable accessibilityLabel="録音を停止して保存" onPress={onStop} style={({ pressed }) => [styles.stopButton, pressed && styles.pressed]}>
              <View style={styles.stopSquare} />
            </Pressable>
            <Pressable accessibilityLabel="ハイライトを追加" onPress={onHighlight} style={({ pressed }) => [styles.highlightButton, pressed && styles.pressed]}>
              <Ionicons color={colors.text} name="bookmark-outline" size={19} />
              {highlightCount ? <Text style={styles.highlightCount}>{highlightCount}</Text> : null}
            </Pressable>
          </View>
        </View>

        {showDiscardConfirm ? (
          <View style={styles.confirmOverlay}>
            <View style={styles.confirmCard}>
              <Text style={styles.confirmTitle}>録音を破棄しますか？</Text>
              <Text style={styles.confirmBody}>ここまでの録音内容は保存されません。</Text>
              <View style={styles.confirmActions}>
                <Pressable onPress={() => setShowDiscardConfirm(false)} style={styles.confirmCancel}><Text style={styles.confirmCancelText}>録音を続ける</Text></Pressable>
                <Pressable onPress={() => { setShowDiscardConfirm(false); onDiscard(); }} style={styles.confirmDelete}><Text style={styles.confirmDeleteText}>破棄する</Text></Pressable>
              </View>
            </View>
          </View>
        ) : null}
    </SafeAreaView>
  );
}

const generateTemplates = [
  { id: 'meeting-notes', label: '議事録' },
  { id: 'key-points', label: '要点まとめ' },
  { id: 'action-items', label: 'アクション抽出' },
  { id: 'clean-transcript', label: 'そのまま整形' },
] as const;

function GenerateOverlay({ defaultName, onBack, onGenerate, onSkip }: { defaultName: string; onBack: () => void; onGenerate: (request: { name: string; options: SummaryOptionsDTO }) => void; onSkip: (options: SummaryOptionsDTO) => void }) {
  const [name, setName] = useState(defaultName);
  const [genMode, setGenMode] = useState<'auto' | 'custom'>('auto');
  const [templateId, setTemplateId] = useState<SummaryOptionsDTO['templateId']>(generateTemplates[0].id);
  const [model, setModel] = useState<SummaryOptionsDTO['provider']>('Gemini');

  useEffect(() => {
    let isMounted = true;
    MemoraNative.loadSettings().then((settings) => {
      if (isMounted) setModel(settings.summaryProvider);
    });
    return () => { isMounted = false; };
  }, []);

  return (
    <SafeAreaView style={styles.generateScreen}>
      <View style={styles.generateHeader}>
        <Pressable accessibilityLabel="録音に戻る" onPress={onBack} style={({ pressed }) => [styles.generateBack, pressed && styles.pressed]}><Ionicons color={colors.ink} name="chevron-back" size={19} /></Pressable>
        <Pressable accessibilityLabel="生成をスキップ" onPress={() => onSkip({ provider: model })} style={({ pressed }) => [styles.generateSkip, pressed && styles.pressed]}><Text style={styles.generateSkipText}>スキップ</Text></Pressable>
      </View>

      <TextInput accessibilityLabel="ファイル名" onChangeText={setName} style={styles.generateName} value={name} />

      <View style={styles.generateCenter}>
        <View>
          <Text style={styles.generateTitle}>文字起こしと要約</Text>
          <Text style={styles.generateDesc}>録音から要点と次のアクションを整理します。</Text>
        </View>
      </View>

      <View style={styles.generatePanel}>
        <View style={styles.generateHandle} />
        <View style={styles.generateModeRow}>
          <Pressable onPress={() => setGenMode('auto')} style={[styles.generateModeCard, genMode === 'auto' && styles.generateModeCardActive]}>
            <Text style={[styles.generateModeTitle, genMode === 'auto' && styles.generateModeTextActive]}>自動</Text>
            <Text style={[styles.generateModeDesc, genMode === 'auto' && styles.generateModeTextActive]}>内容に合わせて整理</Text>
          </Pressable>
          <Pressable onPress={() => setGenMode('custom')} style={[styles.generateModeCard, genMode === 'custom' && styles.generateModeCardActive]}>
            <Text style={[styles.generateModeTitle, genMode === 'custom' && styles.generateModeTextActive]}>テンプレート</Text>
            <Text style={[styles.generateModeDesc, genMode === 'custom' && styles.generateModeTextActive]}>形式を選んで整理</Text>
          </Pressable>
        </View>

        {genMode === 'custom' ? (
          <View style={styles.generateTemplateRow}>
            {generateTemplates.map((item) => (
              <Pressable key={item.id} onPress={() => setTemplateId(item.id)} style={[styles.generateChip, templateId === item.id && styles.generateChipActive]}>
                <Text style={[styles.generateChipText, templateId === item.id && styles.generateModeTextActive]}>{item.label}</Text>
              </Pressable>
            ))}
          </View>
        ) : null}

        <Pressable onPress={() => Alert.alert('要約モデル', '設定画面で選択したモデルを使用します。')} style={styles.generateModelRow}>
          <Text style={styles.generateModelLabel}>要約モデル</Text>
          <View style={styles.generateModelValueWrap}>
            <Text style={styles.generateModelValue}>{model}</Text>
            <Ionicons color={colors.neutralBorder} name="chevron-forward" size={12} />
          </View>
        </Pressable>

        <Pressable accessibilityLabel="処理を開始" onPress={() => onGenerate({ name, options: { provider: model, ...(genMode === 'custom' ? { templateId } : {}) } })} style={({ pressed }) => [styles.generateButton, pressed && styles.pressed]}>
          <Text style={styles.generateButtonText}>処理を開始</Text>
        </Pressable>
      </View>
    </SafeAreaView>
  );
}

function GenerationOverlay({ error, onClose, phase, progress }: { error?: string; onClose: () => void; phase: GenerationPhase; progress: number }) {
  const isComplete = phase === 'completed' || phase === 'failed';

  return (
    <SafeAreaView style={styles.generationScreen}>
        <View style={styles.generationContent}>
          {isComplete ? <Ionicons color={phase === 'completed' ? colors.success : colors.danger} name={phase === 'completed' ? 'checkmark-circle' : 'alert-circle'} size={52} /> : <ActivityIndicator color={colors.text} size="large" />}
          <Text style={styles.generationLabel}>{generationLabel(phase)}</Text>
          <View style={styles.progressTrack}><View style={[styles.progressFill, { width: `${progress * 100}%` }]} /></View>
          <Text style={styles.generationDescription}>{error ?? 'この処理はバックグラウンドで継続されます。ホームに戻っても続行できます。'}</Text>
          {!isComplete ? <Pressable onPress={onClose} style={({ pressed }) => [styles.backgroundButton, pressed && styles.pressed]}><Text style={styles.backgroundButtonText}>バックグラウンドで続行</Text></Pressable> : null}
        </View>
        <Pressable onPress={onClose} style={({ pressed }) => [styles.skipButton, pressed && styles.pressed]}><Text style={styles.skipButtonText}>{isComplete ? '閉じる' : 'スキップして開く'}</Text></Pressable>
    </SafeAreaView>
  );
}

function DynamicIslandPill({
  elapsedSeconds,
  generationLabel: label,
  hasBackgroundGeneration,
  isPaused,
  isRecordingActive,
  onDismissSnackbar,
  onOpenGeneration,
  onOpenRecording,
  showSnackbar,
  snackbarError,
}: {
  elapsedSeconds: number;
  generationLabel: string;
  hasBackgroundGeneration: boolean;
  isPaused: boolean;
  isRecordingActive: boolean;
  onDismissSnackbar: () => void;
  onOpenGeneration: () => void;
  onOpenRecording: () => void;
  showSnackbar: boolean;
  snackbarError: boolean;
}) {
  if (showSnackbar) {
    return (
      <Pressable accessibilityLabel="生成完了通知を閉じる" onPress={onDismissSnackbar} style={[styles.island, styles.islandSnackbar]}>
        <Ionicons color={snackbarError ? colors.accent : colors.success} name={snackbarError ? 'alert-circle' : 'checkmark-circle'} size={18} />
        <Text numberOfLines={1} style={styles.islandSnackbarText}>{snackbarError ? '生成に失敗しました' : '要約が完成しました'}</Text>
      </Pressable>
    );
  }

  if (isRecordingActive) {
    return (
      <Pressable accessibilityLabel="録音を開く" onPress={onOpenRecording} style={[styles.island, styles.islandRecording]}>
        <View style={[styles.islandDot, isPaused && styles.islandDotPaused]} />
        <Text style={styles.islandTimer}>{formatElapsed(elapsedSeconds)}</Text>
        <View style={styles.islandWaveform}>{[8, 13, 10, 14, 9].map((height, index) => <View key={index} style={[styles.islandWave, { height }]} />)}</View>
      </Pressable>
    );
  }

  if (hasBackgroundGeneration) {
    return (
      <Pressable accessibilityLabel="生成進捗を開く" onPress={onOpenGeneration} style={[styles.island, styles.islandGeneration]}>
        <ActivityIndicator color="#FFFFFF" size="small" />
        <Text numberOfLines={1} style={styles.islandGenerationText}>{label}</Text>
      </Pressable>
    );
  }

  return null;
}

function RoundIcon({ accessibilityLabel, color = colors.text, icon, onPress, size = 'small' }: { accessibilityLabel: string; color?: string; icon: 'chevron-down' | 'close' | 'pause' | 'play'; onPress: () => void; size?: 'small' | 'medium' }) {
  const dimension = size === 'medium' ? 52 : 40;
  return <Pressable accessibilityLabel={accessibilityLabel} onPress={onPress} style={({ pressed }) => [styles.roundIcon, { height: dimension, width: dimension }, pressed && styles.pressed]}><Ionicons color={color} name={icon} size={size === 'medium' ? 18 : 16} /></Pressable>;
}

function delay(milliseconds: number) {
  return new Promise<void>((resolve) => setTimeout(resolve, milliseconds));
}

function formatElapsed(seconds: number) {
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;
}

function generationLabel(phase: GenerationPhase) {
  const labels: Record<GenerationPhase, string> = {
    analyzing: '音声を解析中…',
    completed: '完了しました',
    failed: '生成に失敗しました',
    summarizing: '要約を作成中…',
    transcribing: '文字起こしを生成中…',
  };
  return labels[phase];
}

const styles = StyleSheet.create({
  backgroundButton: { backgroundColor: colors.soft, borderRadius: radius.md, paddingHorizontal: 18, paddingVertical: 10 },
  backgroundButtonText: { color: colors.text, fontSize: 13, fontWeight: '600' },
  confirmActions: { flexDirection: 'row', gap: 8, marginTop: 16 },
  confirmBody: { color: colors.textSubtle, fontSize: 12.5, lineHeight: 18, textAlign: 'center' },
  confirmCancel: { alignItems: 'center', backgroundColor: colors.surfaceAlt, borderRadius: radius.md, flex: 1, height: 44, justifyContent: 'center' },
  confirmCancelText: { color: colors.text, fontSize: 14, fontWeight: '600' },
  confirmCard: { backgroundColor: '#FFFFFF', borderRadius: radius.cardAlt, marginHorizontal: 40, padding: 20 },
  confirmDelete: { alignItems: 'center', backgroundColor: colors.danger, borderRadius: radius.md, flex: 1, height: 44, justifyContent: 'center' },
  confirmDeleteText: { color: '#FFFFFF', fontSize: 14, fontWeight: '600' },
  confirmOverlay: { alignItems: 'center', backgroundColor: 'rgba(0,0,0,0.5)', bottom: 0, justifyContent: 'center', left: 0, position: 'absolute', right: 0, top: 0 },
  confirmTitle: { color: colors.text, fontSize: 16, fontWeight: '700', marginBottom: 6, textAlign: 'center' },
  generateBack: { alignItems: 'center', height: 40, justifyContent: 'center', width: 40 },
  generateButton: { alignItems: 'center', backgroundColor: colors.ink, borderRadius: 16, paddingVertical: 16 },
  generateButtonText: { color: colors.surface, fontSize: 16, fontWeight: '600' },
  generateCenter: { alignItems: 'center', flex: 1, gap: 26, justifyContent: 'center', paddingHorizontal: 30 },
  generateChip: { backgroundColor: colors.faint, borderRadius: 12, paddingHorizontal: 14, paddingVertical: 8 },
  generateChipActive: { backgroundColor: colors.ink },
  generateChipText: { color: colors.ink, fontSize: 12.5, fontWeight: '600' },
  generateDesc: { color: colors.textMutedLight, fontSize: 13, lineHeight: 22, textAlign: 'center' },
  generateHandle: { alignSelf: 'center', backgroundColor: '#D9D9D9', borderRadius: 2, height: 4, marginBottom: 16, width: 36 },
  generateHeader: { alignItems: 'center', flexDirection: 'row', justifyContent: 'space-between', paddingHorizontal: 14, paddingTop: 10 },
  generateIconCircle: { alignItems: 'center', backgroundColor: colors.faint, borderRadius: 28, height: 56, justifyContent: 'center', width: 56 },
  generateIconRow: { alignItems: 'center', flexDirection: 'row', gap: 18 },
  generateModeCard: { backgroundColor: colors.faint, borderRadius: 14, flex: 1, padding: 12 },
  generateModeCardActive: { backgroundColor: colors.ink },
  generateModeDesc: { color: colors.textMutedLight, fontSize: 11, lineHeight: 15, marginTop: 2 },
  generateModeRow: { flexDirection: 'row', gap: 8, marginBottom: 14 },
  generateModeTextActive: { color: colors.surface },
  generateModeTitle: { color: colors.ink, fontSize: 13.5, fontWeight: '600', marginBottom: 2 },
  generateModelLabel: { color: colors.ink, fontSize: 14.5, fontWeight: '500' },
  generateModelRow: { alignItems: 'center', flexDirection: 'row', justifyContent: 'space-between', paddingBottom: 16, paddingHorizontal: 2, paddingTop: 6 },
  generateModelValue: { color: colors.textMutedLight, fontSize: 14 },
  generateModelValueWrap: { alignItems: 'center', flexDirection: 'row', gap: 5 },
  generateName: { color: colors.ink, fontSize: 21, fontWeight: '700', paddingBottom: 18, paddingHorizontal: 18, paddingTop: 2 },
  generatePanel: { borderTopColor: '#F2F2F2', borderTopWidth: 1, paddingBottom: 26, paddingHorizontal: 18, paddingTop: 14 },
  generateScreen: { backgroundColor: '#FFFFFF', flex: 1 },
  generateSkip: { backgroundColor: colors.soft, borderRadius: 12, paddingHorizontal: 12, paddingVertical: 8 },
  generateSkipText: { color: colors.textSubtle, fontSize: 13, fontWeight: '600' },
  generateTemplateRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 6, marginBottom: 14 },
  generateTitle: { color: colors.ink, fontSize: 19, fontWeight: '700', marginBottom: 8, textAlign: 'center' },
  generationContent: { alignItems: 'center', flex: 1, justifyContent: 'center', paddingHorizontal: 40 },
  generationDescription: { color: colors.textSubtle, fontSize: 12.5, lineHeight: 18, marginBottom: 20, maxWidth: 260, textAlign: 'center' },
  generationLabel: { color: colors.text, fontSize: 17, fontWeight: '700', marginBottom: 22, marginTop: 22 },
  generationScreen: { backgroundColor: '#FFFFFF', flex: 1 },
  highlightButton: { alignItems: 'center', backgroundColor: colors.soft, borderRadius: 26, height: 52, justifyContent: 'center', width: 52 },
  highlightCount: { backgroundColor: colors.text, borderRadius: 8, color: '#FFFFFF', fontSize: 9, fontWeight: '700', minWidth: 16, overflow: 'hidden', paddingHorizontal: 3, position: 'absolute', right: -2, textAlign: 'center', top: -2 },
  island: { alignItems: 'center', backgroundColor: colors.ink, borderRadius: 20, flexDirection: 'row', justifyContent: 'center', position: 'absolute', shadowColor: '#000000', shadowOffset: { height: 8, width: 0 }, shadowOpacity: 0.28, shadowRadius: 12, top: 11, zIndex: 50 },
  islandDot: { backgroundColor: colors.accent, borderRadius: 4, height: 7, width: 7 },
  islandDotPaused: { backgroundColor: colors.textMutedLight },
  islandGeneration: { gap: 8, height: 36, paddingHorizontal: 14, width: 198 },
  islandGenerationText: { color: '#FFFFFF', flex: 1, fontSize: 12, fontWeight: '500' },
  islandRecording: { gap: 8, height: 36, paddingHorizontal: 14, width: 156 },
  islandSnackbar: { gap: 10, height: 54, justifyContent: 'flex-start', paddingHorizontal: 16, width: 304 },
  islandSnackbarText: { color: '#FFFFFF', flex: 1, fontSize: 13, fontWeight: '500' },
  islandTimer: { color: '#FFFFFF', fontFamily: 'Menlo', fontSize: 12, fontWeight: '500' },
  islandWave: { backgroundColor: '#FFFFFF', borderRadius: 1, width: 2 },
  islandWaveform: { alignItems: 'center', flex: 1, flexDirection: 'row', gap: 2, justifyContent: 'center' },
  modalScreen: { backgroundColor: '#FFFFFF', flex: 1 },
  pressed: { opacity: 0.78, transform: [{ scale: 0.93 }] },
  progressFill: { backgroundColor: colors.text, borderRadius: 2, height: 4 },
  progressTrack: { backgroundColor: colors.border, borderRadius: 2, height: 4, marginBottom: 18, width: 220 },
  recordingContent: { alignItems: 'center', flex: 1, paddingHorizontal: 24, paddingTop: 58 },
  recordingControls: { alignItems: 'center', flexDirection: 'row', gap: 28, marginTop: 28 },
  recordingHeader: { flexDirection: 'row', justifyContent: 'space-between', paddingHorizontal: 18, paddingTop: 18 },
  recordingStatus: { color: colors.quiet, fontSize: 14, fontWeight: '500', marginBottom: 8 },
  recordingTime: { color: colors.text, fontFamily: 'Menlo', fontSize: 44, fontWeight: '600', letterSpacing: -0.44, marginBottom: 36 },
  roundIcon: { alignItems: 'center', backgroundColor: colors.soft, borderRadius: 26, justifyContent: 'center' },
  skipButton: { alignItems: 'center', paddingBottom: 20 },
  skipButtonText: { color: colors.quiet, fontSize: 13, fontWeight: '500' },
  stopButton: { alignItems: 'center', backgroundColor: colors.text, borderRadius: 36, height: 72, justifyContent: 'center', width: 72 },
  stopSquare: { backgroundColor: '#FFFFFF', borderRadius: 6, height: 26, width: 26 },
  transcriptPreview: { alignSelf: 'stretch', borderTopColor: colors.paleLine, borderTopWidth: 1, minHeight: 96, paddingTop: 14 },
  transcriptText: { color: colors.textSubtle, fontSize: 13.5, lineHeight: 24 },
  wave: { borderRadius: 2, width: 4 },
  waveform: { alignItems: 'flex-end', flexDirection: 'row', gap: 4, height: 60, marginBottom: 40 },
});
