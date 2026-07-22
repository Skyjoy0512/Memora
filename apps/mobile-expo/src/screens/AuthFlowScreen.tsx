import { AppIcon } from "../components/AppIcon";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useState } from "react";
import {
  Alert,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  SafeAreaView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import { colors, fonts, radius, textStyles } from "../design/tokens";

type Stage = "onboarding" | "login" | "email" | "code" | "paywall";
const slides = [
  ["記録を、もっと自然に", "会議や雑談をワンタップで記録します。"],
  ["要点を、すぐに把握", "決定事項と次のアクションを自動で整理します。"],
  ["いつでも、聞き返せる", "過去の会話を Ask AI で横断して振り返れます。"],
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
  const [annual, setAnnual] = useState(true);
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
            slide={slide}
            onNext={nextSlide}
            onSkip={() => setStage("login")}
          />
        ) : null}
        {stage === "login" ? (
          <Login
            onEmail={() => setStage("email")}
            onProvider={() =>
              Alert.alert(
                "準備中",
                "外部認証の接続は次の認証バックエンド作業で有効になります。",
              )
            }
          />
        ) : null}
        {stage === "email" ? (
          <EmailStep
            email={email}
            onBack={() => setStage("login")}
            onChange={setEmail}
            onNext={() => email.includes("@") && setStage("code")}
          />
        ) : null}
        {stage === "code" ? (
          <CodeStep
            code={code}
            email={email}
            onBack={() => setStage("email")}
            onChange={setCode}
            onNext={() => code.length === 6 && setStage("paywall")}
          />
        ) : null}
        {stage === "paywall" ? (
          <Paywall
            annual={annual}
            onSelect={setAnnual}
            onSkip={complete}
            onTrial={() => {
              Alert.alert(
                "準備中",
                "購入処理はまだ接続されていません。Free プランで続けます。",
                [{ text: "続ける", onPress: complete }],
              );
            }}
          />
        ) : null}
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

function Onboarding({
  slide,
  onNext,
  onSkip,
}: {
  slide: number;
  onNext: () => void;
  onSkip: () => void;
}) {
  const [title, body] = slides[slide];
  return (
    <View style={styles.page}>
      <View style={styles.skipRow}>
        <Pressable
          accessibilityLabel="オンボーディングをスキップ"
          onPress={onSkip}
        >
          <Text style={styles.skip}>スキップ</Text>
        </Pressable>
      </View>
      <View style={styles.onboardingCenter}>
        {slide === 0 ? (
          <View style={styles.recordGlyph}>
            <View style={styles.recordSquare} />
          </View>
        ) : slide === 1 ? (
          <View style={styles.summaryGlyph}>
            <Text style={styles.glyphTitle}>決定事項</Text>
            <View style={styles.glyphLineLong} />
            <View style={styles.glyphLineShort} />
            <Text style={styles.glyphTitle}>次のアクション</Text>
            <View style={styles.glyphLineMedium} />
          </View>
        ) : (
          <View style={styles.askGlyph}>
            <Text style={styles.askGlyphText}>Search or Ask</Text>
            <View style={styles.askGlyphCircle} />
          </View>
        )}
        <View style={styles.onboardingCopy}>
          <Text style={styles.authTitle}>{title}</Text>
          <Text style={styles.authBody}>{body}</Text>
        </View>
      </View>
      <View>
        <View style={styles.dots}>
          {slides.map((_, index) => (
            <View
              key={index}
              style={[styles.dot, slide === index && styles.dotActive]}
            />
          ))}
        </View>
        <PrimaryButton
          label={slide === 2 ? "はじめる" : "次へ"}
          onPress={onNext}
        />
      </View>
    </View>
  );
}

