import { StyleSheet, View } from 'react-native';
import { SkeletonGroup } from 'heroui-native';
import { radius, spacing } from '../design/tokens';

type FileCardSkeletonProps = {
  count?: number;
};

function SkeletonCard() {
  return (
    <SkeletonGroup isLoading style={skStyles.card}>
      <SkeletonGroup.Item style={skStyles.iconBlock} />
      <View style={skStyles.body}>
        <SkeletonGroup.Item style={skStyles.titleBlock} />
        <SkeletonGroup.Item style={skStyles.metaBlock} />
        <SkeletonGroup.Item style={skStyles.summaryBlock} />
      </View>
      <SkeletonGroup.Item style={skStyles.pillBlock} />
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

const skStyles = StyleSheet.create({
  card: {
    alignItems: 'flex-start',
    borderRadius: radius.md,
    flexDirection: 'row',
    gap: spacing.md,
    minHeight: 72,
    padding: spacing.md,
  },
  iconBlock: {
    borderRadius: radius.sm,
    height: 32,
    width: 32,
  },
  body: {
    flex: 1,
    gap: 6,
  },
  titleBlock: {
    height: 14,
    width: '60%',
  },
  metaBlock: {
    height: 10,
    width: '40%',
  },
  summaryBlock: {
    height: 10,
    width: '80%',
  },
  pillBlock: {
    borderRadius: radius.pill,
    height: 22,
    marginTop: 5,
    width: 56,
  },
});
