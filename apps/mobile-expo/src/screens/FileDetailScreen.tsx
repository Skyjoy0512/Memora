import { AppIcon as Ionicons } from '../components/AppIcon';
import { LiquidGlassView, isLiquidGlassSupported } from '@callstack/liquid-glass';
import * as ImagePicker from 'expo-image-picker';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useRouter } from 'expo-router';
import { Image } from 'expo-image';
import { ActivityIndicator, Alert, Animated, KeyboardAvoidingView, Modal, Platform, Pressable, ScrollView, Share, StyleSheet, Text, TextInput, useWindowDimensions, View } from 'react-native';
import { PlayerBar } from '../components/PlayerBar';
import { FloatingBottomSheet } from '../components/FloatingBottomSheet';
import { Screen } from '../components/Screen';
import { Section } from '../components/Section';
import { SheetCard } from '../components/SheetCard';
import { EmptyState, ErrorState, LoadingState } from '../components/StateViews';
import { StatusPill } from '../components/StatusPill';
import { TranscriptionProgressCard } from '../components/TranscriptionProgressCard';
import { colors, radius, shadow, spacing } from '../design/tokens';
import { useAudioFile } from '../features/files/useAudioFiles';
import { useMemoNotes } from '../features/memo/useMemoNotes';
import { usePlayback } from '../features/playback/usePlayback';
import { useTranscriptionTask } from '../features/transcription/useTranscriptionTask';
import { MemoraNative } from '../native/MemoraNative';
import type { SummaryOptionsDTO } from '../native/MemoraNative.types';
import type { AudioFile } from '../types/memora';

type Tab = 'summary' | 'transcript' | 'memo' | 'ask';

const TAB_LABEL: Record<Tab, string> = {
  summary: '概要',
  transcript: '文字起こし',
  memo: 'メモ',
  ask: '質問',
};

