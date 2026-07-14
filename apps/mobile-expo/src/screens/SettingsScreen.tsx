import { Children, Fragment, useEffect, useState, type ReactNode } from 'react';
import { Alert, Pressable, StyleSheet, Switch, Text, View } from 'react-native';
import { AppIcon as Ionicons } from '../components/AppIcon';
import { useRouter } from 'expo-router';
import { Screen } from '../components/Screen';
import { Section } from '../components/Section';
import { colors, radius, spacing } from '../design/tokens';
import { MemoraNative } from '../native/MemoraNative';
import type { BridgeInfoDTO, SettingsDTO, SummaryOptionsDTO } from '../native/MemoraNative.types';
import type { SettingsGroup } from '../types/memora';

const NOT_CONNECTED_MESSAGE =
  'ネイティブブリッジがこのアクションにまだ接続されていません。SwiftUI版の実データ接続後に有効化します。';

const APP_VERSION = '1.0.0';

const stateColors = {
  ok: colors.success,
  warning: colors.warning,
  off: colors.textTertiary,
} as const;

const defaultSettings: SettingsDTO = {
  speechAnalyzerEnabled: false,
  summaryProvider: 'Gemini',
  transcriptionMode: 'local',
};

const providerOptions: SummaryOptionsDTO['provider'][] = ['Gemini', 'OpenAI', 'DeepSeek', 'Local'];