function Login({
  onEmail,
  onProvider,
}: {
  onEmail: () => void;
  onProvider: () => void;
}) {
  return (
    <View style={styles.page}>
      <View style={styles.loginHero}>
        <Text style={styles.appTitle}>Memora</Text>
        <Text style={styles.authBody}>会話を記録し、AIが要約する</Text>
      </View>
      <View style={styles.loginActions}>
        <PrimaryButton
          icon="logo-apple"
          label="Apple でサインイン"
          onPress={onProvider}
        />
        <Pressable
          accessibilityLabel="Google で続ける"
          onPress={onProvider}
          style={styles.googleButton}
        >
          <Text style={styles.googleG}>G</Text>
          <Text style={styles.googleText}>Google で続ける</Text>
        </Pressable>
        <Pressable
          accessibilityLabel="メールアドレスで続ける"
          onPress={onEmail}
          style={styles.emailButton}
        >
          <Text style={styles.emailText}>メールアドレスで続ける</Text>
        </Pressable>
      </View>
      <Text style={styles.terms}>
        続行すると利用規約とプライバシーポリシーに同意したことになります
      </Text>
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
      <BackButton onPress={onBack} />
      <View style={styles.formCenter}>
        <Text style={styles.authTitle}>メールアドレスを入力</Text>
        <TextInput
          accessibilityLabel="メールアドレス"
          autoCapitalize="none"
          autoComplete="email"
          keyboardType="email-address"
          onChangeText={onChange}
          placeholder="you@example.com"
          placeholderTextColor={colors.textTertiary}
          style={styles.input}
          value={email}
        />
      </View>
      <PrimaryButton
        disabled={!email.includes("@")}
        label="確認コードを送信"
        onPress={onNext}
      />
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
      <BackButton onPress={onBack} />
      <View style={styles.formCenter}>
        <View>
          <Text style={styles.authTitle}>確認コードを入力</Text>
          <Text style={styles.codeHint}>
            {email} 宛に6桁のコードを送信しました
          </Text>
        </View>
        <View style={styles.codeBoxes}>
          {Array.from({ length: 6 }, (_, index) => (
            <View key={index} style={styles.codeBox}>
              <Text style={styles.codeDigit}>{code[index] ?? ""}</Text>
            </View>
          ))}
        </View>
        <TextInput
          accessibilityLabel="確認コード"
          keyboardType="number-pad"
          maxLength={6}
          onChangeText={(value) => onChange(value.replace(/\D/g, ""))}
          placeholder="コードを入力"
          placeholderTextColor={colors.textTertiary}
          style={styles.codeInput}
          value={code}
        />
      </View>
      <PrimaryButton
        disabled={code.length !== 6}
        label="確認"
        onPress={onNext}
      />
    </View>
  );
}

function Paywall({
  annual,
  onSelect,
  onSkip,
  onTrial,
}: {
  annual: boolean;
  onSelect: (annual: boolean) => void;
  onSkip: () => void;
  onTrial: () => void;
}) {
  const features = [
    "文字起こし 月1200分（無料: 300分）",
    "添付のクラウド保存・全デバイス同期",
    "ライフログ自動セグメント無制限",
    "Ask AI 無制限（無料: 1日10回）",
  ];
  return (
    <View style={styles.page}>
      <View style={styles.skipRow}>
        <Pressable accessibilityLabel="あとで" onPress={onSkip}>
          <Text style={styles.skip}>あとで</Text>
        </Pressable>
      </View>
      <View style={styles.paywallContent}>
        <View style={styles.paywallHero}>
          <Text style={styles.proTitle}>Memora Pro</Text>
          <Text style={styles.authBody}>すべての記録を、どこからでも</Text>
        </View>
        <View style={styles.features}>
          {features.map((feature) => (
            <View key={feature} style={styles.feature}>
              <View style={styles.check}>
                <AppIcon color={colors.surface} name="checkmark" size={11} />
              </View>
              <Text style={styles.featureText}>{feature}</Text>
            </View>
          ))}
        </View>
        <View style={styles.plans}>
          <Plan
            active={annual}
            badge="2ヶ月分お得"
            label="年額"
            note="月あたり¥817"
            price="¥9,800"
            onPress={() => onSelect(true)}
          />
          <Plan
            active={!annual}
            label="月額"
            note="いつでも解約可"
            price="¥980"
            onPress={() => onSelect(false)}
          />
        </View>
      </View>
      <View>
        <PrimaryButton label="7日間無料で試す" onPress={onTrial} />
        <Text style={styles.cancelHint}>いつでもキャンセルできます</Text>
        <Text style={styles.legal}>購入を復元　　利用規約　　プライバシー</Text>
      </View>
    </View>
  );
}

