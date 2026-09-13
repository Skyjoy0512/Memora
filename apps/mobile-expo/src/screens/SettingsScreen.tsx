import { Children, useEffect, useState, type ReactNode } from 'react';
import { NumericText } from '../components/NumericText';
import { ToggleSwitch } from '../components/ToggleSwitch';
import { PrimaryAction, SecondaryAction } from '../components/Buttons';
import { buildRecordingHabit, type RecordingHabit } from '../utils/recordingHabit';
import { Alert, Modal, Pressable, StyleSheet, Text, View } from 'react-native';
import { AppIcon as Ionicons } from '../components/AppIcon';
import { useRouter } from 'expo-router';
import { Screen } from '../components/Screen';
import { Section } from '../components/Section';
import { colors, radius, spacing, textStyles } from '../design/tokens';
import { MemoraNative } from '../native/MemoraNative';
import {
  NOTION_SETUP_LABELS,
  extractNotionParentPageId,
  resolveNotionSetupState,
} from '../native/exportLogic';
import type {
  BridgeInfoDTO,
  CustomVocabularyDTO,
  SecureCredentialProvider,
  SettingsDTO,
  SummaryOptionsDTO,
} from '../native/MemoraNative.types';
import type { SettingsGroup } from '../types/memora';
import { Input } from 'heroui-native/input';
import { RadioGroup } from 'heroui-native/radio-group';

const NOT_CONNECTED_MESSAGE =
  'ネイティブブリッジがこのアクションにまだ接続されていません。実データ接続後に有効化します。';

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
  notionParentPage: '',
};

const providerOptions: SummaryOptionsDTO['provider'][] = ['Gemini', 'OpenAI', 'DeepSeek', 'Local'];

