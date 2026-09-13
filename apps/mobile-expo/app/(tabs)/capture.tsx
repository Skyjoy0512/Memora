import { Redirect, useFocusEffect } from 'expo-router';
import { useCallback } from 'react';
import { useCaptureFlow } from '../../src/features/capture/CaptureFlowProvider';

/**
 * 記録メニューはタブバーの「録音」から開く。
 * iOS/Android はトリガが選択を止め、tabPress リスナーで開くのでこの画面には来ない。
 * web のタブ実装はリスナーを持たず /capture へ素通しで遷移し、しかも全タブを
 * マウントしたままにする（forceMount）。そのためマウントではなくフォーカスを
 * 合図にメニューを開き、直前のタブへ戻す。
 */
export default function CaptureRoute() {
  const { openCaptureMenu } = useCaptureFlow();

  useFocusEffect(
    useCallback(() => {
      openCaptureMenu();
    }, [openCaptureMenu]),
  );

  return <Redirect href="/" />;
}
