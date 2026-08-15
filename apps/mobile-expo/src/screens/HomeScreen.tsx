import { useFocusEffect, useRouter } from 'expo-router';
import * as DocumentPicker from 'expo-document-picker';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Modal,
  Pressable,
  RefreshControl,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { FlashList } from '@shopify/flash-list';
import { SymbolView } from 'expo-symbols';
import { SearchBar } from '../components/SearchBar';
import { FileCard } from '../components/FileCard';
import { FileCardSkeleton } from '../components/FileCardSkeleton';
import { DateSeparator } from '../components/DateSeparator';
import { OfflineBanner } from '../components/OfflineBanner';
import { Screen } from '../components/Screen';
import { FloatingBottomSheet } from '../components/FloatingBottomSheet';
import {
  HOME_COMPOSER_GAP,
  HOME_COMPOSER_HEIGHT,
  HOME_PROJECT_SELECTOR_HEIGHT,
  useHomeComposer,
} from '../components/HomeComposer';
import { Button } from 'heroui-native/button';
import { Select } from 'heroui-native/select';
import { Separator } from 'heroui-native/separator';
import { Spinner } from 'heroui-native/spinner';
import { EmptyState, ErrorState } from '../components/StateViews';
import { colors, radius, spacing, textStyles } from '../design/tokens';
import { screenMargin } from '../theme/tokens';
import { useCaptureFlow } from '../features/capture/CaptureFlowProvider';
import { useAudioFiles } from '../features/files/useAudioFiles';
import { MemoraNative } from '../native/MemoraNative';
import type { AudioFile } from '../types/memora';

const viewOptions = [
  { value: 'files', label: 'ファイル' },
  { value: 'projects', label: 'プロジェクト' },
] as const;

type ListItem =
  | { kind: 'date'; id: string; label: string }
  | { kind: 'file'; id: string; file: AudioFile };

/** The system tab bar is about 57pt; round up to the 4pt grid so content clears it. */
const TAB_BAR_CLEARANCE = 60;

/** Files avoid only the tab bar, 60pt composer, and their 4pt gap; the FAB is gone. */
const listBottomPadding = TAB_BAR_CLEARANCE + HOME_COMPOSER_HEIGHT + HOME_COMPOSER_GAP;

/** Projects also avoid the 52pt selector pill rendered above the Home composer. */
const projectViewBottomInset =
  TAB_BAR_CLEARANCE + HOME_PROJECT_SELECTOR_HEIGHT + HOME_COMPOSER_HEIGHT + HOME_COMPOSER_GAP;

