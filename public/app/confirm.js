// A bottom-sheet confirmation in place of the browser's confirm(): a short title, the detail underneath, and a
// button that names the action (red when it destroys something). On the phone layout every <dialog> is already
// a bottom sheet (app.css); on desktop it is a centred dialog. Resolves true on confirm, false on anything else.

import { esc } from './dom.js';
import { haptic } from './haptic.js';

export function confirmSheet({ title, message = '', confirmLabel = 'Continue', destructive = false }) {
  return new Promise((resolve) => {
    const dlg = document.createElement('dialog');
    dlg.className = 'confirm-sheet';
    dlg.setAttribute('aria-labelledby', 'cs-title');
    dlg.innerHTML = `
      <div class="cs-body">
        <h2 id="cs-title">${esc(title)}</h2>
        ${message ? `<p>${esc(message)}</p>` : ''}
        <div class="cs-actions">
          <button type="button" class="${destructive ? 'danger' : 'primary'}" data-ok>${esc(confirmLabel)}</button>
          <button type="button" data-cancel>Cancel</button>
        </div>
      </div>`;
    let answer = false;
    dlg.addEventListener('click', (e) => {
      if (e.target.closest('[data-ok]')) { answer = true; dlg.close(); }
      else if (e.target.closest('[data-cancel]') || e.target === dlg) dlg.close(); // tap on the backdrop
    });
    dlg.addEventListener('close', () => { dlg.remove(); resolve(answer); });
    document.body.appendChild(dlg);
    dlg.showModal();
    if (destructive) haptic('warning');
    dlg.querySelector('[data-cancel]').focus(); // the safe choice is the default
  });
}
