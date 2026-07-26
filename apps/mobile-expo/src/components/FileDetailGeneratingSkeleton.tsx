import { Card, SkeletonGroup } from 'heroui-native';

export function FileDetailGeneratingSkeleton() {
  return (
    <SkeletonGroup className="gap-3" isLoading>
      <Card className="gap-3 border border-border bg-surface p-3">
        <Card.Header>
          <SkeletonGroup.Item className="h-4 w-1/3 rounded" />
        </Card.Header>
        <Card.Body className="gap-2">
          <SkeletonGroup.Item className="h-3 w-full rounded" />
          <SkeletonGroup.Item className="h-3 w-11/12 rounded" />
          <SkeletonGroup.Item className="h-3 w-3/4 rounded" />
          <SkeletonGroup.Item className="h-3 w-5/6 rounded" />
        </Card.Body>
      </Card>
      <Card className="gap-3 border border-border bg-surface p-3">
        <Card.Header>
          <SkeletonGroup.Item className="h-4 w-1/4 rounded" />
        </Card.Header>
        <Card.Body className="gap-2">
          <SkeletonGroup.Item className="h-3 w-4/5 rounded" />
          <SkeletonGroup.Item className="h-3 w-3/5 rounded" />
        </Card.Body>
      </Card>
    </SkeletonGroup>
  );
}