export function SettingsScreen() {
  const router = useRouter();
  const [bridgeInfo, setBridgeInfo] = useState<BridgeInfoDTO | null>(null);
  const [isSecureCredentialConfigured, setIsSecureCredentialConfigured] = useState(false);
  const [isAskAiKeyConfigured, setIsAskAiKeyConfigured] = useState(false);
  const [isNotionTokenConfigured, setIsNotionTokenConfigured] = useState(false);
  const [settings, setSettings] = useState<SettingsDTO>(defaultSettings);
  const [notifEnabled, setNotifEnabled] = useState(false);
  const [isDeveloperOpen, setIsDeveloperOpen] = useState(false);
  const [customVocabulary, setCustomVocabulary] = useState<CustomVocabularyDTO[]>([]);
  const [editingVocabulary, setEditingVocabulary] = useState<CustomVocabularyDTO | null>(null);
  const [editingNotionParentPage, setEditingNotionParentPage] = useState(false);
  const [notionParentDraft, setNotionParentDraft] = useState('');
  const [isSummaryProviderPickerOpen, setIsSummaryProviderPickerOpen] = useState(false);
  const [habit, setHabit] = useState<RecordingHabit>(() => buildRecordingHabit([]));

  useEffect(() => {
    let isMounted = true;

    Promise.all([
      MemoraNative.getBridgeInfo(),
      MemoraNative.loadSettings(),
      MemoraNative.listCustomVocabulary(),
      MemoraNative.getSecureCredentialStatus('Notion'),
      MemoraNative.getSecureCredentialStatus('OpenAI'),
      MemoraNative.listAudioFiles(),
    ]).then(([info, nextSettings, vocabulary, isNotionConfigured, isOpenAiConfigured, audioFiles]) => {
      if (isMounted) {
        setBridgeInfo(info);
        setSettings(nextSettings);
        setCustomVocabulary(vocabulary);
        setIsNotionTokenConfigured(isNotionConfigured);
        setIsAskAiKeyConfigured(isOpenAiConfigured);
        setHabit(buildRecordingHabit(audioFiles.map((file) => file.recordedAt)));
      }
    });

    return () => {
      isMounted = false;
    };
  }, []);

  useEffect(() => {
    let isMounted = true;
    void MemoraNative.getSecureCredentialStatus(settings.summaryProvider).then((isConfigured) => {
      if (isMounted) {
        setIsSecureCredentialConfigured(isConfigured);
      }
    });
    return () => {
      isMounted = false;
    };
  }, [settings.summaryProvider]);

  const notConnected = () => Alert.alert('準備中', NOT_CONNECTED_MESSAGE);

  return (
    <Screen title="設定">
      <RecordingHabitRow habit={habit} />

      <SettingsGroupCard title="アカウント">
        <SettingsRow onPress={notConnected} title="未設定" />
        <Pressable accessibilityLabel="プラン" accessibilityRole="button" onPress={() => router.push('/auth?stage=paywall')} style={styles.v6Row}>
          <Text style={styles.v6RowTitle}>プラン</Text>
          <View style={styles.planBadge}>
            <Text style={styles.planBadgeLabel}>Free</Text>
          </View>
          <Ionicons color={colors.textSecondary} name="chevron-forward" size={16} />
        </Pressable>
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
          <ToggleSwitch
            accessibilityLabel="プッシュ通知のオン・オフ"
            isOn={notifEnabled}
            onToggle={setNotifEnabled}
          />
        </View>
      </SettingsGroupCard>

      <SettingsGroupCard title="連携">
        <SettingsRow
          onPress={manageNotionSetup}
          title="Notion に書き出す"
          value={NOTION_SETUP_LABELS[
            resolveNotionSetupState(isNotionTokenConfigured, Boolean(settings.notionParentPage.trim()))
          ]}
        />
        <SettingsRow
          onPress={chatGptShareDescription}
          title="ChatGPT に共有"
          value="コピー＋共有シート"
        />
      </SettingsGroupCard>

      <SettingsGroupCard title="言語">
        <SettingsRow onPress={notConnected} title="表示言語" value="日本語" />
        <SettingsRow onPress={notConnected} title="文字起こし言語" value="自動検出" />
      </SettingsGroupCard>

      <SettingsGroupCard title="文字起こし・要約">
        <SettingsRow
          onPress={() => setIsSummaryProviderPickerOpen(true)}
          title="要約AIモデル"
          value={settings.summaryProvider}
        />
        <SettingsRow
          onPress={manageSecureCredential}
          title="AI providerのAPIキー"
          value={
            settings.summaryProvider === 'Local'
              ? '不要'
              : isSecureCredentialConfigured
                ? '設定済み'
                : '未設定'
          }
        />
        <SettingsRow
          onPress={manageAskAiCredential}
          title="Ask AI（OpenAI）のAPIキー"
          value={isAskAiKeyConfigured ? '設定済み' : '未設定'}
        />
        <SettingsRow
          onPress={summaryTemplateGuide}
          title="要約テンプレート"
          value="生成時に選択"
        />
        <View style={styles.toggleRow}>
          <Text style={styles.v6RowTitle}>音声解析（話者識別）</Text>
          <ToggleSwitch
            accessibilityLabel="音声解析（話者識別）のオン・オフ"
            isOn={settings.speechAnalyzerEnabled}
            onToggle={(selected) => saveSettings({ ...settings, speechAnalyzerEnabled: selected })}
          />
        </View>
      </SettingsGroupCard>

      <SettingsGroupCard title="ユーザー辞書">
        {customVocabulary.map((vocabulary) => (
          <View key={vocabulary.id} style={styles.vocabularyRow}>
            <Pressable
              accessibilityLabel={`${vocabulary.pattern} を編集`}
              accessibilityRole="button"
              onPress={() => setEditingVocabulary(vocabulary)}
              style={styles.vocabularyEditButton}
            >
              <View style={styles.vocabularyText}>
                <Text style={styles.v6RowTitle}>{vocabulary.pattern}</Text>
                <Text style={styles.vocabularyReplacement}>→ {vocabulary.replacement || '削除'}</Text>
              </View>
            </Pressable>
            <ToggleSwitch
              accessibilityLabel={`${vocabulary.pattern} を${vocabulary.enabled ? '無効' : '有効'}にする`}
              isOn={vocabulary.enabled}
              onToggle={(enabled) => void setCustomVocabularyEnabled(vocabulary.id, enabled)}
            />
          </View>
        ))}
        <Pressable
          accessibilityLabel="ユーザー辞書を追加"
          accessibilityRole="button"
          onPress={() => setEditingVocabulary(newVocabulary())}
          style={styles.vocabularyAddButton}
        >
          <Ionicons color={colors.accent} name="add" size={20} />
          <Text style={styles.vocabularyAddText}>辞書を追加</Text>
        </Pressable>
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

      {__DEV__ ? <>
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
            <RadioGroup
              onValueChange={(value) =>
                saveSettings({ ...settings, transcriptionMode: value as SettingsDTO['transcriptionMode'] })
              }
              value={settings.transcriptionMode}
            >
              <RadioGroup.Item variant="primary" value="local">Local</RadioGroup.Item>
              <RadioGroup.Item variant="primary" value="api">API</RadioGroup.Item>
            </RadioGroup>
          </View>

          <View style={styles.controlBlock}>
            <Text style={styles.label}>Summary provider</Text>
            <RadioGroup
              onValueChange={(value) =>
                saveSettings({ ...settings, summaryProvider: value as SettingsDTO['summaryProvider'] })
              }
              value={settings.summaryProvider}
            >
              {providerOptions.map((provider) => (
                <RadioGroup.Item key={provider} variant="primary" value={provider}>
                  {provider}
                </RadioGroup.Item>
              ))}
            </RadioGroup>
          </View>

          <View style={styles.switchRow}>
            <View>
              <Text style={styles.label}>SpeechAnalyzer</Text>
              <Text style={styles.value}>
                {settings.speechAnalyzerEnabled ? 'Feature flag on' : 'Feature flag off'}
              </Text>
            </View>
            <ToggleSwitch
              accessibilityLabel="SpeechAnalyzer のオン・オフ"
              isOn={settings.speechAnalyzerEnabled}
              onToggle={(selected) =>
                saveSettings({ ...settings, speechAnalyzerEnabled: selected })
              }
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
                bridgeInfo?.recordingSource === 'swiftdata' ||
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
      </> : null}
      <VocabularyEditor
        onClose={() => setEditingVocabulary(null)}
        onDelete={(id) => void deleteCustomVocabulary(id)}
        onSave={(value) => void saveCustomVocabulary(value)}
        value={editingVocabulary}
      />
      <NotionParentPageEditor
        isOpen={editingNotionParentPage}
        onClose={() => setEditingNotionParentPage(false)}
        onChangeText={setNotionParentDraft}
        onSave={() => void saveNotionParentPage()}
        value={notionParentDraft}
      />
      <SummaryProviderPicker
        isOpen={isSummaryProviderPickerOpen}
        onClose={() => setIsSummaryProviderPickerOpen(false)}
        onSelect={(summaryProvider) => {
          saveSettings({ ...settings, summaryProvider });
          setIsSummaryProviderPickerOpen(false);
        }}
        value={settings.summaryProvider}
      />
    </Screen>
  );

  function saveSettings(nextSettings: SettingsDTO) {
    setSettings(nextSettings);
    void MemoraNative.saveSettings(nextSettings);
  }

  function manageSecureCredential() {
    const provider = settings.summaryProvider;
    if (provider === 'Local') {
      Alert.alert('APIキーは不要です', 'Local providerはこの端末上で動作するため、APIキーを保存しません。');
      return;
    }

    if (!isSecureCredentialConfigured) {
      void presentSecureCredentialInput(provider);
      return;
    }

    Alert.alert(`${provider} のAPIキー`, 'APIキーの値は表示されません。', [
      { text: '更新', onPress: () => void presentSecureCredentialInput(provider) },
      {
        text: '削除',
        style: 'destructive',
        onPress: () => void deleteSecureCredential(provider),
      },
      { text: 'キャンセル', style: 'cancel' },
    ]);
  }

  function manageAskAiCredential() {
    if (!isAskAiKeyConfigured) {
      void presentSecureCredentialInput('OpenAI');
      return;
    }

    Alert.alert('OpenAI のAPIキー', 'Ask AI は OpenAI のAPIキーを使います。APIキーの値は表示されません。', [
      { text: '更新', onPress: () => void presentSecureCredentialInput('OpenAI') },
      {
        text: '削除',
        style: 'destructive',
        onPress: () => void deleteSecureCredential('OpenAI'),
      },
      { text: 'キャンセル', style: 'cancel' },
    ]);
  }

  /** OpenAI キーは Ask AI（固定）と要約AIモデル（OpenAI選択時）で共用されるため、両方の表示状態を更新する。 */
  async function refreshCredentialStatus(provider: SecureCredentialProvider) {
    const isConfigured = await MemoraNative.getSecureCredentialStatus(provider);
    if (provider === 'Notion') {
      setIsNotionTokenConfigured(isConfigured);
    } else if (provider === 'OpenAI') {
      setIsAskAiKeyConfigured(isConfigured);
      if (settings.summaryProvider === 'OpenAI') {
        setIsSecureCredentialConfigured(isConfigured);
      }
    } else {
      setIsSecureCredentialConfigured(isConfigured);
    }
  }

  async function presentSecureCredentialInput(provider: SecureCredentialProvider): Promise<boolean> {
    const saved = await MemoraNative.presentSecureCredentialInput(provider);
    if (saved) {
      await refreshCredentialStatus(provider);
    }
    return saved;
  }

  async function deleteSecureCredential(provider: SecureCredentialProvider) {
    const deleted = await MemoraNative.deleteSecureCredential(provider);
    if (deleted) {
      await refreshCredentialStatus(provider);
    }
  }

  function chatGptShareDescription() {
    Alert.alert(
      'ChatGPT に共有',
      'ファイル詳細の「書き出す」から、要約と文字起こしをMarkdownでクリップボードにコピーして共有シートを開きます。認証は不要です。',
    );
  }

  function summaryTemplateGuide() {
    Alert.alert(
      'テンプレートは生成時に選択します',
      'ファイル詳細または録音直後の生成画面でテンプレートを選び、選択した内容で要約を生成します。',
    );
  }

  async function manageNotionSetup() {
    if (!isNotionTokenConfigured) {
      const saved = await presentSecureCredentialInput('Notion');
      if (saved) {
        setNotionParentDraft(settings.notionParentPage);
        setEditingNotionParentPage(true);
      }
      return;
    }

    Alert.alert('Notion に書き出す', '連携の設定を変更できます。', [
      {
        text: '親ページを変更',
        onPress: () => {
          setNotionParentDraft(settings.notionParentPage);
          setEditingNotionParentPage(true);
        },
      },
      { text: 'トークンを更新', onPress: () => void presentSecureCredentialInput('Notion') },
      {
        text: 'トークンを解除',
        style: 'destructive',
        onPress: () => void deleteSecureCredential('Notion'),
      },
      { text: 'キャンセル', style: 'cancel' },
    ]);
  }

  async function saveNotionParentPage() {
    const trimmed = notionParentDraft.trim();
    if (!trimmed) {
      Alert.alert('設定できません', '親ページのURLまたはページIDを入力してください。');
      return;
    }
    if (!extractNotionParentPageId(trimmed)) {
      Alert.alert(
        '設定できません',
        'ページIDを識別できませんでした。NotionのページURL（…/タイトル-32桁のID）またはページIDを入力してください。',
      );
      return;
    }
    saveSettings({ ...settings, notionParentPage: trimmed });
    setEditingNotionParentPage(false);
  }

  async function saveCustomVocabulary(value: CustomVocabularyDTO) {
    const pattern = value.pattern.trim();
    if (!pattern) {
      Alert.alert('登録できません', '置換したい語を入力してください。');
      return;
    }
    const saved = await MemoraNative.saveCustomVocabulary({ ...value, pattern });
    setCustomVocabulary((current) => [
      saved,
      ...current.filter((item) => item.id !== saved.id),
    ]);
    setEditingVocabulary(null);
  }

  async function deleteCustomVocabulary(id: string) {
    const deleted = await MemoraNative.deleteCustomVocabulary(id);
    if (deleted) {
      setCustomVocabulary((current) => current.filter((item) => item.id !== id));
      setEditingVocabulary(null);
    }
  }

  async function setCustomVocabularyEnabled(id: string, enabled: boolean) {
    const updated = await MemoraNative.setCustomVocabularyEnabled(id, enabled);
    if (updated) {
      setCustomVocabulary((current) => current.map((item) => item.id === id ? updated : item));
    }
  }
}