export function SettingsScreen() {
  const router = useRouter();
  const [bridgeInfo, setBridgeInfo] = useState<BridgeInfoDTO | null>(null);
  const [settings, setSettings] = useState<SettingsDTO>(defaultSettings);
  const [notifEnabled, setNotifEnabled] = useState(false);
  const [isDeveloperOpen, setIsDeveloperOpen] = useState(false);

  useEffect(() => {
    let isMounted = true;

    Promise.all([MemoraNative.getBridgeInfo(), MemoraNative.loadSettings()]).then(([info, nextSettings]) => {
      if (isMounted) {
        setBridgeInfo(info);
        setSettings(nextSettings);
      }
    });

    return () => {
      isMounted = false;
    };
  }, []);

  const notConnected = () => Alert.alert('準備中', NOT_CONNECTED_MESSAGE);

  return (
    <Screen title="設定">
      <SettingsGroupCard title="アカウント">
        <SettingsRow onPress={notConnected} title="未設定" />
        <SettingsBadgeRow badgeColor={colors.text} badgeText="Free" onPress={() => router.push('/auth?stage=paywall')} title="プラン" />
      </SettingsGroupCard>

      <SettingsGroupCard title="デバイス">
        <SettingsRow
          onPress={notConnected}
          title="PLAUD / Omi デバイス管理"
          value="未接続"
        />
      </SettingsGroupCard>

      <SettingsGroupCard title="ストレージ">
        <SettingsRow onPress={notConnected} title="添付の保存先" value="この端末（Proでクラウド）" />
      </SettingsGroupCard>

      <SettingsGroupCard title="通知">
        <View style={styles.toggleRow}>
          <Text style={styles.v6RowTitle}>プッシュ通知</Text>
          <Switch
            onValueChange={setNotifEnabled}
            thumbColor={colors.surface}
            trackColor={{ false: colors.border, true: colors.text }}
            value={notifEnabled}
          />
        </View>
      </SettingsGroupCard>

      <SettingsGroupCard title="連携">
        <SettingsRow onPress={notConnected} title="Notion に書き出す" value="未接続" />
        <SettingsRow onPress={notConnected} title="ChatGPT に共有" value="未接続" />
      </SettingsGroupCard>

      <SettingsGroupCard title="言語">
        <SettingsRow onPress={notConnected} title="表示言語" value="日本語" />
        <SettingsRow onPress={notConnected} title="文字起こし言語" value="自動検出" />
      </SettingsGroupCard>

      <SettingsGroupCard title="文字起こし・要約">
        <SettingsRow onPress={notConnected} title="要約AIモデル" value={settings.summaryProvider} />
        <SettingsRow onPress={notConnected} title="要約テンプレート" value="議事録" />
        <View style={styles.toggleRow}>
          <Text style={styles.v6RowTitle}>音声解析（話者識別）</Text>
          <Switch
            onValueChange={(speechAnalyzerEnabled) => saveSettings({ ...settings, speechAnalyzerEnabled })}
            thumbColor={colors.surface}
            trackColor={{ false: colors.border, true: colors.text }}
            value={settings.speechAnalyzerEnabled}
          />
        </View>
      </SettingsGroupCard>

      <SettingsGroupCard title="データ">
        <SettingsRow onPress={notConnected} title="キャッシュを消去" showChevron={false} />
        <SettingsRow onPress={notConnected} title="全データを書き出す" showChevron={false} />
      </SettingsGroupCard>

      <SettingsGroupCard title="情報">
        <View style={styles.v6Row}>
          <Text style={styles.v6RowTitle}>バージョン</Text>
          <Text numberOfLines={1} style={styles.v6RowValue}>{APP_VERSION}</Text>
        </View>
        <SettingsRow onPress={notConnected} title="ライセンス情報" />
        <SettingsRow onPress={notConnected} title="プライバシーポリシー" />
      </SettingsGroupCard>

      <SettingsGroupCard title="アカウント操作">
        <SettingsRow
          destructive
          onPress={notConnected}
          showChevron={false}
          title="ログアウト"
        />
        <SettingsRow
          destructive
          onPress={notConnected}
          showChevron={false}
          title="アカウントを削除する"
        />
      </SettingsGroupCard>

      <Pressable accessibilityRole="button" accessibilityState={{ expanded: isDeveloperOpen }} onPress={() => setIsDeveloperOpen((open) => !open)} style={({ pressed }) => [styles.developerToggle, pressed && styles.developerTogglePressed]}>
        <Text style={styles.developerToggleText}>開発者向け</Text><Ionicons color={colors.textTertiary} name={isDeveloperOpen ? 'chevron-up' : 'chevron-down'} size={14} />
      </Pressable>

      {isDeveloperOpen ? <>
      <Section title="開発ツール">
        <View style={styles.groupCard}>
          <SettingsRow onPress={() => router.push('/dev-fonts')} title="フォント候補を試す" />
        </View>
      </Section>
      <Section title="設定を編集">
        <View style={styles.groupCard}>
          <View style={styles.controlBlock}>
            <Text style={styles.label}>Transcription mode</Text>
            <View style={styles.segmentRow}>
              <SegmentButton
                isSelected={settings.transcriptionMode === 'local'}
                label="Local"
                onPress={() => saveSettings({ ...settings, transcriptionMode: 'local' })}
              />
              <SegmentButton
                isSelected={settings.transcriptionMode === 'api'}
                label="API"
                onPress={() => saveSettings({ ...settings, transcriptionMode: 'api' })}
              />
            </View>
          </View>

          <View style={styles.controlBlock}>
            <Text style={styles.label}>Summary provider</Text>
            <View style={styles.providerGrid}>
              {providerOptions.map((provider) => (
                <SegmentButton
                  key={provider}
                  isSelected={settings.summaryProvider === provider}
                  label={provider}
                  onPress={() => saveSettings({ ...settings, summaryProvider: provider })}
                />
              ))}
            </View>
          </View>

          <View style={styles.switchRow}>
            <View>
              <Text style={styles.label}>SpeechAnalyzer</Text>
              <Text style={styles.value}>
                {settings.speechAnalyzerEnabled ? 'Feature flag on' : 'Feature flag off'}
              </Text>
            </View>
            <Switch
              onValueChange={(speechAnalyzerEnabled) =>
                saveSettings({ ...settings, speechAnalyzerEnabled })
              }
              thumbColor={colors.surface}
              trackColor={{ false: colors.border, true: colors.accent }}
              value={settings.speechAnalyzerEnabled}
            />
          </View>
        </View>
      </Section>

      {buildSettingsGroups(settings, bridgeInfo).map((group) => (
        <Section key={group.title} title={group.title}>
          <View style={styles.groupCard}>
            <View style={styles.rows}>
              {group.items.map((item) => (
                <View key={item.label} style={styles.row}>
                  <View>
                    <Text style={styles.label}>{item.label}</Text>
                    <Text style={styles.value}>{item.value}</Text>
                  </View>
                  <View
                    style={[
                      styles.dot,
                      { backgroundColor: stateColors[item.state ?? 'off'] },
                    ]}
                  />
                </View>
              ))}
            </View>
          </View>
        </Section>
      ))}

      <Section title="Bridge">
        <View style={styles.groupCard}>
          <View style={styles.rows}>
            <InfoRow label="Module" value={bridgeInfo?.moduleName ?? 'Loading'} state="ok" />
            <InfoRow label="Platform" value={bridgeInfo?.platform ?? 'checking'} state="ok" />
            <InfoRow
              label="Audio source"
              value={bridgeInfo?.audioFileSource ?? 'checking'}
              state={bridgeInfo?.isRealDataConnected ? 'ok' : 'warning'}
            />
            <InfoRow
              label="Mutation source"
              value={bridgeInfo?.audioFileMutationSource ?? 'checking'}
              state={
                bridgeInfo?.audioFileMutationSource === 'swiftdata' ||
                bridgeInfo?.audioFileMutationSource === 'native-files'
                  ? 'ok'
                  : 'warning'
              }
            />
            <InfoRow
              label="Recording source"
              value={bridgeInfo?.recordingSource ?? 'checking'}
              state={
                bridgeInfo?.recordingSource === 'native' ||
                bridgeInfo?.recordingSource === 'native-file'
                  ? 'ok'
                  : 'warning'
              }
            />
            <InfoRow
              label="Settings source"
              value={bridgeInfo?.settingsSource ?? 'checking'}
              state={
                bridgeInfo?.settingsSource === 'keychain' ||
                bridgeInfo?.settingsSource === 'userdefaults'
                  ? 'ok'
                  : 'warning'
              }
            />
            <InfoRow
              label="Knowledge source"
              value={bridgeInfo?.knowledgeQuerySource ?? 'checking'}
              state={bridgeInfo?.knowledgeQuerySource === 'mock' ? 'warning' : 'ok'}
            />
            <InfoRow
              label="Summary source"
              value={bridgeInfo?.summarySource ?? 'checking'}
              state={bridgeInfo?.summarySource === 'mock' ? 'warning' : 'ok'}
            />
            <InfoRow
              label="Persistence scope"
              value={bridgeInfo?.persistenceScope ?? 'checking'}
              state={bridgeInfo?.persistenceScope === 'shared-swiftdata' ? 'ok' : 'warning'}
            />
          </View>
        </View>
      </Section>
      </> : null}
    </Screen>
  );

  function saveSettings(nextSettings: SettingsDTO) {
    setSettings(nextSettings);
    void MemoraNative.saveSettings(nextSettings);
  }
}