function Plan({
  active,
  badge,
  label,
  note,
  price,
  onPress,
}: {
  active: boolean;
  badge?: string;
  label: string;
  note: string;
  price: string;
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityLabel={`${label}プランを選択`}
      onPress={onPress}
      style={[styles.plan, active && styles.planActive]}
    >
      {badge ? <Text style={styles.planBadge}>{badge}</Text> : null}
      <Text style={styles.planLabel}>{label}</Text>
      <Text style={styles.planPrice}>{price}</Text>
      <Text style={styles.planNote}>{note}</Text>
    </Pressable>
  );
}
function BackButton({ onPress }: { onPress: () => void }) {
  return (
    <Pressable accessibilityLabel="戻る" onPress={onPress} style={styles.back}>
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
  skipRow: { alignItems: "flex-end" },
  skip: { color: colors.textTertiary, ...textStyles.footnoteBold },
  onboardingCenter: {
    alignItems: "center",
    flex: 1,
    gap: 32,
    justifyContent: "center",
  },
  onboardingCopy: { gap: 8, paddingHorizontal: 18 },
  authTitle: {
    color: colors.text,
    textAlign: "center",
    ...textStyles.title2,
  },
  authBody: {
    color: colors.textTertiary,
    textAlign: "center",
    ...textStyles.body,
  },
  recordGlyph: {
    alignItems: "center",
    backgroundColor: colors.text,
    borderRadius: 44,
    height: 88,
    justifyContent: "center",
    width: 88,
  },
  recordSquare: {
    backgroundColor: colors.surface,
    borderRadius: 8,
    height: 30,
    width: 30,
  },
  summaryGlyph: {
    backgroundColor: colors.surfaceAlt,
    borderRadius: 16,
    gap: 7,
    padding: 16,
    width: 220,
  },
  glyphTitle: {
    color: colors.text,
    marginBottom: 1,
    ...textStyles.footnoteBold,
  },
  glyphLineLong: {
    backgroundColor: colors.border,
    borderRadius: 4,
    height: 8,
    width: "90%",
  },
  glyphLineShort: {
    backgroundColor: colors.border,
    borderRadius: 4,
    height: 8,
    marginBottom: 7,
    width: "65%",
  },
  glyphLineMedium: {
    backgroundColor: colors.border,
    borderRadius: 4,
    height: 8,
    width: "75%",
  },
  askGlyph: {
    alignItems: "center",
    backgroundColor: colors.text,
    borderRadius: 26,
    flexDirection: "row",
    gap: 10,
    height: 52,
    paddingHorizontal: 18,
    width: 220,
  },
  askGlyphText: { color: colors.textTertiary, flex: 1, ...textStyles.footnote },
  askGlyphCircle: {
    backgroundColor: "rgba(255,255,255,0.12)",
    borderRadius: 15,
    height: 30,
    width: 30,
  },
  dots: {
    flexDirection: "row",
    gap: 6,
    justifyContent: "center",
    marginBottom: 22,
  },
  dot: { backgroundColor: colors.border, borderRadius: 3, height: 6, width: 6 },
  dotActive: { backgroundColor: colors.text, width: 20 },
  primary: {
    alignItems: "center",
    backgroundColor: colors.text,
    borderRadius: 16,
    flexDirection: "row",
    gap: 8,
    height: 52,
    justifyContent: "center",
  },
  primaryDisabled: { backgroundColor: colors.border },
  primaryText: { color: colors.surface, ...textStyles.callout },
  loginHero: {
    alignItems: "center",
    flex: 1,
    gap: 8,
    justifyContent: "center",
  },
  appTitle: {
    color: colors.text,
    ...textStyles.display,
  },
  loginActions: { gap: 10 },
  googleButton: {
    alignItems: "center",
    borderColor: colors.border,
    borderRadius: 14,
    borderWidth: 1,
    flexDirection: "row",
    gap: 8,
    height: 52,
    justifyContent: "center",
  },
  googleG: { color: "#4285F4", ...textStyles.callout },
  googleText: { color: colors.text, ...textStyles.bodyBold },
  emailButton: {
    alignItems: "center",
    backgroundColor: colors.surfaceAlt,
    borderRadius: 14,
    height: 52,
    justifyContent: "center",
  },
  emailText: { color: colors.text, ...textStyles.bodyBold },
  terms: {
    color: colors.textTertiary,
    marginTop: 16,
    textAlign: "center",
    ...textStyles.caption,
  },
  back: {
    alignItems: "center",
    height: 40,
    justifyContent: "center",
    width: 40,
  },
  formCenter: { flex: 1, gap: 16, justifyContent: "center" },
  input: {
    borderColor: colors.border,
    borderRadius: 12,
    borderWidth: 1,
    color: colors.text,
    paddingHorizontal: 16,
    paddingVertical: 14,
    ...textStyles.callout,
  },
  codeHint: {
    color: colors.textTertiary,
    marginTop: 6,
    textAlign: "center",
    ...textStyles.footnote,
  },
  codeBoxes: { flexDirection: "row", gap: 8 },
  codeBox: {
    alignItems: "center",
    aspectRatio: 1,
    borderColor: colors.border,
    borderRadius: 10,
    borderWidth: 1,
    flex: 1,
    justifyContent: "center",
  },
  codeDigit: {
    color: colors.text,
    fontSize: 18,
    ...fonts.mono.regular,
  },
  codeInput: {
    borderColor: colors.border,
    borderRadius: 12,
    borderWidth: 1,
    color: colors.text,
    fontSize: 15,
    paddingHorizontal: 14,
    paddingVertical: 12,
    ...fonts.mono.regular,
  },
  paywallContent: { flex: 1, paddingHorizontal: 6, paddingTop: 6 },
  paywallHero: { alignItems: "center", gap: 4, marginBottom: 22 },
  proTitle: {
    color: colors.text,
    letterSpacing: -0.26,
    ...textStyles.title2,
  },
  features: { gap: 12, marginBottom: 22 },
  feature: { alignItems: "center", flexDirection: "row", gap: 10 },
  check: {
    alignItems: "center",
    backgroundColor: colors.text,
    borderRadius: 9,
    height: 18,
    justifyContent: "center",
    width: 18,
  },
  featureText: { color: colors.text, flex: 1, ...textStyles.footnote },
  plans: { flexDirection: "row", gap: 10 },
  plan: {
    borderColor: colors.border,
    borderRadius: 14,
    borderWidth: 2,
    flex: 1,
    padding: 12,
    position: "relative",
  },
  planActive: { borderColor: colors.text },
  planBadge: {
    backgroundColor: colors.text,
    borderRadius: 6,
    color: colors.surface,
    left: 10,
    paddingHorizontal: 7,
    paddingVertical: 2,
    position: "absolute",
    top: -10,
    ...textStyles.captionBold,
  },
  planLabel: {
    color: colors.text,
    marginBottom: 4,
    ...textStyles.footnoteBold,
  },
  planPrice: { color: colors.text, ...textStyles.callout },
  planNote: { color: colors.textTertiary, marginTop: 2, ...textStyles.caption },
  cancelHint: {
    color: colors.textTertiary,
    marginBottom: 16,
    marginTop: 8,
    textAlign: "center",
    ...textStyles.caption,
  },
  legal: { color: colors.textTertiary, textAlign: "center", ...textStyles.caption },
});