function newVocabulary(): CustomVocabularyDTO {
  return {
    createdAt: new Date().toISOString(),
    enabled: true,
    id: `vocabulary-${Date.now()}`,
    pattern: '',
    reading: null,
    replacement: '',
  };
}

function VocabularyEditor({
  onClose,
  onDelete,
  onSave,
  value,
}: {
  onClose: () => void;
  onDelete: (id: string) => void;
  onSave: (value: CustomVocabularyDTO) => void;
  value: CustomVocabularyDTO | null;
}) {
  const [draft, setDraft] = useState<CustomVocabularyDTO | null>(value);

  useEffect(() => setDraft(value), [value]);
  if (!draft) return null;

  return (
    <Modal animationType="slide" onRequestClose={onClose} transparent visible>
      <View style={styles.modalBackdrop}>
        <View style={styles.modalCard}>
          <Text style={styles.modalTitle}>{draft.id.startsWith('vocabulary-') ? '辞書を追加' : '辞書を編集'}</Text>
          <Input
            accessibilityLabel="置換前の語"
            autoCapitalize="none"
            onChangeText={(pattern) => setDraft({ ...draft, pattern })}
            placeholder="置換前の語"
            placeholderTextColor={colors.textTertiary}
            variant="secondary"
            value={draft.pattern}
          />
          <Input
            accessibilityLabel="置換後の語"
            autoCapitalize="none"
            onChangeText={(replacement) => setDraft({ ...draft, replacement })}
            placeholder="置換後の語（空欄で削除）"
            placeholderTextColor={colors.textTertiary}
            variant="secondary"
            value={draft.replacement}
          />
          <Input
            accessibilityLabel="読み仮名"
            autoCapitalize="none"
            onChangeText={(reading) => setDraft({ ...draft, reading: reading || null })}
            placeholder="読み仮名（任意）"
            placeholderTextColor={colors.textTertiary}
            variant="secondary"
            value={draft.reading ?? ''}
          />
          <View style={styles.modalActions}>
            {!draft.id.startsWith('vocabulary-') ? (
              <SecondaryAction
                accessibilityLabel="辞書を削除"
                label="削除"
                onPress={() => onDelete(draft.id)}
                style={styles.vocabularyButton}
              />
            ) : <View />}
            <View style={styles.modalPrimaryActions}>
              <SecondaryAction
                accessibilityLabel="辞書の編集をキャンセル"
                label="キャンセル"
                onPress={onClose}
                style={styles.vocabularyButton}
              />
              <PrimaryAction
                accessibilityLabel="辞書を保存"
                isDisabled={!draft.pattern.trim()}
                label="保存"
                onPress={() => onSave(draft)}
                style={styles.vocabularyButton}
              />
            </View>
          </View>
        </View>
      </View>
    </Modal>
  );
}

