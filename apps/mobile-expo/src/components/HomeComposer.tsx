import { GlassView, isGlassEffectAPIAvailable } from 'expo-glass-effect';
import { SymbolView } from 'expo-symbols';
import { useRouter } from 'expo-router';
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { AccessibilityInfo, Alert, Platform, StyleSheet, Text, View } from 'react-native';
import { Button } from 'heroui-native/button';
import { Select } from 'heroui-native/select';
import { Spinner } from 'heroui-native/spinner';
import { TextArea } from 'heroui-native/text-area';
import { FloatingBottomSheet } from './FloatingBottomSheet';
import { AppIcon } from './AppIcon';
import { colors, radius, spacing, textStyles } from '../design/tokens';
import { colors as themeColors } from '../theme/tokens';
import {
  ASK_AI_MODEL_LABELS,
  ASK_AI_MODEL_OPTIONS,
  buildAskAiRequest,
  mapAskAiError,
  type AskAiModel,
} from '../native/askAiLogic';
import { MemoraNative } from '../native/MemoraNative';
import type { KnowledgeQueryResponseDTO } from '../native/MemoraNative.types';

/**
 * Approximate height of the composer above the tab bar. Used by floating
 * siblings (e.g. CaptureFab) to keep clear of the composer on the Home tab.
 * Tunable after device QA.
 */
export const HOME_COMPOSER_HEIGHT = 110;
export const HOME_COMPOSER_GAP = spacing.sm;

// ── Glass availability ─────────────────────────────────
function useCanUseGlass() {
  const [reduceTransparency, setReduceTransparency] = useState(false);

  useEffect(() => {
    let isMounted = true;
    AccessibilityInfo.isReduceTransparencyEnabled()
      .then((enabled) => {
        if (isMounted) setReduceTransparency(enabled);
      })
      .catch(() => {
        // Reduce Transparency 判定が使えない環境では glass を使わない（false のまま）。
      });
    return () => {
      isMounted = false;
    };
  }, []);

  return Platform.OS === 'ios' && isGlassEffectAPIAvailable() && !reduceTransparency;
}

function GlassFrame({ children }: { children: ReactNode }) {
  const canUseGlass = useCanUseGlass();

  if (canUseGlass) {
    return (
      <GlassView colorScheme="auto" glassEffectStyle="regular" style={composerStyles.frame}>
        {children}
      </GlassView>
    );
  }

  return (
    <View style={[composerStyles.frame, composerStyles.frameFallback]}>{children}</View>
  );
}

// ── Answer sheet state ─────────────────────────────────
type ComposerAnswerState =
  | { kind: 'answer'; question: string; response: KnowledgeQueryResponseDTO }
  | { kind: 'error'; question: string; message: string; hint: 'api-key' | null };

// ── Context ────────────────────────────────────────────
type HomeComposerContextValue = {
  draft: string;
  setDraft: (value: string) => void;
  askModel: AskAiModel;
  setAskModel: (value: AskAiModel) => void;
  canSend: boolean;
  isAnswering: boolean;
  send: () => void;
};

const HomeComposerContext = createContext<HomeComposerContextValue | undefined>(undefined);

export function useHomeComposer(): HomeComposerContextValue {
  const value = useContext(HomeComposerContext);
  if (!value) {
    throw new Error('useHomeComposer must be used within <HomeComposerProvider>');
  }
  return value;
}

