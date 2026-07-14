import {
  useFonts as useIBMPlexSansJP,
  IBMPlexSansJP_400Regular,
  IBMPlexSansJP_600SemiBold,
} from '@expo-google-fonts/ibm-plex-sans-jp';
import {
  useFonts as useMPLUS1p,
  MPLUS1p_400Regular,
  MPLUS1p_700Bold,
} from '@expo-google-fonts/m-plus-1p';
import {
  useFonts as useMurecho,
  Murecho_400Regular,
  Murecho_600SemiBold,
} from '@expo-google-fonts/murecho';
import {
  useFonts as useNotoSansJP,
  NotoSansJP_400Regular,
  NotoSansJP_600SemiBold,
} from '@expo-google-fonts/noto-sans-jp';
import {
  useFonts as useZenKakuGothicNew,
  ZenKakuGothicNew_400Regular,
  ZenKakuGothicNew_700Bold,
} from '@expo-google-fonts/zen-kaku-gothic-new';

export type DevFontKey = 'system' | 'notoSansJP' | 'zenKakuGothicNew' | 'mPlus1p' | 'ibmPlexSansJP' | 'murecho';

export type DevFontCandidate = {
  key: DevFontKey;
  label: string;
  regular?: string;
  semibold?: string;
};

export const DEV_FONT_CANDIDATES: DevFontCandidate[] = [
  { key: 'system', label: 'システム標準 (San Francisco / Hiragino)' },
  { key: 'notoSansJP', label: 'Noto Sans JP', regular: 'NotoSansJP_400Regular', semibold: 'NotoSansJP_600SemiBold' },
  { key: 'zenKakuGothicNew', label: 'Zen Kaku Gothic New', regular: 'ZenKakuGothicNew_400Regular', semibold: 'ZenKakuGothicNew_700Bold' },
  { key: 'mPlus1p', label: 'M PLUS 1p', regular: 'MPLUS1p_400Regular', semibold: 'MPLUS1p_700Bold' },
  { key: 'ibmPlexSansJP', label: 'IBM Plex Sans JP', regular: 'IBMPlexSansJP_400Regular', semibold: 'IBMPlexSansJP_600SemiBold' },
  { key: 'murecho', label: 'Murecho', regular: 'Murecho_400Regular', semibold: 'Murecho_600SemiBold' },
];

export function useDevFontsLoaded() {
  const [notoLoaded] = useNotoSansJP({ NotoSansJP_400Regular, NotoSansJP_600SemiBold });
  const [zenLoaded] = useZenKakuGothicNew({ ZenKakuGothicNew_400Regular, ZenKakuGothicNew_700Bold });
  const [mplusLoaded] = useMPLUS1p({ MPLUS1p_400Regular, MPLUS1p_700Bold });
  const [ibmLoaded] = useIBMPlexSansJP({ IBMPlexSansJP_400Regular, IBMPlexSansJP_600SemiBold });
  const [murechoLoaded] = useMurecho({ Murecho_400Regular, Murecho_600SemiBold });

  return notoLoaded && zenLoaded && mplusLoaded && ibmLoaded && murechoLoaded;
}
