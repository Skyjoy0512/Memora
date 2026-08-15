import { AppIcon as Ionicons } from '../components/AppIcon';
import * as ImagePicker from 'expo-image-picker';
import { Fragment, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useRouter } from 'expo-router';
import { Image } from 'expo-image';
import { ActivityIndicator, Alert, Animated, KeyboardAvoidingView, Platform, Pressable, ScrollView, Share, StyleSheet, Text, TextInput, useWindowDimensions, View } from 'react-native';
import { Button } from 'heroui-native/button';
import { Dialog } from 'heroui-native/dialog';
import { Input } from 'heroui-native/input';
import { Label } from 'heroui-native/label';
import { Description } from 'heroui-native/description';
import { Radio } from 'heroui-native/radio';
import { Separator } from 'heroui-native/separator';
import { TextArea } from 'heroui-native/text-area';
import { Tabs } from 'heroui-native/tabs';
import { RadioGroup } from 'heroui-native/radio-group';
import { PlayerBar } from '../components/PlayerBar';
import { FloatingBottomSheet } from '../components/FloatingBottomSheet';
import { OfflineBanner } from '../components/OfflineBanner';
import { Screen } from '../components/Screen';
import { Section } from '../components/Section';
import { SegmentedControl } from '../components/SegmentedControl';
import { EmptyState, ErrorState, LoadingState } from '../components/StateViews';
import { StatusPill } from '../components/StatusPill';
import { formatRecordedAt } from '../utils/formatRecordedAt';
import { TranscriptionProgressCard } from '../components/TranscriptionProgressCard';
import { FileDetailGeneratingSkeleton } from '../components/FileDetailGeneratingSkeleton';
import { colors, radius, spacing, textStyles } from '../design/tokens';
import { useAudioFile } from '../features/files/useAudioFiles';
import { useMemoNotes } from '../features/memo/useMemoNotes';
import { usePlayback } from '../features/playback/usePlayback';
import { useTranscriptionTask } from '../features/transcription/useTranscriptionTask';
import { MemoraNative } from '../native/MemoraNative';
import { buildExportPayload, NOTION_SETUP_LABELS, resolveNotionSetupState, type NotionSetupState } from '../native/exportLogic';
import { buildTaskFromTranscriptSegment } from '../native/taskLogic';
import type { ProjectDTO, SummaryOptionsDTO } from '../native/MemoraNative.types';
import type { AudioFile } from '../types/memora';

type Tab = 'summary' | 'transcript' | 'memo';

const TAB_LABEL: Record<Tab, string> = {
  summary: '概要',
  transcript: '文字起こし',
  memo: 'メモ',
};
type MoreSheetAction = 'rename' | 'move' | 'delete';
type ExportSheetAction = 'notion' | 'chatgpt' | 'share';
type GenerateSheetView = 'main' | 'template' | 'model' | null;

const GENERATE_TEMPLATES = [
  { id: 'meeting-notes', label: '議事録', description: '決定事項と次のアクションを中心に整理します。' },
  { id: 'detailed-notes', label: '詳細な議事録', description: '発言の要旨を話者ごとに詳しく残します。' },
  { id: 'key-points', label: '要点まとめ', description: '重要なポイントだけを簡潔に抽出します。' },
  { id: 'action-items', label: 'アクション抽出', description: 'タスク化できる項目だけを一覧にします。' },
] as const;

const SUMMARY_PROVIDER_LABELS: Record<SummaryOptionsDTO['provider'], string> = {
  OpenAI: 'OpenAI',
  Gemini: 'Gemini',
  DeepSeek: 'DeepSeek',
  Local: 'On-device',
};

type AskModel = 'auto' | SummaryOptionsDTO['provider'];

const ASK_MODEL_LABELS: Record<AskModel, string> = {
  auto: 'Auto',
  OpenAI: 'OpenAI',
  Gemini: 'Gemini',
  DeepSeek: 'DeepSeek',
  Local: 'On-device',
};