function buildSettingsGroups(
  settings: SettingsDTO,
  bridgeInfo: BridgeInfoDTO | null,
): SettingsGroup[] {
  const transcriptionMode = settings.transcriptionMode === 'api' ? 'API first' : 'Local first';
  const speechAnalyzer = settings.speechAnalyzerEnabled ? 'Feature flag on' : 'Feature flag off';
  const bridgeState = bridgeInfo?.isRealDataConnected ? 'ok' : 'warning';
  const bridgeValue = bridgeInfo
    ? `${bridgeInfo.moduleName} / ${bridgeInfo.audioFileSource} / ${bridgeInfo.audioFileMutationSource} / ${bridgeInfo.recordingSource} / ${bridgeInfo.settingsSource} / ${bridgeInfo.knowledgeQuerySource} / ${bridgeInfo.summarySource}`
    : 'Checking';

  return [
    {
      title: '文字起こしと AI',
      description: '既存 Swift core を維持し、RN からは設定と状態だけを扱う。',
      items: [
        { label: 'Transcription mode', value: transcriptionMode, state: 'ok' },
        { label: 'Summary provider', value: settings.summaryProvider, state: 'ok' },
        {
          label: 'SpeechAnalyzer',
          value: speechAnalyzer,
          state: settings.speechAnalyzerEnabled ? 'ok' : 'warning',
        },
      ],
    },
    {
      title: 'デバイス連携',
      description: 'PLAUD / Omi / Generic recorder の導線を統合する。',
      items: [
        { label: 'PLAUD import', value: 'Connected', state: 'ok' },
        { label: 'Omi preview', value: 'Experimental', state: 'warning' },
        { label: 'Generic BLE', value: 'Bridge pending', state: 'off' },
      ],
    },
    {
      title: 'React Native 移行',
      description: 'Expo Go は mock UI、Dev Client は native bridge 用。',
      items: [
        { label: 'Expo mock screens', value: 'In progress', state: 'warning' },
        { label: 'Native bridge', value: bridgeValue, state: bridgeState },
        { label: 'Cutover', value: 'Feature flag later', state: 'off' },
      ],
    },
  ];
}

function SettingsGroupCard({ children, title }: { children: ReactNode; title: string }) {
  const rows = Children.toArray(children);
  return (
    <View style={styles.v6Group}>
      <Text style={styles.v6GroupTitle}>{title}</Text>
      <View style={styles.v6Card}>
        {rows.map((row, index) => (
          <Fragment key={index}>
            {row}
            {index < rows.length - 1 ? <View style={styles.v6Divider} /> : null}
          </Fragment>
        ))}
      </View>
    </View>
  );
}

function SettingsRow({
  destructive,
  onPress,
  showChevron = true,
  title,
  value,
}: {
  destructive?: boolean;
  onPress: () => void;
  showChevron?: boolean;
  title: string;
  value?: string;
}) {
  return (
    <Pressable onPress={onPress} style={styles.v6Row}>
      <Text style={[styles.v6RowTitle, destructive && styles.v6RowTitleDestructive]}>{title}</Text>
      {value ? (
        <Text numberOfLines={1} style={styles.v6RowValue}>
          {value}
        </Text>
      ) : null}
      {showChevron ? <Ionicons color={colors.border} name="chevron-forward" size={12} /> : null}
    </Pressable>
  );
}

