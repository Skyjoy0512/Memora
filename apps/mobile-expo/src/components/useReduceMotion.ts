import { AccessibilityInfo } from 'react-native';
import { useEffect, useState } from 'react';
import { useReducedMotion as useReanimatedReducedMotion } from 'react-native-reanimated';

export function useReduceMotion() {
  const reanimatedPreference = useReanimatedReducedMotion();
  const [reduceMotion, setReduceMotion] = useState(reanimatedPreference);

  useEffect(() => {
    void AccessibilityInfo.isReduceMotionEnabled().then(setReduceMotion);
    const subscription = AccessibilityInfo.addEventListener('reduceMotionChanged', setReduceMotion);

    return () => subscription.remove();
  }, []);

  return reduceMotion;
}
