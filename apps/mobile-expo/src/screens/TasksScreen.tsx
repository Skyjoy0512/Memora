import { AppIcon } from '../components/AppIcon';
import { useFocusEffect, useRouter } from 'expo-router';
import { useCallback, useMemo, useRef, useState } from 'react';
import { Alert, KeyboardAvoidingView, Platform, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { FloatingBottomSheet } from '../components/FloatingBottomSheet';
import { NumericText } from '../components/NumericText';
import { Screen } from '../components/Screen';
import { EmptyState } from '../components/StateViews';
import { MemoraNative } from '../native/MemoraNative';
import type { ProjectDTO, TaskDTO } from '../native/MemoraNative.types';
import { classifyTaskDue, taskDueDateForChoice, type TaskDue } from '../utils/taskDue';
import { colors, spacing, textStyles } from '../design/tokens';

type DueChoice = '今日' | '明日' | '日付を選択';

const dueChoices: DueChoice[] = ['今日', '明日', '日付を選択'];

type Task = {
  completed: boolean;
  due: TaskDue;
  id: string;
  sourceFileId?: string;
  sourceTitle: string;
  title: string;
};

function toScreenTask(
  item: TaskDTO,
  audioTitles: Map<string, string>,
  projectTitles: Map<string, string>,
): Task {
  const sourceFileId = item.sourceAudioFileId ?? undefined;
  const projectTitle = item.projectId ? projectTitles.get(item.projectId) : undefined;
  return {
    completed: item.isCompleted,
    due: classifyTaskDue(item.dueDate),
    id: item.id,
    sourceFileId,
    sourceTitle: sourceFileId
      ? (audioTitles.get(sourceFileId) ?? '録音から抽出')
      : (projectTitle ?? '個人タスク'),
    title: item.title,
  };
}

export function TasksScreen() {
  const router = useRouter();
  const [tasks, setTasks] = useState<Task[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isAddOpen, setIsAddOpen] = useState(false);
  const [isDoneExpanded, setIsDoneExpanded] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [newDue, setNewDue] = useState<DueChoice>('今日');
  const [newProjectId, setNewProjectId] = useState<string | undefined>();
  const [newNotes, setNewNotes] = useState('');
  const [createError, setCreateError] = useState<string | undefined>();
  const [projects, setProjects] = useState<ProjectDTO[]>([]);
  const audioTitlesRef = useRef<Map<string, string>>(new Map());
  const projectTitlesRef = useRef<Map<string, string>>(new Map());
  // 並行取得が起きた場合は、最後に開始した取得の結果だけを採用する。
  const reloadGenerationRef = useRef(0);

  const reload = useCallback(async () => {
    const generation = ++reloadGenerationRef.current;
    try {
      const [taskItems, audioFiles, projects] = await Promise.all([
        MemoraNative.listTasks(),
        MemoraNative.listAudioFiles(),
        MemoraNative.listProjects(),
      ]);
      if (generation !== reloadGenerationRef.current) {
        return;
      }
      const titles = new Map(audioFiles.map((file) => [file.id, file.title] as const));
      const projectTitles = new Map(
        projects.map((project: ProjectDTO) => [project.id, project.title] as const),
      );
      audioTitlesRef.current = titles;
      projectTitlesRef.current = projectTitles;
      setProjects(projects);
      setTasks(taskItems.map((item) => toScreenTask(item, titles, projectTitles)));
    } catch {
      // 取得失敗時は直前の表示を維持する。
    }
  }, []);

  // 初回フォーカスと再フォーカスの両方で再取得する。FileDetail など他画面で
  // 追加・更新されたタスクや、録音・プロジェクトのタイトル変更を、戻ってきた
  // 際に反映する。再取得中はローディング表示へ戻さず既存一覧を維持する
  // （isLoading は初回取得のみを担い、完了時に false へ倒す）。
  useFocusEffect(
    useCallback(() => {
      void reload().finally(() => {
        setIsLoading(false);
      });
    }, [reload]),
  );

  const grouped = useMemo(() => ({
    done: tasks.filter((task) => task.completed),
    overdue: tasks.filter((task) => !task.completed && task.due === '期限切れ'),
    today: tasks.filter((task) => !task.completed && task.due === '今日'),
    upcoming: tasks.filter((task) => !task.completed && task.due === '今後'),
  }), [tasks]);

  const hasOpenTasks =
    grouped.overdue.length + grouped.today.length + grouped.upcoming.length > 0;

  function toggleTask(id: string) {
    const task = tasks.find((item) => item.id === id);
    if (!task) return;
    const completed = !task.completed;
    setTasks((current) => current.map((item) => item.id === id ? { ...item, completed } : item));
    MemoraNative.toggleTask(id, completed)
      .then((updated) => {
        if (updated) {
          setTasks((current) => current.map((item) =>
            item.id === id ? toScreenTask(updated, audioTitlesRef.current, projectTitlesRef.current) : item
          ));
        }
      })
      .catch(() => {
        setTasks((current) => current.map((item) =>
          item.id === id ? { ...item, completed: !completed } : item
        ));
      });
  }

  async function addTask() {
    const title = newTitle.trim();
    if (!title) {
      setCreateError('タスク名を入力してください。');
      return;
    }
    const notes = newNotes.trim();
    const task: TaskDTO = {
      id: `task-${Date.now()}`,
      title,
      priority: 'medium',
      isCompleted: false,
      createdAt: new Date().toISOString(),
      dueDate: taskDueDateForChoice(newDue),
      ...(newProjectId ? { projectId: newProjectId } : {}),
      ...(notes ? { notes } : {}),
    };
    try {
      const created = await MemoraNative.createTask(task);
      if (created) {
        setTasks((current) => [...current, toScreenTask(created, audioTitlesRef.current, projectTitlesRef.current)]);
      }
    } catch {
      // 永続化に失敗してもシートを閉じて入力を破棄する。
    } finally {
      closeAddSheet();
    }
  }

  function closeAddSheet() {
    setNewTitle('');
    setNewDue('今日');
    setNewProjectId(undefined);
    setNewNotes('');
    setCreateError(undefined);
    setIsAddOpen(false);
  }

  const openSource = (id: string) => router.push({ pathname: '/file/[id]', params: { id } });

  return (
    <Screen title="タスク">
      <View style={styles.content}>
        {isLoading ? null : !hasOpenTasks && grouped.done.length === 0 ? (
          <EmptyState
            actionLabel="タスクを追加"
            body="記録から抽出されたタスクと、手動で追加したタスクがここに表示されます。"
            onAction={() => setIsAddOpen(true)}
            title="未完了のタスクはありません"
          />
        ) : (
          <>
            <TaskGroup label="期限切れ" onOpenSource={openSource} onToggle={toggleTask} tasks={grouped.overdue} />
            <TaskGroup label="今日" onOpenSource={openSource} onToggle={toggleTask} tasks={grouped.today} />
            <TaskGroup label="今後" onOpenSource={openSource} onToggle={toggleTask} tasks={grouped.upcoming} />

            <Pressable
              accessibilityLabel="タスクを追加"
              accessibilityRole="button"
              onPress={() => setIsAddOpen(true)}
              style={({ pressed }) => [styles.settingRow, pressed && styles.rowPressed]}
            >
              <Text style={styles.settingLabel}>タスクを追加</Text>
              <AppIcon color={colors.textSecondary} name="add" size={20} />
            </Pressable>

            {grouped.done.length ? (
              <View>
                <Pressable
                  accessibilityRole="button"
                  accessibilityState={{ expanded: isDoneExpanded }}
                  onPress={() => setIsDoneExpanded((expanded) => !expanded)}
                  style={({ pressed }) => [styles.settingRow, pressed && styles.rowPressed]}
                >
                  <Text style={styles.settingLabel}>完了</Text>
                  <View style={styles.settingValue}>
                    <NumericText style={styles.settingCount}>{`${grouped.done.length}`}</NumericText>
                    <AppIcon
                      color={colors.textSecondary}
                      name="chevron-forward"
                      size={16}
                      style={{ transform: [{ rotate: isDoneExpanded ? '90deg' : '0deg' }] }}
                    />
                  </View>
                </Pressable>
                {isDoneExpanded ? (
                  <TaskGroup onOpenSource={openSource} onToggle={toggleTask} tasks={grouped.done} />
                ) : null}
              </View>
            ) : null}
          </>
        )}
      </View>

      <FloatingBottomSheet isOpen={isAddOpen} onClose={closeAddSheet}>
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          {/* Open Design v2 `task-create`: ラベル + 枠付きコントロールを 24pt 間隔で積む */}
          <View style={styles.sheetContent}>
            <Text style={styles.sheetTitle}>タスクを追加</Text>

            <View style={styles.formField}>
              <Text style={styles.fieldLabel}>タスク名</Text>
              <TextInput
                accessibilityLabel="タスク名"
                autoFocus
                onChangeText={(value: string) => {
                  setNewTitle(value);
                  if (createError) setCreateError(undefined);
                }}
                onSubmitEditing={addTask}
                placeholder="対応することを入力"
                placeholderTextColor={colors.accentMuted}
                returnKeyType="done"
                style={styles.formControl}
                value={newTitle}
              />
            </View>

            <View style={styles.formField}>
              <Text style={styles.fieldLabel}>プロジェクト</Text>
              <View style={styles.choiceList}>
                <ChoiceRow
                  isSelected={!newProjectId}
                  label="未設定"
                  onPress={() => setNewProjectId(undefined)}
                />
                {projects.map((project) => (
                  <ChoiceRow
                    isSelected={newProjectId === project.id}
                    key={project.id}
                    label={project.title}
                    onPress={() => setNewProjectId(project.id)}
                  />
                ))}
              </View>
            </View>

            <View style={styles.formField}>
              <Text style={styles.fieldLabel}>期限</Text>
              <View style={styles.choiceList}>
                {dueChoices.map((choice) => (
                  <ChoiceRow
                    isSelected={newDue === choice}
                    key={choice}
                    label={choice}
                    onPress={() => {
                      if (choice === '日付を選択') {
                        Alert.alert('日付を選択', 'この操作は現在利用できません。');
                        return;
                      }
                      setNewDue(choice);
                    }}
                  />
                ))}
              </View>
            </View>

            <View style={styles.formField}>
              <Text style={styles.fieldLabel}>メモ</Text>
              <TextInput
                accessibilityLabel="メモ"
                multiline
                onChangeText={setNewNotes}
                placeholder="必要な情報を追加"
                placeholderTextColor={colors.accentMuted}
                style={[styles.formControl, styles.formControlMultiline]}
                value={newNotes}
              />
            </View>

            {createError ? (
              <View style={styles.formAlert}>
                <Text style={styles.formAlertText}>{createError}</Text>
              </View>
            ) : null}

            <Pressable
              accessibilityLabel="タスクを追加する"
              accessibilityRole="button"
              onPress={addTask}
              style={({ pressed }) => [styles.primaryAction, pressed && styles.rowPressed]}
            >
              <Text style={styles.primaryActionText}>タスクを追加</Text>
            </Pressable>
          </View>
        </KeyboardAvoidingView>
      </FloatingBottomSheet>
    </Screen>
  );
}

/** フォーム内の単一選択。行 + 右端のチェックで、面や色を増やさずに選択を示す。 */
function ChoiceRow({
  isSelected,
  label,
  onPress,
}: {
  isSelected: boolean;
  label: string;
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityLabel={label}
      accessibilityRole="radio"
      accessibilityState={{ selected: isSelected }}
      onPress={onPress}
      style={({ pressed }) => [styles.choiceRow, pressed && styles.rowPressed]}
    >
      <Text style={[styles.choiceLabel, isSelected && styles.choiceLabelSelected]}>{label}</Text>
      {isSelected ? <AppIcon color={colors.text} name="checkmark" size={16} /> : null}
    </Pressable>
  );
}

/**
 * Open Design v2 の `.task-group` / `.task-row`。
 * チェックは 44pt のタップ領域に 18pt の正方形。完了行は面で沈める。
 */
function TaskGroup({ label, onOpenSource, onToggle, tasks }: { label?: string; onOpenSource: (id: string) => void; onToggle: (id: string) => void; tasks: Task[] }) {
  if (!tasks.length) return null;
  return (
    <View>
      {label ? <Text style={styles.groupLabel}>{label}</Text> : null}
      {tasks.map((task) => (
        <View key={task.id} style={[styles.taskRow, task.completed && styles.taskRowDone]}>
          <Pressable
            accessibilityLabel={task.completed ? '未完了に戻す' : '完了にする'}
            accessibilityRole="checkbox"
            accessibilityState={{ checked: task.completed }}
            onPress={() => onToggle(task.id)}
            style={styles.check}
          >
            <View style={[styles.checkBox, task.completed && styles.checkBoxOn]}>
              {task.completed ? <AppIcon color={colors.surface} name="checkmark" size={14} /> : null}
            </View>
          </Pressable>
          <View style={styles.taskBody}>
            <Text style={[styles.taskTitle, task.completed && styles.taskTitleCompleted]}>{task.title}</Text>
            <View style={styles.metaRow}>
              <Text style={styles.metaPrefix}>出典: </Text>
              {task.sourceFileId ? (
                <Pressable
                  accessibilityLabel={`${task.sourceTitle}を開く`}
                  accessibilityRole="link"
                  hitSlop={8}
                  onPress={() => onOpenSource(task.sourceFileId!)}
                  style={({ pressed }) => [styles.sourceShrink, pressed && styles.rowPressed]}
                >
                  <Text numberOfLines={1} style={styles.sourceLink}>{task.sourceTitle}</Text>
                </Pressable>
              ) : (
                <Text numberOfLines={1} style={[styles.metaText, styles.sourceShrink]}>{task.sourceTitle}</Text>
              )}
              <Text style={styles.metaText}>{` · ${task.due}`}</Text>
            </View>
          </View>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  content: { gap: spacing.xxl },
  groupLabel: { color: colors.textSecondary, marginBottom: spacing.xs, ...textStyles.label },
  rowPressed: { opacity: 0.62 },

  // rows
  taskRow: {
    alignItems: 'flex-start',
    borderBottomColor: colors.border,
    borderBottomWidth: 1,
    flexDirection: 'row',
    minHeight: 76,
  },
  taskRowDone: { backgroundColor: colors.surfaceAlt },
  check: { alignItems: 'center', height: 44, justifyContent: 'center', marginTop: spacing.xs, width: 44 },
  checkBox: {
    alignItems: 'center',
    borderColor: colors.borderLight,
    borderRadius: 0,
    borderWidth: 1,
    height: 18,
    justifyContent: 'center',
    width: 18,
  },
  checkBoxOn: { backgroundColor: colors.accent, borderColor: colors.accent },
  taskBody: { flex: 1, paddingBottom: spacing.sm, paddingTop: spacing.sm },
  taskTitle: { color: colors.text, ...textStyles.rowTitle },
  taskTitleCompleted: { color: colors.textSecondary, textDecorationLine: 'line-through' },
  metaRow: { alignItems: 'center', flexDirection: 'row', marginTop: spacing.xxs },
  metaPrefix: { color: colors.textSecondary, ...textStyles.footnote },
  metaText: { color: colors.textSecondary, ...textStyles.footnote },
  sourceShrink: { flexShrink: 1 },
  sourceLink: { color: colors.textSecondary, textDecorationLine: 'underline', ...textStyles.footnote },

  // setting-row style actions
  settingRow: {
    alignItems: 'center',
    borderBottomColor: colors.border,
    borderBottomWidth: 1,
    borderTopColor: colors.border,
    borderTopWidth: 1,
    flexDirection: 'row',
    justifyContent: 'space-between',
    minHeight: 56,
  },
  settingLabel: { color: colors.text, ...textStyles.footnote },
  settingValue: { alignItems: 'center', flexDirection: 'row', gap: spacing.xs },
  settingCount: { color: colors.textSecondary, ...textStyles.footnote },

  // add sheet
  sheetContent: {
    backgroundColor: colors.surface,
    borderRadius: 0,
    gap: spacing.xl,
    marginBottom: spacing.xl,
    marginHorizontal: spacing.md,
    padding: spacing.lg,
  },
  sheetTitle: { color: colors.text, ...textStyles.sectionTitle },
  formField: { gap: spacing.xxs },
  fieldLabel: { color: colors.textSecondary, ...textStyles.label },
  formControl: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 0,
    borderWidth: 1,
    color: colors.text,
    minHeight: 44,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
    ...textStyles.footnote,
  },
  formControlMultiline: { minHeight: 96, textAlignVertical: 'top' },
  choiceList: { borderTopColor: colors.border, borderTopWidth: 1 },
  choiceRow: {
    alignItems: 'center',
    borderBottomColor: colors.border,
    borderBottomWidth: 1,
    flexDirection: 'row',
    gap: spacing.sm,
    justifyContent: 'space-between',
    minHeight: 44,
    paddingVertical: spacing.xs,
  },
  choiceLabel: { color: colors.textSecondary, flexShrink: 1, ...textStyles.footnote },
  choiceLabelSelected: { color: colors.text },
  formAlert: { borderLeftColor: colors.text, borderLeftWidth: 2, paddingLeft: spacing.sm },
  formAlertText: { color: colors.text, ...textStyles.footnote },
  primaryAction: {
    alignItems: 'center',
    backgroundColor: colors.accent,
    borderRadius: 0,
    justifyContent: 'center',
    minHeight: 44,
  },
  primaryActionText: { color: colors.textInverse, ...textStyles.footnoteBold },
});
