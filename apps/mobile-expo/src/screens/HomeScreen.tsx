import { AppIcon as Ionicons } from '../components/AppIcon';
import { useFocusEffect, useRouter } from 'expo-router';
import * as DocumentPicker from 'expo-document-picker';
import { useCallback, useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Modal,
  Pressable,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { SearchBar } from '../components/SearchBar';
import { SegmentedControl } from '../components/SegmentedControl';
import { FileCard } from '../components/FileCard';
import { FileCardSkeleton } from '../components/FileCardSkeleton';
import { DateSeparator } from '../components/DateSeparator';
import { OfflineBanner } from '../components/OfflineBanner';
import { Screen } from '../components/Screen';
import { FloatingBottomSheet } from '../components/FloatingBottomSheet';
import { SheetCard } from '../components/SheetCard';
import { EmptyState, ErrorState } from '../components/StateViews';
import { colors, radius, spacing } from '../design/tokens';
import { useCaptureFlow } from '../features/capture/CaptureFlowProvider';
import { useAudioFiles } from '../features/files/useAudioFiles';
import { MemoraNative } from '../native/MemoraNative';
import type { AudioFile } from '../types/memora';

type HomeSegment = 'all' | 'favorites' | 'projects';
const segmentItems: Array<{ key: HomeSegment; label: string }> = [
  { key: 'all', label: 'すべて' },
  { key: 'favorites', label: 'お気に入り' },
  { key: 'projects', label: 'プロジェクト' },
];

export function HomeScreen() {
  const router = useRouter();
  const { data: files, error, isLoading, refresh, removeAudioFile, upsertAudioFile } = useAudioFiles();
  const capture = useCaptureFlow();

  const [segment, setSegment] = useState<HomeSegment>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [bridgeError, setBridgeError] = useState<string | undefined>();
  const [moreTarget, setMoreTarget] = useState<AudioFile | undefined>();
  const [deleteTarget, setDeleteTarget] = useState<AudioFile | undefined>();
  const [isDeleting, setIsDeleting] = useState(false);
  const [isImporting, setIsImporting] = useState(false);
  const [selectedProject, setSelectedProject] = useState<string | undefined>();

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
  const projectNames = [...new Set(files.map((f) => f.project).filter(Boolean))] as string[];

  return (
    <>
      <Screen
        refreshControl={<RefreshControl colors={[colors.accent]} onRefresh={handleRefresh} refreshing={isRefreshing} tintColor={colors.accent} />}
        titleContent={<Text style={homeStyles.screenTitle}>Memora</Text>}
        headerAccessory={
          <View style={homeStyles.headerActions}>
            <Pressable
              accessibilityLabel="音声ファイルを読み込む"
              accessibilityRole="button"
              disabled={isImporting}
              onPress={() => void handleImport()}
              style={({ pressed }) => [homeStyles.headerBtn, (pressed || isImporting) && homeStyles.pressed]}
            >
              {isImporting ? <ActivityIndicator color={colors.accent} size="small" /> : <Ionicons color={colors.text} name="attach-outline" size={20} />}
            </Pressable>
            <Pressable
              accessibilityLabel="設定"
              accessibilityRole="button"
              onPress={() => router.push('/settings')}
              style={({ pressed }) => [homeStyles.headerBtn, pressed && homeStyles.pressed]}
            >
              <Ionicons color={colors.text} name="settings-outline" size={20} />
            </Pressable>
          </View>
        }
      >
        {/* search */}
        <SearchBar value={searchQuery} onChangeText={setSearchQuery} />

        {/* segment */}
        <SegmentedControl segments={segmentItems} selected={segment} onSelect={setSegment} />

        {/* offline */}
        {bridgeError ? <OfflineBanner message={bridgeError} /> : null}

        {/* error */}
        {error ? <ErrorState message={error} onRetry={() => void handleRefresh()} /> : null}

        {/* loading */}
        {isLoading ? <FileCardSkeleton count={5} /> : null}

        {/* empty — first time */}
        {isEmpty && !isLoading && !error ? (
          <View style={homeStyles.emptyActions}>
            <EmptyState
              title="最初の記録を残してみましょう"
              body="タブバーの + から録音、またはファイルを取り込めます"
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
              {isImporting ? <ActivityIndicator color={colors.accent} size="small" /> : <Ionicons color={colors.accent} name="attach-outline" size={18} />}
              <Text style={homeStyles.importEmptyActionText}>{isImporting ? '読み込み中…' : '音声ファイルを読み込む'}</Text>
            </Pressable>
          </View>
        ) : null}

        {/* empty — search */}
        {isSearchEmpty ? (
          <EmptyState title="一致する記録はありません" body="別のキーワードで試してみてください" />
        ) : null}

        {/* project view */}
        {!isLoading && !error && segment === 'projects' && files.length > 0 ? (
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

        {/* file list */}
        {!isLoading && !error && segment !== 'projects' && !isEmpty && !isSearchEmpty ? (
          grouped.map((group) => (
            <View key={group.label}>
              <DateSeparator date={group.label} />
              {group.files.map((file) => (
                <FileCard
                  key={file.id}
                  file={file}
                  onPress={() => router.push({ pathname: '/file/[id]', params: { id: file.id } })}
                  onMore={() => setMoreTarget(file)}
                  showSummary={!searchQuery.trim()}
                />
              ))}
            </View>
          ))
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
            <View style={[homeStyles.projectAvatar, { backgroundColor: ['#1A7F6B', '#5F6368', '#9AA0A6', '#3C4043'][i % 4] }]}>
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
          <Ionicons color={colors.text} name="chevron-back" size={18} />
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
      <SheetCard style={homeStyles.sheet}>
        <Pressable accessibilityRole="button" onPress={() => closeThen('rename')} style={({ pressed }) => [homeStyles.sheetRow, pressed && homeStyles.sheetRowPressed]}>
          <Ionicons color={colors.text} name="create-outline" size={18} />
          <Text style={homeStyles.sheetRowText}>タイトルを変更</Text>
        </Pressable>
        <Pressable accessibilityRole="button" onPress={() => closeThen('delete')} style={({ pressed }) => [homeStyles.sheetRow, pressed && homeStyles.sheetRowPressed]}>
          <Ionicons color={colors.danger} name="trash-outline" size={18} />
          <Text style={homeStyles.sheetDeleteText}>削除</Text>
        </Pressable>
      </SheetCard>
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
  screenTitle: { color: colors.text, fontSize: 30, fontWeight: '700', letterSpacing: -0.4 },
  headerActions: { flexDirection: 'row' },
  headerBtn: { alignItems: 'center', height: 44, justifyContent: 'center', width: 44 },
  pressed: { opacity: 0.62, transform: [{ scale: 0.93 }] },
  emptyActions: { gap: spacing.sm },
  importEmptyAction: { alignItems: 'center', borderColor: colors.accent, borderRadius: radius.md, borderWidth: 1, flexDirection: 'row', gap: spacing.xs, justifyContent: 'center', marginTop: -spacing.xs, minHeight: 44, paddingHorizontal: spacing.lg },
  importEmptyActionText: { color: colors.accent, fontSize: 14, fontWeight: '600' },

  // projects
  projectsGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  projectCard: { borderColor: colors.borderLight, borderRadius: radius.md, borderWidth: 1, gap: 28, padding: spacing.md, width: '48%' },
  cardPressed: { opacity: 0.76, transform: [{ scale: 0.97 }] },
  projectAvatar: { alignItems: 'center', borderRadius: radius.sm, height: 26, justifyContent: 'center', width: 26 },
  projectAvatarText: { color: colors.surface, fontSize: 12, fontWeight: '700' },
  projectName: { color: colors.text, fontSize: 14, fontWeight: '600' },
  projectCount: { color: colors.textTertiary, fontSize: 12, marginTop: 2 },
  projectView: { gap: spacing.xs },
  projectHeader: { alignItems: 'center', flexDirection: 'row', gap: spacing.sm, marginBottom: spacing.sm },
  projectViewTitle: { color: colors.text, fontSize: 17, fontWeight: '700' },
  backBtn: { alignItems: 'center', height: 44, justifyContent: 'center', marginLeft: -spacing.sm, width: 44 },

  // sheets
  sheet: { gap: spacing.xs, paddingBottom: spacing.md, paddingHorizontal: spacing.md, paddingTop: spacing.sm },
  sheetRow: { alignItems: 'center', backgroundColor: 'rgba(255,255,255,0.86)', borderRadius: radius.md, flexDirection: 'row', gap: spacing.sm, minHeight: 50, paddingHorizontal: spacing.md },
  sheetRowText: { color: colors.text, flex: 1, fontSize: 15, fontWeight: '500' },
  sheetDeleteText: { color: colors.danger, flex: 1, fontSize: 15, fontWeight: '500' },
  sheetRowPressed: { opacity: 0.72, transform: [{ scale: 0.985 }] },

  // modal
  modalBackdrop: { alignItems: 'center', backgroundColor: colors.overlay, flex: 1, justifyContent: 'center', padding: spacing.lg },
  modalCard: { backgroundColor: colors.surface, borderRadius: radius.lg, gap: spacing.sm, padding: spacing.lg, width: '100%' },
  modalTitle: { color: colors.text, fontSize: 16, fontWeight: '700', textAlign: 'center' },
  modalBody: { color: colors.textSecondary, fontSize: 13, lineHeight: 19, textAlign: 'center' },
  modalActions: { flexDirection: 'row', gap: spacing.sm, marginTop: spacing.sm },
  modalCancel: { alignItems: 'center', backgroundColor: colors.surfaceAlt, borderRadius: radius.md, flex: 1, paddingVertical: spacing.md },
  modalDelete: { alignItems: 'center', backgroundColor: colors.danger, borderRadius: radius.md, flex: 1, paddingVertical: spacing.md },
  modalCancelText: { color: colors.text, fontSize: 14, fontWeight: '600' },
  modalDeleteText: { color: colors.surface, fontSize: 14, fontWeight: '600' },
  disabled: { opacity: 0.58 },
});
