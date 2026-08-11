import { GlassView, isGlassEffectAPIAvailable } from 'expo-glass-effect';
import { useRouter } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { AccessibilityInfo, Alert, Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import { Button } from 'heroui-native/button';
import { Select } from 'heroui-native/select';
import { colors, radius, spacing, textStyles } from '../design/tokens';
import {
  ASK_AI_MODEL_LABELS,
  ASK_AI_MODEL_OPTIONS,
  buildAskAiRequest,
  mapAskAiError,
  type AskAiModel,
} from '../native/askAiLogic';
import { MemoraNative } from '../native/MemoraNative';
import type { AskMessage } from '../types/memora';
import { colors as themeColors } from '../theme/tokens';

/** Exact Home frame height: one 44pt row plus padding/border, rounded to the 4pt grid. */
export const HOME_COMPOSER_HEIGHT = 60;
export const HOME_PROJECT_SELECTOR_HEIGHT = 52;
export const HOME_COMPOSER_GAP = spacing.xxs;

export type HomeViewMode = 'files' | 'projects';

function useCanUseGlass() {
  const [reduceTransparency, setReduceTransparency] = useState(false);

  useEffect(() => {
    let isMounted = true;
    AccessibilityInfo.isReduceTransparencyEnabled()
      .then((enabled) => {
        if (isMounted) setReduceTransparency(enabled);
      })
      .catch(() => {
        // 判定できない環境では不透明 Surface を使う。
        if (isMounted) setReduceTransparency(true);
      });
    return () => {
      isMounted = false;
    };
  }, []);

  return Platform.OS === 'ios' && isGlassEffectAPIAvailable() && !reduceTransparency;
}

export function ComposerGlassFrame({
  children,
  compact = false,
}: {
  children: ReactNode;
  compact?: boolean;
}) {
  const canUseGlass = useCanUseGlass();
  const frameStyle = [styles.frame, compact && styles.compactFrame];

  if (canUseGlass) {
    return (
      <GlassView colorScheme="auto" glassEffectStyle="regular" style={frameStyle}>
        {children}
      </GlassView>
    );
  }

  return <View style={[frameStyle, styles.glassFallback]}>{children}</View>;
}

type HomeComposerContextValue = {
  draft: string;
  setDraft: (value: string) => void;
  askModel: AskAiModel;
  setAskModel: (value: AskAiModel) => void;
  canSend: boolean;
  isAnswering: boolean;
  messages: AskMessage[];
  send: () => Promise<void>;
  viewMode: HomeViewMode;
  setViewMode: (value: HomeViewMode) => void;
  selectedProject: string | undefined;
  setSelectedProject: (value: string | undefined) => void;
  projectOptions: string[];
  setProjectOptions: (value: string[]) => void;
};

const HomeComposerContext = createContext<HomeComposerContextValue | undefined>(undefined);

export function useHomeComposer(): HomeComposerContextValue {
  const value = useContext(HomeComposerContext);
  if (!value) {
    throw new Error('useHomeComposer must be used within <HomeComposerProvider>');
  }
  return value;
}

export function HomeComposerProvider({ children }: { children: ReactNode }) {
  const [draft, setDraft] = useState('');
  const [askModel, setAskModel] = useState<AskAiModel>('auto');
  const [isAnswering, setIsAnswering] = useState(false);
  const [messages, setMessages] = useState<AskMessage[]>([]);
  const [viewMode, setViewMode] = useState<HomeViewMode>('files');
  const [selectedProject, setSelectedProject] = useState<string | undefined>();
  const [projectOptions, setProjectOptions] = useState<string[]>([]);

  const canSend = draft.trim().length > 0 && !isAnswering;

  const send = useCallback(async () => {
    const question = draft.trim();
    if (!question || isAnswering) return;

    const requestId = Date.now();
    setDraft('');
    setIsAnswering(true);
    setMessages((current) => [
      ...current,
      { id: `home-user-${requestId}`, role: 'user', text: question },
    ]);

    try {
      const response = await MemoraNative.queryKnowledge(
        buildAskAiRequest('global', question, {}),
      );
      setMessages((current) => [
        ...current,
        {
          id: response.id,
          role: 'assistant',
          text: response.answer,
          sources: response.sources,
          isSample: response.isSample,
        },
      ]);
    } catch (error) {
      const mapping = mapAskAiError(error);
      setMessages((current) => [
        ...current,
        {
          id: `home-error-${requestId}`,
          role: 'assistant',
          text: mapping.message,
          hint: mapping.hint ?? undefined,
        },
      ]);
    } finally {
      setIsAnswering(false);
    }
  }, [draft, isAnswering]);

  const value = useMemo(
    () => ({
      draft,
      setDraft,
      askModel,
      setAskModel,
      canSend,
      isAnswering,
      messages,
      send,
      viewMode,
      setViewMode,
      selectedProject,
      setSelectedProject,
      projectOptions,
      setProjectOptions,
    }),
    [
      askModel,
      canSend,
      draft,
      isAnswering,
      messages,
      projectOptions,
      selectedProject,
      send,
      viewMode,
    ],
  );

  return <HomeComposerContext.Provider value={value}>{children}</HomeComposerContext.Provider>;
}

export function AskModelSelect({ compact = false }: { compact?: boolean }) {
  const { askModel, setAskModel } = useHomeComposer();
  const modelValue = useMemo(
    () => ({
      value: askModel,
      label: compact && askModel === 'auto' ? 'Auto' : ASK_AI_MODEL_LABELS[askModel],
    }),
    [askModel, compact],
  );

  return (
    <Select
      onValueChange={(option) => {
        if (option) setAskModel(option.value as AskAiModel);
      }}
      presentation="popover"
      value={modelValue}
    >
      <Select.Trigger
        accessibilityLabel="AIモデルを選択"
        variant="unstyled"
        style={[styles.modelTrigger, compact && styles.modelTriggerCompact]}
      >
        <Select.Value numberOfLines={1} placeholder="モデルを選択" style={styles.modelValue} />
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
  );
}

function ProjectSelectPill() {
  const canUseGlass = useCanUseGlass();
  const { projectOptions, selectedProject, setSelectedProject } = useHomeComposer();
  const selectedValue = selectedProject
    ? { value: selectedProject, label: selectedProject }
    : undefined;
  const trigger = (
    <Select.Trigger
      accessibilityLabel="プロジェクトを選択"
      variant="unstyled"
      style={styles.projectTrigger}
    >
      <SymbolView
        name={{ ios: 'folder', android: 'folder', web: 'folder' }}
        size={16}
        tintColor={colors.textSecondary}
      />
      <Select.Value
        numberOfLines={1}
        placeholder="プロジェクトを選択"
        style={styles.projectValue}
      />
      <Select.TriggerIndicator iconProps={{ color: colors.textSecondary, size: 12 }} />
    </Select.Trigger>
  );

  return (
    <Select
      isDisabled={projectOptions.length === 0}
      onValueChange={(option) => setSelectedProject(option?.value)}
      presentation="bottom-sheet"
      value={selectedValue}
    >
      {canUseGlass ? (
        <GlassView colorScheme="auto" glassEffectStyle="regular" style={styles.projectPill}>
          {trigger}
        </GlassView>
      ) : (
        <View style={[styles.projectPill, styles.glassFallback]}>{trigger}</View>
      )}
      <Select.Portal>
        <Select.Overlay />
        <Select.Content presentation="bottom-sheet">
          <Select.ListLabel style={styles.projectSheetLabel}>プロジェクトを選択</Select.ListLabel>
          {projectOptions.map((project) => (
            <Select.Item key={project} label={project} value={project}>
              <Select.ItemLabel />
              <Select.ItemIndicator />
            </Select.Item>
          ))}
        </Select.Content>
      </Select.Portal>
    </Select>
  );
}

/** Home BottomAccessory entry point. The actual text input lives in /ask. */
export function HomeComposer() {
  const router = useRouter();
  const { viewMode } = useHomeComposer();

  return (
    <View style={styles.accessory}>
      {viewMode === 'projects' ? <ProjectSelectPill /> : null}
      <ComposerGlassFrame compact>
        <View style={styles.entryRow}>
          <Pressable
            accessibilityLabel="Ask AI を開く"
            accessibilityRole="button"
            onPress={() => router.push('/ask')}
            style={({ pressed }) => [styles.entryPrompt, pressed && styles.pressed]}
          >
            <Text numberOfLines={1} style={styles.placeholder}>
              Ask anything...
            </Text>
          </Pressable>
          <View style={styles.entryActions}>
            <Button
              accessibilityLabel="ファイルを添付"
              feedbackVariant="none"
              isIconOnly
              onPress={() => Alert.alert('添付', 'この操作は現在利用できません。')}
              size="md"
              variant="ghost"
              style={styles.iconButton}
            >
              <SymbolView
                name={{ ios: 'paperclip', android: 'attach_file', web: 'attach_file' }}
                size={18}
                tintColor={colors.textTertiary}
              />
            </Button>

            <AskModelSelect compact />

            <Button
              accessibilityLabel="音声入力を開始"
              feedbackVariant="none"
              isIconOnly
              onPress={() => Alert.alert('音声入力', 'この操作は現在利用できません。')}
              size="md"
              variant="primary"
              style={styles.iconButton}
            >
              <SymbolView
                name={{ ios: 'waveform', android: 'graphic_eq', web: 'graphic_eq' }}
                size={18}
                tintColor={colors.surface}
              />
            </Button>
          </View>
        </View>
      </ComposerGlassFrame>
    </View>
  );
}

export const homeComposerStyles = StyleSheet.create({
  actions: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.xs,
  },
  iconButton: {
    height: 44,
    width: 44,
  },
  input: {
    color: colors.text,
    maxHeight: 88,
    minHeight: 44,
    paddingVertical: 0,
    ...textStyles.body,
  },
});

