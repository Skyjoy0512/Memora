import { useLocalSearchParams } from 'expo-router';
import { FileDetailScreen } from '../../src/screens/FileDetailScreen';

export default function FileRoute() {
  const { id } = useLocalSearchParams<{ id: string }>();
  return <FileDetailScreen fileId={id} />;
}
