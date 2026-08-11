import { Redirect } from 'expo-router';

/**
 * The native capture tab prevents selection and opens CaptureSheet instead.
 * Redirect defensively if JavaScript navigation targets this route directly.
 */
export default function CaptureRoute() {
  return <Redirect href="/" />;
}
