import AsyncStorage from '@react-native-async-storage/async-storage';
import { useEffect, useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { AppIcon } from '../components/AppIcon';
import { useRouter } from 'expo-router';
import { colors, radius, spacing, typography } from '../design/tokens';
import { DEV_FONT_CANDIDATES, useDevFontsLoaded, type DevFontCandidate, type DevFontKey } from '../features/dev/devFontCandidates';

const SAMPLE_JA = '録音を要約しました。次のアクションを確認してください。';
const SAMPLE_EN = 'Ask AI about this recording';
const SELECTED_FONT_STORAGE_KEY = 'memora.dev.selected-font';

export function DevFontPreviewScreen() {
  const router = useRouter();
  const fontsLoaded = useDevFontsLoaded();
  const [selectedKey, setSelectedKey] = useState<DevFontKey>(DEV_FONT_CANDIDATES[0].key);
  const [isSelectionLoaded, setIsSelectionLoaded] = useState(false);
  const [persistenceError, setPersistenceError] = useState<string | null>(null);
  const selected = DEV_FONT_CANDIDATES.find((item) => item.key === selectedKey) ?? DEV_FONT_CANDIDATES[0];

  useEffect(() => {
    let isMounted = true;
    AsyncStorage.getItem(SELECTED_FONT_STORAGE_KEY)
      .then((storedKey) => {
        if (!isMounted) return;
        if (storedKey && DEV_FONT_CANDIDATES.some((candidate) => candidate.key === storedKey)) {
          setSelectedKey(storedKey as DevFontKey);
        }
      })
      .catch(() => {
        if (isMounted) setPersistenceError('保存したフォントを読み込めませんでした。');
      })
      .finally(() => {
        if (isMounted) setIsSelectionLoaded(true);
      });

    return () => {
      isMounted = false;
    };
  }, []);

  function selectFont(key: DevFontKey) {
    setSelectedKey(key);
    setPersistenceError(null);
    void AsyncStorage.setItem(SELECTED_FONT_STORAGE_KEY, key).catch(() => {
      setPersistenceError('フォントの選択を保存できませんでした。');
    });
  }

  return (
    <View style={styles.screen}>
      <View style={styles.header}>
        <Pressable accessibilityLabel="閉じる" accessibilityRole="button" hitSlop={12} onPress={() => router.back()} style={styles.closeButton}>
          <AppIcon color={colors.text} name="close" size={20} />
        </Pressable>
        <Text style={styles.headerTitle}>フォント候補プレビュー</Text>
        <View style={styles.closeButton} />
      </View>

      {!fontsLoaded || !isSelectionLoaded ? (
        <View style={styles.loading}><ActivityIndicator color={colors.text} /></View>
      ) : (
        <>
          <ScrollView contentContainerStyle={styles.pickerRow} horizontal showsHorizontalScrollIndicator={false}>
            {DEV_FONT_CANDIDATES.map((candidate) => (
              <FontChip
                key={candidate.key}
                isSelected={candidate.key === selectedKey}
                label={candidate.label}
                onPress={() => selectFont(candidate.key)}
              />
            ))}
          </ScrollView>

          {persistenceError ? <Text accessibilityRole="alert" style={styles.persistenceError}>{persistenceError}</Text> : null}

          <ScrollView contentContainerStyle={styles.preview}>
            <PreviewBlock candidate={selected} />
          </ScrollView>
        </>
      )}
    </View>
  );
}

function FontChip({ isSelected, label, onPress }: { isSelected: boolean; label: string; onPress: () => void }) {
  return (
    <Pressable accessibilityRole="button" accessibilityState={{ selected: isSelected }} onPress={onPress} style={[styles.chip, isSelected && styles.chipSelected]}>
      <Text style={[styles.chipText, isSelected && styles.chipTextSelected]}>{label}</Text>
    </Pressable>
  );
}

function PreviewBlock({ candidate }: { candidate: DevFontCandidate }) {
  const regular = candidate.regular ? { fontFamily: candidate.regular } : undefined;
  const semibold = candidate.semibold ? { fontFamily: candidate.semibold } : undefined;

  return (
    <View style={styles.previewCard}>
      <Text style={[styles.displaySample, semibold]}>{SAMPLE_JA}</Text>
      <Text style={[styles.titleSample, semibold]}>{SAMPLE_EN}</Text>
      <Text style={[styles.bodySample, regular]}>
        {SAMPLE_JA} Recorded 48 minutes, transcribed and summarized automatically. 0123456789
      </Text>
      <Text style={[styles.captionSample, regular]}>今日 14:20 ・ 要約済み ・ ABCDEFG abcdefg</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { backgroundColor: colors.canvas, flex: 1, paddingTop: 60 },
  header: { alignItems: 'center', flexDirection: 'row', justifyContent: 'space-between', paddingHorizontal: spacing.lg, paddingBottom: spacing.md },
  closeButton: { alignItems: 'center', height: 32, justifyContent: 'center', width: 32 },
  headerTitle: { color: colors.text, fontSize: typography.size.subtitle, fontWeight: '700' },
  loading: { alignItems: 'center', flex: 1, justifyContent: 'center' },
  pickerRow: { gap: spacing.sm, paddingHorizontal: spacing.lg, paddingVertical: spacing.sm },
  chip: { backgroundColor: colors.surfaceAlt, borderRadius: radius.pill, paddingHorizontal: spacing.md, paddingVertical: spacing.xs },
  chipSelected: { backgroundColor: colors.ink },
  chipText: { color: colors.textMuted, fontSize: typography.size.body, fontWeight: '600' },
  chipTextSelected: { color: '#FFFFFF' },
  persistenceError: { color: colors.danger, fontSize: typography.size.caption, paddingHorizontal: spacing.lg, paddingTop: spacing.sm },
  preview: { padding: spacing.lg },
  previewCard: { backgroundColor: colors.surfaceAlt, borderRadius: radius.cardAlt, gap: spacing.md, padding: spacing.lg },
  displaySample: { color: colors.text, fontSize: typography.size.display, lineHeight: typography.lineHeight(typography.size.display) },
  titleSample: { color: colors.text, fontSize: typography.size.title, fontWeight: '700', lineHeight: typography.lineHeight(typography.size.title) },
  bodySample: { color: colors.textMuted, fontSize: typography.size.body, lineHeight: typography.lineHeight(typography.size.body) },
  captionSample: { color: colors.textSubtle, fontSize: typography.size.caption, lineHeight: typography.lineHeight(typography.size.caption) },
});
