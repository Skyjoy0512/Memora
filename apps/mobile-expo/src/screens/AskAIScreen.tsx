import { AppIcon } from '../components/AppIcon';
import { FloatingBottomSheet } from '../components/FloatingBottomSheet';
import { NumericText } from '../components/NumericText';
import { IconButton } from '../components/Buttons';
import { EmptyState } from '../components/StateViews';
import { useTabBarClearance } from '../components/useTabBarClearance';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { Alert, Keyboard, Platform, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { useFocusEffect, useRouter } from 'expo-router';
import { Screen } from '../components/Screen';
import { colors, radius, spacing, textStyles } from '../design/tokens';
import {
  buildAskAiRequest,
  describeNoTarget,
  mapAskAiError,
  resolveAskAiDataStatus,
  resolveAskAiScope,
} from '../native/askAiLogic';
import { MemoraNative } from '../native/MemoraNative';
import { buildTaskFromAssistantAnswer } from '../native/taskLogic';
import type { BridgeInfoDTO, KnowledgeQueryScope } from '../native/MemoraNative.types';
import type { AskMessage } from '../types/memora';
import { RadioGroup } from 'heroui-native/radio-group';
import { Spinner } from 'heroui-native/spinner';

const scopeLabels: Record<KnowledgeQueryScope, string> = {
  global: 'すべての記録',
  project: 'プロジェクト',
  file: '記録',
};

const suggestedQuestions = ['この会議の決定事項は？', '次に対応すべきことを教えて', '関連する記録を探して'];

export function AskAIScreen() {
  const router = useRouter();
  const tabBarClearance = useTabBarClearance();
  const [activeScope, setActiveScope] = useState<KnowledgeQueryScope>('global');
  const [draft, setDraft] = useState('');
  const [isAnswering, setIsAnswering] = useState(false);
  const [isKeyboardOpen, setIsKeyboardOpen] = useState(false);
  const [isInputFocused, setIsInputFocused] = useState(false);
  const [isScopeSheetOpen, setIsScopeSheetOpen] = useState(false);
  const [isHistoryOpen, setIsHistoryOpen] = useState(false);
  const [bridgeInfo, setBridgeInfo] = useState<BridgeInfoDTO | null>(null);
  const [hasRecords, setHasRecords] = useState<boolean | null>(null);
  const [isKeyConfigured, setIsKeyConfigured] = useState<boolean | null>(null);
  // 対象選択UIが未実装のため常に未選択。File Detail からの遷移時に audioFileId / projectId を渡す経路を確保する。
  const [audioFileId] = useState<string | undefined>(undefined);
  const [projectId] = useState<string | undefined>(undefined);

  useEffect(() => {
    const showEvent = Platform.OS === 'ios' ? 'keyboardWillShow' : 'keyboardDidShow';
    const hideEvent = Platform.OS === 'ios' ? 'keyboardWillHide' : 'keyboardDidHide';
    const show = Keyboard.addListener(showEvent, () => setIsKeyboardOpen(true));
    const hide = Keyboard.addListener(hideEvent, () => setIsKeyboardOpen(false));
    return () => { show.remove(); hide.remove(); };
  }, []);

  const [messagesByScope, setMessagesByScope] =
    useState<Record<KnowledgeQueryScope, AskMessage[]>>({ file: [], project: [], global: [] });

  useFocusEffect(
    useCallback(() => {
      let isMounted = true;

      void (async () => {
        const [info, files, keyConfigured] = await Promise.all([
          MemoraNative.getBridgeInfo(),
          MemoraNative.listAudioFiles(),
          MemoraNative.getSecureCredentialStatus('OpenAI'),
        ]);
        if (!isMounted) return;
        setBridgeInfo(info);
        setHasRecords(files.length > 0);
        setIsKeyConfigured(keyConfigured);
      })();

      return () => {
        isMounted = false;
      };
    }, []),
  );

  const messages = messagesByScope[activeScope];
  const dataStatus = resolveAskAiDataStatus(hasRecords);
  const scopeResolution = resolveAskAiScope(activeScope, { audioFileId, projectId });
  const composerBlocked = !scopeResolution.canSend || dataStatus === 'empty';
  const noTarget = describeNoTarget(activeScope);
  const canSend = draft.trim().length > 0 && !isAnswering && !composerBlocked;

  // 質問の履歴。永続化はまだ無いので、このセッションで送った質問だけを並べる。
  const history = useMemo(
    () =>
      (Object.keys(messagesByScope) as KnowledgeQueryScope[])
        .flatMap((scope) =>
          messagesByScope[scope]
            .filter((message) => message.role === 'user')
            .map((message) => ({ id: message.id, question: message.text, scope })),
        )
        .reverse(),
    [messagesByScope],
  );

  async function sendQuestion(questionOverride?: string) {
    const question = (questionOverride ?? draft).trim();
    if (!question || isAnswering || composerBlocked) return;

    const requestScope = activeScope;

    const userMessage: AskMessage = {
      id: `${requestScope}-user-${Date.now()}`,
      role: 'user',
      text: question,
    };

    setDraft('');
    setIsAnswering(true);
    setMessagesByScope((current) => ({
      ...current,
      [requestScope]: [...current[requestScope], userMessage],
    }));

    try {
      // 実データ（SwiftData）パスでのみAPIキー前提チェックを行う。
      // web / sample パスはサンプル回答なのでキー不要。
      if (bridgeInfo?.knowledgeQuerySource === 'swiftdata' && isKeyConfigured === false) {
        throw new Error('選択したプロバイダーのAPIキーが設定されていません。');
      }

      const response = await MemoraNative.queryKnowledge(
        buildAskAiRequest(requestScope, question, { audioFileId, projectId }),
      );
      const assistantMessage: AskMessage = {
        id: response.id,
        role: 'assistant',
        text: response.answer,
        sources: response.sources,
        isSample: response.isSample,
      };

      setMessagesByScope((current) => ({
        ...current,
        [requestScope]: [...current[requestScope], assistantMessage],
      }));
    } catch (error) {
      const mapping = mapAskAiError(error);
      const errorMessage: AskMessage = {
        id: `${requestScope}-error-${Date.now()}`,
        role: 'assistant',
        text: mapping.message,
        hint: mapping.hint ?? undefined,
      };
      setMessagesByScope((current) => ({
        ...current,
        [requestScope]: [...current[requestScope], errorMessage],
      }));
    } finally {
      setIsAnswering(false);
    }
  }

  function handleNewChat() {
    if (messages.length === 0) return;
    Alert.alert('現在の会話をクリアしますか？', undefined, [
      { style: 'cancel', text: 'キャンセル' },
      {
        style: 'destructive',
        text: '新しい質問を始める',
        onPress: () => setMessagesByScope((current) => ({ ...current, [activeScope]: [] })),
      },
    ]);
  }

  async function handleTaskize(message: AskMessage) {
    try {
      const task = buildTaskFromAssistantAnswer(message.text, {
        sourceAudioFileId: audioFileId,
      });
      const created = await MemoraNative.createTask(task);
      if (!created) {
        Alert.alert('タスクを追加できません', 'タスクの保存に失敗しました。');
        return;
      }
      Alert.alert('タスクに追加しました', undefined, [
        { text: 'キャンセル', style: 'cancel' },
        { text: 'タスク一覧を開く', onPress: () => router.push('/tasks') },
      ]);
    } catch (error) {
      Alert.alert(
        'タスクを追加できません',
        error instanceof Error ? error.message : 'タスクの保存に失敗しました。',
      );
    }
  }

  return (
    <Screen
      footerAccessory={
        <View
          style={[
            styles.dock,
            { paddingBottom: tabBarClearance + spacing.xs },
            isKeyboardOpen && styles.dockKeyboard,
          ]}
        >
          {/* 対象の宣言。プロジェクト/記録の指定はここから切り替える。 */}
          <Pressable
            accessibilityLabel="質問の対象を選ぶ"
            accessibilityRole="button"
            onPress={() => setIsScopeSheetOpen(true)}
            style={({ pressed }) => [styles.scopeRow, pressed && styles.pressed]}
          >
            <Text numberOfLines={1} style={styles.scopeText}>{`対象: ${scopeLabels[activeScope]}`}</Text>
            <AppIcon color={colors.textSecondary} name="chevron-forward" size={16} />
          </Pressable>

          {/* 質問できない理由は本文の空状態ブロックが説明しているので、ここでは繰り返さない。
              対象行だけ残し、対象を変えれば解除できることを示す。 */}
          {composerBlocked ? null : (
            <View style={styles.composerRow}>
              <TextInput
                accessibilityLabel="記録について質問"
                onBlur={() => setIsInputFocused(false)}
                onChangeText={setDraft}
                onFocus={() => setIsInputFocused(true)}
                onSubmitEditing={() => void sendQuestion()}
                placeholder="記録について質問"
                placeholderTextColor={colors.accentMuted}
                returnKeyType="send"
                style={[styles.input, isInputFocused && styles.inputFocused]}
                value={draft}
              />
              <Pressable
                accessibilityLabel="質問を送信"
                accessibilityRole="button"
                accessibilityState={{ disabled: !canSend }}
                disabled={!canSend}
                onPress={() => void sendQuestion()}
                style={({ pressed }) => [styles.sendButton, !canSend && styles.sendDisabled, pressed && styles.pressed]}
              >
                {isAnswering ? (
                  <Spinner size="sm" />
                ) : (
                  <AppIcon color={colors.textInverse} name="arrow-forward" size={18} />
                )}
              </Pressable>
            </View>
          )}
        </View>
      }
      headerAccessory={
        <View style={styles.headerActions}>
          <IconButton
            accessibilityLabel="質問の履歴"
            onPress={() => setIsHistoryOpen(true)}
            style={styles.headerIconButton}
          >
            <AppIcon color={colors.text} name="chatbubble-outline" size={20} />
          </IconButton>
          <IconButton
            accessibilityLabel="新しい質問"
            onPress={handleNewChat}
            style={styles.headerIconButton}
          >
            <AppIcon color={colors.text} name="create-outline" size={20} />
          </IconButton>
        </View>
      }
      title="Ask AI"
    >
      {messages.length === 0 ? (
        <View>
          {/* 質問できない状態は、記録・タスクと同じ空状態ブロックで揃える。
              質問できる状態の導入文だけがプロトタイプ通りの左寄せ（.ask-empty-intro）。 */}
          {!scopeResolution.canSend ? (
            <EmptyState body={noTarget.body} title={noTarget.title} />
          ) : dataStatus === 'loading' ? null : dataStatus === 'empty' ? (
            <EmptyState
              body="録音・取り込み・文字起こしが完了すると、Ask AI が記録から回答できるようになります。"
              title="まだ記録がありません"
            />
          ) : bridgeInfo?.knowledgeQuerySource === 'swiftdata' && isKeyConfigured === false ? (
            <EmptyState
              actionLabel="設定を開く"
              body="「設定 > 文字起こし・要約 > AI providerのAPIキー」から OpenAI の API キーを入力すると、記録から回答できるようになります。"
              onAction={() => router.push('/settings')}
              title="OpenAI の API キーが未設定です"
            />
          ) : (
            <>
              <View style={styles.intro}>
                <Text style={styles.introTitle}>調べたいことを質問してください</Text>
                <Text style={styles.introBody}>最近の記録、または選択した対象から回答します。</Text>
              </View>
              <View style={styles.promptList}>
                {suggestedQuestions.map((question) => (
                  <Pressable
                    accessibilityLabel={`${question}を質問する`}
                    accessibilityRole="button"
                    key={question}
                    onPress={() => void sendQuestion(question)}
                    style={({ pressed }) => [styles.promptButton, pressed && styles.rowPressed]}
                  >
                    <Text style={styles.promptText}>{question}</Text>
                    <AppIcon color={colors.textSecondary} name="chevron-forward" size={20} />
                  </Pressable>
                ))}
              </View>
            </>
          )}
        </View>
      ) : (
        <View>
          {messages.map((message) =>
            message.role === 'user' ? (
              <View key={message.id} style={styles.questionBlock}>
                <Text style={styles.label}>質問</Text>
                <Text style={styles.questionText}>{message.text}</Text>
              </View>
            ) : (
              <View key={message.id} style={styles.answerCard}>
                <View style={styles.answerHead}>
                  <Text style={styles.label}>回答</Text>
                  {message.sources?.length ? (
                    <NumericText style={styles.answerMeta}>
                      {`${message.sources.length}件の記録を参照`}
                    </NumericText>
                  ) : null}
                </View>
                {message.isSample ? (
                  <Text style={styles.sampleNote}>サンプル回答（ネイティブ未接続）</Text>
                ) : null}
                <Text style={styles.answerBody}>{message.text}</Text>

                {message.sources?.length ? (
                  <View style={styles.answerSection}>
                    <Text style={styles.sectionLabel}>出典</Text>
                    {message.sources.map((source) => (
                      <Text key={source} numberOfLines={2} style={styles.sourceLink}>
                        {source}
                      </Text>
                    ))}
                  </View>
                ) : null}

                <View style={styles.answerActions}>
                  <Pressable
                    accessibilityLabel="回答をコピー"
                    accessibilityRole="button"
                    onPress={() => Alert.alert('コピー', 'この操作は現在利用できません。')}
                    style={({ pressed }) => [styles.actionButton, pressed && styles.pressed]}
                  >
                    <Text style={styles.actionText}>コピー</Text>
                  </Pressable>
                  <Pressable
                    accessibilityLabel="回答からタスクを作成"
                    accessibilityRole="button"
                    onPress={() => void handleTaskize(message)}
                    style={({ pressed }) => [styles.actionButton, pressed && styles.pressed]}
                  >
                    <Text style={styles.actionText}>タスク化</Text>
                  </Pressable>
                  {message.hint === 'api-key' ? (
                    <Pressable
                      accessibilityLabel="設定でAPIキーを入力する"
                      accessibilityRole="button"
                      onPress={() => router.push('/settings')}
                      style={({ pressed }) => [styles.actionButton, pressed && styles.pressed]}
                    >
                      <Text style={styles.actionText}>設定でAPIキーを入力</Text>
                    </Pressable>
                  ) : null}
                </View>
              </View>
            ),
          )}
          {isAnswering ? (
            <View style={styles.answeringStatus}>
              <Spinner size="sm" />
              <Text style={styles.answeringLabel}>回答を生成中</Text>
            </View>
          ) : null}
        </View>
      )}

      <FloatingBottomSheet isOpen={isHistoryOpen} onClose={() => setIsHistoryOpen(false)}>
        <View style={styles.historySheet}>
          <Text style={styles.sheetTitle}>質問の履歴</Text>
          <Text style={styles.sheetNote}>
            このセッションで送った質問です。アプリを閉じると消えます。
          </Text>
          {history.length === 0 ? (
            <Text style={styles.historyEmpty}>まだ質問していません。</Text>
          ) : (
            <View style={styles.historyList}>
              <Text style={styles.label}>最近</Text>
              {history.map((item) => (
                <Pressable
                  accessibilityLabel={`${item.question}をもう一度質問する`}
                  accessibilityRole="button"
                  key={item.id}
                  onPress={() => {
                    setIsHistoryOpen(false);
                    setActiveScope(item.scope);
                    void sendQuestion(item.question);
                  }}
                  style={({ pressed }) => [styles.historyRow, pressed && styles.rowPressed]}
                >
                  <View style={styles.historyBody}>
                    <Text numberOfLines={2} style={styles.historyTitle}>{item.question}</Text>
                    <Text style={styles.historyMeta}>{`対象: ${scopeLabels[item.scope]}`}</Text>
                  </View>
                  <AppIcon color={colors.textSecondary} name="chevron-forward" size={16} />
                </Pressable>
              ))}
            </View>
          )}
        </View>
      </FloatingBottomSheet>

      <FloatingBottomSheet isOpen={isScopeSheetOpen} onClose={() => setIsScopeSheetOpen(false)}>
        <View style={styles.scopeSheet}>
          <Text style={styles.sheetTitle}>質問の対象</Text>
          <Text style={styles.sheetNote}>
            プロジェクトと記録の指定は、対象を選んでから質問すると絞り込まれます。
          </Text>
          <RadioGroup
            onValueChange={(value) => {
              setActiveScope(value as KnowledgeQueryScope);
              setIsScopeSheetOpen(false);
            }}
            value={activeScope}
          >
            {(Object.keys(scopeLabels) as KnowledgeQueryScope[]).map((scope) => (
              <RadioGroup.Item key={scope} value={scope}>
                {scopeLabels[scope]}
              </RadioGroup.Item>
            ))}
          </RadioGroup>
        </View>
      </FloatingBottomSheet>
    </Screen>
  );
}

const styles = StyleSheet.create({
  headerActions: { flexDirection: 'row' },
  headerIconButton: { height: 44, width: 44 },
  pressed: { opacity: 0.62 },
  rowPressed: { backgroundColor: colors.surfaceAlt },

  // intro / prompts
  intro: { gap: spacing.xs, paddingTop: spacing.xxl },
  introTitle: { color: colors.text, ...textStyles.sectionTitle },
  introBody: { color: colors.textSecondary, ...textStyles.footnote },
  promptList: { borderTopColor: colors.border, borderTopWidth: 1, marginTop: spacing.xl },
  promptButton: {
    alignItems: 'center',
    borderBottomColor: colors.border,
    borderBottomWidth: 1,
    flexDirection: 'row',
    gap: spacing.md,
    justifyContent: 'space-between',
    minHeight: 56,
    paddingVertical: spacing.sm,
  },
  promptText: { color: colors.text, flexShrink: 1, ...textStyles.body },

  // thread
  label: { color: colors.textSecondary, ...textStyles.label },
  questionBlock: { gap: spacing.xxs, paddingTop: spacing.lg },
  questionText: { color: colors.text, ...textStyles.sectionTitle },
  answerCard: {
    borderBottomColor: colors.border,
    borderBottomWidth: 1,
    borderTopColor: colors.text,
    borderTopWidth: 2,
    marginTop: spacing.xl,
    paddingVertical: spacing.md,
  },
  answerHead: { alignItems: 'baseline', flexDirection: 'row', gap: spacing.md, justifyContent: 'space-between' },
  answerMeta: { color: colors.textSecondary, ...textStyles.caption },
  sampleNote: { color: colors.textSecondary, marginTop: spacing.xs, ...textStyles.caption },
  answerBody: { color: colors.text, marginTop: spacing.xs, ...textStyles.body },
  answerSection: {
    borderTopColor: colors.border,
    borderTopWidth: 1,
    marginTop: spacing.md,
    paddingTop: spacing.md,
  },
  sectionLabel: { color: colors.textSecondary, marginBottom: spacing.xxs, ...textStyles.label },
  sourceLink: {
    color: colors.textSecondary,
    marginTop: spacing.xs,
    textDecorationLine: 'underline',
    ...textStyles.footnote,
  },
  answerActions: { alignItems: 'center', flexDirection: 'row', gap: spacing.md, marginTop: spacing.sm },
  actionButton: { justifyContent: 'center', minHeight: 44 },
  actionText: { color: colors.textSecondary, textDecorationLine: 'underline', ...textStyles.footnote },
  answeringStatus: { alignItems: 'center', flexDirection: 'row', gap: spacing.sm, paddingVertical: spacing.sm },
  answeringLabel: { color: colors.textSecondary, ...textStyles.caption },

  // composer
  dock: {
    backgroundColor: colors.surface,
    borderTopColor: colors.border,
    borderTopWidth: 1,
    paddingHorizontal: spacing.md,
    paddingTop: spacing.sm,
  },
  dockKeyboard: { paddingBottom: spacing.sm },
  scopeRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.xs,
    justifyContent: 'space-between',
    minHeight: 36,
  },
  scopeText: { color: colors.textSecondary, flexShrink: 1, ...textStyles.caption },
  composerRow: { alignItems: 'center', flexDirection: 'row', gap: spacing.xs },
  input: {
    backgroundColor: colors.surface,
    borderColor: colors.borderLight,
    borderRadius: 0,
    borderWidth: 1,
    color: colors.text,
    flex: 1,
    height: 44,
    paddingHorizontal: spacing.sm,
    paddingVertical: 0,
    ...textStyles.footnote,
  },
  inputFocused: { borderColor: colors.text },
  sendButton: {
    alignItems: 'center',
    backgroundColor: colors.accent,
    borderRadius: radius.circle,
    flexShrink: 0,
    height: 44,
    justifyContent: 'center',
    width: 44,
  },
  sendDisabled: { opacity: 0.38 },

  // history sheet
  historySheet: {
    backgroundColor: colors.surface,
    gap: spacing.xs,
    marginBottom: spacing.md,
    marginHorizontal: spacing.md,
    padding: spacing.md,
  },
  historyEmpty: { color: colors.textSecondary, paddingVertical: spacing.md, ...textStyles.footnote },
  historyList: { marginTop: spacing.sm },
  historyRow: {
    alignItems: 'center',
    borderBottomColor: colors.border,
    borderBottomWidth: 1,
    borderTopColor: colors.border,
    borderTopWidth: 1,
    flexDirection: 'row',
    gap: spacing.md,
    marginTop: -1,
    minHeight: 72,
    paddingVertical: spacing.sm,
  },
  historyBody: { flex: 1, minWidth: 0 },
  historyTitle: { color: colors.text, ...textStyles.rowTitle },
  historyMeta: { color: colors.textSecondary, marginTop: spacing.xxs, ...textStyles.caption },

  // scope sheet
  scopeSheet: {
    backgroundColor: colors.surface,
    borderRadius: 0,
    gap: spacing.sm,
    marginBottom: spacing.md,
    marginHorizontal: spacing.md,
    padding: spacing.md,
  },
  sheetTitle: { color: colors.text, ...textStyles.sectionTitle },
  sheetNote: { color: colors.textSecondary, ...textStyles.caption },
});
