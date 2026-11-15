// A small status message with an optional action ("Done · Undo"). One at a time; a new one replaces the old.
// Bottom-centre on desktop, above the tab bar on a phone (app.css). Announced to screen readers.

import { esc } from './dom.js';

let timer = null;

export function toast(message, { action, onAction, ms = 5000 } = {}) {
  document.getElementById('toast')?.remove();
  clearTimeout(timer);
  const el = document.createElement('div');
  el.id = 'toast';
  el.className = 'toast';
  el.setAttribute('role', 'status');
  el.innerHTML = `<span>${esc(message)}</span>${action ? `<button type="button" class="small">${esc(action)}</button>` : ''}`;
  const hide = () => { clearTimeout(timer); el.remove(); };
  el.querySelector('button')?.addEventListener('click', () => { hide(); onAction?.(); });
  document.body.appendChild(el);
  timer = setTimeout(hide, ms);
  return hide;
}