export function HomeScreen() {
  const router = useRouter();
  const { data: files, error, isLoading, refresh, removeAudioFile, upsertAudioFile } = useAudioFiles();
  const capture = useCaptureFlow();
  const {
    selectedProject,
    setProjectOptions,
    setSelectedProject,
    setViewMode,
    viewMode,
  } = useHomeComposer();

  const [isSearchVisible, setIsSearchVisible] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [bridgeError, setBridgeError] = useState<string | undefined>();
  const [moreTarget, setMoreTarget] = useState<AudioFile | undefined>();
  const [deleteTarget, setDeleteTarget] = useState<AudioFile | undefined>();
  const [isDeleting, setIsDeleting] = useState(false);
  const [isImporting, setIsImporting] = useState(false);

  useFocusEffect(useCallback(() => { void refresh({ silent: true }); }, [refresh]));
  useEffect(() => { if (capture.latestFile) upsertAudioFile(capture.latestFile); }, [capture.latestFile, upsertAudioFile]);

  async function handleRefresh() {
    setIsRefreshing(true);
    try { await refresh({ silent: true }); } finally { setIsRefreshing(false); }
  }

  async function handleDelete(file: AudioFile) {
    if (isDeleting) return;
    setIsDeleting(true);
    setMoreTarget(undefined);
    setBridgeError(undefined);
    try {
      const ok = await MemoraNative.deleteAudioFile(file.id);
      if (!ok) { setBridgeError('削除できるレコードが見つかりませんでした。'); setDeleteTarget(undefined); return; }
      removeAudioFile(file.id);
      setDeleteTarget(undefined);
      void refresh({ silent: true });
    } catch {
      setBridgeError('削除に失敗しました。もう一度お試しください。');
      setDeleteTarget(undefined);
    } finally { setIsDeleting(false); }
  }

  async function handleImport() {
    if (isImporting) return;
    setBridgeError(undefined);
    try {
      const result = await DocumentPicker.getDocumentAsync({
        copyToCacheDirectory: true,
        multiple: false,
        type: ['audio/*'],
      });
      if (result.canceled || !result.assets[0]?.uri) return;

      setIsImporting(true);
      await capture.importAudio(result.assets[0].uri);
      await refresh({ silent: true });
    } catch {
      setBridgeError('ファイルの取り込みに失敗しました。音声ファイルを選んでもう一度お試しください。');
    } finally {
      setIsImporting(false);
    }
  }

  // ── computed ───────────────────────────────────────────
  const filtered = searchQuery.trim()
    ? files.filter((f) => `${f.title} ${f.summary} ${f.project ?? ''}`.toLowerCase().includes(searchQuery.trim().toLowerCase()))
    : files;

  const grouped = groupByDate(filtered);
  const isEmpty = !isLoading && !error && files.length === 0;
  const isSearchEmpty = !isLoading && !error && searchQuery.trim() !== '' && filtered.length === 0;

  // ── project view ───────────────────────────────────────
  const projectNames = useMemo(
    () => [...new Set(files.map((f) => f.project).filter(Boolean))] as string[],
    [files],
  );

  useEffect(() => {
    setProjectOptions(projectNames);
  }, [projectNames, setProjectOptions]);

  const viewValue = viewOptions.find((option) => option.value === viewMode) ?? viewOptions[0];

  // ── FlashList items ────────────────────────────────────
  const listItems = useMemo<ListItem[]>(() => {
    const items: ListItem[] = [];
    for (const group of grouped) {
      items.push({ kind: 'date', id: `date-${group.label}`, label: group.label });
      for (const file of group.files) {
        items.push({ kind: 'file', id: file.id, file });
      }
    }
    return items;
  }, [grouped]);

  const showFileList = viewMode === 'files' && !error;

  return (
    <>
      <Screen
        refreshControl={<RefreshControl colors={[colors.accent]} onRefresh={handleRefresh} refreshing={isRefreshing} tintColor={colors.accent} />}
        titleContent={<Text style={homeStyles.screenTitle}>Memora</Text>}
        headerAccessory={
          <View style={homeStyles.headerAccessory}>
            <Select
              onValueChange={(option) => {
                if (!option) return;
                setViewMode(option.value as 'files' | 'projects');
                setSelectedProject(undefined);
              }}
              presentation="popover"
              value={viewValue}
            >
              <Select.Trigger accessibilityLabel="表示を切り替え" variant="unstyled" style={homeStyles.viewSelectTrigger}>
                <Select.Value numberOfLines={1} placeholder="表示" style={homeStyles.viewSelectValue} />
                <Select.TriggerIndicator iconProps={{ color: colors.textSecondary, size: 12 }} />
              </Select.Trigger>
              <Select.Portal>
                <Select.Overlay />
                <Select.Content align="end" placement="bottom" presentation="popover" style={homeStyles.viewSelectContent}>
                  {viewOptions.map((option) => (
                    <Select.Item key={option.value} label={option.label} value={option.value}>
                      <Select.ItemLabel />
                      <Select.ItemIndicator />
                    </Select.Item>
                  ))}
                </Select.Content>
              </Select.Portal>
            </Select>
            <Button
              accessibilityLabel={isSearchVisible ? '検索を閉じる' : '記録を検索'}
              feedbackVariant="none"
              isIconOnly
              onPress={() => setIsSearchVisible((visible) => !visible)}
              size="md"
              variant="ghost"
              style={homeStyles.headerIconButton}
            >
              <SymbolView
                name={{
                  ios: isSearchVisible ? 'xmark' : 'magnifyingglass',
                  android: isSearchVisible ? 'close' : 'search',
                  web: isSearchVisible ? 'close' : 'search',
                }}
                size={20}
                tintColor={colors.text}
              />
            </Button>
            <Button
              accessibilityLabel="音声ファイルを読み込む"
              feedbackVariant="none"
              isDisabled={isImporting}
              isIconOnly
              onPress={() => void handleImport()}
              size="md"
              variant="ghost"
              style={homeStyles.headerIconButton}
            >
              {isImporting ? (
                <Spinner size="sm" />
              ) : (
                <SymbolView
                  name={{ ios: 'paperclip', android: 'attach_file', web: 'attach_file' }}
                  size={20}
                  tintColor={colors.text}
                />
              )}
            </Button>
          </View>
        }
        list={showFileList ? (
          <FlashList
            contentContainerStyle={homeStyles.listContent}
            data={listItems}
            getItemType={(item) => item.kind}
            keyExtractor={(item) => item.id}
            ListEmptyComponent={
              isLoading ? (
                <FileCardSkeleton count={5} />
              ) : isEmpty ? (
                <View style={homeStyles.emptyActions}>
                  <EmptyState
                    title="最初の記録を残してみましょう"
                    body="中央の + から録音、またはファイルを取り込めます"
                    actionLabel="録音を始める"
                    onAction={() => capture.openRecording().catch(() => {})}
                  />
                  <Pressable
                    accessibilityLabel="音声ファイルを読み込む"
                    accessibilityRole="button"
                    disabled={isImporting}
                    onPress={() => void handleImport()}
                    style={({ pressed }) => [homeStyles.importEmptyAction, (pressed || isImporting) && homeStyles.pressed]}
                  >
                    {isImporting ? <ActivityIndicator color={colors.accent} size="small" /> : <SymbolView name={{ ios: 'paperclip', android: 'attach_file', web: 'attach_file' }} size={18} tintColor={colors.accent} />}
                    <Text style={homeStyles.importEmptyActionText}>{isImporting ? '読み込み中…' : '音声ファイルを読み込む'}</Text>
                  </Pressable>
                </View>
              ) : isSearchEmpty ? (
                <EmptyState title="一致する記録はありません" body="別のキーワードで試してみてください" />
              ) : null
            }
            onRefresh={handleRefresh}
            refreshing={isRefreshing}
            renderItem={({ item }) =>
              item.kind === 'date' ? (
                <DateSeparator date={item.label} />
              ) : (
                <FileCard
                  file={item.file}
                  onPress={() => router.push({ pathname: '/file/[id]', params: { id: item.file.id } })}
                  onMore={() => setMoreTarget(item.file)}
                  showSummary={!searchQuery.trim()}
                />
              )
            }
            showsVerticalScrollIndicator={false}
          />
        ) : undefined}
      >
        {/* search */}
        {isSearchVisible ? <SearchBar value={searchQuery} onChangeText={setSearchQuery} /> : null}

        {/* offline */}
        {bridgeError ? <OfflineBanner message={bridgeError} /> : null}

        {/* error */}
        {error ? <ErrorState message={error} onRetry={() => void handleRefresh()} /> : null}

        {/* project view */}
        {!isLoading && !error && viewMode === 'projects' && files.length > 0 ? (
          selectedProject ? (
            <ProjectFiles
              files={files.filter((f) => f.project === selectedProject)}
              onBack={() => setSelectedProject(undefined)}
              onOpen={(id) => router.push({ pathname: '/file/[id]', params: { id } })}
              onMore={setMoreTarget}
              project={selectedProject}
            />
          ) : (
            <ProjectsGrid
              projects={projectNames}
              files={files}
              onSelect={setSelectedProject}
            />
          )
        ) : null}

        {/* keep the project grid clear of the pill + composer */}
        {viewMode === 'projects' ? (
          <View accessibilityElementsHidden importantForAccessibility="no-hide-descendants" style={homeStyles.projectBottomSpacer} />
        ) : null}
      </Screen>

      {/* more sheet */}
      <FileMoreSheet file={moreTarget} onClose={() => setMoreTarget(undefined)} onDelete={(f) => { setDeleteTarget(f); setMoreTarget(undefined); }} />
      {/* delete confirm */}
      <DeleteConfirm file={deleteTarget} isDeleting={isDeleting} onCancel={() => setDeleteTarget(undefined)} onConfirm={() => deleteTarget && void handleDelete(deleteTarget)} />
    </>
  );
}