const ASK_SUGGESTIONS = ['決定事項を整理して', 'アクションアイテムを抽出', '話者ごとに発言をまとめて'];
type MoreSheetAction = 'rename' | 'move' | 'delete';
type ExportSheetAction = 'notion' | 'chatgpt' | 'share';

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

  const handleGenerateSummary = async () => {
    if (!file || isGeneratingSummary) {
      return;
    }

    setIsGeneratingSummary(true);
    setSummaryError(null);

    try {
      const summary = await MemoraNative.generateSummary({
        audioFileId: file.id,
        options: { provider: summaryProvider },
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
      Alert.alert('プロジェクトに移動', 'プロジェクト機能の接続後に有効になります。');
    } else if (action === 'delete') {
      setIsDeleteOpen(true);
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
      Alert.alert('Notion に転記', '連携の接続後に有効になります。');
    } else if (action === 'chatgpt') {
      Alert.alert('ChatGPT に共有', '連携の接続後に有効になります。');
    } else if (action === 'share') {
      void handleShare();
    }
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
      topRow={<View style={styles.detailTopRow}><Pressable accessibilityLabel="ファイル一覧に戻る" accessibilityRole="button" onPress={() => router.back()} style={styles.headerIcon}><Ionicons color={colors.text} name="chevron-back" size={19} /></Pressable><View style={styles.headerActions}><Pressable accessibilityLabel="ファイルを共有" accessibilityRole="button" onPress={() => setIsExportOpen(true)} style={styles.headerIcon}><Ionicons color={colors.text} name="share-outline" size={18} /></Pressable><Pressable accessibilityLabel="その他の操作" accessibilityRole="button" onPress={handleMore} style={styles.headerIcon}><Ionicons color={colors.text} name="ellipsis-horizontal" size={19} /></Pressable></View></View>}
      footerAccessory={
        playback.status ? (
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
        ) : null
      }
      titleContent={
        <View style={styles.detailHeader}>
          <Text numberOfLines={1} style={styles.detailTitle}>{file.title}</Text>
          <View style={styles.detailMetaRow}>
            <Text style={styles.detailMeta}>{`${file.recordedAt} · ${file.duration}`}</Text>
            <StatusPill status={file.status} />
          </View>
        </View>
      }
    >
      <View style={styles.tabs}>
        {(['summary', 'transcript', 'memo', 'ask'] as const).map((item) => (
          <Pressable
            accessibilityRole="tab"
            accessibilityState={{ selected: tab === item }}
            key={item}
            onPress={() => setTab(item)}
            style={[styles.tab, tab === item && styles.tabActive]}
          >
            <Text style={[styles.tabText, tab === item && styles.tabTextActive]}>
              {TAB_LABEL[item]}
            </Text>
          </Pressable>
        ))}
      </View>

      <Animated.View style={{ opacity: tabOpacity }}>
      {tab === 'summary' ? (
        <View style={styles.summaryTab}>
          <Text style={styles.summaryMeta}>{file.duration} ・ 話者{new Set(file.transcript.map((segment) => segment.speaker).filter(Boolean)).size}名 ・ タスク{file.memo.length}件</Text>
          {file.transcript.length ? <View style={styles.summarySection}><Text style={styles.summarySectionTitle}>チャプター</Text><View>{file.transcript.slice(0, 4).map((segment) => <Pressable accessibilityRole="button" key={segment.id} onPress={() => setTab('transcript')} style={styles.chapterRow}><Text style={styles.chapterTime}>{segment.time}</Text><Text numberOfLines={1} style={styles.chapterText}>{segment.text}</Text><Ionicons color={colors.border} name="chevron-forward" size={12} /></Pressable>)}</View></View> : null}
          <View style={styles.summarySection}><Text style={styles.summarySectionTitle}>決定事項</Text><Text style={styles.decisionText}>・{file.summary}</Text></View>
          <View style={styles.summarySection}><Text style={styles.summarySectionTitle}>次のアクション</Text><View style={styles.actionList}>{file.memo.map((item) => <View key={item} style={styles.actionItem}><Text style={styles.actionItemText}>{item}</Text><Pressable accessibilityRole="button" onPress={() => Alert.alert('タスクに追加', 'この操作は現在利用できません。')} style={styles.taskifyButton}><Ionicons color={colors.textTertiary} name="add" size={14} /><Text style={styles.taskifyText}>タスク</Text></Pressable></View>)}</View></View>
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
          <View style={styles.summarySection}>
            <Text style={styles.summarySectionTitle}>要約</Text>
            <Text style={styles.bodyText}>{file.summary}</Text>
            {summaryMetadata ? (
              <Text style={styles.summaryMetadata}>
                {summaryMetadata.provider} · {new Date(summaryMetadata.generatedAt).toLocaleString('ja-JP')}
              </Text>
            ) : null}
            {summaryError ? <Text style={styles.summaryError}>{summaryError}</Text> : null}
            <Pressable
              accessibilityLabel="要約を再生成"
              accessibilityRole="button"
              disabled={isGeneratingSummary}
              onPress={handleGenerateSummary}
              style={[styles.summaryButton, isGeneratingSummary && styles.disabledButton]}
            >
              <Ionicons color={colors.accent} name="refresh" size={17} />
              <Text style={styles.summaryButtonText}>
                {isGeneratingSummary ? '要約を生成中...' : '要約を再生成'}
              </Text>
            </Pressable>
          </View>
        </View>
      ) : null}

      {tab === 'transcript' ? (
        <Section title="文字起こし">
          {playback.error ? <Text style={styles.summaryError}>{playback.error}</Text> : null}

          {transcriptCount === 0 ? <TranscriptionProgressCard
            error={transcription.error}
            event={transcription.latestEvent}
            isRunning={transcription.isRunning}
            onCancel={transcription.cancel}
            onStart={transcription.start}
            task={transcription.task}
          /> : null}
          <View style={styles.panel}>
            {transcriptCount > 0 ? <Pressable accessibilityLabel="文字起こし表示を切り替え" accessibilityRole="button" onPress={() => setShowCleanedTranscript((value) => !value)} style={styles.startTranscription}>
              <Text style={styles.startTranscriptionText}>{showCleanedTranscript ? '元の文字起こしを表示' : '整形後を表示'}</Text>
            </Pressable> : null}
            {transcriptCount === 0 ? (
              <View style={styles.transcriptEmpty}><Text style={styles.transcriptEmptyTitle}>文字起こしはまだありません</Text><Text style={styles.transcriptEmptyBody}>録音を文字起こしすると、全文とタイムスタンプ付きセグメントをこのタブで確認できます。</Text><Pressable onPress={transcription.start} style={styles.startTranscription}><Text style={styles.startTranscriptionText}>文字起こしを開始</Text></Pressable></View>
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
                  <Pressable
                    accessibilityLabel={`${segment.speaker}、${segment.time}から再生`}
                    accessibilityRole="button"
                    key={segment.id}
                    onLayout={(event) => {
                      transcriptRowOffsetsRef.current[segment.id] = event.nativeEvent.layout.y;
                      if (!isTranscriptAutoScrollPaused && activeTranscriptSegmentId === segment.id) {
                        requestAnimationFrame(() => scrollTranscriptToSegment(segment.id));
                      }
                    }}
                    onPress={() => {
                      void (async () => {
                        await playback.seek(timeToSeconds(segment.time));
                        await playback.play();
                      })();
                    }}
                    style={[styles.segment, activeTranscriptSegmentId === segment.id ? styles.segmentActive : null]}
                  >
                    <View style={styles.segmentMeta}>
                      <Text style={styles.speaker}>{segment.speaker}</Text>
                      <Text style={styles.time}>{segment.time}</Text>
                    </View>
                    <Text style={styles.bodyText}>{showCleanedTranscript ? (segment.cleanedText ?? segment.text) : segment.text}</Text>
                  </Pressable>
                ))}
              </ScrollView>
            )}
          </View>
        </Section>
      ) : null}

      {tab === 'memo' ? (
        <Section title="メモ">
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
                <Pressable
                  accessibilityRole="button"
                  onPress={() => {
                    void memoNotes.saveDraft(memoDraftText);
                    setIsEditingMemo(false);
                  }}
                  style={styles.memoSaveButton}
                >
                  <Text style={styles.memoSaveText}>保存</Text>
                </Pressable>
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

      {tab === 'ask' ? (
        <Section title="この記録について質問する">
          <View style={styles.askSuggestions}>
            {ASK_SUGGESTIONS.map((suggestion) => (
              <Pressable
                accessibilityRole="button"
                key={suggestion}
                onPress={() => router.push('/ask-ai')}
                style={({ pressed }) => [styles.askSuggestionChip, pressed && styles.scalePress]}
              >
                <Text style={styles.askSuggestionText}>{suggestion}</Text>
              </Pressable>
            ))}
          </View>
          <Pressable
            accessibilityLabel="この記録について聞く"
            accessibilityRole="button"
            onPress={() => router.push('/ask-ai')}
            style={styles.askInputRow}
          >
            <Text style={styles.askInputPlaceholder}>質問を入力...</Text>
            <Ionicons color={colors.textInverse} name="arrow-forward" size={16} />
          </Pressable>
        </Section>
      ) : null}
      </Animated.View>

      <FloatingBottomSheet isOpen={isMoreOpen} onClose={handleMoreDismiss}>
        <SheetCard style={styles.sheet}>
          <Pressable accessibilityRole="button" onPress={() => closeMoreThen('rename')} style={styles.sheetRow}><Ionicons color={colors.text} name="create-outline" size={18} /><Text style={styles.sheetRowText}>タイトルを変更</Text></Pressable>
          <Pressable accessibilityRole="button" onPress={() => closeMoreThen('move')} style={styles.sheetRow}><Ionicons color={colors.text} name="file-tray-outline" size={18} /><Text style={styles.sheetRowText}>プロジェクトに移動</Text></Pressable>
          <Pressable accessibilityRole="button" onPress={() => closeMoreThen('delete')} style={styles.sheetRow}><Ionicons color={colors.danger} name="trash-outline" size={18} /><Text style={styles.deleteText}>削除</Text></Pressable>
        </SheetCard>
      </FloatingBottomSheet>
      <Modal animationType="fade" onRequestClose={() => setIsDeleteOpen(false)} presentationStyle="overFullScreen" statusBarTranslucent transparent visible={isDeleteOpen}>
        <View style={styles.renameBackdrop}><LiquidGlassView colorScheme="light" effect="regular" tintColor="rgba(255,255,255,0.82)" style={[styles.renameSheet, !isLiquidGlassSupported && styles.sheetFallback]}><Text style={styles.renameSheetTitle}>このファイルを削除しますか？</Text><Text style={styles.deleteDescription}>録音・文字起こし・メモはすべて削除されます。</Text><View style={styles.renameSheetActions}><Pressable onPress={() => setIsDeleteOpen(false)} style={styles.renameCancel}><Text style={styles.renameCancelText}>キャンセル</Text></Pressable><Pressable onPress={() => void handleDelete()} style={styles.deleteConfirm}><Text style={styles.renameSaveText}>削除</Text></Pressable></View></LiquidGlassView></View>
      </Modal>
      <FloatingBottomSheet isOpen={isExportOpen} onClose={handleExportDismiss}>
        <SheetCard style={styles.sheet}>
          <Text style={styles.exportTitle}>書き出す</Text>
          <Pressable accessibilityRole="button" onPress={() => closeExportThen('notion')} style={styles.exportRow}>
            <View style={[styles.exportIcon, { backgroundColor: '#000000' }]}><Ionicons color="#FFFFFF" name="document-outline" size={14} /></View>
            <Text style={styles.exportRowLabel}>Notion に転記</Text>
            <Text style={styles.exportRowStatus}>未接続</Text>
          </Pressable>
          <Pressable accessibilityRole="button" onPress={() => closeExportThen('chatgpt')} style={styles.exportRow}>
            <View style={[styles.exportIcon, { backgroundColor: '#10A37F' }]}><Ionicons color="#FFFFFF" name="chatbubble-outline" size={14} /></View>
            <Text style={styles.exportRowLabel}>ChatGPT に共有</Text>
            <Text style={styles.exportRowStatus}>未接続</Text>
          </Pressable>
          <Pressable accessibilityRole="button" onPress={() => closeExportThen('share')} style={styles.exportRow}>
            <View style={[styles.exportIcon, { backgroundColor: '#8E8EA0' }]}><Ionicons color="#FFFFFF" name="share-outline" size={14} /></View>
            <Text numberOfLines={1} style={styles.exportRowLabel}>Markdown / TXT / SRT で書き出す</Text>
          </Pressable>
        </SheetCard>
      </FloatingBottomSheet>
      <Modal animationType="fade" onRequestClose={() => setIsEditingTitle(false)} transparent visible={isEditingTitle}>
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.renameBackdrop}>
          <LiquidGlassView colorScheme="light" effect="regular" tintColor="rgba(255,255,255,0.82)" style={[styles.renameSheet, !isLiquidGlassSupported && styles.sheetFallback]}>
            <Text style={styles.renameSheetTitle}>タイトルを変更</Text>
            <TextInput accessibilityLabel="ファイル名入力" autoFocus onChangeText={setDraftTitle} onSubmitEditing={handleRename} returnKeyType="done" style={styles.renameSheetInput} value={draftTitle} />
            {renameError ? <Text style={styles.renameError}>{renameError}</Text> : null}
            <View style={styles.renameSheetActions}>
              <Pressable onPress={() => { setIsEditingTitle(false); setRenameError(null); }} style={styles.renameCancel}><Text style={styles.renameCancelText}>キャンセル</Text></Pressable>
              <Pressable disabled={isSavingTitle} onPress={handleRename} style={[styles.renameSave, isSavingTitle && styles.disabledButton]}><Text style={styles.renameSaveText}>{isSavingTitle ? '保存中' : '保存'}</Text></Pressable>
            </View>
          </LiquidGlassView>
        </KeyboardAvoidingView>
      </Modal>
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
  summaryMeta: { color: colors.textTertiary, fontSize: 12.5 },
  summarySection: { gap: spacing.sm },
  summarySectionTitle: { color: colors.text, fontSize: 15, fontWeight: '700' },
  chapterRow: { alignItems: 'center', flexDirection: 'row', gap: spacing.md, paddingHorizontal: spacing.xs, paddingVertical: spacing.sm },
  chapterTime: { color: colors.textTertiary, fontFamily: 'Menlo', fontSize: 12, width: 38 },
  chapterText: { color: colors.text, flex: 1, fontSize: 14 },
  decisionText: { color: colors.textSecondary, fontSize: 14, lineHeight: 24 },
  actionList: { gap: spacing.md },
  actionItem: { alignItems: 'center', flexDirection: 'row', gap: spacing.sm },
  actionItemText: { color: colors.text, flex: 1, fontSize: 14, lineHeight: 20 },
  taskifyButton: { alignItems: 'center', flexDirection: 'row', gap: 2, minHeight: 36, paddingHorizontal: spacing.xs },
  taskifyText: { color: colors.textTertiary, fontSize: 11.5, fontWeight: '600' },
  attachmentHeading: { alignItems: 'baseline', flexDirection: 'row', gap: spacing.sm },
  attachmentCaption: { color: colors.textTertiary, fontSize: 11 },
  attachmentGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  attachmentThumbWrap: { aspectRatio: 1, borderRadius: radius.md, overflow: 'hidden', width: '30.8%' },
  attachmentThumb: { height: '100%', width: '100%' },
  attachmentLocalBadge: { backgroundColor: 'rgba(13,13,13,0.7)', borderRadius: 6, left: 5, paddingHorizontal: 5, paddingVertical: 2, position: 'absolute', top: 5 },
  attachmentLocalBadgeText: { color: colors.surface, fontSize: 8.5, fontWeight: '600' },
  attachmentAdd: { alignItems: 'center', aspectRatio: 1, borderColor: colors.border, borderRadius: radius.md, borderStyle: 'dashed', borderWidth: 1.5, justifyContent: 'center', width: '30.8%' },
  attachmentStorageNote: { color: colors.textTertiary, fontSize: 12, fontWeight: '500', marginTop: 2 },
  detailTopRow: { alignItems: 'center', flexDirection: 'row', justifyContent: 'space-between', marginHorizontal: -6 },
  headerActions: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.xs,
  },
  headerIcon: {
    alignItems: 'center',
    height: 40,
    justifyContent: 'center',
    width: 40,
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
    fontSize: 12,
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
  disabledButton: {
    opacity: 0.55,
  },
  renameError: {
    color: colors.danger,
    fontSize: 13,
    fontWeight: '800',
  },
  summaryError: {
    color: colors.danger,
    fontSize: 13,
    fontWeight: '800',
  },
  summaryMetadata: {
    color: colors.textTertiary,
    fontSize: 12,
    fontWeight: '800',
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
  summaryButton: {
    alignItems: 'center',
    alignSelf: 'flex-start',
    backgroundColor: colors.text,
    borderRadius: radius.pill,
    flexDirection: 'row',
    gap: spacing.sm,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
  },
  summaryButtonText: {
    color: colors.surface,
    fontWeight: '900',
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
  detailTitle: { color: colors.text, fontSize: 24, fontWeight: '700', letterSpacing: -0.24 },
  detailMetaRow: { alignItems: 'center', flexDirection: 'row', gap: spacing.sm },
  detailMeta: { color: colors.textTertiary, fontSize: 12.5 },
  tabs: {
    borderBottomColor: colors.border,
    borderBottomWidth: 1,
    flexDirection: 'row',
    gap: spacing.lg,
    justifyContent: 'center',
  },
  tab: {
    alignItems: 'center',
    paddingBottom: spacing.sm,
    paddingTop: spacing.xs,
  },
  tabActive: {
    borderBottomColor: colors.text,
    borderBottomWidth: 2,
  },
  tabText: {
    color: colors.textTertiary,
    fontSize: 14,
    fontWeight: '600',
  },
  tabTextActive: {
    color: colors.text,
  },
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
    ...shadow.card,
  },
  askSuggestions: {
    gap: spacing.sm,
  },
  askSuggestionChip: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radius.md,
    borderWidth: 1,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.md,
  },
  askSuggestionText: {
    color: colors.text,
    fontSize: 14,
  },
  askInputRow: {
    alignItems: 'center',
    backgroundColor: colors.text,
    borderRadius: radius.pill,
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: spacing.sm,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
  },
  askInputPlaceholder: {
    color: colors.textInverse,
    fontSize: 14,
  },
  sheetBackdrop: { backgroundColor: 'rgba(0,0,0,0.32)', flex: 1, justifyContent: 'flex-end' },
  sheetPress: { width: '100%' },
  sheet: { gap: spacing.xs, paddingBottom: spacing.md, paddingHorizontal: spacing.md, paddingTop: spacing.sm },
  sheetFallback: { backgroundColor: colors.surface },
  sheetRow: { alignItems: 'center', backgroundColor: 'rgba(255,255,255,0.86)', borderRadius: radius.md, flexDirection: 'row', gap: spacing.sm, minHeight: 50, paddingHorizontal: spacing.md },
  sheetRowText: { color: colors.text, fontSize: 15, fontWeight: '500' },
  deleteText: { color: colors.danger, fontSize: 15, fontWeight: '500' },
  renameBackdrop: { alignItems: 'center', backgroundColor: 'rgba(0,0,0,0.32)', flex: 1, justifyContent: 'center', padding: spacing.lg },
  renameSheet: { borderRadius: radius.lg, gap: spacing.md, overflow: 'hidden', padding: spacing.lg, width: '100%' },
  renameSheetTitle: { color: colors.text, fontSize: 16, fontWeight: '700' },
  renameSheetInput: { backgroundColor: colors.surfaceAlt, borderColor: colors.border, borderRadius: radius.md, borderWidth: 1, color: colors.text, fontSize: 15, minHeight: 46, paddingHorizontal: spacing.md },
  renameSheetActions: { flexDirection: 'row', gap: spacing.sm, justifyContent: 'flex-end' },
  renameCancel: { paddingHorizontal: spacing.md, paddingVertical: spacing.sm },
  renameCancelText: { color: colors.textTertiary, fontSize: 14, fontWeight: '600' },
  renameSave: { backgroundColor: colors.text, borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.sm },
  renameSaveText: { color: colors.surface, fontSize: 14, fontWeight: '600' },
  deleteDescription: { color: colors.textSecondary, fontSize: 12.5, lineHeight: 19, textAlign: 'center' }, deleteConfirm: { backgroundColor: colors.danger, borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.sm },
  exportTitle: { color: colors.text, fontSize: 16, fontWeight: '700', marginBottom: spacing.sm, marginLeft: spacing.xs }, exportRow: { alignItems: 'center', backgroundColor: 'rgba(255,255,255,0.86)', borderRadius: radius.md, flexDirection: 'row', gap: spacing.sm, minHeight: 52, paddingHorizontal: spacing.md }, exportIcon: { alignItems: 'center', borderRadius: 6, height: 24, justifyContent: 'center', width: 24 }, exportRowLabel: { color: colors.text, flex: 1, fontSize: 14.5, fontWeight: '500' }, exportRowStatus: { color: colors.textTertiary, fontSize: 11.5 },
  bodyText: {
    color: colors.text,
    fontSize: 14,
    lineHeight: 24,
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
    fontSize: 15,
    fontWeight: '700',
  },
  segment: {
    borderRadius: 10,
    gap: 3,
    minHeight: 44,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.sm,
  },
  segmentActive: { backgroundColor: colors.accentSoft },
  segmentMeta: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  speaker: {
    color: colors.textSecondary,
    fontSize: 12,
    fontWeight: '600',
  },
  time: {
    color: colors.textTertiary,
    fontFamily: 'Menlo',
    fontSize: 10.5,
    fontWeight: '500',
  },
  transcriptScroll: {
    flexShrink: 1,
  },
  transcriptScrollContent: {
    gap: spacing.xs,
    paddingBottom: spacing.md,
  },
  transcriptEmpty: { alignItems: 'center', gap: spacing.sm, paddingHorizontal: spacing.lg, paddingTop: spacing.xl },
  transcriptEmptyTitle: { color: colors.text, fontSize: 15, fontWeight: '700' },
  transcriptEmptyBody: { color: colors.textTertiary, fontSize: 12.5, lineHeight: 20, textAlign: 'center' },
  startTranscription: { backgroundColor: colors.text, borderRadius: radius.md, marginTop: spacing.xs, paddingHorizontal: spacing.lg, paddingVertical: spacing.sm },
  startTranscriptionText: { color: colors.surface, fontSize: 13.5, fontWeight: '600' },
  memoEditBlock: {
    gap: spacing.sm,
  },
  memoInput: {
    backgroundColor: colors.surface,
    borderColor: colors.text,
    borderRadius: radius.lg,
    borderWidth: 1,
    color: colors.text,
    fontSize: 14,
    lineHeight: 25,
    minHeight: 120,
    padding: spacing.md,
    textAlignVertical: 'top',
  },
  memoSaveButton: {
    alignItems: 'center',
    alignSelf: 'flex-start',
    backgroundColor: colors.text,
    borderRadius: radius.md,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
  },
  memoSaveText: {
    color: colors.surface,
    fontSize: 13.5,
    fontWeight: '600',
  },
  memoDisplayBlock: {
    backgroundColor: '#FAFAFA',
    borderRadius: radius.lg,
    padding: spacing.md,
  },
  memoDisplayText: {
    color: colors.text,
    fontSize: 14,
    lineHeight: 25,
  },
  memoPlaceholderText: {
    color: colors.border,
    fontSize: 14,
    lineHeight: 25,
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
    fontSize: 11,
  },
});
