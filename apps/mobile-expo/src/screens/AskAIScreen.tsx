import { AppIcon as Ionicons } from '../components/AppIcon';
import { FloatingBottomSheet } from '../components/FloatingBottomSheet';
import { SheetCard } from '../components/SheetCard';
import { useEffect, useMemo, useState } from 'react';
import { Alert, Keyboard, LayoutAnimation, Platform, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { Screen } from '../components/Screen';
import { EmptyState, LoadingState } from '../components/StateViews';
import { colors, radius, spacing, textStyles } from '../design/tokens';
import { askMessages } from '../mocks/memoraData';
import { MemoraNative } from '../native/MemoraNative';
import type { KnowledgeQueryScope, SummaryOptionsDTO } from '../native/MemoraNative.types';
import type { AskMessage } from '../types/memora';

const scopeOptions: Array<{ label: string; value: KnowledgeQueryScope }> = [
  { label: '全体', value: 'global' },
  { label: 'プロジェクト', value: 'project' },
  { label: 'ファイル', value: 'file' },
];

type AskModel = 'auto' | SummaryOptionsDTO['provider'];

const ASK_MODEL_LABELS: Record<AskModel, string> = {
  auto: 'Auto',
  OpenAI: 'OpenAI',
  Gemini: 'Gemini',
  DeepSeek: 'DeepSeek',
  Local: 'On-device',
};

const initialMessagesByScope: Record<KnowledgeQueryScope, AskMessage[]> = {
  file: askMessages,
  project: [
    {
      id: 'project-welcome',
      role: 'assistant',
      text:
        'Memora Launch の移行メモを横断できます。画面、bridge、検証ログのどこから見たいか聞いてください。',
      sources: ['React Native / Expo Migration Plan'],
    },
  ],
  global: [],
};

const suggestedQuestions = ['この会議の決定事項は？', '次に対応すべきことを教えて', '関連する記録を探して'];

export function AskAIScreen() {
  const [activeScope, setActiveScope] = useState<KnowledgeQueryScope>('global');
  const [draft, setDraft] = useState('');
  const [isAnswering, setIsAnswering] = useState(false);
  const [isKeyboardOpen, setIsKeyboardOpen] = useState(false);
  const [askModel, setAskModel] = useState<AskModel>('auto');
  const [isModelSheetOpen, setIsModelSheetOpen] = useState(false);

  useEffect(() => {
    const showEvent = Platform.OS === 'ios' ? 'keyboardWillShow' : 'keyboardDidShow';
    const hideEvent = Platform.OS === 'ios' ? 'keyboardWillHide' : 'keyboardDidHide';
    const show = Keyboard.addListener(showEvent, () => setIsKeyboardOpen(true));
    const hide = Keyboard.addListener(hideEvent, () => setIsKeyboardOpen(false));
    return () => { show.remove(); hide.remove(); };
  }, []);
  const [messagesByScope, setMessagesByScope] =
    useState<Record<KnowledgeQueryScope, AskMessage[]>>(initialMessagesByScope);

  const messages = messagesByScope[activeScope];
  const canSend = draft.trim().length > 0 && !isAnswering;
  const placeholder = useMemo(() => {
    if (activeScope === 'file') return 'この記録について質問する';
    if (activeScope === 'project') return 'このプロジェクトについて質問する';
    return 'すべての記録に質問する';
  }, [activeScope]);

  async function sendQuestion(questionOverride?: string) {
    const question = (questionOverride ?? draft).trim();
    if (!question || isAnswering) return;

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
      const response = await MemoraNative.queryKnowledge({
        question,
        scope: requestScope,
      });
      const assistantMessage: AskMessage = {
        id: response.id,
        role: 'assistant',
        text: response.answer,
        sources: response.sources,
      };

      setMessagesByScope((current) => ({
        ...current,
        [requestScope]: [...current[requestScope], assistantMessage],
      }));
    } catch {
      const errorMessage: AskMessage = {
        id: `${requestScope}-error-${Date.now()}`,
        role: 'assistant',
        text: '回答を取得できませんでした。時間をおいて、もう一度お試しください。',
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
        text: '新しい会話を始める',
        onPress: () => setMessagesByScope((current) => ({ ...current, [activeScope]: [] })),
      },
    ]);
  }

  return (
    <Screen
      footerAccessory={
        <View style={[styles.askDock, isKeyboardOpen && styles.askDockKeyboard]}>
          <View style={styles.askBox}>
            <TextInput
              accessibilityLabel="Ask AI question"
              multiline
              onChangeText={setDraft}
              onSubmitEditing={() => void sendQuestion()}
              placeholder={placeholder}
              placeholderTextColor="#DCE1DE"
              returnKeyType="send"
              style={styles.askInput}
              value={draft}
            />
            <Pressable accessibilityLabel="ファイルを添付" accessibilityRole="button" onPress={() => Alert.alert('添付', 'この操作は現在利用できません。')} style={styles.attachButton}>
              <Ionicons color={colors.textTertiary} name="attach-outline" size={18} />
            </Pressable>
            <Pressable accessibilityLabel="AIモデルを選択" accessibilityRole="button" onPress={() => setIsModelSheetOpen(true)} style={styles.modelPill}>
              <Text style={styles.modelPillText}>{ASK_MODEL_LABELS[askModel]}</Text>
              <Ionicons color={colors.textSecondary} name="chevron-down" size={12} />
            </Pressable>
            <Pressable
              accessibilityLabel="Ask AI send"
              accessibilityRole="button"
              disabled={!canSend}
              onPress={() => void sendQuestion()}
              style={[styles.sendButton, !canSend ? styles.sendButtonDisabled : null]}
            >
              <Ionicons color={colors.surface} name="arrow-forward" size={17} />
            </Pressable>
          </View>
        </View>
      }
      headerAccessory={<Pressable accessibilityLabel="新しい会話" accessibilityRole="button" hitSlop={6} onPress={handleNewChat} style={({ pressed }) => [styles.newChatButton, pressed && styles.iconPressed]}><Ionicons color={colors.text} name="create-outline" size={21} /></Pressable>}
      title="聞く"
    >
      <View style={styles.scopeBar}>
        {scopeOptions.map((scope) => {
          const isActive = activeScope === scope.value;
          return (
            <Pressable
              key={scope.value}
              accessibilityRole="button"
              accessibilityState={{ selected: isActive }}
              onPress={() => { LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut); setActiveScope(scope.value); }}
              style={[styles.scopeButton, isActive ? styles.scopeActive : null]}
            >
              <Text style={[styles.scopeText, isActive ? styles.scopeTextActive : null]}>
                {scope.label}
              </Text>
            </Pressable>
          );
        })}
      </View>
      <Text style={styles.scopeCaption}>{activeScope === 'global' ? 'すべての記録から回答します' : activeScope === 'project' ? 'プロジェクト内から回答します' : 'このファイルの内容から回答します'}</Text>

      <View style={styles.thread}>
        {messages.length === 0 ? (
          <View style={styles.emptyAsk}>
            <Text style={styles.emptyTitle}>調べたいことを質問してください</Text>
            <Text style={styles.emptySubtitle}>最近の記録から</Text>
            <View style={styles.suggestions}>{suggestedQuestions.map((question) => <Pressable accessibilityLabel={`${question}を質問する`} accessibilityRole="button" key={question} onPress={() => void sendQuestion(question)} style={({ pressed }) => [styles.suggestion, pressed && styles.suggestionPressed]}><Text style={styles.suggestionText}>{question}</Text><Ionicons color={colors.border} name="arrow-forward" size={15} /></Pressable>)}</View>
          </View>
        ) : (
          messages.map((message) =>
            message.role === 'user' ? (
              <View key={message.id} style={styles.userRow}>
                <View style={styles.userBubble}>
                  <Text style={styles.userText}>{message.text}</Text>
                </View>
              </View>
            ) : (
              <View key={message.id} style={styles.assistantBlock}>
                <Text style={styles.assistantText}>{message.text}</Text>
                {message.sources ? (
                  <View style={styles.sources}>
                    {message.sources.map((source) => (
                      <View key={source} style={styles.sourcePill}>
                        <Ionicons color={colors.textTertiary} name="document-outline" size={10} />
                        <Text numberOfLines={1} style={styles.sourceText}>
                          {source}
                        </Text>
                      </View>
                    ))}
                  </View>
                ) : null}
                <View style={styles.messageActions}><Pressable accessibilityLabel="回答をコピー" accessibilityRole="button" onPress={() => Alert.alert('コピー', 'この操作は現在利用できません。')}><Text style={styles.messageActionText}>コピー</Text></Pressable><Pressable accessibilityLabel="回答からタスクを作成" accessibilityRole="button" onPress={() => Alert.alert('タスク化', 'この操作は現在利用できません。')}><Text style={styles.messageActionText}>タスク化</Text></Pressable><Text style={styles.messageTime}>たった今</Text></View>
              </View>
            ),
          )
        )}
        {isAnswering ? <View style={styles.typingDots}><View style={styles.typingDot} /><View style={styles.typingDot} /><View style={styles.typingDot} /></View> : null}
      </View>

      <FloatingBottomSheet isOpen={isModelSheetOpen} onClose={() => setIsModelSheetOpen(false)}>
        <SheetCard style={styles.modelSheet}>
          {(Object.keys(ASK_MODEL_LABELS) as AskModel[]).map((model) => (
            <Pressable
              accessibilityRole="button"
              key={model}
              onPress={() => {
                setAskModel(model);
                setIsModelSheetOpen(false);
              }}
              style={styles.modelSheetRow}
            >
              <Text style={styles.modelSheetRowText}>{ASK_MODEL_LABELS[model]}</Text>
              {askModel === model ? <Ionicons color={colors.text} name="checkmark" size={16} /> : null}
            </Pressable>
          ))}
        </SheetCard>
      </FloatingBottomSheet>
    </Screen>
  );
}