// ── Provider（タブレイアウトで 1 インスタンス）────────────
export function HomeComposerProvider({ children }: { children: ReactNode }) {
  const [draft, setDraft] = useState('');
  const [askModel, setAskModel] = useState<AskAiModel>('auto');
  const [isAnswering, setIsAnswering] = useState(false);
  const [answerState, setAnswerState] = useState<ComposerAnswerState | undefined>();
  const [isAnswerSheetOpen, setAnswerSheetOpen] = useState(false);

  const canSend = draft.trim().length > 0 && !isAnswering;

  const send = useCallback(async () => {
    const question = draft.trim();
    if (!question || isAnswering) return;

    setIsAnswering(true);
    try {
      const response = await MemoraNative.queryKnowledge(
        buildAskAiRequest('global', question, {}),
      );
      setAnswerState({ kind: 'answer', question, response });
      setDraft('');
      setAnswerSheetOpen(true);
    } catch (error) {
      const mapping = mapAskAiError(error);
      setAnswerState({ kind: 'error', question, message: mapping.message, hint: mapping.hint });
      setAnswerSheetOpen(true);
    } finally {
      setIsAnswering(false);
    }
  }, [draft, isAnswering]);

  const value = useMemo(
    () => ({ draft, setDraft, askModel, setAskModel, canSend, isAnswering, send }),
    [draft, askModel, canSend, isAnswering, send],
  );

  return (
    <HomeComposerContext.Provider value={value}>
      {children}
      <HomeComposerAnswerSheet
        isOpen={isAnswerSheetOpen}
        onClose={() => setAnswerSheetOpen(false)}
        state={answerState}
      />
    </HomeComposerContext.Provider>
  );
}

// ── 本体（BottomAccessory / フォールバック overlay 共用）──
export function HomeComposer() {
  const { draft, setDraft, askModel, setAskModel, canSend, isAnswering, send } = useHomeComposer();

  const modelValue = useMemo(
    () => ({ value: askModel, label: ASK_AI_MODEL_LABELS[askModel] }),
    [askModel],
  );

  return (
    <GlassFrame>
      <TextArea
        accessibilityLabel="Ask anything"
        background={null}
        maxLength={2000}
        onChangeText={setDraft}
        placeholder="Ask anything..."
        placeholderTextColor={colors.textTertiary}
        style={composerStyles.input}
        value={draft}
        variant="secondary"
      />
      <View style={composerStyles.actions}>
        <Button
          accessibilityLabel="ファイルを添付"
          feedbackVariant="none"
          isIconOnly
          onPress={() => Alert.alert('添付', 'この操作は現在利用できません。')}
          size="md"
          variant="ghost"
          style={composerStyles.iconButton}
        >
          <SymbolView
            name={{ ios: 'paperclip', android: 'attach_file', web: 'attach_file' }}
            size={18}
            tintColor={colors.textTertiary}
          />
        </Button>

        <Select
          onValueChange={(option) => {
            if (option) setAskModel(option.value as AskAiModel);
          }}
          presentation="popover"
          value={modelValue}
        >
          <Select.Trigger variant="unstyled" style={composerStyles.modelTrigger}>
            <Select.Value numberOfLines={1} placeholder="モデルを選択" style={composerStyles.modelValue} />
            <Select.TriggerIndicator iconProps={{ color: colors.textSecondary, size: 12 }} />
          </Select.Trigger>
          <Select.Portal>
            <Select.Overlay />
            <Select.Content align="center" placement="top" presentation="popover">
              {ASK_AI_MODEL_OPTIONS.map((model) => (
                <Select.Item key={model} label={ASK_AI_MODEL_LABELS[model]} value={model}>
                  <Select.ItemLabel />
                  <Select.ItemIndicator />
                </Select.Item>
              ))}
            </Select.Content>
          </Select.Portal>
        </Select>

        <Button
          accessibilityLabel="Ask AI send"
          feedbackVariant="none"
          isDisabled={!canSend}
          isIconOnly
          onPress={() => void send()}
          size="md"
          variant="primary"
          style={composerStyles.iconButton}
        >
          {isAnswering ? (
            <Spinner size="sm" />
          ) : (
            <SymbolView
              name={{ ios: 'arrow.up', android: 'arrow_upward', web: 'arrow_upward' }}
              size={18}
              tintColor={colors.surface}
            />
          )}
        </Button>
      </View>
    </GlassFrame>
  );
}

