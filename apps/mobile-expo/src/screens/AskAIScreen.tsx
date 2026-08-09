import { AppIcon } from '../components/AppIcon';
import { FloatingBottomSheet } from '../components/FloatingBottomSheet';
import { useEffect, useMemo, useState } from 'react';
import { Alert, Keyboard, LayoutAnimation, Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import { Screen } from '../components/Screen';
import { colors, radius, spacing, textStyles } from '../design/tokens';
import { askMessages } from '../mocks/memoraData';
import { MemoraNative } from '../native/MemoraNative';
import type { KnowledgeQueryScope, SummaryOptionsDTO } from '../native/MemoraNative.types';
import type { AskMessage } from '../types/memora';
import { Button } from 'heroui-native/button';
import { TextArea } from 'heroui-native/text-area';
import { Tabs } from 'heroui-native/tabs';
import { RadioGroup } from 'heroui-native/radio-group';
import { Spinner } from 'heroui-native/spinner';

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
            <TextArea
              accessibilityLabel="Ask AI question"
              onChangeText={setDraft}
              onSubmitEditing={() => void sendQuestion()}
              placeholder={placeholder}
              placeholderTextColor={colors.textTertiary}
              returnKeyType="send"
              style={styles.askInput}
              value={draft}
              variant="secondary"
            />
            <View style={styles.composerActions}>
              <Button
                accessibilityLabel="ファイルを添付"
                feedbackVariant="none"
                isIconOnly
                onPress={() => Alert.alert('添付', 'この操作は現在利用できません。')}
                size="sm"
                variant="ghost"
                style={styles.attachButton}
              >
                <AppIcon color={colors.textTertiary} name="attach-outline" size={18} />
              </Button>
              <Button
                accessibilityLabel="AIモデルを選択"
                onPress={() => setIsModelSheetOpen(true)}
                size="md"
                variant="ghost"
                style={styles.modelButton}
              >
                <Text style={styles.modelButtonText}>{ASK_MODEL_LABELS[askModel]}</Text>
                <AppIcon color={colors.textSecondary} name="chevron-down" size={12} />
              </Button>
              <Button
                accessibilityLabel="Ask AI send"
                feedbackVariant="none"
                isDisabled={!canSend}
                isIconOnly
                onPress={() => void sendQuestion()}
                variant="primary"
                style={styles.sendButton}
              >
                {isAnswering ? (
                  <Spinner size="sm" />
                ) : (
                  <AppIcon color={colors.surface} name="arrow-forward" size={17} />
                )}
              </Button>
            </View>
          </View>
        </View>
      }
      headerAccessory={
        <Button
          accessibilityLabel="新しい会話"
          feedbackVariant="none"
          isIconOnly
          onPress={handleNewChat}
          size="md"
          variant="ghost"
          style={styles.newChatButton}
        >
          <AppIcon color={colors.text} name="create-outline" size={21} />
        </Button>
      }
      title="聞く"
    >
      <Tabs
        onValueChange={(value) => {
          LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
          setActiveScope(value as KnowledgeQueryScope);
        }}
        value={activeScope}
        variant="secondary"
      >
        <Tabs.List>
          <Tabs.Indicator />
          {scopeOptions.map((scope) => (
            <Tabs.Trigger key={scope.value} value={scope.value}>
              <Tabs.Label>{scope.label}</Tabs.Label>
            </Tabs.Trigger>
          ))}
        </Tabs.List>
      </Tabs>
      <Text style={styles.scopeCaption}>
        {activeScope === 'global'
          ? 'すべての記録から回答します'
          : activeScope === 'project'
            ? 'プロジェクト内から回答します'
            : 'このファイルの内容から回答します'}
      </Text>

      <View style={styles.thread}>
        {messages.length === 0 ? (
          <View style={styles.emptyAsk}>
            <Text style={styles.emptyTitle}>調べたいことを質問してください</Text>
            <Text style={styles.emptySubtitle}>最近の記録から</Text>
            <View style={styles.suggestions}>
              {suggestedQuestions.map((question) => (
                <Pressable
                  accessibilityLabel={`${question}を質問する`}
                  accessibilityRole="button"
                  key={question}
                  onPress={() => void sendQuestion(question)}
                  style={({ pressed }) => [styles.suggestion, pressed && styles.suggestionPressed]}
                >
                  <Text style={styles.suggestionText}>{question}</Text>
                  <AppIcon color={colors.border} name="arrow-forward" size={15} />
                </Pressable>
              ))}
            </View>
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
                        <AppIcon color={colors.textTertiary} name="document-outline" size={10} />
                        <Text numberOfLines={1} style={styles.sourceText}>
                          {source}
                        </Text>
                      </View>
                    ))}
                  </View>
                ) : null}
                <View style={styles.messageActions}>
                  <Button
                    accessibilityLabel="回答をコピー"
                    onPress={() => Alert.alert('コピー', 'この操作は現在利用できません。')}
                    size="sm"
                    variant="ghost"
                    style={styles.actionButton}
                  >
                    コピー
                  </Button>
                  <Button
                    accessibilityLabel="回答からタスクを作成"
                    onPress={() => Alert.alert('タスク化', 'この操作は現在利用できません。')}
                    size="sm"
                    variant="ghost"
                    style={styles.actionButton}
                  >
                    タスク化
                  </Button>
                  <Text style={styles.messageTime}>たった今</Text>
                </View>
              </View>
            ),
          )
        )}
        {isAnswering ? (
          <View style={styles.answeringStatus}>
            <Spinner size="sm" />
            <Text style={styles.answeringLabel}>回答を生成中</Text>
          </View>
        ) : null}
      </View>

      <FloatingBottomSheet isOpen={isModelSheetOpen} onClose={() => setIsModelSheetOpen(false)}>
        <View style={styles.modelSheetContainer}>
          <Text style={styles.modelSheetHeading}>AIモデル</Text>
          <RadioGroup
            onValueChange={(value) => {
              setAskModel(value as AskModel);
              setIsModelSheetOpen(false);
            }}
            value={askModel}
          >
            {(Object.keys(ASK_MODEL_LABELS) as AskModel[]).map((model) => (
              <RadioGroup.Item key={model} value={model}>
                {ASK_MODEL_LABELS[model]}
              </RadioGroup.Item>
            ))}
          </RadioGroup>
        </View>
      </FloatingBottomSheet>
    </Screen>
  );
}

