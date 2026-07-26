import { Card, SkeletonGroup } from 'heroui-native';

type FileCardSkeletonProps = {
  count?: number;
};

function SkeletonCard() {
  return (
    <SkeletonGroup className="gap-3" isLoading>
      <Card className="gap-3 border border-border bg-surface p-3">
        <Card.Header className="flex-row items-center gap-3">
          <SkeletonGroup.Item className="h-4 flex-1 rounded" />
          <SkeletonGroup.Item className="h-5 w-14 rounded-full" />
        </Card.Header>
        <Card.Body className="gap-2">
          <SkeletonGroup.Item className="h-3 w-3/5 rounded" />
          <SkeletonGroup.Item className="h-3 w-4/5 rounded" />
        </Card.Body>
        <Card.Footer className="min-h-11 flex-row items-center justify-between">
          <SkeletonGroup.Item className="h-3 w-1/4 rounded" />
          <SkeletonGroup.Item className="h-8 w-8 rounded" />
        </Card.Footer>
      </Card>
    </SkeletonGroup>
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
