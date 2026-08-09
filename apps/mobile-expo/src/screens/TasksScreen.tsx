import { AppIcon } from '../components/AppIcon';
import { Button } from 'heroui-native/button';
import { Checkbox } from 'heroui-native/checkbox';
import { Input } from 'heroui-native/input';
import { RadioGroup } from 'heroui-native/radio-group';
import { useRouter } from 'expo-router';
import { useMemo, useState } from 'react';
import { Alert, KeyboardAvoidingView, Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import { FloatingBottomSheet } from '../components/FloatingBottomSheet';
import { Screen } from '../components/Screen';
import { EmptyState } from '../components/StateViews';
import { colors, radius, spacing, textStyles } from '../design/tokens';

type DueChoice = '今日' | '明日' | '日付を選択';

const dueChoices: DueChoice[] = ['今日', '明日', '日付を選択'];

type Task = {
  completed: boolean;
  due: '期限切れ' | '今日' | '今後';
  id: string;
  sourceFileId?: string;
  sourceTitle: string;
  title: string;
};

const initialTasks: Task[] = [
  { completed: false, due: '期限切れ', id: 'task-1', sourceFileId: 'meet-sales-sync', sourceTitle: 'プロダクト定例', title: '見積もりの修正版を送る' },
  { completed: false, due: '今日', id: 'task-2', sourceFileId: 'weekly-growth-0709', sourceTitle: '顧客ミーティング', title: '来週のデモ日程を共有する' },
  { completed: false, due: '今後', id: 'task-3', sourceFileId: 'plaud-import-test', sourceTitle: '採用面談', title: '次回面談の質問事項をまとめる' },
  { completed: true, due: '今日', id: 'task-4', sourceTitle: '週次レビュー', title: '会議資料をチームに共有する' },
];

export function TasksScreen() {
  const router = useRouter();
  const [tasks, setTasks] = useState(initialTasks);
  const [isAddOpen, setIsAddOpen] = useState(false);
  const [isDoneExpanded, setIsDoneExpanded] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [newDue, setNewDue] = useState<DueChoice>('今日');

  const grouped = useMemo(() => ({
    done: tasks.filter((task) => task.completed),
    overdue: tasks.filter((task) => !task.completed && task.due === '期限切れ'),
    today: tasks.filter((task) => !task.completed && task.due === '今日'),
    upcoming: tasks.filter((task) => !task.completed && task.due === '今後'),
  }), [tasks]);

  function toggleTask(id: string) {
    setTasks((current) => current.map((task) => task.id === id ? { ...task, completed: !task.completed } : task));
  }

  function addTask() {
    const title = newTitle.trim();
    if (!title) return;
    const due: Task['due'] = newDue === '今日' ? '今日' : '今後';
    setTasks((current) => [...current, { completed: false, due, id: `task-${Date.now()}`, sourceTitle: '個人タスク', title }]);
    closeAddSheet();
  }

  function closeAddSheet() {
    setNewTitle('');
    setNewDue('今日');
    setIsAddOpen(false);
  }

  return (
    <Screen
      headerAccessory={
        <Button
          accessibilityLabel="タスクを追加"
          feedbackVariant="none"
          isIconOnly
          onPress={() => setIsAddOpen(true)}
          size="md"
          variant="ghost"
          style={{ height: 44, marginRight: -spacing.sm, width: 44 }}
        >
          <AppIcon color={colors.text} name="add" size={25} />
        </Button>
      }
      title="タスク"
    >
      <View style={styles.content}>
        {tasks.length === 0 ? (
          <EmptyState
            actionLabel="タスクを追加"
            body="記録から抽出されたアクションがここに表示されます。「+」から手動で追加することもできます。"
            onAction={() => setIsAddOpen(true)}
            title="タスクはまだありません"
          />
        ) : (
          <>
            <TaskGroup color={colors.warning} label="期限切れ" onOpenSource={(id) => router.push({ pathname: '/file/[id]', params: { id } })} onToggle={toggleTask} tasks={grouped.overdue} />
            <TaskGroup color={colors.textTertiary} label="今日" onOpenSource={(id) => router.push({ pathname: '/file/[id]', params: { id } })} onToggle={toggleTask} tasks={grouped.today} />
            <TaskGroup color={colors.textTertiary} label="今後" onOpenSource={(id) => router.push({ pathname: '/file/[id]', params: { id } })} onToggle={toggleTask} tasks={grouped.upcoming} />

            {grouped.done.length ? (
              <View style={styles.doneGroup}>
                <Pressable accessibilityRole="button" accessibilityState={{ expanded: isDoneExpanded }} onPress={() => setIsDoneExpanded((expanded) => !expanded)} style={({ pressed }) => [styles.doneButton, pressed && styles.doneButtonPressed]}>
                  <Text style={styles.groupLabel}>完了（{grouped.done.length}）</Text>
                  <AppIcon color={colors.textTertiary} name="chevron-down" size={12} style={{ transform: [{ rotate: isDoneExpanded ? '0deg' : '-90deg' }] }} />
                </Pressable>
                {isDoneExpanded ? <TaskGroup color={colors.textTertiary} onOpenSource={(id) => router.push({ pathname: '/file/[id]', params: { id } })} onToggle={toggleTask} tasks={grouped.done} /> : null}
              </View>
            ) : null}
          </>
        )}
      </View>

      <FloatingBottomSheet isOpen={isAddOpen} onClose={closeAddSheet}>
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          <View style={styles.sheetContent}>
            <Text style={styles.sheetTitle}>タスクを追加</Text>
            <Text style={styles.fieldLabel}>内容</Text>
            <Input
              accessibilityLabel="タスクの内容"
              autoFocus
              onChangeText={setNewTitle}
              onSubmitEditing={addTask}
              placeholder="タスクの内容"
              placeholderTextColor={colors.textTertiary}
              returnKeyType="done"
              style={styles.input}
              value={newTitle}
            />

            <Text style={styles.fieldLabel}>期限</Text>
            <RadioGroup
              onValueChange={(value) => {
                if (value === '日付を選択') {
                  Alert.alert('日付を選択', 'この操作は現在利用できません。');
                  return;
                }
                setNewDue(value as DueChoice);
              }}
              value={newDue}
            >
              {dueChoices.map((choice) => (
                <RadioGroup.Item key={choice} value={choice}>
                  {choice}
                </RadioGroup.Item>
              ))}
            </RadioGroup>

            <Text style={styles.fieldLabel}>プロジェクト</Text>
            <View style={styles.projectRow}>
              <Text style={styles.projectText}>個人タスク</Text>
            </View>

            <Button
              accessibilityLabel="タスクを追加する"
              isDisabled={!newTitle.trim()}
              onPress={addTask}
              variant="primary"
              style={{ marginTop: spacing.lg, borderRadius: radius.sm }}
            >
              <AppIcon color={colors.textInverse} name="add" size={18} />
              <Button.Label>追加する</Button.Label>
            </Button>
          </View>
        </KeyboardAvoidingView>
      </FloatingBottomSheet>
    </Screen>
  );
}

function TaskGroup({ color, label, onOpenSource, onToggle, tasks }: { color: string; label?: string; onOpenSource: (id: string) => void; onToggle: (id: string) => void; tasks: Task[] }) {
  if (!tasks.length) return null;
  return (
    <View style={styles.group}>
      {label ? <Text style={[styles.groupLabel, { color }]}>{label}</Text> : null}
      {tasks.map((task) => (
        <View key={task.id} style={styles.taskRow}>
          <Checkbox
            accessibilityLabel={task.title}
            isSelected={task.completed}
            onSelectedChange={() => onToggle(task.id)}
            variant="primary"
          />
          <View style={styles.taskBody}>
            <Text style={[styles.taskTitle, task.completed && styles.taskTitleCompleted]}>{task.title}</Text>
            <View style={styles.metaRow}>
              {task.sourceFileId ? (
                <Pressable accessibilityLabel={`${task.sourceTitle}を開く`} accessibilityRole="link" hitSlop={4} onPress={() => onOpenSource(task.sourceFileId!)} style={({ pressed }) => [styles.sourceShrink, pressed && styles.sourceLinkPressed]}>
                  <Text numberOfLines={1} style={styles.sourceLink}>{task.sourceTitle}</Text>
                </Pressable>
              ) : <Text numberOfLines={1} style={[styles.sourceText, styles.sourceShrink]}>{task.sourceTitle}</Text>}
              <View style={styles.metaDot} />
              <Text style={[styles.dueBadge, { color: task.due === '期限切れ' ? colors.warning : colors.textTertiary }]}>{task.due}</Text>
            </View>
          </View>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  content: { gap: spacing.lg },
  doneButton: { alignItems: 'center', flexDirection: 'row', gap: spacing.xs, minHeight: 44 },
  doneGroup: { gap: spacing.sm },
  group: { gap: spacing.sm },
  groupLabel: { ...textStyles.captionBold },
  input: {
    backgroundColor: colors.surface,
    borderRadius: radius.sm,
    color: colors.text,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.md,
    ...textStyles.body,
  },
  doneButtonPressed: { opacity: 0.6 },
  sheetContent: {
    backgroundColor: colors.surface,
    borderRadius: radius.sm,
    marginBottom: spacing.xl,
    marginHorizontal: spacing.md,
    minHeight: 340,
    padding: spacing.lg,
  },
  sheetTitle: { color: colors.text, marginBottom: spacing.md, ...textStyles.callout },
  fieldLabel: { color: colors.textSecondary, marginBottom: spacing.xs, marginTop: spacing.md, ...textStyles.captionBold },
  projectRow: { backgroundColor: colors.surfaceAlt, borderRadius: radius.sm, paddingHorizontal: spacing.md, paddingVertical: spacing.md },
  projectText: { color: colors.text, ...textStyles.body },
  metaRow: { alignItems: 'center', flexDirection: 'row', gap: 6, marginTop: 3 },
  metaDot: { backgroundColor: colors.textTertiary, borderRadius: 1.5, height: 3, width: 3 },
  sourceShrink: { flexShrink: 1 },
  sourceLink: { color: colors.textTertiary, textDecorationLine: 'underline', ...textStyles.caption },
  sourceLinkPressed: { opacity: 0.6 },
  sourceText: { color: colors.textTertiary, ...textStyles.caption },
  dueBadge: { ...textStyles.captionBold },
  taskBody: { flex: 1 },
  taskRow: { borderBottomColor: colors.borderLight, borderBottomWidth: 1, flexDirection: 'row', gap: spacing.md, minHeight: 44, paddingVertical: 14 },
  taskTitle: { color: colors.text, ...textStyles.body },
  taskTitleCompleted: { color: colors.textTertiary, textDecorationLine: 'line-through' },
});