const styles = StyleSheet.create({
  scopeBar: {
    borderBottomColor: colors.border,
    borderBottomWidth: 1,
    flexDirection: 'row',
    gap: spacing.lg,
  },
  scopeButton: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingBottom: spacing.sm,
    paddingTop: spacing.xs,
  },
  scopeActive: {
    borderBottomColor: colors.text,
    borderBottomWidth: 2,
  },
  scopeText: {
    color: colors.textSecondary,
    textAlign: 'center',
    ...textStyles.footnoteBold,
  },
  scopeTextActive: {
    borderRadius: radius.pill,
    color: colors.text,
  },
  scopeCaption: { color: colors.textTertiary, marginTop: -8, ...textStyles.caption },
  newChatButton: { alignItems: 'center', height: 44, justifyContent: 'center', marginRight: -spacing.sm, width: 44 },
  iconPressed: { opacity: 0.45 },
  thread: {
    gap: spacing.md,
  },
  userRow: {
    alignItems: 'flex-end',
  },
  userBubble: {
    backgroundColor: colors.accentSoft,
    borderRadius: radius.md,
    maxWidth: '84%',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  userText: {
    color: colors.text,
    ...textStyles.body,
  },
  assistantBlock: {
    borderBottomColor: colors.borderLight,
    borderBottomWidth: 1,
    gap: spacing.sm,
    paddingBottom: spacing.sm,
  },
  messageActions: { alignItems: 'center', flexDirection: 'row', gap: spacing.md, marginTop: 2 },
  messageActionText: { color: colors.textTertiary, ...textStyles.caption },
  messageTime: { color: colors.border, marginLeft: 'auto', ...textStyles.caption },
  emptyAsk: { gap: spacing.xs, paddingTop: spacing.xl },
  emptyTitle: { color: colors.text, ...textStyles.callout },
  emptySubtitle: { color: colors.textTertiary, paddingBottom: spacing.sm, ...textStyles.captionBold },
  suggestions: { borderTopColor: colors.borderLight, borderTopWidth: 1 },
  suggestion: { alignItems: 'center', borderBottomColor: colors.borderLight, borderBottomWidth: 1, flexDirection: 'row', minHeight: 52, paddingHorizontal: 2 },
  suggestionPressed: { opacity: 0.46 },
  suggestionText: { color: colors.text, flex: 1, ...textStyles.body },
  typingDots: { alignItems: 'center', flexDirection: 'row', gap: spacing.xs, paddingVertical: spacing.sm },
  typingDot: { backgroundColor: colors.border, borderRadius: 3, height: 6, width: 6 },
  assistantText: {
    color: colors.text,
    ...textStyles.body,
  },
  sources: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.xs,
  },
  sourcePill: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.xs,
    paddingVertical: 2,
  },
  sourceText: {
    color: colors.textTertiary,
    ...textStyles.caption,
  },
  askBox: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radius.md,
    borderWidth: 1,
    flexDirection: 'row',
    gap: spacing.sm,
    justifyContent: 'space-between',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  attachButton: { alignItems: 'center', height: 32, justifyContent: 'center', width: 28 },
  modelPill: {
    alignItems: 'center',
    backgroundColor: colors.surfaceAlt,
    borderRadius: radius.pill,
    flexDirection: 'row',
    gap: 4,
    paddingHorizontal: spacing.sm,
    paddingVertical: 6,
  },
  modelPillText: {
    color: colors.textSecondary,
    ...textStyles.caption,
  },
  modelSheet: {
    paddingVertical: spacing.xs,
  },
  modelSheetRow: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    minHeight: 48,
    paddingHorizontal: spacing.md,
  },
  modelSheetRowText: {
    color: colors.text,
    ...textStyles.body,
  },
  askDock: {
    backgroundColor: colors.surface,
    paddingBottom: 94,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.sm,
  },
  askDockKeyboard: {
    paddingBottom: spacing.sm,
  },
  askInput: {
    color: colors.text,
    flex: 1,
    maxHeight: 96,
    minHeight: 24,
    ...textStyles.body,
  },
  sendButton: {
    alignItems: 'center',
    backgroundColor: colors.text,
    borderRadius: radius.pill,
    height: 36,
    justifyContent: 'center',
    width: 36,
  },
  sendButtonDisabled: {
    backgroundColor: colors.textTertiary,
    opacity: 0.55,
  },
});
