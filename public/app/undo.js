// "Perform, then Undo" for deletes. The item disappears at once and a toast offers Undo; the real DELETE is
// sent only when the toast runs out (or the page is closed), so Undo is just "never send it".

import { toast } from './toast.js';
import { state } from './state.js';

const WAIT = 6000;
const pending = new Map(); // url -> { timer }

export const isPendingDelete = (id) => pending.has(String(id));

function send(key) {
  const p = pending.get(key);
  if (!p) return;
  clearTimeout(p.timer);
  pending.delete(key);
  fetch(p.url, { method: 'DELETE', keepalive: true }).catch(() => {});
}

// key: the item id (used to hide it from lists). hide/restore re-render the UI.
export function deleteWithUndo({ key, url, label, hide, restore }) {
  key = String(key);
  pending.set(key, { url, timer: setTimeout(() => send(key), WAIT) });
  hide();
  toast(label, {
    action: 'Undo', ms: WAIT,
    onAction: () => {
      const p = pending.get(key);
      if (p) { clearTimeout(p.timer); pending.delete(key); }
      restore();
    },
  });
}

if (typeof addEventListener === 'function') addEventListener('pagehide', () => [...pending.keys()].forEach(send));