function SettingsBadgeRow({
  badgeColor,
  badgeText,
  onPress,
  title,
}: {
  badgeColor: string;
  badgeText: string;
  onPress: () => void;
  title: string;
}) {
  return (
    <Pressable onPress={onPress} style={styles.v6Row}>
      <Text style={styles.v6RowTitle}>{title}</Text>
      <View style={[styles.v6Badge, { backgroundColor: badgeColor }]}>
        <Text style={styles.v6BadgeText}>{badgeText}</Text>
      </View>
      <Ionicons color={colors.border} name="chevron-forward" size={12} />
    </Pressable>
  );
}

function InfoRow({
  label,
  state,
  value,
}: {
  label: string;
  state: keyof typeof stateColors;
  value: string;
}) {
  return (
    <View style={styles.row}>
      <View>
        <Text style={styles.label}>{label}</Text>
        <Text style={styles.value}>{value}</Text>
      </View>
      <View style={[styles.dot, { backgroundColor: stateColors[state] }]} />
    </View>
  );
}

function SegmentButton({
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
      accessibilityRole="button"
      accessibilityState={{ selected: isSelected }}
      onPress={onPress}
      style={[styles.segmentButton, isSelected && styles.segmentButtonSelected]}
    >
      <Text style={[styles.segmentText, isSelected && styles.segmentTextSelected]}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  v6Group: {
    gap: spacing.sm,
  },
  v6GroupTitle: {
    color: colors.textTertiary,
    fontSize: 13,
    fontWeight: '600',
  },
  v6Card: {
    backgroundColor: colors.canvas,
  },
  v6Divider: {
    backgroundColor: colors.borderLight,
    height: 1,
  },
  developerToggle: { alignItems: 'center', alignSelf: 'center', flexDirection: 'row', gap: spacing.xs, marginTop: spacing.sm, paddingHorizontal: spacing.md, paddingVertical: spacing.sm },
  developerTogglePressed: { opacity: 0.65, transform: [{ scale: 0.96 }] },
  developerToggleText: { color: colors.textTertiary, fontSize: 12, fontWeight: '500' },
  v6Row: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
    minHeight: 50,
    paddingVertical: 14,
  },
  v6RowTitle: {
    color: colors.text,
    flexShrink: 0,
    fontSize: 15,
  },
  v6RowTitleDestructive: {
    color: colors.danger,
    flex: 1,
  },
  v6RowValue: {
    color: colors.textTertiary,
    flex: 1,
    fontSize: 13,
    textAlign: 'right',
  },
  v6Badge: {
    borderRadius: 8,
    paddingHorizontal: spacing.sm,
    paddingVertical: 3,
  },
  v6BadgeText: {
    color: colors.surface,
    fontSize: 11,
    fontWeight: '700',
  },
  toggleRow: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    minHeight: 50,
    paddingVertical: 14,
  },
  groupCard: {
    backgroundColor: colors.surface,
    gap: spacing.md,
    paddingBottom: spacing.sm,
  },
  description: {
    color: colors.textSecondary,
    fontSize: 14,
    lineHeight: 21,
  },
  rows: {
    gap: spacing.md,
  },
  controlBlock: {
    gap: spacing.sm,
  },
  segmentRow: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  providerGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
  },
  segmentButton: {
    alignItems: 'center',
    backgroundColor: colors.surfaceAlt,
    borderColor: colors.border,
    borderRadius: radius.sm,
    borderWidth: 1,
    minHeight: 40,
    minWidth: 88,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  segmentButtonSelected: {
    backgroundColor: colors.text,
    borderColor: colors.text,
  },
  segmentText: {
    color: colors.textSecondary,
    fontSize: 13,
    fontWeight: '500',
  },
  segmentTextSelected: {
    color: colors.surface,
  },
  switchRow: {
    alignItems: 'center',
    borderTopColor: colors.border,
    borderTopWidth: 1,
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingTop: spacing.md,
  },
  row: {
    alignItems: 'center',
    borderTopColor: colors.border,
    borderTopWidth: 1,
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingTop: spacing.md,
  },
  label: {
    color: colors.text,
    fontSize: 15,
    fontWeight: '500',
  },
  value: {
    color: colors.textSecondary,
    fontSize: 13,
    fontWeight: '400',
    marginTop: 4,
  },
  dot: {
    borderRadius: radius.pill,
    height: 10,
    width: 10,
  },
});
