import { type ReactNode, useEffect } from 'react';
import Animated, { Easing, useAnimatedStyle, useSharedValue, withSpring, withTiming } from 'react-native-reanimated';
import { motion } from '../design/tokens';
import { useReduceMotion } from './useReduceMotion';

type MotionAppearProps = {
  children: ReactNode;
  distance?: number;
};

export function MotionAppear({ children, distance = 8 }: MotionAppearProps) {
  const reduceMotion = useReduceMotion();
  const opacity = useSharedValue(0);
  const translateY = useSharedValue(distance);

  useEffect(() => {
    opacity.value = withTiming(1, {
      duration: reduceMotion ? motion.duration.reducedCrossfade : motion.duration.fast,
      easing: Easing.out(Easing.cubic),
    });
    translateY.value = reduceMotion ? 0 : withSpring(0, motion.spring.entrance);
  }, [opacity, reduceMotion, translateY]);

  const animatedStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
    transform: [{ translateY: translateY.value }],
  }));

  return <Animated.View style={animatedStyle}>{children}</Animated.View>;
}