const styles = StyleSheet.create({
  accessory: {
    gap: HOME_COMPOSER_GAP,
  },
  frame: {
    borderColor: themeColors.light.glassBorderFallback,
    borderRadius: radius.lg,
    borderWidth: 1,
    gap: spacing.xs,
    marginHorizontal: spacing.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  compactFrame: {
    height: HOME_COMPOSER_HEIGHT,
    justifyContent: 'center',
    paddingVertical: spacing.xxs,
  },
  glassFallback: {
    backgroundColor: themeColors.light.glassFallback,
  },
  entryPrompt: {
    flex: 1,
    justifyContent: 'center',
    minHeight: 44,
  },
  entryRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.xs,
    minHeight: 44,
  },
  entryActions: {
    alignItems: 'center',
    flexDirection: 'row',
    flexShrink: 0,
    gap: spacing.xs,
  },
  placeholder: {
    color: colors.textTertiary,
    ...textStyles.body,
  },
  pressed: {
    opacity: 0.72,
  },
  actions: homeComposerStyles.actions,
  iconButton: homeComposerStyles.iconButton,
  modelTrigger: {
    alignItems: 'center',
    // Without an explicit row direction the value and the chevron stack vertically.
    // `flex: 1` here collapses the label to zero width, so size from content instead.
    flexDirection: 'row',
    flexGrow: 0,
    flexShrink: 1,
    gap: spacing.xxs,
    justifyContent: 'center',
    minHeight: 44,
    paddingHorizontal: spacing.sm,
  },
  modelTriggerCompact: {
    flex: 0,
    width: 80,
  },
  modelValue: {
    color: colors.textSecondary,
    flexShrink: 1,
    ...textStyles.caption,
  },
  projectPill: {
    borderColor: themeColors.light.glassBorderFallback,
    borderRadius: radius.pill,
    borderWidth: 1,
    marginHorizontal: spacing.md,
    overflow: 'hidden',
  },
  projectTrigger: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.xs,
    minHeight: 44,
    paddingHorizontal: spacing.md,
  },
  projectValue: {
    color: colors.textSecondary,
    flex: 1,
    ...textStyles.footnoteBold,
  },
  projectSheetLabel: {
    color: colors.textSecondary,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    ...textStyles.footnoteBold,
  },
});
