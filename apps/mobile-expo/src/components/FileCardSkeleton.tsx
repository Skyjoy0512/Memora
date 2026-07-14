import { useEffect, useRef } from 'react';
import { Animated, StyleSheet, View } from 'react-native';
import { colors, radius, spacing } from '../design/tokens';

type FileCardSkeletonProps = {
  count?: number;
};

function SkeletonCard() {
  const shimmer = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    const animation = Animated.loop(
      Animated.sequence([
        Animated.timing(shimmer, {
          toValue: 1,
          duration: 1200,
          useNativeDriver: true,
        }),
        Animated.timing(shimmer, {
          toValue: 0,
          duration: 1200,
          useNativeDriver: true,
        }),
      ]),
    );
    animation.start();
    return () => animation.stop();
  }, [shimmer]);

  const opacity = shimmer.interpolate({
    inputRange: [0, 1],
    outputRange: [0.3, 0.7],
  });

  return (
    <Animated.View style={[skStyles.card, { opacity }]}>
      <View style={[skStyles.block, skStyles.iconBlock]} />
      <View style={skStyles.body}>
        <View style={[skStyles.block, skStyles.titleBlock]} />
        <View style={[skStyles.block, skStyles.metaBlock]} />
        <View style={[skStyles.block, skStyles.summaryBlock]} />
      </View>
      <View style={[skStyles.block, skStyles.pillBlock]} />
    </Animated.View>
  );
}

export function FileCardSkeleton({ count = 5 }: FileCardSkeletonProps) {
  return (
    <>
      {Array.from({ length: count }, (_, i) => (
        <SkeletonCard key={i} />
      ))}
    </>
  );
}

const skStyles = StyleSheet.create({
  card: {
    alignItems: 'flex-start',
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radius.md,
    borderWidth: 1,
    flexDirection: 'row',
    gap: spacing.md,
    minHeight: 72,
    padding: spacing.md,
  },
  block: {
    backgroundColor: colors.skeleton,
    borderRadius: 4,
  },
  iconBlock: {
    borderRadius: radius.sm,
    height: 32,
    width: 32,
  },
  body: {
    flex: 1,
    gap: 6,
  },
  titleBlock: {
    height: 14,
    width: '60%',
  },
  metaBlock: {
    height: 10,
    width: '40%',
  },
  summaryBlock: {
    height: 10,
    width: '80%',
  },
  pillBlock: {
    borderRadius: radius.pill,
    height: 22,
    marginTop: 5,
    width: 56,
  },
});
