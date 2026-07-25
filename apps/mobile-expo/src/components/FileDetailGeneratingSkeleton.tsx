import { StyleSheet, View } from 'react-native';
import { SkeletonGroup } from 'heroui-native';
import { radius, spacing } from '../design/tokens';

export function FileDetailGeneratingSkeleton() {
  return (
    <SkeletonGroup isLoading style={styles.container}>
      <View style={styles.section}>
        <SkeletonGroup.Item style={styles.headingBlock} />
        <SkeletonGroup.Item style={[styles.lineBlock, { width: '100%' }]} />
        <SkeletonGroup.Item style={[styles.lineBlock, { width: '90%' }]} />
        <SkeletonGroup.Item style={[styles.lineBlock, { width: '75%' }]} />
        <SkeletonGroup.Item style={[styles.lineBlock, { width: '95%' }]} />
      </View>
      <View style={styles.section}>
        <SkeletonGroup.Item style={styles.headingBlock} />
        <SkeletonGroup.Item style={[styles.lineBlock, { width: '85%' }]} />
        <SkeletonGroup.Item style={[styles.lineBlock, { width: '60%' }]} />
      </View>
    </SkeletonGroup>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: spacing.lg,
  },
  section: {
    gap: spacing.sm,
  },
  headingBlock: {
    borderRadius: radius.sm,
    height: 15,
    width: '30%',
  },
  lineBlock: {
    borderRadius: radius.sm,
    height: 10,
  },
});
