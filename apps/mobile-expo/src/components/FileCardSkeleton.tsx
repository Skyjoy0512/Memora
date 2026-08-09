import { StyleSheet, View } from 'react-native';
import { SkeletonGroup } from 'heroui-native/skeleton-group';
import { Separator } from 'heroui-native/separator';
import { spacing } from '../design/tokens';

type FileCardSkeletonProps = {
  count?: number;
};

function SkeletonRow() {
  return (
    <View style={skStyles.card} accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
      <SkeletonGroup.Item className="h-8 w-8 rounded" />
      <View style={skStyles.body}>
        <SkeletonGroup.Item className="h-4 w-3/5 rounded" />
        <SkeletonGroup.Item className="h-3 w-2/5 rounded" />
        <SkeletonGroup.Item className="h-3 w-4/5 rounded" />
      </View>
      <SkeletonGroup.Item className="h-6 w-14 rounded-full" />
    </View>
  );
}

export function FileCardSkeleton({ count = 5 }: FileCardSkeletonProps) {
  return (
    <View
      accessibilityLabel="記録を読み込み中"
      accessibilityRole="progressbar"
      accessibilityState={{ busy: true }}
      style={skStyles.container}
    >
      <SkeletonGroup>
        {Array.from({ length: count }, (_, i) => (
          <View key={i}>
            <SkeletonRow />
            {i < count - 1 ? <Separator orientation="horizontal" variant="thin" /> : null}
          </View>
        ))}
      </SkeletonGroup>
    </View>
  );
}

const skStyles = StyleSheet.create({
  container: {
    paddingVertical: spacing.xs,
  },
  card: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: spacing.md,
    minHeight: 72,
    paddingVertical: spacing.md,
  },
  body: {
    flex: 1,
    gap: spacing.xs,
    minWidth: 0,
    paddingTop: 2,
  },
});
