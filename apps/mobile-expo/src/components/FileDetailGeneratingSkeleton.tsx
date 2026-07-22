import { useEffect, useRef } from 'react';
import { Animated, StyleSheet, View } from 'react-native';
import { colors, radius, spacing } from '../design/tokens';

export function FileDetailGeneratingSkeleton() {
  const shimmer = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    const animation = Animated.loop(
      Animated.sequence([
        Animated.timing(shimmer, { toValue: 1, duration: 1200, useNativeDriver: true }),
        Animated.timing(shimmer, { toValue: 0, duration: 1200, useNativeDriver: true }),
      ]),
    );
    animation.start();
    return () => animation.stop();
  }, [shimmer]);

  const opacity = shimmer.interpolate({ inputRange: [0, 1], outputRange: [0.3, 0.7] });

  return (
    <Animated.View style={[styles.container, { opacity }]}>
      <View style={styles.section}>
        <View style={[styles.block, styles.headingBlock]} />
        <View style={[styles.block, styles.lineBlock, { width: '100%' }]} />
        <View style={[styles.block, styles.lineBlock, { width: '90%' }]} />
        <View style={[styles.block, styles.lineBlock, { width: '75%' }]} />
        <View style={[styles.block, styles.lineBlock, { width: '95%' }]} />
      </View>
      <View style={styles.section}>
        <View style={[styles.block, styles.headingBlock]} />
        <View style={[styles.block, styles.lineBlock, { width: '85%' }]} />
        <View style={[styles.block, styles.lineBlock, { width: '60%' }]} />
      </View>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: spacing.lg,
  },
  section: {
    gap: spacing.sm,
  },
  block: {
    backgroundColor: colors.skeleton,
    borderRadius: radius.sm,
  },
  headingBlock: {
    height: 15,
    width: '30%',
  },
  lineBlock: {
    height: 10,
  },
});
