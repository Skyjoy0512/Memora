import type { IconComponent, IconProps } from 'reicon-react-native';
import AlertCircle from 'reicon-react-native/icons/AlertCircle';
import ArrowRight from 'reicon-react-native/icons/ArrowRight';
import AttachCircle2 from 'reicon-react-native/icons/AttachCircle2';
import Bookmark from 'reicon-react-native/icons/Bookmark';
import Chat from 'reicon-react-native/icons/Chat';
import Check from 'reicon-react-native/icons/Check';
import CheckCircle from 'reicon-react-native/icons/CheckCircle';
import ChevronDown from 'reicon-react-native/icons/ChevronDown';
import ChevronLeft from 'reicon-react-native/icons/ChevronLeft';
import ChevronRight from 'reicon-react-native/icons/ChevronRight';
import ChevronUp from 'reicon-react-native/icons/ChevronUp';
import Edit2 from 'reicon-react-native/icons/Edit2';
import File from 'reicon-react-native/icons/File';
import FileText from 'reicon-react-native/icons/FileText';
import Fingerprint from 'reicon-react-native/icons/Fingerprint';
import Folder from 'reicon-react-native/icons/Folder';
import Home from 'reicon-react-native/icons/Home';
import Image from 'reicon-react-native/icons/Image';
import Microphone from 'reicon-react-native/icons/Microphone';
import MoreH from 'reicon-react-native/icons/MoreH';
import Pause from 'reicon-react-native/icons/Pause';
import Play from 'reicon-react-native/icons/Play';
import Plus from 'reicon-react-native/icons/Plus';
import Pulse from 'reicon-react-native/icons/Pulse';
import Refresh from 'reicon-react-native/icons/Refresh';
import Search from 'reicon-react-native/icons/Search';
import Settings from 'reicon-react-native/icons/Settings';
import Share from 'reicon-react-native/icons/Share';
import Sparkles from 'reicon-react-native/icons/Sparkles';
import Trash from 'reicon-react-native/icons/Trash';
import Warning22 from 'reicon-react-native/icons/Warning22';
import X from 'reicon-react-native/icons/X';

/**
 * The app's semantic icon vocabulary.  Keeping Ionicons-style names here makes
 * the Reicon migration incremental while all rendering comes from one library.
 */
const icons = {
  add: Plus,
  'alert-circle': AlertCircle,
  'arrow-forward': ArrowRight,
  'attach-outline': AttachCircle2,
  'bookmark-outline': Bookmark,
  'chatbubble-outline': Chat,
  checkmark: Check,
  'checkmark-circle': CheckCircle,
  'chevron-back': ChevronLeft,
  'chevron-down': ChevronDown,
  'chevron-forward': ChevronRight,
  'chevron-up': ChevronUp,
  close: X,
  'create-outline': Edit2,
  'document-outline': FileText,
  'ellipsis-horizontal': MoreH,
  'file-tray-outline': File,
  folder: Folder,
  home: Home,
  'image-outline': Image,
  'logo-apple': Fingerprint,
  'mic-outline': Microphone,
  pause: Pause,
  play: Play,
  'pulse-outline': Pulse,
  refresh: Refresh,
  'search-outline': Search,
  settings: Settings,
  'settings-outline': Settings,
  'share-outline': Share,
  sparkles: Sparkles,
  'sync-outline': Refresh,
  'trash-outline': Trash,
  'warning-outline': Warning22,
} as const;

export type AppIconName = keyof typeof icons;

type AppIconProps = IconProps & {
  name: AppIconName;
};

export function AppIcon({ name, weight = 'Outline', ...props }: AppIconProps) {
  const Icon: IconComponent = icons[name];
  return <Icon {...props} weight={weight} />;
}