function NotionParentPageEditor({
  isOpen,
  onClose,
  onChangeText,
  onSave,
  value,
}: {
  isOpen: boolean;
  onClose: () => void;
  onChangeText: (text: string) => void;
  onSave: () => void;
  value: string;
}) {
  if (!isOpen) return null;

  return (
    <Modal animationType="slide" onRequestClose={onClose} transparent visible>
      <View style={styles.modalBackdrop}>
        <View style={styles.modalCard}>
          <Text style={styles.modalTitle}>Notion の書き出し先（親ページ）</Text>
          <Input
            accessibilityLabel="Notionの親ページURLまたはページID"
            autoCapitalize="none"
            autoCorrect={false}
            onChangeText={onChangeText}
            placeholder="https://www.notion.so/… またはページID"
            placeholderTextColor={colors.textTertiary}
            variant="secondary"
            value={value}
          />
          <Text style={styles.notionParentHint}>
            書き出し先にしたいNotionページのURL（…/タイトル-32桁のID）またはページIDを入力してください。
            転記はこのページの子ページとして作成されます。
          </Text>
          <View style={styles.modalActions}>
            <View style={styles.modalPrimaryActions}>
              <SecondaryAction
                accessibilityLabel="親ページ設定をキャンセル"
                label="キャンセル"
                onPress={onClose}
                style={styles.vocabularyButton}
              />
              <PrimaryAction
                accessibilityLabel="親ページ設定を保存"
                isDisabled={!value.trim()}
                label="保存"
                onPress={onSave}
                style={styles.vocabularyButton}
              />
            </View>
          </View>
        </View>
      </View>
    </Modal>
  );
}