// ── ProjectsGrid ─────────────────────────────────────────
function ProjectsGrid({ projects, files, onSelect }: { projects: string[]; files: AudioFile[]; onSelect: (p: string) => void }) {
  if (!projects.length) return <EmptyState title="プロジェクトはまだありません" body="録音をプロジェクトに整理すると、ここに表示されます。" />;
  return (
    <View style={homeStyles.projectsGrid}>
      {projects.map((project, i) => {
        const count = files.filter((f) => f.project === project).length;
        return (
          <Pressable
            accessibilityLabel={`${project}を開く`}
            accessibilityRole="button"
            key={project}
            onPress={() => onSelect(project)}
            style={({ pressed }) => [homeStyles.projectCard, pressed && homeStyles.cardPressed]}
          >
            <View style={[homeStyles.projectAvatar, { backgroundColor: [colors.categorySlate, colors.categoryTeal, colors.categoryOlive, colors.categoryMauve][i % 4] }]}>
              <Text style={homeStyles.projectAvatarText}>{project.slice(0, 1)}</Text>
            </View>
            <View>
              <Text numberOfLines={1} style={homeStyles.projectName}>{project}</Text>
              <Text style={homeStyles.projectCount}>{count}件の記録</Text>
            </View>
          </Pressable>
        );
      })}
    </View>
  );
}

