import { AppIcon } from './AppIcon';
import { Alert, Button, Card, Spinner } from 'heroui-native';
import { MotionAppear } from './MotionAppear';

export function LoadingState({ label = '読み込み中' }: { label?: string }) {
  return (
    <MotionAppear>
      <Card className="items-center gap-3 border border-border bg-surface p-5">
        <Card.Header className="items-center">
          <Spinner size="sm" />
        </Card.Header>
        <Card.Body className="items-center gap-1">
          <Card.Title>{label}</Card.Title>
          <Card.Description className="text-center">
            記録を確認しています。しばらくお待ちください。
          </Card.Description>
        </Card.Body>
      </Card>
    </MotionAppear>
  );
}

export function EmptyState({
  title,
  body,
  actionLabel,
  onAction,
}: {
  title: string;
  body: string;
  actionLabel?: string;
  onAction?: () => void;
}) {
  return (
    <MotionAppear>
      <Card className="items-center gap-3 border border-border bg-surface p-5">
        <Card.Header className="items-center">
          <AppIcon name="file-tray-outline" size={20} />
        </Card.Header>
        <Card.Body className="items-center gap-1">
          <Card.Title className="text-center">{title}</Card.Title>
          <Card.Description className="text-center">{body}</Card.Description>
        </Card.Body>
        {actionLabel && onAction ? (
          <Card.Footer className="min-h-11">
            <Button
              accessibilityLabel={actionLabel}
              accessibilityRole="button"
              className="min-h-11"
              onPress={onAction}
              variant="primary"
          >
              {actionLabel}
            </Button>
          </Card.Footer>
        ) : null}
      </Card>
    </MotionAppear>
  );
}

export function ErrorState({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <MotionAppear>
      <Alert accessibilityRole="alert" className="items-start" status="danger">
        <Alert.Indicator />
        <Alert.Content className="gap-1">
          <Alert.Title>読み込みに失敗しました</Alert.Title>
          <Alert.Description>{message}</Alert.Description>
          {onRetry ? (
            <Button
              accessibilityLabel="ファイルを再読み込み"
              accessibilityRole="button"
              className="mt-2 min-h-11 self-start"
              onPress={onRetry}
              variant="danger"
            >
              再試行
            </Button>
          ) : null}
        </Alert.Content>
      </Alert>
    </MotionAppear>
  );
}