// ── 回答シート ─────────────────────────────────────────
function HomeComposerAnswerSheet({
  isOpen,
  onClose,
  state,
}: {
  isOpen: boolean;
  onClose: () => void;
  state: ComposerAnswerState | undefined;
}) {
  const router = useRouter();

  const openAiTab = () => {
    onClose();
    router.push('/ask-ai');
  };

  return (
    <FloatingBottomSheet isOpen={isOpen} onClose={onClose}>
      {state ? (
        <View style={sheetStyles.container}>
          <View style={sheetStyles.questionRow}>
            <View style={sheetStyles.questionBubble}>
              <Text style={sheetStyles.questionText}>{state.question}</Text>
            </View>
          </View>

          {state.kind === 'answer' ? (
            <>
              {state.response.isSample ? (
                <View style={sheetStyles.sampleBadge}>
                  <AppIcon color={colors.warning} name="warning-outline" size={12} />
                  <Text style={sheetStyles.sampleBadgeText}>サンプル回答（ネイティブ未接続）</Text>
                </View>
              ) : null}
              <Text style={sheetStyles.answerText}>{state.response.answer}</Text>
              {state.response.sources && state.response.sources.length > 0 ? (
                <View style={sheetStyles.sources}>
                  {state.response.sources.map((source) => (
                    <View key={source} style={sheetStyles.sourcePill}>
                      <AppIcon color={colors.textTertiary} name="document-outline" size={10} />
                      <Text numberOfLines={1} style={sheetStyles.sourceText}>
                        {source}
                      </Text>
                    </View>
                  ))}
                </View>
              ) : null}
            </>
          ) : (
            <Text style={sheetStyles.errorText}>{state.message}</Text>
          )}

          <View style={sheetStyles.actions}>
            {state.kind === 'error' && state.hint === 'api-key' ? (
              <Button
                accessibilityLabel="設定でAPIキーを入力"
                onPress={() => router.push('/settings')}
                size="sm"
                variant="primary"
              >
                設定でAPIキーを入力
              </Button>
            ) : null}
            <Button
              accessibilityLabel="AIタブで開く"
              onPress={openAiTab}
              size="sm"
              variant={state.kind === 'error' && state.hint === 'api-key' ? 'ghost' : 'primary'}
            >
              AIタブで開く
            </Button>
          </View>
        </View>
      ) : null}
    </FloatingBottomSheet>
  );
}

// ── styles ─────────────────────────────────────────────
const composerStyles = StyleSheet.create({
  frame: {
    borderColor: themeColors.light.glassBorderFallback,
    borderRadius: radius.lg,
    borderWidth: 1,
    gap: spacing.xs,
    marginHorizontal: spacing.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  frameFallback: {
    backgroundColor: themeColors.light.glassFallback,
  },
  input: {
    color: colors.text,
    maxHeight: 88,
    minHeight: 40,
    paddingVertical: 0,
    ...textStyles.body,
  },
  actions: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.xs,
  },
  iconButton: {
    height: 44,
    width: 44,
  },
  modelTrigger: {
    alignItems: 'center',
    flex: 1,
    justifyContent: 'center',
    minHeight: 44,
    paddingHorizontal: spacing.sm,
  },
  modelValue: {
    color: colors.textSecondary,
    flexShrink: 1,
    ...textStyles.caption,
  },
});

const sheetStyles = StyleSheet.create({
  container: {
    backgroundColor: colors.surface,
    gap: spacing.md,
    paddingBottom: spacing.xl,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.sm,
  },
  questionRow: {
    alignItems: 'flex-end',
  },
  questionBubble: {
    alignSelf: 'flex-end',
    backgroundColor: colors.accentSoft,
    borderRadius: radius.sm,
    maxWidth: '84%',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  questionText: {
    color: colors.text,
    ...textStyles.body,
  },
  sampleBadge: {
    alignItems: 'center',
    alignSelf: 'flex-start',
    backgroundColor: colors.warningSoft,
    borderRadius: radius.pill,
    flexDirection: 'row',
    gap: spacing.xs,
    paddingHorizontal: spacing.sm,
    paddingVertical: 3,
  },
  sampleBadgeText: {
    color: colors.warning,
    ...textStyles.footnoteBold,
  },
  answerText: {
    color: colors.text,
    ...textStyles.body,
  },
  errorText: {
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
  actions: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
  },
});