// ── ProjectFiles ─────────────────────────────────────────
function ProjectFiles({ files, onBack, onOpen, onMore, project }: { files: AudioFile[]; onBack: () => void; onOpen: (id: string) => void; onMore: (f: AudioFile) => void; project: string }) {
  return (
    <View style={homeStyles.projectView}>
      <View style={homeStyles.projectHeader}>
        <Pressable accessibilityLabel="プロジェクト一覧に戻る" accessibilityRole="button" onPress={onBack} style={homeStyles.backBtn}>
          <SymbolView name={{ ios: 'chevron.left', android: 'chevron_left', web: 'chevron_left' }} size={18} tintColor={colors.text} />
        </Pressable>
        <View>
          <Text numberOfLines={1} style={homeStyles.projectViewTitle}>{project}</Text>
          <Text style={homeStyles.projectCount}>{files.length}件の記録</Text>
        </View>
      </View>
      {files.map((file) => (
        <FileCard key={file.id} file={file} onPress={() => onOpen(file.id)} onMore={() => onMore(file)} />
      ))}
    </View>
  );
}

// ── FileMoreSheet (token-compatible) ─────────────────────
function FileMoreSheet({ file, onClose, onDelete }: { file?: AudioFile; onClose: () => void; onDelete: (f: AudioFile) => void }) {
  const pending = useRef<'rename' | 'move' | 'delete' | null>(null);
  const pendingFile = useRef<AudioFile | undefined>(undefined);

  function closeThen(action: 'rename' | 'move' | 'delete') {
    pending.current = action; pendingFile.current = file; onClose();
  }
  function handleDismiss() {
    onClose();
    const action = pending.current; const target = pendingFile.current;
    pending.current = null; pendingFile.current = undefined;
    if (action === 'rename') Alert.alert('タイトルを変更', 'ファイル詳細画面から変更できます。');
    else if (action === 'delete' && target) onDelete(target);
  }

  return (
    <FloatingBottomSheet isOpen={Boolean(file)} onClose={handleDismiss}>
      <View style={homeStyles.sheetSurface}>
        <Button variant="ghost" background={null} onPress={() => closeThen('rename')} style={homeStyles.sheetAction} accessibilityLabel="タイトルを変更">
          <SymbolView name={{ ios: 'pencil', android: 'edit', web: 'edit' }} size={18} tintColor={colors.text} />
          <Button.Label>タイトルを変更</Button.Label>
        </Button>
        <Separator orientation="horizontal" variant="thin" />
        <Button variant="danger-soft" background={null} onPress={() => closeThen('delete')} style={homeStyles.sheetAction} accessibilityLabel="削除">
          <SymbolView name={{ ios: 'trash', android: 'delete', web: 'delete' }} size={18} tintColor={colors.danger} />
          <Button.Label>削除</Button.Label>
        </Button>
      </View>
    </FloatingBottomSheet>
  );
}