function SummaryProviderPicker({
  isOpen,
  onClose,
  onSelect,
  value,
}: {
  isOpen: boolean;
  onClose: () => void;
  onSelect: (provider: SettingsDTO['summaryProvider']) => void;
  value: SettingsDTO['summaryProvider'];
}) {
  if (!isOpen) return null;

  return (
    <Modal animationType="slide" onRequestClose={onClose} transparent visible>
      <View style={styles.modalBackdrop}>
        <View style={styles.modalCard}>
          <Text style={styles.modalTitle}>要約AIモデル</Text>
          <RadioGroup
            onValueChange={(next) => onSelect(next as SettingsDTO['summaryProvider'])}
            value={value}
          >
            {providerOptions.map((provider) => (
              <RadioGroup.Item key={provider} variant="primary" value={provider}>
                {provider === 'Local' ? 'Local（端末内）' : provider}
              </RadioGroup.Item>
            ))}
          </RadioGroup>
          <Text style={styles.notionParentHint}>
            要約の生成に使うAIモデルを選びます。APIキーはこの画面の「AI providerのAPIキー」から設定します。
          </Text>
          <View style={styles.modalActions}>
            <View style={styles.modalPrimaryActions}>
              <SecondaryAction
                accessibilityLabel="要約AIモデルの変更をキャンセル"
                label="キャンセル"
                onPress={onClose}
                style={styles.vocabularyButton}
              />
            </View>
          </View>
        </View>
      </View>
    </Modal>
  );
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
      description: 'ネイティブの文字起こしエンジンと連携し、アプリからは設定と状態だけを扱う。',
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

/**
 * Open Design v2 の `.settings-group` / `.setting-row`。
 * グループ見出しは小さなラベル、行は上罫線で区切り、最後の行だけ下罫線を足す。
 * カード面や角丸は使わない。
 */
/**
 * Open Design v2 の `settings-habit-grid`。直近28日を 7 列 × 4 行の升目で示す。
 * 数字は mono、記録した日だけを塗る。励ましも警告もしない事実の表示。
 */
function RecordingHabitRow({ habit }: { habit: RecordingHabit }) {
  const weeks: boolean[][] = [];
  for (let index = 0; index < habit.days.length; index += 7) {
    weeks.push(habit.days.slice(index, index + 7));
  }

  return (
    <View style={styles.habitRow}>
      <View style={styles.habitCopy}>
        <Text style={styles.habitLabel}>記録の習慣</Text>
        <NumericText style={styles.habitMeta}>
          {`${habit.recordedCount}日記録 · 直近${habit.totalDays}日`}
        </NumericText>
      </View>
      <View
        accessibilityLabel={`直近${habit.totalDays}日間の記録状況。${habit.recordedCount}日記録しました`}
        accessibilityRole="image"
        style={styles.habitGrid}
      >
        {weeks.map((week, weekIndex) => (
          <View key={weekIndex} style={styles.habitWeek}>
            {week.map((isRecorded, dayIndex) => (
              <View
                key={dayIndex}
                style={[styles.habitCell, isRecorded && styles.habitCellOn]}
              />
            ))}
          </View>
        ))}
      </View>
    </View>
  );
}

function SettingsGroupCard({ children, title }: { children: ReactNode; title: string }) {
  const rows = Children.toArray(children);
  return (
    <View style={styles.v6Group}>
      <Text style={styles.v6GroupTitle}>{title}</Text>
      <View style={styles.v6Card}>
        {rows.map((row, index) => (
          <View key={index} style={[styles.v6RowFrame, index === rows.length - 1 && styles.v6RowFrameLast]}>
            {row}
          </View>
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
      {showChevron ? <Ionicons color={colors.textSecondary} name="chevron-forward" size={16} /> : null}
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

const styles = StyleSheet.create({
  habitRow: {
    alignItems: 'center',
    borderBottomColor: colors.border,
    borderBottomWidth: 1,
    borderTopColor: colors.border,
    borderTopWidth: 1,
    flexDirection: 'row',
    gap: spacing.md,
    justifyContent: 'space-between',
    minHeight: 72,
    paddingVertical: spacing.sm,
  },
  habitCopy: { flexShrink: 1 },
  habitLabel: { color: colors.text, ...textStyles.label },
  habitMeta: { color: colors.textSecondary, marginTop: spacing.xxs, ...textStyles.footnote },
  habitGrid: { flexShrink: 0, gap: spacing.xxs },
  habitWeek: { flexDirection: 'row', gap: spacing.xxs },
  habitCell: {
    backgroundColor: colors.surfaceAlt,
    borderColor: colors.border,
    borderRadius: 0,
    borderWidth: 1,
    height: 12,
    width: 12,
  },
  habitCellOn: { backgroundColor: colors.text, borderColor: colors.text },
  v6Group: {
    gap: spacing.xs,
  },
  v6GroupTitle: {
    color: colors.textSecondary,
    ...textStyles.label,
  },
  v6Card: {
    backgroundColor: colors.canvas,
  },
  planBadge: {
    backgroundColor: colors.accent,
    borderRadius: 0,
    paddingHorizontal: spacing.xs,
    paddingVertical: spacing.xxs,
  },
  planBadgeLabel: {
    color: colors.textInverse,
    ...textStyles.label,
  },
  v6RowFrame: {
    borderTopColor: colors.border,
    borderTopWidth: 1,
  },
  v6RowFrameLast: {
    borderBottomColor: colors.border,
    borderBottomWidth: 1,
  },
  developerToggle: { alignItems: 'center', alignSelf: 'center', flexDirection: 'row', gap: spacing.xs, marginTop: spacing.sm, paddingHorizontal: spacing.md, paddingVertical: spacing.sm },
  developerTogglePressed: { opacity: 0.65, transform: [{ scale: 0.96 }] },
  developerToggleText: { color: colors.textTertiary, ...textStyles.caption },
  v6Row: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
    minHeight: 56,
    paddingVertical: spacing.sm,
  },
  v6RowTitle: {
    color: colors.text,
    flexShrink: 0,
    ...textStyles.footnote,
  },
  v6RowTitleDestructive: {
    color: colors.danger,
    flex: 1,
  },
  v6RowValue: {
    color: colors.textSecondary,
    flex: 1,
    textAlign: 'right',
    ...textStyles.footnote,
  },
  toggleRow: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    minHeight: 56,
    paddingVertical: spacing.sm,
  },
  vocabularyRow: {
    alignItems: 'center',
    flexDirection: 'row',
    minHeight: 50,
  },
  vocabularyEditButton: {
    justifyContent: 'center',
    minHeight: 50,
    paddingVertical: spacing.sm,
    flex: 1,
  },
  vocabularyText: {
    gap: spacing.xs,
  },
  vocabularyReplacement: {
    color: colors.textSecondary,
    ...textStyles.footnote,
  },
  vocabularyAddButton: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
    minHeight: 50,
  },
  vocabularyAddText: {
    color: colors.accent,
    ...textStyles.bodyBold,
  },
  modalBackdrop: {
    alignItems: 'center',
    backgroundColor: colors.overlay,
    flex: 1,
    justifyContent: 'center',
    padding: spacing.lg,
  },
  modalCard: {
    backgroundColor: colors.surface,
    borderRadius: 0,
    gap: spacing.md,
    padding: spacing.lg,
    width: '100%',
  },
  modalTitle: {
    color: colors.text,
    ...textStyles.sectionTitle,
  },
  notionParentHint: {
    color: colors.textSecondary,
    ...textStyles.footnote,
  },
  modalActions: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  modalPrimaryActions: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  vocabularyButton: {
    borderRadius: 0,
    minHeight: 44,
  },
  groupCard: {
    backgroundColor: colors.surface,
    gap: spacing.md,
    paddingBottom: spacing.sm,
  },
  rows: {
    gap: spacing.md,
  },
  controlBlock: {
    gap: spacing.sm,
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
    ...textStyles.bodyBold,
  },
  value: {
    color: colors.textSecondary,
    marginTop: 4,
    ...textStyles.footnote,
  },
  dot: {
    borderRadius: radius.circle,
    height: 10,
    width: 10,
  },
});
