import { useFocusEffect, useRouter } from 'expo-router';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  Alert,
  Modal,
  Pressable,
  RefreshControl,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { FlashList } from '@shopify/flash-list';
import { AppIcon } from '../components/AppIcon';
import { SearchBar } from '../components/SearchBar';
import { NumericText } from '../components/NumericText';
import { FileCard } from '../components/FileCard';
import { FileCardSkeleton } from '../components/FileCardSkeleton';
import { DateSeparator } from '../components/DateSeparator';
import { OfflineBanner } from '../components/OfflineBanner';
import { Screen } from '../components/Screen';
import { SegmentedControl } from '../components/SegmentedControl';
import { FloatingBottomSheet } from '../components/FloatingBottomSheet';
import { ASK_ENTRY_BAR_HEIGHT } from '../components/AskEntryBar';
import { useTabBarClearance } from '../components/useTabBarClearance';
import { useHomeViewState, type HomeViewMode } from '../features/home/HomeViewState';
import { Separator } from 'heroui-native/separator';
import { IconButton, SheetAction } from '../components/Buttons';
import { EmptyState, ErrorState } from '../components/StateViews';
import { colors, spacing, textStyles } from '../design/tokens';
import { screenMargin } from '../theme/tokens';
import { useCaptureFlow } from '../features/capture/CaptureFlowProvider';
import { useAudioFiles } from '../features/files/useAudioFiles';
import { MemoraNative } from '../native/MemoraNative';
import type { AudioFile } from '../types/memora';

const viewSegments: Array<{ key: HomeViewMode; label: string }> = [
  { key: 'files', label: 'すべて' },
  { key: 'projects', label: 'プロジェクト' },
];

type ListItem =
  | { kind: 'date'; id: string; label: string }
  | { kind: 'file'; id: string; file: AudioFile };