// ── DeleteConfirm ────────────────────────────────────────
function DeleteConfirm({ file, isDeleting, onCancel, onConfirm }: { file?: AudioFile; isDeleting: boolean; onCancel: () => void; onConfirm: () => void }) {
  return (
    <Modal animationType="fade" onRequestClose={isDeleting ? undefined : onCancel} presentationStyle="overFullScreen" statusBarTranslucent transparent visible={Boolean(file)}>
      <View style={homeStyles.modalBackdrop}>
        <View style={homeStyles.modalCard}>
          <Text style={homeStyles.modalTitle}>この記録を削除しますか？</Text>
          <Text style={homeStyles.modalBody}>録音・文字起こし・メモはすべて削除されます。この操作は元に戻せません。</Text>
          <View style={homeStyles.modalActions}>
            <Pressable accessibilityRole="button" disabled={isDeleting} onPress={onCancel} style={[homeStyles.modalCancel, isDeleting && homeStyles.disabled]}>
              <Text style={homeStyles.modalCancelText}>キャンセル</Text>
            </Pressable>
            <Pressable accessibilityRole="button" disabled={isDeleting} onPress={onConfirm} style={[homeStyles.modalDelete, isDeleting && homeStyles.disabled]}>
              <Text style={homeStyles.modalDeleteText}>{isDeleting ? '削除中…' : '削除'}</Text>
            </Pressable>
          </View>
        </View>
      </View>
    </Modal>
  );
}

// ── helpers ──────────────────────────────────────────────
function groupByDate(files: AudioFile[]) {
  const today: AudioFile[] = [];
  const yesterday: AudioFile[] = [];
  const week: AudioFile[] = [];
  const earlier: AudioFile[] = [];
  const now = new Date();
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const startOfYesterday = startOfToday - 86_400_000;

  for (const f of files) {
    const ts = Date.parse(f.recordedAt);
    if (!Number.isNaN(ts) && ts >= startOfToday) { today.push(f); }
    else if (!Number.isNaN(ts) && ts >= startOfYesterday && ts < startOfToday) { yesterday.push(f); }
    else if (!Number.isNaN(ts) && ts >= startOfToday - 6 * 86_400_000) { week.push(f); }
    else { earlier.push(f); }
  }
  return [
    { label: '今日', files: today },
    { label: '昨日', files: yesterday },
    { label: '今週', files: week },
    { label: '以前', files: earlier },
  ].filter((g) => g.files.length > 0);
}

