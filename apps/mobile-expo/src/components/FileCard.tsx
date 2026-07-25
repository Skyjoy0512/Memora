import { Button, Card, PressableFeedback } from 'heroui-native';
import { MotionAppear } from './MotionAppear';
import { StatusPill } from './StatusPill';
import type { AudioFile } from '../types/memora';
import { formatRecordedAt } from '../utils/formatRecordedAt';

type FileCardProps = {
  file: AudioFile;
  onPress: () => void;
  onMore?: () => void;
  showSummary?: boolean;
};

export function FileCard({
  file,
  onPress,
  onMore,
  showSummary = true,
}: FileCardProps) {
  const source = file.source === 'iPhone' ? 'iPhoneで録音' : 'ファイルから読み込み';

  return (
    <MotionAppear>
      <PressableFeedback
        accessibilityLabel={`${file.title}を開く`}
        accessibilityRole="button"
        onPress={onPress}
      >
        <Card className="gap-3 border border-border bg-surface p-3">
          <Card.Header className="flex-row items-center gap-3">
            <Card.Title className="flex-1" numberOfLines={1}>
              {file.title}
            </Card.Title>
            <StatusPill status={file.status} />
          </Card.Header>

          <Card.Body className="gap-1">
            <Card.Description numberOfLines={1}>
              {formatRecordedAt(file.recordedAt)} · {file.duration} · {source}
            </Card.Description>
            {showSummary && file.summary ? (
              <Card.Description numberOfLines={2}>{file.summary}</Card.Description>
            ) : null}
          </Card.Body>

          <Card.Footer className="min-h-11 flex-row items-center justify-between gap-3">
            <Card.Description numberOfLines={1}>
              {file.project ?? '未分類'}
            </Card.Description>
            {onMore ? (
              <Button
                accessibilityLabel="その他の操作"
                accessibilityRole="button"
                isIconOnly
                onPress={onMore}
                size="md"
                variant="ghost"
              >
                ⋯
              </Button>
            ) : null}
          </Card.Footer>
        </Card>
      </PressableFeedback>
    </MotionAppear>
  );
}