export function FileDetailScreen({ fileId }: { fileId?: string }) {
  const router = useRouter();
  const [tab, setTab] = useState<Tab>('summary');
  const { data: file, error, isLoading, setAudioFile } = useAudioFile(fileId);
  const [draftTitle, setDraftTitle] = useState('');
  const [renameError, setRenameError] = useState<string | null>(null);
  const [isEditingTitle, setIsEditingTitle] = useState(false);
  const [isSavingTitle, setIsSavingTitle] = useState(false);
  const [isGeneratingSummary, setIsGeneratingSummary] = useState(false);
  const [summaryError, setSummaryError] = useState<string | null>(null);
  const [summaryProvider, setSummaryProvider] = useState<SummaryOptionsDTO['provider']>('Gemini');
  const [summaryMetadata, setSummaryMetadata] = useState<{
    generatedAt: string;
    provider: SummaryOptionsDTO['provider'];
  } | null>(null);
  const refreshTranscribedFile = useCallback(async (completedFileId: string) => {
    const updatedFile = await MemoraNative.getAudioFile(completedFileId);
    if (updatedFile) {
      setAudioFile(updatedFile);
    }
  }, [setAudioFile]);
  const transcription = useTranscriptionTask(fileId ?? '', refreshTranscribedFile);
  const transcriptCount = useMemo(() => file?.transcript.length ?? 0, [file]);
  const [showCleanedTranscript, setShowCleanedTranscript] = useState(true);
  const canRenameFile = file ? isRenameableBridgeFile(file) : false;
  const playback = usePlayback(fileId);
  const memoNotes = useMemoNotes(fileId);
  const [memoDraftText, setMemoDraftText] = useState('');
  const [isEditingMemo, setIsEditingMemo] = useState(false);
  const [isAttachingPhoto, setIsAttachingPhoto] = useState(false);
  const [isMoreOpen, setIsMoreOpen] = useState(false);
  const [isExportOpen, setIsExportOpen] = useState(false);
  const [isDeleteOpen, setIsDeleteOpen] = useState(false);
  const [isProjectMoveOpen, setIsProjectMoveOpen] = useState(false);
  const [isProjectMoveLoading, setIsProjectMoveLoading] = useState(false);
  const [projects, setProjects] = useState<ProjectDTO[]>([]);
  const [generateSheetView, setGenerateSheetView] = useState<GenerateSheetView>(null);
  const [notionSetup, setNotionSetup] = useState<NotionSetupState>('not-configured');
  const [fileAskDraft, setFileAskDraft] = useState('');
  const [fileAskModel, setFileAskModel] = useState<AskModel>('auto');
  const [isFileAskModelSheetOpen, setIsFileAskModelSheetOpen] = useState(false);
  const [generateTemplateId, setGenerateTemplateId] = useState<(typeof GENERATE_TEMPLATES)[number]['id']>(GENERATE_TEMPLATES[0].id);
  const pendingMoreActionRef = useRef<MoreSheetAction | null>(null);
  const pendingExportActionRef = useRef<ExportSheetAction | null>(null);
  const tabOpacity = useRef(new Animated.Value(1)).current;
  const transcriptScrollRef = useRef<ScrollView>(null);
  const transcriptRowOffsetsRef = useRef<Record<string, number>>({});
  const transcriptAutoScrollTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const [isTranscriptAutoScrollPaused, setIsTranscriptAutoScrollPaused] = useState(false);
  const { height: windowHeight } = useWindowDimensions();
  const transcriptMaxHeight = Math.max(spacing.xxl * 4, Math.round(windowHeight * 0.52));
  const activeTranscriptSegmentId = useMemo(
    () => activeTranscriptSegmentIdForPosition(file?.transcript ?? [], playback.status?.position),
    [file?.transcript, playback.status?.position],
  );

  const resumeTranscriptAutoScrollAfterDelay = useCallback(() => {
    if (transcriptAutoScrollTimerRef.current) {
      clearTimeout(transcriptAutoScrollTimerRef.current);
    }
    setIsTranscriptAutoScrollPaused(true);
    transcriptAutoScrollTimerRef.current = setTimeout(() => {
      setIsTranscriptAutoScrollPaused(false);
      transcriptAutoScrollTimerRef.current = null;
    }, 3_000);
  }, []);

  const scrollTranscriptToSegment = useCallback((segmentId: string) => {
    const offset = transcriptRowOffsetsRef.current[segmentId];
    if (offset === undefined) return;
    transcriptScrollRef.current?.scrollTo({ animated: true, y: Math.max(0, offset - spacing.md) });
  }, []);

  useEffect(() => {
    if (tab !== 'transcript' || isTranscriptAutoScrollPaused || !activeTranscriptSegmentId) return;
    const frame = requestAnimationFrame(() => scrollTranscriptToSegment(activeTranscriptSegmentId));
    return () => cancelAnimationFrame(frame);
  }, [activeTranscriptSegmentId, isTranscriptAutoScrollPaused, scrollTranscriptToSegment, tab]);

  useEffect(() => () => {
    if (transcriptAutoScrollTimerRef.current) {
      clearTimeout(transcriptAutoScrollTimerRef.current);
    }
  }, []);

  useEffect(() => {
    tabOpacity.setValue(0);
    Animated.timing(tabOpacity, { toValue: 1, duration: 180, useNativeDriver: true }).start();
  }, [tab, tabOpacity]);

  useEffect(() => {
    setMemoDraftText(memoNotes.draft);
  }, [memoNotes.draft]);

  async function handleAttachPhoto() {
    setIsAttachingPhoto(true);
    try {
      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ['images'],
        quality: 0.8,
      });
      if (!result.canceled && result.assets[0]) {
        await memoNotes.addPhoto(result.assets[0].uri);
      }
    } finally {
      setIsAttachingPhoto(false);
    }
  }

  useEffect(() => {
    if (file) {
      setDraftTitle(file.title);
    }
  }, [file]);

  useEffect(() => {
    let isMounted = true;

    MemoraNative.loadSettings()
      .then((settings) => {
        if (isMounted) {
          setSummaryProvider(settings.summaryProvider);
        }
      })
      .catch(() => {
        // Keep the safe Gemini default when settings are unavailable.
      });

    return () => {
      isMounted = false;
    };
  }, []);

  useEffect(() => {
    let isMounted = true;

    Promise.all([MemoraNative.getSecureCredentialStatus('Notion'), MemoraNative.loadSettings()])
      .then(([isTokenConfigured, nextSettings]) => {
        if (isMounted) {
          setNotionSetup(
            resolveNotionSetupState(isTokenConfigured, Boolean(nextSettings.notionParentPage.trim())),
          );
        }
      })
      .catch(() => {
        // Keep the default（未設定）when the bridge is unavailable.
      });

    return () => {
      isMounted = false;
    };
  }, []);

  const handleRename = async () => {
    if (!file) {
      return;
    }

    const trimmedTitle = draftTitle.trim();
    if (!trimmedTitle) {
      setRenameError('タイトルを入力してください。');
      return;
    }

    setIsSavingTitle(true);
    setRenameError(null);

    try {
      const renamedFile = await MemoraNative.renameAudioFile(file.id, trimmedTitle);
      if (!renamedFile) {
        setRenameError('このファイルはまだリネーム対象ではありません。');
        return;
      }

      setAudioFile(renamedFile);
      setIsEditingTitle(false);
    } catch (error: unknown) {
      setRenameError(error instanceof Error ? error.message : 'タイトル変更に失敗しました。');
    } finally {
      setIsSavingTitle(false);
    }
  };

  const handleGenerateSummary = async (overrides?: Partial<SummaryOptionsDTO>) => {
    if (!file || isGeneratingSummary) {
      return;
    }

    setIsGeneratingSummary(true);
    setSummaryError(null);

    try {
      const summary = await MemoraNative.generateSummary({
        audioFileId: file.id,
        options: { provider: summaryProvider, ...overrides },
      });
      setAudioFile({ ...file, status: 'summarized', summary: summary.text });
      setSummaryMetadata({ generatedAt: summary.generatedAt, provider: summary.provider });
    } catch (error: unknown) {
      setSummaryError(error instanceof Error ? error.message : '要約の生成に失敗しました。');
    } finally {
      setIsGeneratingSummary(false);
    }
  };

  async function handleShare() {
    if (!file) return;
    const transcriptText = file.transcript.map((segment) => `${segment.time} ${segment.text}`).join('\n');
    await Share.share({
      message: `${file.title}\n\n${file.summary}\n\n${transcriptText}`,
      title: file.title,
    });
  }

  function handleMore() {
    setIsMoreOpen(true);
  }

  function closeMoreThen(action: MoreSheetAction) {
    pendingMoreActionRef.current = action;
    setIsMoreOpen(false);
  }

  function handleMoreDismiss() {
    setIsMoreOpen(false);
    const action = pendingMoreActionRef.current;
    pendingMoreActionRef.current = null;

    if (action === 'rename') {
      if (!file) return;
      if (canRenameFile) {
        setDraftTitle(file.title);
        setIsEditingTitle(true);
      } else {
        Alert.alert('タイトルを変更', 'このファイルはまだタイトル変更の対象ではありません。');
      }
    } else if (action === 'move') {
      void openProjectMoveSheet();
    } else if (action === 'delete') {
      setIsDeleteOpen(true);
    }
  }

  async function openProjectMoveSheet() {
    setIsProjectMoveOpen(true);
    setIsProjectMoveLoading(true);
    try {
      setProjects(await MemoraNative.listProjects());
    } catch {
      setProjects([]);
    } finally {
      setIsProjectMoveLoading(false);
    }
  }

  async function handleMoveToProject(projectId: string | null) {
    if (!file) return;
    setIsProjectMoveOpen(false);
    try {
      const updated = await MemoraNative.moveAudioFile(file.id, projectId);
      if (!updated) {
        Alert.alert('移動できません', 'このファイルはまだ移動の対象ではありません。');
        return;
      }
      setAudioFile(updated);
      Alert.alert(
        '移動しました',
        projectId ? 'この録音をプロジェクトに移動しました。' : 'この録音をInbox（個人）に移動しました。',
      );
    } catch (error: unknown) {
      Alert.alert(
        '移動できません',
        error instanceof Error ? error.message : 'プロジェクトへの移動に失敗しました。',
      );
    }
  }

  async function handleTaskizeSegment(segment: AudioFile['transcript'][number]) {
    if (!file) return;
    try {
      const task = buildTaskFromTranscriptSegment(segment, { audioFileId: file.id });
      const created = await MemoraNative.createTask(task);
      if (!created) {
        Alert.alert('タスクを追加できません', 'タスクの保存に失敗しました。');
        return;
      }
      Alert.alert('タスクに追加しました', undefined, [
        { text: 'キャンセル', style: 'cancel' },
        { text: 'タスク一覧を開く', onPress: () => router.push('/tasks') },
      ]);
    } catch (error: unknown) {
      Alert.alert(
        'タスクを追加できません',
        error instanceof Error ? error.message : 'タスクの保存に失敗しました。',
      );
    }
  }

  function closeExportThen(action: ExportSheetAction) {
    pendingExportActionRef.current = action;
    setIsExportOpen(false);
  }

  function handleExportDismiss() {
    setIsExportOpen(false);
    const action = pendingExportActionRef.current;
    pendingExportActionRef.current = null;

    if (action === 'notion') {
      void runNotionExport();
    } else if (action === 'chatgpt') {
      void runChatGptExport();
    } else if (action === 'share') {
      void handleShare();
    }
  }

  async function runNotionExport() {
    if (!file) return;
    if (notionSetup !== 'ready') {
      Alert.alert('Notion に転記', 'Notionの連携が未設定です。設定画面からトークンと親ページを設定してください。', [
        { text: 'キャンセル', style: 'cancel' },
        { text: '設定を開く', onPress: () => router.push('/settings') },
      ]);
      return;
    }

    try {
      const result = await MemoraNative.exportToDestination(buildExportPayload(file, 'notion'));
      if (result.ok) {
        Alert.alert('転記しました', 'Notion に子ページを作成しました。');
      } else {
        Alert.alert('転記できません', result.error ?? 'Notionへの転記に失敗しました。');
      }
    } catch (error: unknown) {
      Alert.alert(
        '転記できません',
        error instanceof Error ? error.message : 'Notionへの転記に失敗しました。',
      );
    }
  }

  async function runChatGptExport() {
    if (!file) return;

    try {
      const result = await MemoraNative.exportToDestination(buildExportPayload(file, 'chatgpt'));
      if (result.ok) {
        Alert.alert(
          '共有シートを開きました',
          '要約と文字起こしをクリップボードにコピー済みです。共有シートから ChatGPT などを選択してください。',
        );
      } else {
        Alert.alert('共有できません', result.error ?? '共有に失敗しました。');
      }
    } catch (error: unknown) {
      Alert.alert(
        '共有できません',
        error instanceof Error ? error.message : '共有に失敗しました。',
      );
    }
  }

  function handleFileAskSubmit() {
    if (!fileAskDraft.trim()) return;
    setFileAskDraft('');
    router.push('/ask-ai');
  }

  function handleGenerateSheetDismiss() {
    setGenerateSheetView(null);
  }

  function handleAutoGenerate() {
    setGenerateSheetView(null);
    void handleGenerateSummary({ provider: summaryProvider });
  }

  function handleCustomGenerate() {
    setGenerateSheetView(null);
    void handleGenerateSummary({ provider: summaryProvider, templateId: generateTemplateId });
  }

  async function handleDelete() {
    if (!file) return;
    setIsDeleteOpen(false);
    const didDelete = await MemoraNative.deleteAudioFile(file.id);
    if (didDelete) router.back();
    else Alert.alert('削除できません', 'このファイルはまだ削除対象ではありません。');
  }

  if (isLoading) {
    return (
      <Screen title="ファイル詳細" subtitle="Native bridge facade から読み込みます。">
        <LoadingState label="詳細を読み込み中" />
      </Screen>
    );
  }

  if (error) {
    return (
      <Screen title="ファイル詳細" subtitle="Native bridge facade でエラーが発生しました。">
        <ErrorState message={error} />
      </Screen>
    );
  }

  if (!file) {
    return (
      <Screen title="ファイル詳細" subtitle="指定されたファイルが見つかりません。">
        <EmptyState title="ファイルがありません" body="一覧から別のファイルを選んでください。" />
      </Screen>
    );
  }

  return (
    <Screen
      topRow={<View style={styles.detailTopRow}><Button variant="ghost" isIconOnly background={null} onPress={() => router.back()} accessibilityLabel="ファイル一覧に戻る"><Ionicons color={colors.text} name="chevron-back" size={19} /></Button><View style={styles.headerActions}><Button variant="ghost" isIconOnly background={null} onPress={() => setIsExportOpen(true)} accessibilityLabel="ファイルを共有"><Ionicons color={colors.text} name="share-outline" size={18} /></Button><Button variant="ghost" isIconOnly background={null} onPress={handleMore} accessibilityLabel="その他の操作"><Ionicons color={colors.text} name="ellipsis-horizontal" size={19} /></Button></View></View>}
      footerAccessory={
        <>
          {playback.status ? (
            <View style={styles.playerFooter}>
              <PlayerBar
                onCycleRate={() => void playback.cycleRate()}
                onSeek={(position) => void playback.seek(position)}
                onTogglePlay={() =>
                  void (playback.status?.isPlaying ? playback.pause() : playback.play())
                }
                status={playback.status}
              />
            </View>
          ) : null}
          <View style={styles.fileAskDock}>
            <Pressable
              accessibilityLabel="プロジェクトを選択"
              accessibilityRole="button"
              onPress={() => Alert.alert('プロジェクトを選択', 'この操作は現在利用できません。')}
              style={styles.fileAskProjectRow}
            >
              <Ionicons color={colors.textTertiary} name="folder" size={14} />
              <Text style={styles.fileAskProjectRowText}>プロジェクトを選択</Text>
            </Pressable>
            <View style={styles.fileAskBox}>
              <TextArea
                variant="secondary"
                placeholder="この記録について質問する"
                value={fileAskDraft}
                onChangeText={setFileAskDraft}
                onSubmitEditing={handleFileAskSubmit}
                accessibilityLabel="この記録について質問する"
                style={{ height: 72 }}
                containerClassName="w-full"
              />
              <View style={styles.fileAskBoxRow}>
                <Button variant="ghost" isIconOnly background={null} onPress={() => Alert.alert('添付', 'この操作は現在利用できません。')} accessibilityLabel="ファイルを添付">
                  <Ionicons color={colors.textTertiary} name="attach-outline" size={18} />
                </Button>
                <Button variant="ghost" size="md" background={null} onPress={() => setIsFileAskModelSheetOpen(true)} accessibilityLabel="AIモデルを選択">
                  <Button.Label>{ASK_MODEL_LABELS[fileAskModel]}</Button.Label>
                  <Ionicons color={colors.textSecondary} name="chevron-down" size={12} />
                </Button>
                <View style={styles.fileAskSpacer} />
                <Button variant="primary" isIconOnly isDisabled={!fileAskDraft.trim()} onPress={handleFileAskSubmit} accessibilityLabel="この記録について聞く">
                  <Ionicons color={colors.surface} name="arrow-forward" size={16} />
                </Button>
              </View>
            </View>
          </View>
        </>
      }
      titleContent={
        <View style={styles.detailHeader}>
          <Text numberOfLines={1} style={styles.detailTitle}>{file.title}</Text>
          <View style={styles.detailMetaRow}>
<Text style={styles.detailMeta}>{`${formatRecordedAt(file.recordedAt)} · ${file.duration}`}</Text>
            <StatusPill status={file.status} />
          </View>
        </View>
      }
    >
      <Tabs variant="secondary" value={tab} onValueChange={(value) => setTab(value as Tab)}>
        <Tabs.List>
          <Tabs.Indicator />
          <Tabs.Trigger value="summary"><Tabs.Label>{TAB_LABEL.summary}</Tabs.Label></Tabs.Trigger>
          <Tabs.Trigger value="transcript"><Tabs.Label>{TAB_LABEL.transcript}</Tabs.Label></Tabs.Trigger>
          <Tabs.Trigger value="memo"><Tabs.Label>{TAB_LABEL.memo}</Tabs.Label></Tabs.Trigger>
        </Tabs.List>

      <Animated.View style={{ opacity: tabOpacity }}>
      {tab === 'summary' ? (
        <View style={styles.summaryTab}>
          {!isGeneratingSummary && file.status !== 'queued' ? (
            <Text style={styles.summaryMeta}>{file.duration} ・ 話者{new Set(file.transcript.map((segment) => segment.speaker).filter(Boolean)).size}名 ・ タスク{file.memo.length}件</Text>
          ) : null}
          {!isGeneratingSummary && file.transcript.length ? <View style={styles.summarySection}><Text style={styles.summarySectionTitle}>チャプター</Text><View>{file.transcript.slice(0, 4).map((segment) => <Pressable accessibilityRole="button" key={segment.id} onPress={() => setTab('transcript')} style={styles.chapterRow}><Text style={styles.chapterTime}>{segment.time}</Text><Text numberOfLines={1} style={styles.chapterText}>{segment.text}</Text><Ionicons color={colors.border} name="chevron-forward" size={12} /></Pressable>)}</View></View> : null}
          {isGeneratingSummary ? <FileDetailGeneratingSkeleton /> : null}
          {!isGeneratingSummary && file.status !== 'queued' ? (
            <>
              <View style={styles.summarySection}><Text style={styles.summarySectionTitle}>決定事項</Text><Text style={styles.decisionText}>・{file.summary}</Text></View>
              <View style={styles.summarySection}>
                <Text style={styles.summarySectionTitle}>次のアクション</Text>
                <View style={styles.actionList}>
                  {file.memo.map((item) => (
                    <View key={item} style={styles.actionItem}>
                      <Text style={styles.actionItemText}>{item}</Text>
                      <Button
                        variant="ghost"
                        background={null}
                        onPress={() => Alert.alert('タスクに追加', 'この操作は現在利用できません。')}
                        style={styles.taskAction}
                      >
                        <Ionicons color={colors.textTertiary} name="add" size={14} />
                        <Button.Label>タスク</Button.Label>
                      </Button>
                    </View>
                  ))}
                </View>
              </View>
            </>
          ) : null}
          <View style={styles.summarySection}>
            <View style={styles.attachmentHeading}>
              <Text style={styles.summarySectionTitle}>添付</Text>
              <Text style={styles.attachmentCaption}>質問時に参照されます</Text>
            </View>
            <View style={styles.attachmentGrid}>
              {memoNotes.photos.map((photo) => (
                <View key={photo.id} style={styles.attachmentThumbWrap}>
                  <Image source={{ uri: photo.uri }} style={styles.attachmentThumb} transition={150} />
                  <View pointerEvents="none" style={styles.attachmentLocalBadge}>
                    <Text style={styles.attachmentLocalBadgeText}>この端末のみ</Text>
                  </View>
                </View>
              ))}
              <Pressable
                accessibilityLabel="メモで写真を添付"
                accessibilityRole="button"
                onPress={() => setTab('memo')}
                style={({ pressed }) => [styles.attachmentAdd, pressed && styles.scalePress]}
              >
                <Ionicons color={colors.textTertiary} name="add" size={20} />
              </Pressable>
            </View>
            <Text style={styles.attachmentStorageNote}>クラウド保存と全デバイス同期は Pro で ›</Text>
          </View>
          {isGeneratingSummary ? null : file.status === 'queued' ? (
            <View style={styles.generateCta}>
              <View style={styles.generateIconRow}>
                <Ionicons color={colors.text} name="mic-outline" size={24} weight="Filled" />
                <Ionicons color={colors.textTertiary} name="arrow-forward" size={22} style={styles.generateArrow} />
                <Ionicons color={colors.text} name="play" size={24} weight="Filled" />
              </View>
              <Text style={styles.generateTitle}>文字起こし・要約を生成する</Text>
              <Text style={styles.generateBody}>音声の内容を把握し重要ポイント・決定事項・タスクを自動抽出します。</Text>
              <Button
                variant="primary"
                onPress={() => setGenerateSheetView('main')}
                accessibilityLabel="AI生成"
              >
                <Button.Label>AI生成</Button.Label>
              </Button>
            </View>
          ) : (
            <View style={styles.summarySection}>
              <Text style={styles.summarySectionTitle}>要約</Text>
              <Text style={styles.bodyText}>{file.summary}</Text>
              {summaryMetadata ? (
                <Text style={styles.summaryMetadata}>
                  {summaryMetadata.provider} · {new Date(summaryMetadata.generatedAt).toLocaleString('ja-JP')}
                </Text>
              ) : null}
              {summaryError ? <Text style={styles.summaryError}>{summaryError}</Text> : null}
              <Button
                variant="outline"
                onPress={() => void handleGenerateSummary()}
                accessibilityLabel="要約を再生成"
              >
                <Ionicons color={colors.accent} name="refresh" size={17} />
                <Button.Label>要約を再生成</Button.Label>
              </Button>
            </View>
          )}
        </View>
      ) : null}

      {tab === 'transcript' ? (
        <Section>
          {playback.error ? <OfflineBanner message={playback.error} /> : null}

          {transcriptCount === 0 ? <TranscriptionProgressCard
            error={transcription.error}
            event={transcription.latestEvent}
            isRunning={transcription.isRunning}
            onCancel={transcription.cancel}
            onStart={transcription.start}
            task={transcription.task}
          /> : null}
          <View style={styles.panel}>
            {transcriptCount > 0 ? <SegmentedControl
              onSelect={(key) => setShowCleanedTranscript(key === 'cleaned')}
              segments={[
                { key: 'cleaned', label: '整形後' },
                { key: 'original', label: '元の文字起こし' },
              ]}
              selected={showCleanedTranscript ? 'cleaned' : 'original'}
            /> : null}
            {transcriptCount === 0 ? (
              <View style={styles.generateCta}>
                <View style={styles.generateIconRow}>
                  <Ionicons color={colors.text} name="pulse-outline" size={24} weight="Filled" />
                  <Ionicons color={colors.textTertiary} name="arrow-forward" size={22} style={styles.generateArrow} />
                  <Ionicons color={colors.text} name="document-outline" size={24} weight="Filled" />
                </View>
                <Text style={styles.generateTitle}>文字起こし・要約を生成する</Text>
                <Text style={styles.generateBody}>音声の内容を把握し重要ポイント・決定事項・タスクを自動抽出します。</Text>
                <Button
                  variant="primary"
                  onPress={transcription.start}
                  accessibilityLabel="AI生成"
                >
                  <Button.Label>AI生成</Button.Label>
                </Button>
              </View>
            ) : (
              <ScrollView
                contentContainerStyle={styles.transcriptScrollContent}
                nestedScrollEnabled
                onScrollBeginDrag={resumeTranscriptAutoScrollAfterDelay}
                onScrollEndDrag={resumeTranscriptAutoScrollAfterDelay}
                ref={transcriptScrollRef}
                showsVerticalScrollIndicator
                style={[styles.transcriptScroll, { maxHeight: transcriptMaxHeight }]}
              >
                {file.transcript.map((segment) => (
                  <View
                    key={segment.id}
                    onLayout={(event) => {
                      transcriptRowOffsetsRef.current[segment.id] = event.nativeEvent.layout.y;
                      if (!isTranscriptAutoScrollPaused && activeTranscriptSegmentId === segment.id) {
                        requestAnimationFrame(() => scrollTranscriptToSegment(segment.id));
                      }
                    }}
                    style={[styles.segmentRow, activeTranscriptSegmentId === segment.id ? styles.segmentActive : null]}
                  >
                    <Pressable
                      accessibilityLabel={`${segment.speaker}、${segment.time}から再生`}
                      accessibilityRole="button"
                      onPress={() => {
                        void (async () => {
                          await playback.seek(timeToSeconds(segment.time));
                          await playback.play();
                        })();
                      }}
                      style={({ pressed }) => [styles.segment, pressed && styles.segmentPressed]}
                    >
                      <View style={styles.segmentMeta}>
                        <Text style={styles.speaker}>{segment.speaker}</Text>
                        <Text style={styles.time}>{segment.time}</Text>
                      </View>
                      <Text style={styles.bodyText}>{showCleanedTranscript ? (segment.cleanedText ?? segment.text) : segment.text}</Text>
                    </Pressable>
                    <Button
                      accessibilityLabel="この発言をタスクに追加"
                      background={null}
                      onPress={() => void handleTaskizeSegment(segment)}
                      variant="ghost"
                      style={styles.segmentTaskize}
                    >
                      <Ionicons color={colors.textTertiary} name="add" size={14} />
                      <Button.Label>タスク</Button.Label>
                    </Button>
                  </View>
                ))}
              </ScrollView>
            )}
          </View>
        </Section>
      ) : null}

      {tab === 'memo' ? (
        <Section>
          <View style={styles.panel}>
            {isEditingMemo ? (
              <View style={styles.memoEditBlock}>
                <TextInput
                  multiline
                  onChangeText={setMemoDraftText}
                  placeholder="メモを入力"
                  placeholderTextColor={colors.border}
                  style={styles.memoInput}
                  value={memoDraftText}
                />
                <Button
                  variant="primary"
                  onPress={() => {
                    void memoNotes.saveDraft(memoDraftText);
                    setIsEditingMemo(false);
                  }}
                >
                  <Button.Label>保存</Button.Label>
                </Button>
              </View>
            ) : (
              <Pressable onPress={() => setIsEditingMemo(true)} style={({ pressed }) => [styles.memoDisplayBlock, pressed && styles.scalePress]}>
                <Text style={memoDraftText ? styles.memoDisplayText : styles.memoPlaceholderText}>
                  {memoDraftText || 'タップしてメモを追加'}
                </Text>
              </Pressable>
            )}

            {memoNotes.error ? <Text style={styles.summaryError}>{memoNotes.error}</Text> : null}

            <View style={styles.photoRow}>
              {memoNotes.photos.map((photo) => (
                <View key={photo.id} style={styles.photoThumbWrap}>
                  <Image source={{ uri: photo.uri }} style={styles.photoThumb} transition={150} />
                  <Pressable
                    accessibilityLabel="写真を削除"
                    onPress={() => void memoNotes.deletePhoto(photo.id)}
                    style={styles.photoDeleteButton}
                  >
                    <Ionicons color={colors.surface} name="close" size={12} />
                  </Pressable>
                </View>
              ))}
              {memoNotes.photos.length === 0 ? <Pressable
                accessibilityLabel="写真を添付"
                disabled={isAttachingPhoto}
                onPress={() => void handleAttachPhoto()}
                style={({ pressed }) => [styles.photoEmptyAdd, pressed && styles.scalePress]}
              >
                {isAttachingPhoto ? (
                  <ActivityIndicator color={colors.textTertiary} />
                ) : (
                  <>
                    <Ionicons color={colors.textTertiary} name="image-outline" size={20} />
                    <Text style={styles.photoAddText}>写真を添付</Text>
                  </>
                )}
              </Pressable> : <Pressable accessibilityLabel="写真を添付" disabled={isAttachingPhoto} onPress={() => void handleAttachPhoto()} style={({ pressed }) => [styles.photoAddButton, pressed && styles.scalePress]}>{isAttachingPhoto ? <ActivityIndicator color={colors.textTertiary} /> : <Ionicons color={colors.textTertiary} name="add" size={18} />}</Pressable>}
            </View>
          </View>
        </Section>
      ) : null}

      </Animated.View>
      </Tabs>

      <FloatingBottomSheet isOpen={isMoreOpen} onClose={handleMoreDismiss}>
        <View style={styles.sheetSurface}>
          <Button variant="ghost" background={null} onPress={() => closeMoreThen('rename')} style={styles.sheetAction}>
            <Ionicons color={colors.text} name="create-outline" size={18} />
            <Button.Label>タイトルを変更</Button.Label>
          </Button>
          <Separator />
          <Button variant="ghost" background={null} onPress={() => closeMoreThen('move')} style={styles.sheetAction}>
            <Ionicons color={colors.text} name="file-tray-outline" size={18} />
            <Button.Label>プロジェクトに移動</Button.Label>
          </Button>
          <Separator />
          <Button variant="danger-soft" background={null} onPress={() => closeMoreThen('delete')} style={styles.sheetAction}>
            <Ionicons color={colors.danger} name="trash-outline" size={18} />
            <Button.Label>削除</Button.Label>
          </Button>
        </View>
      </FloatingBottomSheet>
      <FloatingBottomSheet isOpen={isProjectMoveOpen} onClose={() => setIsProjectMoveOpen(false)}>
        <View style={styles.sheetSurface}>
          <Text style={styles.exportTitle}>プロジェクトに移動</Text>
          {isProjectMoveLoading ? (
            <View style={styles.projectMoveLoading}>
              <ActivityIndicator color={colors.textTertiary} />
            </View>
          ) : (
            <>
              <Button variant="ghost" background={null} onPress={() => void handleMoveToProject(null)} style={styles.sheetAction}>
                <Ionicons color={colors.text} name="folder" size={18} />
                <Button.Label>Inbox（個人）</Button.Label>
              </Button>
              {projects.length > 0 ? <Separator /> : null}
              {projects.map((project, index) => (
                <Fragment key={project.id}>
                  <Button variant="ghost" background={null} onPress={() => void handleMoveToProject(project.id)} style={styles.sheetAction}>
                    <Ionicons color={colors.text} name="folder" size={18} />
                    <Button.Label>{project.title}</Button.Label>
                  </Button>
                  {index < projects.length - 1 ? <Separator /> : null}
                </Fragment>
              ))}
            </>
          )}
        </View>
      </FloatingBottomSheet>
      <Dialog isOpen={isDeleteOpen} onOpenChange={(open) => { if (!open) setIsDeleteOpen(false); }}>
        <Dialog.Portal>
          <Dialog.Overlay variant="default" />
          <Dialog.Content style={styles.dialogContent}>
            <Dialog.Title>このファイルを削除しますか？</Dialog.Title>
            <Dialog.Description>録音・文字起こし・メモはすべて削除されます。</Dialog.Description>
            <View style={styles.renameSheetActions}>
              <Button variant="ghost" background={null} onPress={() => setIsDeleteOpen(false)}>
                <Button.Label>キャンセル</Button.Label>
              </Button>
              <Button variant="danger" onPress={() => void handleDelete()}>
                <Button.Label>削除</Button.Label>
              </Button>
            </View>
          </Dialog.Content>
        </Dialog.Portal>
      </Dialog>
      <FloatingBottomSheet isOpen={isExportOpen} onClose={handleExportDismiss}>
        <View style={styles.sheetSurface}>
          <Text style={styles.exportTitle}>書き出す</Text>
          <Button variant="ghost" background={null} onPress={() => closeExportThen('notion')} style={styles.sheetAction}>
            <Ionicons color={colors.text} name="document-outline" size={18} />
            <View style={styles.sheetActionCopy}><Button.Label>Notion に転記</Button.Label></View>
            <Text style={styles.exportRowStatus}>{NOTION_SETUP_LABELS[notionSetup]}</Text>
          </Button>
          <Separator />
          <Button variant="ghost" background={null} onPress={() => closeExportThen('chatgpt')} style={styles.sheetAction}>
            <Ionicons color={colors.text} name="chatbubble-outline" size={18} />
            <View style={styles.sheetActionCopy}><Button.Label>ChatGPT に共有</Button.Label></View>
            <Text style={styles.exportRowStatus}>コピー＋共有シート</Text>
          </Button>
          <Separator />
          <Button variant="ghost" background={null} onPress={() => closeExportThen('share')} style={styles.sheetAction}>
            <Ionicons color={colors.text} name="share-outline" size={18} />
            <Button.Label>Markdown / TXT / SRT で書き出す</Button.Label>
          </Button>
        </View>
      </FloatingBottomSheet>
      <FloatingBottomSheet isOpen={generateSheetView === 'main'} onClose={handleGenerateSheetDismiss}>
        <View style={styles.sheetSurface}>
          <Button variant="ghost" background={null} onPress={handleAutoGenerate} style={styles.generateSheetButton}>
            <Ionicons color={colors.text} name="sparkles" size={20} />
            <View style={styles.generateSheetRowText}>
              <Text style={styles.generateSheetRowTitle}>自動生成</Text>
              <Text style={styles.generateSheetRowDesc}>内容に応じて最適な形に自動要約</Text>
            </View>
          </Button>
          <Separator />
          <Button variant="ghost" background={null} onPress={() => setGenerateSheetView('template')} style={styles.generateSheetButton}>
            <Ionicons color={colors.text} name="file-tray-outline" size={20} />
            <View style={styles.generateSheetRowText}>
              <Text style={styles.generateSheetRowTitle}>カスタム生成</Text>
              <Text style={styles.generateSheetRowDesc}>テンプレートを選択して要約</Text>
            </View>
            <Ionicons color={colors.border} name="chevron-forward" size={16} />
          </Button>
          <Button variant="primary" onPress={handleAutoGenerate} accessibilityLabel="生成">
            <Button.Label>生成</Button.Label>
          </Button>
        </View>
      </FloatingBottomSheet>
      <FloatingBottomSheet isOpen={generateSheetView === 'template'} onClose={handleGenerateSheetDismiss}>
        <View style={styles.sheetSurface}>
          <Text style={styles.exportTitle}>テンプレートを選択</Text>
          <RadioGroup
            value={generateTemplateId}
            onValueChange={(value) => setGenerateTemplateId(value as (typeof GENERATE_TEMPLATES)[number]['id'])}
            variant="primary"
          >
            {GENERATE_TEMPLATES.map((template, index) => (
              <Fragment key={template.id}>
                {index > 0 ? <Separator /> : null}
                <RadioGroup.Item value={template.id}>
                  <View>
                    <Label>{template.label}</Label>
                    <Description>{template.description}</Description>
                  </View>
                  <Radio />
                </RadioGroup.Item>
              </Fragment>
            ))}
          </RadioGroup>
          <Button variant="ghost" background={null} onPress={() => setGenerateSheetView('model')} style={styles.generateModelButton}>
            <Ionicons color={colors.text} name="sparkles" size={16} />
            <Text style={styles.generateModelButtonLabel}>AIモデル</Text>
            <Text style={styles.generateModelButtonValue}>{SUMMARY_PROVIDER_LABELS[summaryProvider]}</Text>
            <Ionicons color={colors.border} name="chevron-forward" size={14} />
          </Button>
          <Button variant="primary" onPress={handleCustomGenerate} accessibilityLabel="生成">
            <Button.Label>生成</Button.Label>
          </Button>
        </View>
      </FloatingBottomSheet>
      <FloatingBottomSheet
        isOpen={generateSheetView === 'model' || isFileAskModelSheetOpen}
        onClose={() => {
          if (isFileAskModelSheetOpen) {
            setIsFileAskModelSheetOpen(false);
          } else {
            handleGenerateSheetDismiss();
          }
        }}
      >
        {isFileAskModelSheetOpen ? (
          <View style={styles.sheetSurface}>
            <Text style={styles.fileAskModelSheetHeading}>AIモデル</Text>
            <RadioGroup
              value={fileAskModel}
              onValueChange={(value) => {
                setFileAskModel(value as AskModel);
                setIsFileAskModelSheetOpen(false);
              }}
              variant="primary"
            >
              {(Object.keys(ASK_MODEL_LABELS) as AskModel[]).map((model) => (
                <RadioGroup.Item key={model} value={model}>
                  {ASK_MODEL_LABELS[model]}
                </RadioGroup.Item>
              ))}
            </RadioGroup>
          </View>
        ) : (
          <View style={styles.sheetSurface}>
            <Text style={styles.exportTitle}>AIモデルを選択</Text>
            <RadioGroup
              value={summaryProvider}
              onValueChange={(value) => {
                setSummaryProvider(value as SummaryOptionsDTO['provider']);
                setGenerateSheetView('template');
              }}
              variant="primary"
            >
              {(Object.keys(SUMMARY_PROVIDER_LABELS) as SummaryOptionsDTO['provider'][]).map((provider, index) => (
                <Fragment key={provider}>
                  {index > 0 ? <Separator /> : null}
                  <RadioGroup.Item value={provider}>
                    {SUMMARY_PROVIDER_LABELS[provider]}
                  </RadioGroup.Item>
                </Fragment>
              ))}
            </RadioGroup>
          </View>
        )}
      </FloatingBottomSheet>
      <Dialog isOpen={isEditingTitle} onOpenChange={(open) => { if (!open) { setIsEditingTitle(false); setRenameError(null); } }}>
        <Dialog.Portal>
          <Dialog.Overlay variant="default" />
          <Dialog.Content style={styles.dialogContent}>
            <Dialog.Title>タイトルを変更</Dialog.Title>
            <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.dialogBody}>
              <Input
                accessibilityLabel="ファイル名入力"
                autoFocus
                onChangeText={setDraftTitle}
                onSubmitEditing={handleRename}
                returnKeyType="done"
                value={draftTitle}
              />
              {renameError ? <Text style={styles.renameError}>{renameError}</Text> : null}
              <View style={styles.renameSheetActions}>
                <Button variant="ghost" background={null} onPress={() => { setIsEditingTitle(false); setRenameError(null); }}>
                  <Button.Label>キャンセル</Button.Label>
                </Button>
                <Button variant="primary" isDisabled={isSavingTitle} onPress={handleRename} accessibilityState={{ busy: isSavingTitle, disabled: isSavingTitle }}>
                  <Button.Label>{isSavingTitle ? '保存中' : '保存'}</Button.Label>
                </Button>
              </View>
            </KeyboardAvoidingView>
          </Dialog.Content>
        </Dialog.Portal>
      </Dialog>
    </Screen>
  );
}

