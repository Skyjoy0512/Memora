import { AppIcon } from "../components/AppIcon";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useState } from "react";
import {
  Alert,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import { colors, fonts, radius, spacing, textStyles } from "../design/tokens";
import { isCompleteCode, isEmailLike } from "../utils/authFlow";

type Stage = "onboarding" | "login" | "email" | "code" | "paywall";

// Open Design v2 のオンボーディング3画面（onboarding-welcome / capture / privacy）。
// 機能の宣伝ではなく「音声が正本である」ことを最初に伝える順番になっている。
type OnboardingSlide = {
  title: string;
  body: string;
  action: string;
  options?: ReadonlyArray<{ no: string; title: string; body: string }>;
  rules?: ReadonlyArray<{ title: string; body: string }>;
};

const slides: readonly OnboardingSlide[] = [
  {
    title: "話すだけで、\n議事録になります",
    body: "録音した音声を正本として残し、文字起こし、要約、次の行動まで一つの流れで確認できます。",
    action: "はじめる",
  },
  {
    title: "記録の入口を\n選べます",
    body: "場所や機材に合わせて始めても、すべて同じ記録として整理されます。",
    action: "次へ",
    options: [
      { no: "01", title: "本体マイク", body: "オフラインでも録音できます" },
      { no: "02", title: "音声ファイル", body: "PLAUDなどの音声を取り込みます" },
      { no: "03", title: "会議キャプチャー", body: "会議音声をそのまま記録します" },
    ],
  },
  {
    title: "音声は、いつでも\n戻れる正本です",
    body: "文字起こしや要約に失敗しても、保存した音声からやり直せます。",
    action: "Memoraを使い始める",
    rules: [
      {
        title: "ローカルを優先します",
        body: "同期できないときも、録音、再生、メモを利用できます。",
      },
      {
        title: "音声の削除だけを確認します",
        body: "再生成できない操作にだけ、確認を表示します。",
      },
    ],
  },
];

// Open Design v2 の paywall。価格は App Store が正本なので画面に書かない
// （StoreKit 未接続の状態で数字を出すと嘘になる）。
const proFeatures = [
  { no: "01", title: "長い録音の文字起こしと要約", body: "音声から何度でも再生成できます" },
  { no: "02", title: "プロジェクト横断のAsk AI", body: "答え、次の行動、出典を確認できます" },
  { no: "03", title: "外部デバイスからの継続取り込み", body: "PLAUDとOmiの音声を同じ記録として扱います" },
  { no: "04", title: "端末間の同期", body: "ローカルの記録を優先して複製します" },
] as const;

const purchaseFacts = [
  { label: "料金", value: "App Storeで表示" },
  { label: "更新条件", value: "購入前に確認" },
] as const;

export function AuthFlowScreen() {
  const router = useRouter();
  const params = useLocalSearchParams<{ stage?: string }>();
  const [stage, setStage] = useState<Stage>(
    params.stage === "paywall" ? "paywall" : "onboarding",
  );
  const [slide, setSlide] = useState(0);
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const complete = () => router.replace("/");
  const nextSlide = () =>
    slide === slides.length - 1
      ? setStage("login")
      : setSlide((value) => value + 1);

  return (
    <SafeAreaView style={styles.safe}>
      <KeyboardAvoidingView
        behavior={Platform.OS === "ios" ? "padding" : undefined}
        style={styles.flex}
      >
        {stage === "onboarding" ? (
          <Onboarding
            onBack={() => setSlide((value) => Math.max(0, value - 1))}
            onNext={nextSlide}
            onSkip={() => setStage("login")}
            slide={slide}
          />
        ) : null}
        {stage === "login" ? (
          <Login
            onBack={() => setStage("onboarding")}
            onEmail={() => setStage("email")}
            onProvider={complete}
          />
        ) : null}
        {stage === "email" ? (
          <EmailStep
            email={email}
            onBack={() => setStage("login")}
            onChange={setEmail}
            onNext={() => isEmailLike(email) && setStage("code")}
          />
        ) : null}
        {stage === "code" ? (
          <CodeStep
            code={code}
            email={email}
            onBack={() => setStage("email")}
            onChange={setCode}
            onNext={() => isCompleteCode(code) && setStage("paywall")}
          />
        ) : null}
        {stage === "paywall" ? (
          <Paywall onSkip={complete} />
        ) : null}
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

function Onboarding({
  slide,
  onBack,
  onNext,
  onSkip,
}: {
  slide: number;
  onBack: () => void;
  onNext: () => void;
  onSkip: () => void;
}) {
  const step = slides[slide];
  return (
    <View style={styles.page}>
      <View style={styles.onboardingHeaderRow}>
        {slide === 0 ? (
          <Text style={styles.brandLabel}>MEMORA</Text>
        ) : (
          <Pressable
            accessibilityLabel="前の説明に戻る"
            accessibilityRole="button"
            hitSlop={8}
            onPress={onBack}
            style={styles.onboardingBack}
          >
            <AppIcon color={colors.text} name="chevron-back" size={20} />
          </Pressable>
        )}
        <View style={styles.onboardingHeaderEnd}>
          <Text
            accessibilityLabel={`${slides.length}段階中${slide + 1}段階目`}
            style={styles.stepCounter}
          >
            {`${slide + 1} / ${slides.length}`}
          </Text>
          <Pressable
            accessibilityLabel="オンボーディングをスキップ"
            accessibilityRole="button"
            hitSlop={8}
            onPress={onSkip}
          >
            <Text style={styles.skip}>スキップ</Text>
          </Pressable>
        </View>
      </View>

      <View accessibilityElementsHidden importantForAccessibility="no-hide-descendants" style={styles.progress}>
        {slides.map((_, index) => (
          <View
            key={index}
            style={[styles.progressSegment, index <= slide && styles.progressSegmentActive]}
          />
        ))}
      </View>

      <ScrollView
        contentContainerStyle={styles.onboardingContent}
        showsVerticalScrollIndicator={false}
        style={styles.flex}
      >
        <View style={styles.onboardingCopy}>
          {slide === 0 ? <BrandMark /> : null}
          <Text style={styles.onboardingTitle}>{step.title}</Text>
          <Text style={styles.onboardingBody}>{step.body}</Text>
        </View>

        {step.options ? (
          <View style={styles.onboardingList}>
            {step.options.map((option) => (
              <View key={option.no} style={styles.onboardingItem}>
                <Text style={styles.onboardingItemNo}>{option.no}</Text>
                <View style={styles.flex}>
                  <Text style={styles.onboardingItemTitle}>{option.title}</Text>
                  <Text style={styles.onboardingItemBody}>{option.body}</Text>
                </View>
              </View>
            ))}
          </View>
        ) : null}

        {step.rules?.map((rule, index) => (
          <View
            key={rule.title}
            style={[styles.privacyRule, index === 0 && styles.privacyRuleLead]}
          >
            <Text style={styles.privacyRuleTitle}>{rule.title}</Text>
            <Text style={styles.privacyRuleBody}>{rule.body}</Text>
          </View>
        ))}
      </ScrollView>

      <PrimaryButton label={step.action} onPress={onNext} />
    </View>
  );
}

/** ブランドマーク。4本の縦バーは波形の抜き出しで、prototype の `.brand-mark` と同寸。 */
function BrandMark() {
  return (
    <View accessibilityElementsHidden importantForAccessibility="no-hide-descendants" style={styles.brandMark}>
      {[25, 40, 18, 30].map((height) => (
        <View key={height} style={[styles.brandMarkBar, { height }]} />
      ))}
    </View>
  );
}

function AuthHeader({ onBack }: { onBack?: () => void }) {
  return (
    <View style={styles.authHeaderRow}>
      {onBack ? (
        <Pressable
          accessibilityLabel="前の画面に戻る"
          accessibilityRole="button"
          hitSlop={8}
          onPress={onBack}
          style={styles.onboardingBack}
        >
          <AppIcon color={colors.text} name="chevron-back" size={20} />
        </Pressable>
      ) : (
        <View style={styles.onboardingBack} />
      )}
      <Text style={styles.brandLabel}>アカウント</Text>
      <View style={styles.onboardingBack} />
    </View>
  );
}

/** `.auth-divider`: 主導線と代替手段の間を「または」で仕切る。 */
function AuthDivider() {
  return (
    <View style={styles.authDivider}>
      <View style={styles.authDividerRule} />
      <Text style={styles.authDividerLabel}>または</Text>
      <View style={styles.authDividerRule} />
    </View>
  );
}

function AuthButton({ label, onPress }: { label: string; onPress: () => void }) {
  return (
    <Pressable
      accessibilityLabel={label}
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [styles.authButton, pressed && styles.authButtonPressed]}
    >
      <Text style={styles.authButtonText}>{label}</Text>
    </Pressable>
  );
}

function Login({
  onBack,
  onEmail,
  onProvider,
}: {
  onBack: () => void;
  onEmail: () => void;
  onProvider: () => void;
}) {
  return (
    <View style={styles.page}>
      <AuthHeader onBack={onBack} />
      <ScrollView
        contentContainerStyle={styles.authContent}
        showsVerticalScrollIndicator={false}
        style={styles.flex}
      >
        <BrandMark />
        <Text style={styles.onboardingTitle}>ログイン</Text>
        <Text style={styles.onboardingBody}>記録を同期するにはログインしてください。</Text>

        <View style={styles.authForm}>
          <PrimaryButton label="メールアドレスで続ける" onPress={onEmail} />
        </View>

        <AuthDivider />
        <View style={styles.authActions}>
          <AuthButton label="Appleで続ける" onPress={onProvider} />
          <AuthButton label="Googleで続ける" onPress={onProvider} />
        </View>

        <Text style={styles.terms}>
          続行すると利用規約とプライバシーポリシーに同意したものとします。
        </Text>
        <Text style={styles.devNote}>
          デモ用の仮フローです（実際のログイン・課金は行いません）
        </Text>
      </ScrollView>
    </View>
  );
}

function EmailStep({
  email,
  onBack,
  onChange,
  onNext,
}: {
  email: string;
  onBack: () => void;
  onChange: (value: string) => void;
  onNext: () => void;
}) {
  return (
    <View style={styles.page}>
      <AuthHeader onBack={onBack} />
      <ScrollView
        contentContainerStyle={styles.authContent}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
        style={styles.flex}
      >
        <Text style={styles.onboardingTitle}>メールアドレスを入力</Text>
        <Text style={styles.onboardingBody}>
          入力したアドレスに、確認コードを送ります。
        </Text>
        <View style={styles.authForm}>
          <View style={styles.formField}>
            <Text style={styles.fieldLabel}>メールアドレス</Text>
            <TextInput
              accessibilityLabel="メールアドレス"
              autoCapitalize="none"
              autoComplete="email"
              keyboardType="email-address"
              onChangeText={onChange}
              placeholder="name@example.com"
              placeholderTextColor={colors.accentMuted}
              style={styles.formControl}
              value={email}
            />
          </View>
          <PrimaryButton
            disabled={!isEmailLike(email)}
            label="確認コードを送信"
            onPress={onNext}
          />
        </View>
      </ScrollView>
    </View>
  );
}

function CodeStep({
  code,
  email,
  onBack,
  onChange,
  onNext,
}: {
  code: string;
  email: string;
  onBack: () => void;
  onChange: (value: string) => void;
  onNext: () => void;
}) {
  return (
    <View style={styles.page}>
      <AuthHeader onBack={onBack} />
      <ScrollView
        contentContainerStyle={styles.authContent}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
        style={styles.flex}
      >
        <Text style={styles.onboardingTitle}>確認コードを入力</Text>
        <Text style={styles.onboardingBody}>{`${email} 宛に6桁のコードを送信しました。`}</Text>
        <View style={styles.authForm}>
          <View style={styles.formField}>
            <Text style={styles.fieldLabel}>確認コード</Text>
            <TextInput
              accessibilityLabel="確認コード"
              keyboardType="number-pad"
              maxLength={6}
              onChangeText={(value) => onChange(value.replace(/\D/g, ""))}
              placeholder="000000"
              placeholderTextColor={colors.accentMuted}
              style={[styles.formControl, styles.codeInput]}
              value={code}
            />
          </View>
          <PrimaryButton
            disabled={!isCompleteCode(code)}
            label="確認"
            onPress={onNext}
          />
        </View>
      </ScrollView>
    </View>
  );
}

function Paywall({ onSkip }: { onSkip: () => void }) {
  const notReady = () =>
    Alert.alert("準備中", "購入手続きはまだ利用できません。無料のまま続けられます。");

  return (
    <View style={styles.page}>
      <View style={styles.paywallHeaderRow}>
        <Text style={styles.brandLabel}>プラン</Text>
        <Pressable
          accessibilityLabel="無料で続ける"
          accessibilityRole="button"
          hitSlop={8}
          onPress={onSkip}
        >
          <Text style={styles.skip}>無料で続ける</Text>
        </Pressable>
      </View>

      <ScrollView
        contentContainerStyle={styles.paywallContent}
        showsVerticalScrollIndicator={false}
        style={styles.flex}
      >
        <Text style={styles.paywallEyebrow}>MEMORA PRO</Text>
        <Text style={styles.onboardingTitle}>記録から次の行動まで、ひとつの流れで</Text>
        <Text style={styles.onboardingBody}>
          長い記録や複数のプロジェクトでも、音声を正本として文字起こし、要約、Ask AIをつなげます。
        </Text>

        <View style={styles.onboardingList}>
          {proFeatures.map((feature) => (
            <View key={feature.no} style={styles.onboardingItem}>
              <Text style={styles.onboardingItemNo}>{feature.no}</Text>
              <View style={styles.flex}>
                <Text style={styles.onboardingItemTitle}>{feature.title}</Text>
                <Text style={styles.onboardingItemBody}>{feature.body}</Text>
              </View>
            </View>
          ))}
        </View>

        <View style={styles.paywallMeta}>
          {purchaseFacts.map((fact, index) => (
            <View
              key={fact.label}
              style={[styles.paywallFact, index === 0 && styles.paywallFactFirst]}
            >
              <Text style={styles.paywallFactLabel}>{fact.label}</Text>
              <Text style={styles.paywallFactValue}>{fact.value}</Text>
            </View>
          ))}
          <Pressable
            accessibilityLabel="購入を復元"
            accessibilityRole="button"
            onPress={notReady}
            style={({ pressed }) => [styles.secondaryButton, pressed && styles.secondaryButtonPressed]}
          >
            <Text style={styles.secondaryButtonText}>購入を復元</Text>
          </Pressable>
        </View>

        <Text style={styles.devNote}>
          デモ用の仮フローです（実際のログイン・課金は行いません）
        </Text>
      </ScrollView>

      <PrimaryButton label="購入画面を確認" onPress={notReady} />
    </View>
  );
}

function BackButton({ onPress }: { onPress: () => void }) {
  return (
    <Pressable accessibilityLabel="戻る" hitSlop={2} onPress={onPress} style={styles.back}>
      <AppIcon color={colors.text} name="chevron-back" size={19} />
    </Pressable>
  );
}
function PrimaryButton({
  label,
  onPress,
  disabled,
  icon,
}: {
  label: string;
  onPress: () => void;
  disabled?: boolean;
  icon?: "logo-apple";
}) {
  return (
    <Pressable
      accessibilityLabel={label}
      accessibilityRole="button"
      disabled={disabled}
      onPress={onPress}
      style={[styles.primary, disabled && styles.primaryDisabled]}
    >
      {icon ? <AppIcon color={colors.surface} name={icon} size={18} /> : null}
      <Text style={styles.primaryText}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  safe: { backgroundColor: colors.surface, flex: 1 },
  flex: { flex: 1 },
  page: { flex: 1, paddingBottom: 36, paddingHorizontal: 28, paddingTop: 20 },
  skip: { color: colors.textSecondary, ...textStyles.footnote },
  onboardingHeaderRow: {
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
    minHeight: 36,
  },
  onboardingHeaderEnd: { alignItems: "center", flexDirection: "row", gap: spacing.md },
  onboardingBack: {
    alignItems: "center",
    height: 36,
    justifyContent: "center",
    marginLeft: -spacing.xs,
    width: 36,
  },
  brandLabel: { color: colors.text, ...textStyles.label },
  stepCounter: { color: colors.textSecondary, ...fonts.mono.regular, ...textStyles.caption },
  progress: {
    flexDirection: "row",
    gap: spacing.xxs,
    marginTop: spacing.md,
  },
  progressSegment: { backgroundColor: colors.border, flex: 1, height: 2 },
  progressSegmentActive: { backgroundColor: colors.text },
  onboardingContent: { justifyContent: "center", minHeight: "100%", paddingVertical: spacing.xl },
  onboardingCopy: { maxWidth: 420 },
  onboardingTitle: {
    color: colors.text,
    ...textStyles.screenTitle,
  },
  onboardingBody: {
    color: colors.textSecondary,
    marginTop: spacing.md,
    ...textStyles.body,
  },
  brandMark: {
    alignItems: "flex-end",
    flexDirection: "row",
    gap: 5,
    height: 48,
    marginBottom: spacing.xxl,
  },
  // 幅5ptのバーの端を丸める。角丸禁止の例外はブランドマークのみ（prototype .brand-mark i）。
  brandMarkBar: { backgroundColor: colors.text, borderRadius: radius.circle, width: 5 },
  onboardingList: {
    borderTopColor: colors.border,
    borderTopWidth: 1,
    marginTop: spacing.xxl,
  },
  onboardingItem: {
    alignItems: "center",
    borderBottomColor: colors.border,
    borderBottomWidth: 1,
    flexDirection: "row",
    gap: spacing.sm,
    minHeight: 72,
  },
  onboardingItemNo: { color: colors.textSecondary, width: 32, ...fonts.mono.regular, ...textStyles.footnote },
  onboardingItemTitle: { color: colors.text, ...textStyles.rowTitle },
  onboardingItemBody: { color: colors.textSecondary, marginTop: spacing.xxs, ...textStyles.footnote },
  privacyRule: {
    borderTopColor: colors.border,
    borderTopWidth: 1,
    marginTop: spacing.xl,
    paddingTop: spacing.xl,
  },
  privacyRuleLead: {
    borderTopColor: colors.text,
    borderTopWidth: 2,
    marginTop: spacing.xxl,
  },
  privacyRuleTitle: { color: colors.text, ...textStyles.sectionTitle },
  privacyRuleBody: { color: colors.textSecondary, marginTop: spacing.xs, ...textStyles.footnote },
  primary: {
    alignItems: "center",
    backgroundColor: colors.text,
    borderRadius: 0,
    flexDirection: "row",
    gap: 8,
    height: 52,
    justifyContent: "center",
  },
  primaryDisabled: { backgroundColor: colors.border },
  primaryText: { color: colors.surface, ...textStyles.callout },
  terms: {
    color: colors.textTertiary,
    marginTop: 16,
    textAlign: "center",
    ...textStyles.caption,
  },
  devNote: {
    color: colors.textTertiary,
    marginTop: 8,
    textAlign: "center",
    ...textStyles.caption,
  },
  back: {
    alignItems: "center",
    height: 40,
    justifyContent: "center",
    width: 40,
  },
  authHeaderRow: {
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
    minHeight: 36,
  },
  authContent: { paddingBottom: spacing.xl, paddingTop: spacing.xxl },
  authForm: { gap: spacing.xl, marginTop: spacing.xxl },
  formField: { gap: spacing.xxs },
  fieldLabel: { color: colors.textSecondary, ...textStyles.label },
  formControl: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 0,
    borderWidth: 1,
    color: colors.text,
    minHeight: 44,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
    ...textStyles.body,
  },
  codeInput: { ...fonts.mono.regular, letterSpacing: 4 },
  authDivider: {
    alignItems: "center",
    flexDirection: "row",
    gap: spacing.md,
    marginTop: spacing.xxl,
  },
  authDividerRule: { backgroundColor: colors.border, flex: 1, height: 1 },
  authDividerLabel: { color: colors.textSecondary, ...textStyles.label },
  authActions: { gap: spacing.sm, marginTop: spacing.md },
  authButton: {
    alignItems: "center",
    borderColor: colors.borderLight,
    borderRadius: 0,
    borderWidth: 1,
    justifyContent: "center",
    minHeight: 44,
  },
  authButtonPressed: { backgroundColor: colors.surfaceAlt },
  authButtonText: { color: colors.text, ...textStyles.footnoteBold },
  paywallHeaderRow: {
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
    minHeight: 36,
  },
  paywallContent: { paddingBottom: spacing.xl, paddingTop: spacing.xl },
  paywallEyebrow: { color: colors.textSecondary, marginBottom: spacing.sm, ...textStyles.label },
  paywallMeta: {
    borderTopColor: colors.border,
    borderTopWidth: 1,
    marginTop: spacing.xxl,
    paddingTop: spacing.md,
  },
  paywallFact: {
    alignItems: "center",
    borderBottomColor: colors.border,
    borderBottomWidth: 1,
    flexDirection: "row",
    gap: spacing.md,
    justifyContent: "space-between",
    minHeight: 44,
  },
  paywallFactFirst: { borderTopColor: colors.border, borderTopWidth: 1 },
  paywallFactLabel: { color: colors.text, ...textStyles.footnote },
  paywallFactValue: { color: colors.textSecondary, ...textStyles.footnote },
  secondaryButton: {
    alignItems: "center",
    borderColor: colors.borderLight,
    borderRadius: 0,
    borderWidth: 1,
    justifyContent: "center",
    marginTop: spacing.md,
    minHeight: 44,
  },
  secondaryButtonPressed: { backgroundColor: colors.surfaceAlt },
  secondaryButtonText: { color: colors.text, ...textStyles.footnoteBold },
});
