import { Pressable, StyleSheet, Text, View } from 'react-native';
import Animated, { useAnimatedStyle, useSharedValue, withSpring, withTiming } from 'react-native-reanimated';
import { PressableFeedback } from 'heroui-native/pressable-feedback';
import { Separator } from 'heroui-native/separator';
import { AppIcon } from './AppIcon';
import { StatusPill } from './StatusPill';
import { colors, motion, spacing, textStyles } from '../design/tokens';
import type { AudioFile } from '../types/memora';
import { formatRecordedAt } from '../utils/formatRecordedAt';

type FileCardProps = {
  file: AudioFile;
  onPress: () => void;
  onMore?: () => void;
  showSummary?: boolean;
};

function CardMainTarget({
  onPress,
  accessibilityLabel,
  children,
}: {
  onPress: () => void;
  accessibilityLabel: string;
  children: React.ReactNode;
}) {
  const scale = useSharedValue(1);
  const animatedStyle = useAnimatedStyle(() => ({ transform: [{ scale: scale.value }] }));

  return (
    <Pressable
      accessibilityLabel={accessibilityLabel}
      accessibilityRole="button"
      onPress={onPress}
      onPressIn={() => {
        scale.value = withTiming(0.98, { duration: motion.duration.fast });
      }}
      onPressOut={() => {
        scale.value = withSpring(1, motion.spring.tap);
      }}
      style={fcStyles.mainTarget}
    >
      <Animated.View style={[fcStyles.mainInner, animatedStyle]}>{children}</Animated.View>
    </Pressable>
  );
}

export function FileCard({
  file,
  onPress,
  onMore,
  showSummary = true,
}: FileCardProps) {
  return (
    <View>
      <View style={fcStyles.content}>
        <CardMainTarget
          accessibilityLabel={`${file.title}を開く`}
          onPress={onPress}
        >
          <View style={fcStyles.icon}>
            <AppIcon
              color={file.source === 'iPhone' ? colors.text : colors.textSecondary}
              name={file.source === 'iPhone' ? 'mic-outline' : 'document-outline'}
              size={16}
            />
          </View>

          <View style={fcStyles.body}>
            <Text numberOfLines={1} style={fcStyles.title}>
              {file.title}
            </Text>
            <Text numberOfLines={1} style={fcStyles.meta}>
              {formatRecordedAt(file.recordedAt)} · {file.duration}
            </Text>
            {showSummary && file.summary ? (
              <Text numberOfLines={1} style={fcStyles.summary}>
                {file.summary}
              </Text>
            ) : null}
          </View>

          <View style={fcStyles.status}>
            <StatusPill status={file.status} />
          </View>
        </CardMainTarget>

        {onMore ? (
          <PressableFeedback
            accessibilityLabel="その他の操作"
            accessibilityRole="button"
            animation={false}
            onPress={onMore}
            style={fcStyles.more}
          >
            <PressableFeedback.Highlight
              animation={{
                opacity: { value: [0, 0.12] },
              }}
            />
            <Text style={fcStyles.moreText}>⋯</Text>
          </PressableFeedback>
        ) : null}
      </View>
      <Separator orientation="horizontal" variant="thin" />
    </View>
  );
}

const fcStyles = StyleSheet.create({
  content: {
    alignItems: 'center',
    flexDirection: 'row',
    minHeight: 72,
  },
  mainTarget: {
    alignSelf: 'stretch',
    flex: 1,
  },
  mainInner: {
    alignItems: 'center',
    flex: 1,
    flexDirection: 'row',
    gap: spacing.md,
    minHeight: 72,
    paddingVertical: spacing.md,
  },
  icon: {
    alignItems: 'center',
    flexShrink: 0,
    height: 32,
    justifyContent: 'center',
    width: 32,
  },
  body: {
    flex: 1,
    minWidth: 0,
  },
  title: {
    color: colors.text,
    ...textStyles.bodyBold,
  },
  meta: {
    color: colors.textSecondary,
    marginTop: spacing.xxs,
    ...textStyles.footnote,
  },
  summary: {
    color: colors.textTertiary,
    marginTop: spacing.xxs,
    ...textStyles.caption,
  },
  status: {
    flexShrink: 0,
  },
  more: {
    alignItems: 'center',
    flexShrink: 0,
    height: 44,
    justifyContent: 'center',
    marginVertical: -6,
    marginLeft: -6,
    width: 44,
  },
  moreText: {
    color: colors.textTertiary,
    ...textStyles.callout,
  },
});
