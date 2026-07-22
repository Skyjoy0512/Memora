import { Link } from 'expo-router';
import { StyleSheet, Text, View } from 'react-native';
import { Screen } from '../components/Screen';
import { Section } from '../components/Section';
import { colors, radius, spacing, textStyles } from '../design/tokens';
import { audioFiles } from '../mocks/memoraData';

export function PreviewIndexScreen() {
  return (
    <Screen
      title="Preview Index"
      subtitle="Claude / DeepSeek / Codex が画面単位で確認するための RN mock UI 入口です。"
    >
      <Section title="Routes">
        <View style={styles.list}>
          <PreviewLink href="/" label="Home" />
          <PreviewLink href="/ask-ai" label="Ask AI" />
          <PreviewLink href="/settings" label="Settings" />
          <PreviewLink href="/auth" label="Auth: onboarding / login / paywall" />
          <PreviewLink href="/file/empty-transcript" label="File: empty transcript state" />
          <PreviewLink href="/file/queued-preview" label="File: queued (pre-transcription) state" />
          <PreviewLink href="/file/not-found" label="File: not found state" />
          {audioFiles.map((file) => (
            <PreviewLink href={`/file/${file.id}`} key={file.id} label={`File: ${file.title}`} />
          ))}
        </View>
      </Section>
    </Screen>
  );
}

function PreviewLink({ href, label }: { href: string; label: string }) {
  return (
    <Link href={href} style={styles.link}>
      <Text style={styles.linkText}>{label}</Text>
    </Link>
  );
}

const styles = StyleSheet.create({
  list: {
    gap: spacing.md,
  },
  link: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radius.md,
    borderWidth: 1,
    padding: spacing.lg,
  },
  linkText: {
    color: colors.text,
    ...textStyles.callout,
  },
});