function isRenameableBridgeFile(file: AudioFile) {
  return (
    file.id.startsWith('native-recording-') ||
    file.id.startsWith('native-import-') ||
    file.id.startsWith('import-')
  );
}

function timeToSeconds(time: string) {
  const [minutes = '0', seconds = '0'] = time.split(':');
  return Number(minutes) * 60 + Number(seconds);
}

function activeTranscriptSegmentIdForPosition(
  transcript: AudioFile['transcript'],
  position?: number,
): string | undefined {
  if (position === undefined) return undefined;
  let activeSegmentId: string | undefined;
  for (const segment of transcript) {
    if (timeToSeconds(segment.time) <= position) {
      activeSegmentId = segment.id;
    }
  }
  return activeSegmentId;
}

const styles = StyleSheet.create({
  summaryTab: { gap: spacing.lg, paddingBottom: spacing.lg, paddingTop: spacing.sm },
  summaryMeta: { color: colors.textTertiary, ...textStyles.caption },
  summarySection: { gap: spacing.sm },
  summarySectionTitle: { color: colors.text, ...textStyles.bodyBold },
  chapterRow: { alignItems: 'center', flexDirection: 'row', gap: spacing.md, paddingHorizontal: spacing.xs, paddingVertical: spacing.sm },
  chapterTime: { color: colors.textTertiary, width: 38, ...textStyles.monoBody },
  chapterText: { color: colors.text, flex: 1, ...textStyles.body },
  decisionText: { color: colors.textSecondary, ...textStyles.body },
  actionList: { gap: spacing.md },
  actionItem: { alignItems: 'center', flexDirection: 'row', gap: spacing.sm },
  actionItemText: { color: colors.text, flex: 1, ...textStyles.body },
  attachmentHeading: { alignItems: 'baseline', flexDirection: 'row', gap: spacing.sm },
  attachmentCaption: { color: colors.textTertiary, ...textStyles.caption },
  attachmentGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  attachmentThumbWrap: { aspectRatio: 1, borderRadius: radius.md, overflow: 'hidden', width: '30.8%' },
  attachmentThumb: { height: '100%', width: '100%' },
  attachmentLocalBadge: { backgroundColor: 'rgba(13,13,13,0.7)', borderRadius: 6, left: 5, paddingHorizontal: 5, paddingVertical: 2, position: 'absolute', top: 5 },
  attachmentLocalBadgeText: { color: colors.surface, ...textStyles.captionBold },
  attachmentAdd: { alignItems: 'center', aspectRatio: 1, borderColor: colors.border, borderRadius: radius.md, borderStyle: 'dashed', borderWidth: 1.5, justifyContent: 'center', width: '30.8%' },
  attachmentStorageNote: { color: colors.textTertiary, marginTop: 2, ...textStyles.caption },
  detailTopRow: { alignItems: 'center', flexDirection: 'row', justifyContent: 'space-between', marginHorizontal: -6 },
  headerActions: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.xs,
  },
  backButton: {
    alignItems: 'center',
    height: 40,
    justifyContent: 'center',
    width: 40,
  },
  fileMetaRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
  },
  sourceMeta: {
    color: colors.textTertiary,
    flex: 1,
    ...textStyles.caption,
  },
  summaryIntro: {
    gap: spacing.lg,
    paddingBottom: spacing.sm,
  },
  heroTop: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  date: {
    color: colors.textTertiary,
    fontSize: 12,
    fontWeight: '800',
  },
  titleBlock: {
    gap: spacing.sm,
  },
  titleRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
    justifyContent: 'space-between',
  },
  heroTitle: {
    color: colors.text,
    flex: 1,
    fontSize: 24,
    fontWeight: '700',
    letterSpacing: -0.24,
    lineHeight: 30,
  },
  renameForm: {
    gap: spacing.md,
  },
  titleInput: {
    backgroundColor: colors.surface,
    borderColor: colors.accent,
    borderRadius: radius.md,
    borderWidth: 2,
    color: colors.text,
    fontSize: 18,
    fontWeight: '900',
    minHeight: 48,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  renameActions: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  iconButton: {
    alignItems: 'center',
    backgroundColor: colors.accent,
    borderRadius: radius.pill,
    height: 40,
    justifyContent: 'center',
    width: 40,
  },
  ghostIconButton: {
    alignItems: 'center',
    backgroundColor: colors.surfaceAlt,
    borderRadius: radius.pill,
    height: 40,
    justifyContent: 'center',
    width: 40,
  },
  renameError: {
    color: colors.danger,
    ...textStyles.footnoteBold,
  },
  summaryError: {
    color: colors.danger,
    ...textStyles.footnoteBold,
  },
  summaryMetadata: {
    color: colors.textTertiary,
    ...textStyles.caption,
  },
  heroSummary: {
    color: colors.text,
    fontSize: 16,
    fontWeight: '400',
    lineHeight: 24,
  },
  heroActions: {
    flexDirection: 'row',
    gap: spacing.md,
  },
  actionButton: {
    alignItems: 'center',
    backgroundColor: colors.accent,
    borderRadius: radius.pill,
    flexDirection: 'row',
    gap: spacing.sm,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
  },
  actionText: {
    color: colors.surface,
    fontWeight: '900',
  },
  generateCta: {
    alignItems: 'center',
    gap: spacing.sm,
    paddingTop: spacing.xl,
  },
  generateIconRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.lg,
    marginBottom: spacing.sm,
  },
  generateArrow: {
    marginTop: spacing.sm,
  },
  generateTitle: {
    color: colors.text,
    textAlign: 'center',
    ...textStyles.sectionTitle,
  },
  generateBody: {
    color: colors.textSecondary,
    paddingHorizontal: spacing.lg,
    textAlign: 'center',
    ...textStyles.footnote,
  },
  generateSheetButton: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
    minHeight: 56,
    paddingHorizontal: spacing.md,
  },
  generateSheetRowText: {
    flex: 1,
    gap: 2,
  },
  generateSheetRowTitle: {
    color: colors.text,
    ...textStyles.body,
  },
  generateSheetRowDesc: {
    color: colors.textTertiary,
    ...textStyles.caption,
  },
  generateModelButton: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
    marginTop: spacing.sm,
    minHeight: 48,
    paddingHorizontal: spacing.md,
  },
  generateModelButtonLabel: {
    color: colors.text,
    flex: 1,
    ...textStyles.footnoteBold,
  },
  generateModelButtonValue: {
    color: colors.textTertiary,
    ...textStyles.footnote,
  },
  ghostButton: {
    alignItems: 'center',
    backgroundColor: colors.surfaceAlt,
    borderRadius: radius.pill,
    flexDirection: 'row',
    gap: spacing.sm,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
  },
  ghostText: {
    color: colors.text,
    fontWeight: '900',
  },
  detailHeader: { flex: 1, gap: spacing.xs },
  detailTitle: { color: colors.text, letterSpacing: -0.24, ...textStyles.title2 },
  detailMetaRow: { alignItems: 'center', flexDirection: 'row', gap: spacing.sm },
  detailMeta: { color: colors.textTertiary, ...textStyles.caption },
  panel: {
    backgroundColor: colors.surface,
    borderBottomColor: colors.border,
    borderBottomWidth: 1,
    gap: spacing.lg,
    paddingBottom: spacing.lg,
    paddingTop: spacing.sm,
  },
  playerFooter: {
    backgroundColor: colors.surface,
    borderTopColor: colors.border,
    borderTopWidth: 1,
    paddingBottom: spacing.sm,
    paddingHorizontal: spacing.lg,
  },
  fileAskDock: {
    backgroundColor: colors.surface,
    borderTopColor: colors.border,
    borderTopWidth: 1,
    gap: spacing.sm,
    paddingBottom: spacing.sm,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.sm,
  },
  fileAskProjectRow: {
    alignItems: 'center',
    alignSelf: 'flex-start',
    flexDirection: 'row',
    gap: spacing.xs,
    minHeight: 44,
    paddingHorizontal: spacing.xs,
  },
  fileAskProjectRowText: {
    color: colors.textTertiary,
    ...textStyles.caption,
  },
  fileAskBox: {
    gap: spacing.xs,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  fileAskBoxRow: {
    alignItems: 'center',
    borderTopColor: colors.border,
    borderTopWidth: 1,
    flexDirection: 'row',
    gap: spacing.sm,
    paddingTop: spacing.sm,
  },
  fileAskSpacer: {
    flex: 1,
  },
  fileAskModelSheetHeading: {
    color: colors.text,
    ...textStyles.callout,
  },
  sheetSurface: { backgroundColor: colors.surface, borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth, paddingBottom: spacing.xl, paddingHorizontal: spacing.md, paddingTop: spacing.sm, width: '100%' },
  renameSheetActions: { flexDirection: 'row', gap: spacing.sm, justifyContent: 'flex-end' },
  exportTitle: { color: colors.text, marginBottom: spacing.sm, marginLeft: spacing.xs, ...textStyles.callout },
  exportRowStatus: { color: colors.textTertiary, ...textStyles.caption },
  sheetAction: { justifyContent: 'flex-start', minHeight: 44, width: '100%' as const },
  projectMoveLoading: { alignItems: 'center', justifyContent: 'center', minHeight: 56 },
  sheetActionCopy: { flex: 1 },
  dialogContent: { gap: spacing.md },
  dialogBody: { gap: spacing.md, marginTop: spacing.md },
  taskAction: { minHeight: 44 },
  bodyText: {
    color: colors.text,
    ...textStyles.body,
  },
  todoList: {
    gap: spacing.md,
  },
  todoItem: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
  },
  todoText: {
    color: colors.text,
    flex: 1,
    ...textStyles.bodyBold,
  },
  segment: {
    flex: 1,
    gap: 3,
    minHeight: 44,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.sm,
  },
  segmentPressed: { opacity: 0.6 },
  segmentRow: {
    alignItems: 'center',
    borderRadius: 10,
    flexDirection: 'row',
    minHeight: 44,
  },
  segmentActive: { backgroundColor: colors.accentSoft },
  segmentTaskize: { minHeight: 44 },
  segmentMeta: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  speaker: {
    color: colors.textSecondary,
    ...textStyles.captionBold,
  },
  time: {
    color: colors.textTertiary,
    ...textStyles.monoBody,
  },
  transcriptScroll: {
    flexShrink: 1,
  },
  transcriptScrollContent: {
    gap: spacing.xs,
    paddingBottom: spacing.md,
  },
  memoEditBlock: {
    gap: spacing.sm,
  },
  memoInput: {
    backgroundColor: colors.surface,
    borderColor: colors.text,
    borderRadius: radius.lg,
    borderWidth: 1,
    color: colors.text,
    minHeight: 120,
    padding: spacing.md,
    textAlignVertical: 'top',
    ...textStyles.body,
  },
  memoDisplayBlock: {
    backgroundColor: colors.surfaceAlt,
    borderRadius: radius.lg,
    padding: spacing.md,
  },
  memoDisplayText: {
    color: colors.text,
    ...textStyles.body,
  },
  memoPlaceholderText: {
    color: colors.border,
    ...textStyles.body,
  },
  photoRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
  },
  photoThumbWrap: {
    height: 98,
    width: 132,
  },
  photoThumb: {
    borderRadius: radius.lg,
    height: '100%',
    width: '100%',
  },
  photoDeleteButton: {
    alignItems: 'center',
    backgroundColor: 'rgba(13,13,13,0.72)',
    borderRadius: 10,
    height: 20,
    justifyContent: 'center',
    position: 'absolute',
    right: 4,
    top: 4,
    width: 20,
  },
  photoAddButton: {
    alignItems: 'center',
    borderColor: colors.border,
    borderRadius: radius.lg,
    borderStyle: 'dashed',
    borderWidth: 1.5,
    gap: spacing.xs,
    height: 98,
    justifyContent: 'center',
    width: 98,
  },
  photoEmptyAdd: { alignItems: 'center', backgroundColor: colors.surfaceAlt, borderRadius: radius.md, gap: spacing.xs, height: 190, justifyContent: 'center', width: '100%' },
  scalePress: { opacity: 0.82, transform: [{ scale: 0.97 }] },
  photoAddText: {
    color: colors.textTertiary,
    ...textStyles.caption,
  },
});
