import { FlashList, type FlashListRef } from '@shopify/flash-list';
import { useRouter } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { useEffect, useRef } from 'react';
import {
  Alert,
  KeyboardAvoidingView,
  Platform,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { Button } from 'heroui-native/button';
import { Spinner } from 'heroui-native/spinner';
import { TextArea } from 'heroui-native/text-area';
import { AppIcon } from '../components/AppIcon';
import {
  AskModelSelect,
  ComposerGlassFrame,
  homeComposerStyles,
  useHomeComposer,
} from '../components/HomeComposer';
import { colors, radius, spacing, textStyles } from '../design/tokens';
import type { AskMessage } from '../types/memora';

export function AskAiOverlayScreen() {
  const router = useRouter();
  const listRef = useRef<FlashListRef<AskMessage>>(null);
  const { canSend, draft, isAnswering, messages, send, setDraft } = useHomeComposer();

  useEffect(() => {
    if (messages.length > 0 || isAnswering) {
      requestAnimationFrame(() => listRef.current?.scrollToEnd({ animated: true }));
    }
  }, [isAnswering, messages.length]);

  const handlePrimaryAction = () => {
    if (canSend) {
      void send();
      return;
    }
    if (!isAnswering) {
      Alert.alert('音声入力', 'この操作は現在利用できません。');
    }
  };

  return (
    // fullScreenModal is presented as its own view controller, where the ambient
    // safe-area context collapses to zero. A local provider measures this screen.
    <SafeAreaProvider style={styles.safeArea}>
      <SafeAreaView edges={['top', 'bottom']} style={styles.safeArea}>
        <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={styles.keyboardAvoiding}
      >
        <View style={styles.header}>
          <View
            accessibilityElementsHidden
            importantForAccessibility="no-hide-descendants"
            style={styles.grabber}
          />
          <Button
            accessibilityLabel="Ask AI を閉じる"
            onPress={() => router.back()}
            size="md"
            variant="ghost"
            style={styles.closeButton}
          >
            閉じる
          </Button>
        </View>

        <FlashList
          ref={listRef}
          contentContainerStyle={styles.listContent}
          data={messages}
          keyExtractor={(message) => message.id}
          keyboardDismissMode="interactive"
          keyboardShouldPersistTaps="handled"
          ListEmptyComponent={
            <View style={styles.emptyState}>
              <Text style={styles.emptyTitle}>Ask AI</Text>
              <Text style={styles.emptyBody}>記録について知りたいことを質問してください。</Text>
            </View>
          }
          ListFooterComponent={
            isAnswering ? (
              <View style={styles.answeringStatus}>
                <Spinner size="sm" />
                <Text style={styles.answeringText}>回答を生成中</Text>
              </View>
            ) : null
          }
          renderItem={({ item }) =>
            item.role === 'user' ? (
              <View style={styles.questionRow}>
                <View style={styles.questionBubble}>
                  <Text style={styles.questionText}>{item.text}</Text>
                </View>
              </View>
            ) : (
              <View style={styles.answerBlock}>
                {item.isSample ? (
                  <View style={styles.sampleBadge}>
                    <AppIcon color={colors.warning} name="warning-outline" size={12} />
                    <Text style={styles.sampleBadgeText}>サンプル回答（ネイティブ未接続）</Text>
                  </View>
                ) : null}
                <Text style={styles.answerText}>{item.text}</Text>
                {item.sources && item.sources.length > 0 ? (
                  <View style={styles.sources}>
                    {item.sources.map((source) => (
                      <View key={source} style={styles.sourcePill}>
                        <AppIcon color={colors.textTertiary} name="document-outline" size={10} />
                        <Text numberOfLines={1} style={styles.sourceText}>
                          {source}
                        </Text>
                      </View>
                    ))}
                  </View>
                ) : null}
                {item.hint === 'api-key' ? (
                  <Button
                    accessibilityLabel="設定で API キーを入力"
                    onPress={() => router.push('/settings')}
                    size="sm"
                    variant="primary"
                    style={styles.settingsButton}
                  >
                    設定で API キーを入力
                  </Button>
                ) : null}
              </View>
            )
          }
          showsVerticalScrollIndicator={false}
          style={styles.list}
        />

        <View style={styles.composerDock}>
          <ComposerGlassFrame>
            <TextArea
              accessibilityLabel="Ask AI question"
              autoFocus
              background={null}
              maxLength={2000}
              onChangeText={setDraft}
              onSubmitEditing={() => {
                if (canSend) void send();
              }}
              placeholder="Ask anything..."
              placeholderTextColor={colors.textTertiary}
              returnKeyType="send"
              style={homeComposerStyles.input}
              value={draft}
              variant="secondary"
            />
            <View style={homeComposerStyles.actions}>
              <Button
                accessibilityLabel="ファイルを添付"
                feedbackVariant="none"
                isIconOnly
                onPress={() => Alert.alert('添付', 'この操作は現在利用できません。')}
                size="md"
                variant="ghost"
                style={homeComposerStyles.iconButton}
              >
                <SymbolView
                  name={{ ios: 'paperclip', android: 'attach_file', web: 'attach_file' }}
                  size={18}
                  tintColor={colors.textTertiary}
                />
              </Button>

              {/* Fixed-width trigger: the flexible one collapses the label to zero width. */}
              <AskModelSelect compact />

              <Button
                accessibilityLabel={draft.trim() ? '質問を送信' : '音声入力を開始'}
                accessibilityState={{ busy: isAnswering }}
                feedbackVariant="none"
                isDisabled={isAnswering}
                isIconOnly
                onPress={handlePrimaryAction}
                size="md"
                variant="primary"
                style={[homeComposerStyles.iconButton, styles.sendButton]}
              >
                {isAnswering ? (
                  <Spinner size="sm" />
                ) : (
                  <SymbolView
                    name={
                      draft.trim()
                        ? { ios: 'arrow.up', android: 'arrow_upward', web: 'arrow_upward' }
                        : { ios: 'waveform', android: 'graphic_eq', web: 'graphic_eq' }
                    }
                    size={18}
                    tintColor={colors.surface}
                  />
                )}
              </Button>
            </View>
          </ComposerGlassFrame>
        </View>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    backgroundColor: colors.canvas,
    flex: 1,
  },
  keyboardAvoiding: {
    flex: 1,
  },
  header: {
    alignItems: 'center',
    minHeight: 52,
    paddingHorizontal: spacing.md,
    position: 'relative',
  },
  grabber: {
    backgroundColor: colors.border,
    borderRadius: radius.pill,
    height: 5,
    marginTop: spacing.xs,
    width: 36,
  },
  closeButton: {
    alignSelf: 'flex-end',
    minHeight: 44,
    minWidth: 44,
    position: 'absolute',
    right: spacing.md,
    top: 0,
  },
  list: {
    flex: 1,
  },
  listContent: {
    paddingBottom: spacing.lg,
    paddingHorizontal: spacing.md,
    paddingTop: spacing.sm,
  },
  emptyState: {
    alignItems: 'center',
    gap: spacing.xs,
    paddingHorizontal: spacing.lg,
    paddingTop: 96,
  },
  emptyTitle: {
    color: colors.text,
    ...textStyles.title2,
  },
  emptyBody: {
    color: colors.textSecondary,
    textAlign: 'center',
    ...textStyles.body,
  },
  questionRow: {
    alignItems: 'flex-end',
    marginBottom: spacing.md,
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
  answerBlock: {
    alignItems: 'flex-start',
    gap: spacing.sm,
    marginBottom: spacing.md,
  },
  sampleBadge: {
    alignItems: 'center',
    alignSelf: 'flex-start',
    backgroundColor: colors.warningSoft,
    borderRadius: radius.pill,
    flexDirection: 'row',
    gap: spacing.xs,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xxs,
  },
  sampleBadgeText: {
    color: colors.warning,
    ...textStyles.footnoteBold,
  },
  answerText: {
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
    paddingVertical: spacing.xxs,
  },
  sourceText: {
    color: colors.textTertiary,
    ...textStyles.caption,
  },
  settingsButton: {
    minHeight: 44,
  },
  answeringStatus: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.xs,
    paddingBottom: spacing.md,
  },
  answeringText: {
    color: colors.textSecondary,
    ...textStyles.footnote,
  },
  composerDock: {
    paddingBottom: spacing.xs,
  },
  sendButton: {
    marginLeft: 'auto',
  },
});
