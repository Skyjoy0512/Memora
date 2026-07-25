import { Alert } from 'heroui-native';

type OfflineBannerProps = {
  message?: string;
};

export function OfflineBanner({
  message = 'オフライン — 端末内の記録のみ表示されます',
}: OfflineBannerProps) {
  return (
    <Alert accessibilityLiveRegion="polite" accessibilityRole="alert" status="warning">
      <Alert.Indicator />
      <Alert.Content>
        <Alert.Description>{message}</Alert.Description>
      </Alert.Content>
    </Alert>
  );
}