/** Dock bottom clearance when keyboard is closed, tuned to clear the center FAB and NativeTabs on iPhone. */
const DOCK_BOTTOM_CLEARANCE = 176;

const styles = StyleSheet.create({
  scopeCaption: { color: colors.textTertiary, marginTop: spacing.xs, ...textStyles.caption },
  newChatButton: { height: 44, marginRight: -spacing.sm, width: 44 },
  thread: {
    gap: spacing.md,
  },
  userRow: {
    alignItems: 'flex-end',
  },
  userBubble: {
    backgroundColor: colors.accentSoft,
    borderRadius: radius.sm,
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
  messageActions: { alignItems: 'center', flexDirection: 'row', gap: spacing.xs },
  actionButton: { minHeight: 44, minWidth: 44 },
  modelSheetContainer: {
    backgroundColor: colors.surface,
    borderRadius: radius.sm,
    marginBottom: spacing.md,
    marginHorizontal: spacing.md,
    padding: spacing.md,
  },
  modelSheetHeading: {
    color: colors.textSecondary,
    marginBottom: spacing.sm,
    ...textStyles.captionBold,
  },
  messageTime: { color: colors.border, marginLeft: 'auto', ...textStyles.caption },
  emptyAsk: { gap: spacing.xs, paddingTop: spacing.xl },
  emptyTitle: { color: colors.text, ...textStyles.callout },
  emptySubtitle: { color: colors.textTertiary, paddingBottom: spacing.sm, ...textStyles.captionBold },
  suggestions: { borderTopColor: colors.borderLight, borderTopWidth: 1 },
  suggestion: {
    alignItems: 'center',
    borderBottomColor: colors.borderLight,
    borderBottomWidth: 1,
    flexDirection: 'row',
    minHeight: 52,
    paddingHorizontal: 2,
  },
  suggestionPressed: { opacity: 0.46 },
  suggestionText: { color: colors.text, flex: 1, ...textStyles.body },
  answeringStatus: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
    paddingVertical: spacing.sm,
  },
  answeringLabel: { color: colors.textTertiary, ...textStyles.caption },
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
    backgroundColor: colors.surface,
    flexDirection: 'column',
    gap: spacing.xs,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
  },
  attachButton: { height: 44, justifyContent: 'center', width: 44 },
  modelButton: { minHeight: 44 },
  modelButtonText: {
    color: colors.textSecondary,
    ...textStyles.caption,
  },
  composerActions: {
    alignItems: 'center',
    borderTopColor: colors.borderLight,
    borderTopWidth: 1,
    flexDirection: 'row',
    paddingTop: spacing.xs,
  },
  sendButton: { height: 44, marginLeft: 'auto', width: 44 },
  askDock: {
    backgroundColor: colors.surface,
    paddingBottom: DOCK_BOTTOM_CLEARANCE,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.sm,
  },
  askDockKeyboard: {
    paddingBottom: spacing.sm,
  },
  askInput: {
    color: colors.text,
    height: 72,
    width: '100%',
    ...textStyles.body,
  },
});
