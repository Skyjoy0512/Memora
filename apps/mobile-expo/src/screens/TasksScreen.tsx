import { AppIcon } from '../components/AppIcon';
import { useRouter } from 'expo-router';
import { useMemo, useState } from 'react';
import { Alert, KeyboardAvoidingView, Platform, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { FloatingBottomSheet } from '../components/FloatingBottomSheet';
import { Screen } from '../components/Screen';
import { SheetCard } from '../components/SheetCard';
import { EmptyState } from '../components/StateViews';
import { colors, radius, spacing } from '../design/tokens';

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
      headerAccessory={<Pressable accessibilityLabel="タスクを追加" accessibilityRole="button" hitSlop={6} onPress={() => setIsAddOpen(true)} style={({ pressed }) => [styles.headerAddButton, pressed && styles.pressed]}><AppIcon color={colors.text} name="add" size={25} /></Pressable>}
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
            <TaskGroup color={colors.accent} label="期限切れ" onOpenSource={(id) => router.push({ pathname: '/file/[id]', params: { id } })} onToggle={toggleTask} tasks={grouped.overdue} />
            <TaskGroup color={colors.textTertiary} label="今日" onOpenSource={(id) => router.push({ pathname: '/file/[id]', params: { id } })} onToggle={toggleTask} tasks={grouped.today} />
            <TaskGroup color={colors.textTertiary} label="今後" onOpenSource={(id) => router.push({ pathname: '/file/[id]', params: { id } })} onToggle={toggleTask} tasks={grouped.upcoming} />

            {grouped.done.length ? (
              <View style={styles.doneGroup}>
                <Pressable accessibilityRole="button" accessibilityState={{ expanded: isDoneExpanded }} onPress={() => setIsDoneExpanded((expanded) => !expanded)} style={styles.doneButton}>
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
          <SheetCard style={styles.sheet}>
            <Text style={styles.sheetTitle}>タスクを追加</Text>
            <Text style={styles.fieldLabel}>内容</Text>
            <TextInput accessibilityLabel="タスクの内容" autoFocus onChangeText={setNewTitle} onSubmitEditing={addTask} placeholder="タスクの内容" placeholderTextColor={colors.textTertiary} returnKeyType="done" style={styles.input} value={newTitle} />

            <Text style={styles.fieldLabel}>期限</Text>
            <View style={styles.dueRow}>
              {dueChoices.map((choice) => {
                const isActive = newDue === choice;
                return (
                  <Pressable
                    accessibilityRole="radio"
                    accessibilityState={{ checked: isActive }}
                    key={choice}
                    onPress={() => {
                      if (choice === '日付を選択') {
                        Alert.alert('日付を選択', 'この操作は現在利用できません。');
                        return;
                      }
                      setNewDue(choice);
                    }}
                    style={[styles.dueChip, isActive && styles.dueChipActive]}
                  >
                    <Text style={[styles.dueChipText, isActive && styles.dueChipTextActive]}>{choice}</Text>
                  </Pressable>
                );
              })}
            </View>

            <Text style={styles.fieldLabel}>プロジェクト</Text>
            <View style={styles.projectRow}>
              <Text style={styles.projectText}>個人タスク</Text>
            </View>

            <Pressable accessibilityRole="button" onPress={addTask} style={({ pressed }) => [styles.saveButton, pressed && styles.pressed]}>
              <AppIcon color="#FFFFFF" name="add" size={18} />
              <Text style={styles.saveButtonText}>追加する</Text>
            </Pressable>
          </SheetCard>
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
          <Pressable accessibilityLabel={task.title} accessibilityRole="checkbox" accessibilityState={{ checked: task.completed }} onPress={() => onToggle(task.id)} style={[styles.checkbox, task.completed && styles.checkboxCompleted]}>
            {task.completed ? <AppIcon color="#FFFFFF" name="checkmark" size={13} /> : null}
          </Pressable>
          <View style={styles.taskBody}>
            <Text style={[styles.taskTitle, task.completed && styles.taskTitleCompleted]}>{task.title}</Text>
            <View style={styles.metaRow}>
              {task.sourceFileId ? (
                <Pressable accessibilityLabel={`${task.sourceTitle}を開く`} accessibilityRole="link" hitSlop={4} onPress={() => onOpenSource(task.sourceFileId!)} style={styles.sourceShrink}>
                  <Text numberOfLines={1} style={styles.sourceLink}>{task.sourceTitle}</Text>
                </Pressable>
              ) : <Text numberOfLines={1} style={[styles.sourceText, styles.sourceShrink]}>{task.sourceTitle}</Text>}
              <View style={styles.metaDot} />
              <Text style={[styles.dueBadge, { color: task.due === '期限切れ' ? colors.accent : colors.textTertiary }]}>{task.due}</Text>
            </View>
          </View>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  headerAddButton: { alignItems: 'center', height: 44, justifyContent: 'center', marginRight: -spacing.sm, width: 44 },
  checkbox: { alignItems: 'center', borderColor: colors.border, borderRadius: 11, borderWidth: 1.6, height: 22, justifyContent: 'center', marginTop: 1, width: 22 },
  checkboxCompleted: { backgroundColor: colors.text, borderColor: colors.text },
  content: { gap: spacing.lg },
  doneButton: { alignItems: 'center', flexDirection: 'row', gap: spacing.xs },
  doneGroup: { gap: spacing.sm },
  group: { gap: spacing.sm },
  groupLabel: { fontSize: 12, fontWeight: '600' },
  input: { backgroundColor: 'rgba(255,255,255,0.86)', borderRadius: radius.md, color: colors.text, fontSize: 15, paddingHorizontal: spacing.md, paddingVertical: spacing.md },
  pressed: { opacity: 0.78, transform: [{ scale: 0.98 }] },
  saveButton: { alignItems: 'center', backgroundColor: colors.text, borderRadius: radius.lg, flexDirection: 'row', gap: spacing.xs, justifyContent: 'center', marginTop: spacing.lg, paddingVertical: spacing.md },
  saveButtonText: { color: '#FFFFFF', fontSize: 16, fontWeight: '600' },
  sheet: { minHeight: 340, padding: spacing.lg },
  sheetTitle: { color: colors.text, fontSize: 18, fontWeight: '700', marginBottom: spacing.md },
  fieldLabel: { color: colors.textSecondary, fontSize: 12, fontWeight: '600', marginBottom: spacing.xs, marginTop: spacing.md },
  dueRow: { flexDirection: 'row', gap: spacing.sm },
  dueChip: { backgroundColor: colors.surfaceAlt, borderRadius: radius.pill, paddingHorizontal: spacing.md, paddingVertical: spacing.sm },
  dueChipActive: { backgroundColor: colors.text },
  dueChipText: { color: colors.textSecondary, fontSize: 13, fontWeight: '600' },
  dueChipTextActive: { color: '#FFFFFF' },
  projectRow: { backgroundColor: colors.surfaceAlt, borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.md },
  projectText: { color: colors.text, fontSize: 14.5 },
  metaRow: { alignItems: 'center', flexDirection: 'row', gap: 6, marginTop: 3 },
  metaDot: { backgroundColor: colors.textTertiary, borderRadius: 1.5, height: 3, width: 3 },
  sourceShrink: { flexShrink: 1 },
  sourceLink: { color: colors.textTertiary, fontSize: 12, textDecorationLine: 'underline' },
  sourceText: { color: colors.textTertiary, fontSize: 12 },
  dueBadge: { fontSize: 11.5, fontWeight: '600' },
  taskBody: { flex: 1 },
  taskRow: { borderBottomColor: colors.borderLight, borderBottomWidth: 1, flexDirection: 'row', gap: spacing.md, paddingVertical: 14 },
  taskTitle: { color: colors.text, fontSize: 14.5, fontWeight: '500', lineHeight: 20 },
  taskTitleCompleted: { color: colors.textTertiary, textDecorationLine: 'line-through' },
});
