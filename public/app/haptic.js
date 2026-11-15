// Haptic feedback. WKWebView ignores navigator.vibrate, so inside the Attest iPhone app the page asks the
// native shell (apple/App/Shared/WebView.swift) to play one. In a plain browser, or the Mac app, nothing happens.
// Styles: light, medium, heavy, selection, success, warning, error.

export const STYLES = ['light', 'medium', 'heavy', 'selection', 'success', 'warning', 'error'];

const bridge = () => (typeof window !== 'undefined' ? window.webkit?.messageHandlers?.attest : null);

// Tells the app whether a recording is running, so its Action Button shortcut can map a second press to stop.
export function reportRecording(on) {
  const b = bridge();
  if (!b) return false;
  try { b.postMessage({ action: 'recording', on: Boolean(on) }); return true; } catch { return false; }
}

export function haptic(style = 'light') {
  if (!STYLES.includes(style)) return false;
  const b = bridge();
  if (!b) return false;
  try { b.postMessage({ action: 'haptic', style }); return true; } catch { return false; }
}
