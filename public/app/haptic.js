// Haptic feedback. WKWebView ignores navigator.vibrate, so inside the Attest iPhone app the page asks the
// native shell (apple/App/Shared/WebView.swift) to play one. In a plain browser, or the Mac app, nothing happens.
// Styles: light, medium, heavy, selection, success, warning, error.

export const STYLES = ['light', 'medium', 'heavy', 'selection', 'success', 'warning', 'error'];

const bridge = () => (typeof window !== 'undefined' ? window.webkit?.messageHandlers?.attest : null);

export function haptic(style = 'light') {
  if (!STYLES.includes(style)) return false;
  const b = bridge();
  if (!b) return false;
  try { b.postMessage({ action: 'haptic', style }); return true; } catch { return false; }
}