// ── styles ───────────────────────────────────────────────
const homeStyles = StyleSheet.create({
  screenTitle: { color: colors.text, ...textStyles.screenTitle },
  headerAccessory: { alignItems: 'center', flexDirection: 'row', gap: spacing.xs },
  headerIconButton: { height: 44, width: 44 },
  viewSelectTrigger: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.xs,
    justifyContent: 'center',
    minHeight: 44,
    // heroui-native の .select__value は flex: 1（flexBasis: 0）を持つ。自動幅の親では
    // 配分すべき空間が確定せずラベルが幅ゼロに潰れるため、トリガに確定幅を与える。
    // style prop で flexGrow/flexBasis を打ち消す方法は実機で効かなかった（検証済み）。
    // 値は最長ラベル「プロジェクト」+ シェブロンが収まる 4pt 基底の幅。
    minWidth: 112,
    paddingHorizontal: spacing.sm,
  },
  viewSelectValue: {
    color: colors.text,
    ...textStyles.footnoteBold,
  },
  // .select__item-label も flex: 1 を持つため、Content が自動幅だと項目ラベルが
  // 1文字ずつ折り返す（実機で確認）。Content 側にも確定幅を与える。
  viewSelectContent: { minWidth: 180 },
  listContent: { paddingBottom: listBottomPadding, paddingHorizontal: screenMargin.compact },
  projectBottomSpacer: { height: projectViewBottomInset },
  pressed: { opacity: 0.62, transform: [{ scale: 0.93 }] },
  emptyActions: { gap: spacing.sm },
  importEmptyAction: { alignItems: 'center', borderColor: colors.accent, borderRadius: radius.sm, borderWidth: 1, flexDirection: 'row', gap: spacing.xs, justifyContent: 'center', minHeight: 44, paddingHorizontal: spacing.lg },
  importEmptyActionText: { color: colors.accent, ...textStyles.footnoteBold },

  // projects
  projectsGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  projectCard: { borderColor: colors.borderLight, borderRadius: radius.md, borderWidth: 1, gap: 28, padding: spacing.md, width: '48%' },
  cardPressed: { opacity: 0.76, transform: [{ scale: 0.97 }] },
  projectAvatar: { alignItems: 'center', borderRadius: radius.sm, height: 26, justifyContent: 'center', width: 26 },
  projectAvatarText: { color: colors.surface, ...textStyles.captionBold },
  projectName: { color: colors.text, ...textStyles.footnoteBold },
  projectCount: { color: colors.textTertiary, marginTop: spacing.xxs, ...textStyles.caption },
  projectView: { gap: spacing.xs },
  projectHeader: { alignItems: 'center', flexDirection: 'row', gap: spacing.sm, marginBottom: spacing.sm },
  projectViewTitle: { color: colors.text, ...textStyles.callout },
  backBtn: { alignItems: 'center', height: 44, justifyContent: 'center', marginLeft: -spacing.sm, width: 44 },

  // sheets
  sheetSurface: { backgroundColor: colors.surface, paddingBottom: spacing.xl, paddingHorizontal: spacing.md, paddingTop: spacing.sm, width: '100%' },
  sheetAction: { justifyContent: 'flex-start', minHeight: 44, width: '100%' as const },

  // modal
  modalBackdrop: { alignItems: 'center', backgroundColor: colors.overlay, flex: 1, justifyContent: 'center', padding: spacing.lg },
  modalCard: { backgroundColor: colors.surface, borderRadius: radius.lg, gap: spacing.sm, padding: spacing.lg, width: '100%' },
  modalTitle: { color: colors.text, textAlign: 'center', ...textStyles.callout },
  modalBody: { color: colors.textSecondary, textAlign: 'center', ...textStyles.footnote },
  modalActions: { flexDirection: 'row', gap: spacing.sm, marginTop: spacing.sm },
  modalCancel: { alignItems: 'center', backgroundColor: colors.surfaceAlt, borderRadius: radius.md, flex: 1, paddingVertical: spacing.md },
  modalDelete: { alignItems: 'center', backgroundColor: colors.danger, borderRadius: radius.md, flex: 1, paddingVertical: spacing.md },
  modalCancelText: { color: colors.text, ...textStyles.footnoteBold },
  modalDeleteText: { color: colors.surface, ...textStyles.footnoteBold },
  disabled: { opacity: 0.58 },
});