export function HomeScreen() {
  const router = useRouter();
  const { data: files, error, isLoading, refresh, removeAudioFile, upsertAudioFile } = useAudioFiles();
  const capture = useCaptureFlow();
  const { selectedProject, setSelectedProject, setViewMode, viewMode } = useHomeViewState();
  // 記録一覧は、タブバーと浮いた Ask AI バー（＋その上下パディング）を避ける。
  const listBottomPadding = useTabBarClearance() + ASK_ENTRY_BAR_HEIGHT + spacing.md;

  const [searchQuery, setSearchQuery] = useState('');
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [bridgeError, setBridgeError] = useState<string | undefined>();
  const [moreTarget, setMoreTarget] = useState<AudioFile | undefined>();
  const [deleteTarget, setDeleteTarget] = useState<AudioFile | undefined>();
  const [isDeleting, setIsDeleting] = useState(false);

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
        title="記録"
        headerAccessory={
          <IconButton
            accessibilityLabel="同期状態を確認"
            onPress={() => router.push('/settings')}
            style={homeStyles.headerIconButton}
          >
            <AppIcon color={colors.text} name="sync-outline" size={20} />
          </IconButton>
        }
        list={showFileList ? (
          <FlashList
            contentContainerStyle={[homeStyles.listContent, { paddingBottom: listBottomPadding }]}
            data={listItems}
            getItemType={(item) => item.kind}
            keyExtractor={(item) => item.id}
            ListEmptyComponent={
              isLoading ? (
                <FileCardSkeleton count={5} />
              ) : isEmpty ? (
                <EmptyState
                  title="最初の記録を残してみましょう"
                  body="下部中央の + から、録音・ファイルの取り込み・会議のキャプチャーを始められます。"
                  actionLabel="録音を始める"
                  onAction={() => capture.openRecording().catch(() => {})}
                />
              ) : isSearchEmpty ? (
                <EmptyState title="一致する記録がありません" body="別の語句またはプロジェクトで探してください。" />
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
        {/* search + scope: ヘッダーに常設する（開閉トグルは廃止） */}
        <SearchBar value={searchQuery} onChangeText={setSearchQuery} />
        <SegmentedControl
          onSelect={(key) => {
            setViewMode(key);
            setSelectedProject(undefined);
          }}
          segments={viewSegments}
          selected={viewMode}
          variant="boxed"
        />

        {/* offline */}
        {bridgeError ? <OfflineBanner message={bridgeError} /> : null}

        {/* error */}
        {error ? <ErrorState message={error} onRetry={() => void handleRefresh()} /> : null}

        {/* project view */}
        {!isLoading && !error && viewMode === 'projects' ? (
          selectedProject ? (
            <ProjectFiles
              files={files.filter((f) => f.project === selectedProject)}
              onBack={() => setSelectedProject(undefined)}
              onOpen={(id) => router.push({ pathname: '/file/[id]', params: { id } })}
              onMore={setMoreTarget}
              project={selectedProject}
            />
          ) : (
            <ProjectList
              projects={projectNames}
              files={files}
              onSelect={setSelectedProject}
            />
          )
        ) : null}

        {/* keep the project list clear of the floating Ask AI bar */}
        {viewMode === 'projects' ? (
          <View accessibilityElementsHidden importantForAccessibility="no-hide-descendants" style={{ height: listBottomPadding }} />
        ) : null}
      </Screen>

      {/* more sheet */}
      <FileMoreSheet file={moreTarget} onClose={() => setMoreTarget(undefined)} onDelete={(f) => { setDeleteTarget(f); setMoreTarget(undefined); }} />
      {/* delete confirm */}
      <DeleteConfirm file={deleteTarget} isDeleting={isDeleting} onCancel={() => setDeleteTarget(undefined)} onConfirm={() => deleteTarget && void handleDelete(deleteTarget)} />
    </>
  );
}

// ── ProjectList ──────────────────────────────────────────
function ProjectList({ projects, files, onSelect }: { projects: string[]; files: AudioFile[]; onSelect: (p: string) => void }) {
  if (!projects.length) return <EmptyState title="プロジェクトはまだありません" body="録音をプロジェクトに整理すると、ここに表示されます。" />;
  return (
    <View style={homeStyles.projectList}>
      {projects.map((project) => {
        const count = files.filter((f) => f.project === project).length;
        return (
          <Pressable
            accessibilityLabel={`${project}を開く`}
            accessibilityRole="button"
            key={project}
            onPress={() => onSelect(project)}
            style={({ pressed }) => [homeStyles.projectRow, pressed && homeStyles.rowPressed]}
          >
            <View style={homeStyles.projectRowBody}>
              <Text numberOfLines={1} style={homeStyles.projectName}>{project}</Text>
              <NumericText style={homeStyles.projectCount}>{`${count}件の記録`}</NumericText>
            </View>
            <AppIcon color={colors.textSecondary} name="chevron-forward" size={16} />
          </Pressable>
        );
      })}
    </View>
  );
}

// ── ProjectFiles ─────────────────────────────────────────
function ProjectFiles({ files, onBack, onOpen, onMore, project }: { files: AudioFile[]; onBack: () => void; onOpen: (id: string) => void; onMore: (f: AudioFile) => void; project: string }) {
  return (
    <View>
      <View style={homeStyles.projectHeader}>
        <Pressable accessibilityLabel="プロジェクト一覧に戻る" accessibilityRole="button" onPress={onBack} style={homeStyles.backBtn}>
          <AppIcon color={colors.text} name="chevron-back" size={20} />
        </Pressable>
        <View>
          <Text numberOfLines={1} style={homeStyles.projectViewTitle}>{project}</Text>
          <NumericText style={homeStyles.projectCount}>{`${files.length}件の記録`}</NumericText>
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
        <SheetAction
          accessibilityLabel="タイトルを変更"
          icon={<AppIcon color={colors.text} name="create-outline" size={18} />}
          label="タイトルを変更"
          onPress={() => closeThen('rename')}
        />
        <Separator orientation="horizontal" variant="thin" />
        <SheetAction
          accessibilityLabel="削除"
          icon={<AppIcon color={colors.danger} name="trash-outline" size={18} />}
          isDestructive
          label="削除"
          onPress={() => closeThen('delete')}
        />
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
  headerIconButton: { height: 44, marginRight: -spacing.sm, width: 44 },
  listContent: { paddingHorizontal: screenMargin.compact },
  rowPressed: { opacity: 0.62 },

  // projects
  projectList: { borderTopColor: colors.border, borderTopWidth: 1 },
  projectRow: {
    alignItems: 'center',
    borderBottomColor: colors.border,
    borderBottomWidth: 1,
    flexDirection: 'row',
    gap: spacing.md,
    minHeight: 56,
    paddingVertical: spacing.sm,
  },
  projectRowBody: { flex: 1, minWidth: 0 },
  projectName: { color: colors.text, ...textStyles.rowTitle },
  projectCount: { color: colors.textSecondary, marginTop: spacing.xxs, ...textStyles.caption },
  projectHeader: { alignItems: 'center', flexDirection: 'row', gap: spacing.sm, marginBottom: spacing.sm },
  projectViewTitle: { color: colors.text, ...textStyles.sectionTitle },
  backBtn: { alignItems: 'center', height: 44, justifyContent: 'center', marginLeft: -spacing.sm, width: 44 },

  // sheets
  sheetSurface: { backgroundColor: colors.surface, paddingBottom: spacing.xl, paddingHorizontal: spacing.md, paddingTop: spacing.sm, width: '100%' },

  // modal
  modalBackdrop: { alignItems: 'center', backgroundColor: colors.overlay, flex: 1, justifyContent: 'center', padding: spacing.lg },
  modalCard: { backgroundColor: colors.surface, borderRadius: 0, gap: spacing.sm, padding: spacing.lg, width: '100%' },
  modalTitle: { color: colors.text, textAlign: 'center', ...textStyles.callout },
  modalBody: { color: colors.textSecondary, textAlign: 'center', ...textStyles.footnote },
  modalActions: { flexDirection: 'row', gap: spacing.sm, marginTop: spacing.sm },
  modalCancel: { alignItems: 'center', backgroundColor: colors.surfaceAlt, borderRadius: 0, flex: 1, paddingVertical: spacing.md },
  modalDelete: { alignItems: 'center', backgroundColor: colors.danger, borderRadius: 0, flex: 1, paddingVertical: spacing.md },
  modalCancelText: { color: colors.text, ...textStyles.footnoteBold },
  modalDeleteText: { color: colors.surface, ...textStyles.footnoteBold },
  disabled: { opacity: 0.58 },
});
