import { Pressable, type GestureResponderEvent, type PressableProps, type StyleProp, type ViewStyle } from 'react-native';
import Animated, { Easing, useAnimatedStyle, useSharedValue, withSpring, withTiming } from 'react-native-reanimated';
import { motion } from '../design/tokens';
import { useReduceMotion } from './useReduceMotion';

type MotionPressableProps = Omit<PressableProps, 'onPressIn' | 'onPressOut' | 'style'> & {
  onPressIn?: PressableProps['onPressIn'];
  onPressOut?: PressableProps['onPressOut'];
  pressScale?: number;
  style?: StyleProp<ViewStyle>;
};

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export function MotionPressable({ onPressIn, onPressOut, pressScale = 0.97, style, ...props }: MotionPressableProps) {
  const reduceMotion = useReduceMotion();
  const scale = useSharedValue(1);
  const opacity = useSharedValue(1);

  const animatedStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
    transform: [{ scale: scale.value }],
  }));

  return (
    <AnimatedPressable
      {...props}
      onPressIn={(event: GestureResponderEvent) => {
        if (reduceMotion) {
          opacity.value = withTiming(0.92, { duration: motion.duration.pressDown, easing: Easing.out(Easing.cubic) });
        } else {
          scale.value = withTiming(pressScale, { duration: motion.duration.pressDown, easing: Easing.out(Easing.cubic) });
        }
        onPressIn?.(event);
      }}
      onPressOut={(event: GestureResponderEvent) => {
        if (reduceMotion) {
          opacity.value = withTiming(1, { duration: motion.duration.reducedCrossfade, easing: Easing.out(Easing.cubic) });
        } else {
          scale.value = withSpring(1, motion.spring.press);
        }
        onPressOut?.(event);
      }}
      style={[style, animatedStyle]}
    />
  );
}
