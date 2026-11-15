// Actions on the Library list: Retry on a failed card, and a menu (right-click, or long-press on a touch screen)
// with Open, Retry, Change area, Export and Delete. On a touch screen a swipe left on a card deletes it.
// The menu is the shared popover (menu.js): a dropdown on desktop, a bottom sheet on a phone (app.css).

import { $, esc } from './dom.js';
import { api } from './api.js';
import { state } from './state.js';
import { refresh } from './lists.js';
import { open, process } from './recordings.js';
import { showToday } from './today.js';
import { openMenu, closeMenu } from './menu.js';
import { deleteWithUndo } from './undo.js';
import { haptic } from './haptic.js';
import { AREAS } from './scope.js';

const STUCK = ['error', 'processing', 'transcribed'];
const find = (id) => state.recordings.find((r) => r.id === id);

export async function retry(id) {
  const r = await api('/recordings/' + id);
  state.current = id;
  await process(r, { force: true });
  refresh();
}

export async function remove(id) {
  const r = find(id);
  deleteWithUndo({
    key: id, url: '/api/recordings/' + id, label: `Deleted ${r ? `“${r.title}”` : 'recording'}`,
    hide: () => { if (state.current === id) { state.current = null; showToday(); } refresh(); },
    restore: () => refresh(),
  });
  haptic('success');
  return true;
}

async function setArea(id, area) {
  await api(`/recordings/${id}/area`, { method: 'PATCH', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ area }) });
  await refresh();
}

const item = (act, label, extra = '') => `<button class="opt${extra}" data-act="${act}">${esc(label)}</button>`;

function menuFor(card) {
  const id = card.dataset.id;
  const r = find(id);
  if (!r) return;
  haptic('medium');
  const areas = AREAS.map(([k, l]) => `<button class="opt${r.area === k ? ' on' : ''}" data-act="area" data-area="${k}">${esc(l)}</button>`).join('');
  openMenu(card, `
    ${item('open', 'Open')}
    ${STUCK.includes(r.status) ? item('retry', r.status === 'error' ? 'Retry' : 'Retry processing') : ''}
    <div class="blurb">Move to area</div>${areas}${item('area', 'Let Attest decide', '')}
    <a class="opt" href="/api/export?id=${esc(id)}" download>Export .md</a>
    <a class="opt" href="/api/export?id=${esc(id)}&format=docx" download>Export .docx</a>
    ${item('delete', 'Delete…', ' danger-opt')}`, {
    label: 'Recording actions',
    onClick: async (e) => {
      const b = e.target.closest('[data-act]');
      if (!b) return;
      closeMenu();
      try {
        if (b.dataset.act === 'open') open(id);
        else if (b.dataset.act === 'retry') await retry(id);
        else if (b.dataset.act === 'area') await setArea(id, b.dataset.area || 'auto');
        else if (b.dataset.act === 'delete') await remove(id);
      } catch (err) { alert(err.message); }
    },
  });
}

export function wireLibrary() {
  const list = $('list');
  // Retry button on a failed card (the click must not also open the recording).
  list.addEventListener('click', async (e) => {
    const btn = e.target.closest('.card-retry');
    if (!btn) return;
    e.stopPropagation(); e.preventDefault();
    btn.disabled = true;
    try { await retry(btn.closest('.card').dataset.id); } catch (err) { alert(err.message); btn.disabled = false; }
  }, true);

  list.addEventListener('contextmenu', (e) => {
    const card = e.target.closest('.card');
    if (!card) return;
    e.preventDefault();
    menuFor(card);
  });

  // Touch: long-press for the menu, swipe left to delete.
  let t = null;
  const reset = (card) => { if (card) { card.style.transform = ''; card.style.background = ''; } };
  list.addEventListener('touchstart', (e) => {
    const card = e.target.closest('.card');
    if (!card || e.touches.length !== 1) return;
    t = { card, x: e.touches[0].clientX, y: e.touches[0].clientY, dx: 0, swiping: false, pressed: false };
    t.timer = setTimeout(() => { if (t && !t.swiping) { t.pressed = true; menuFor(card); } }, 550);
  }, { passive: true });
  list.addEventListener('touchmove', (e) => {
    if (!t) return;
    const dx = e.touches[0].clientX - t.x, dy = e.touches[0].clientY - t.y;
    if (!t.swiping && (Math.abs(dy) > 12 || (Math.abs(dx) < 12))) { if (Math.abs(dy) > 12) { clearTimeout(t.timer); t = null; } return; }
    if (dx < 0) {
      t.swiping = true; t.dx = dx; clearTimeout(t.timer);
      t.card.style.transform = `translateX(${Math.max(dx, -140)}px)`;
      t.card.style.background = dx < -90 ? 'rgba(239,68,68,.25)' : '';
    }
  }, { passive: true });
  const end = async () => {
    if (!t) return;
    const { card, dx, swiping, pressed } = t;
    clearTimeout(t.timer); t = null;
    if (swiping) {
      list.dataset.swiped = '1'; setTimeout(() => delete list.dataset.swiped, 300); // swallow the click that follows a swipe
      const go = dx < -90;
      reset(card);
      if (go) { try { await remove(card.dataset.id); } catch (err) { alert(err.message); } }
    } else if (pressed) { list.dataset.swiped = '1'; setTimeout(() => delete list.dataset.swiped, 300); }
  };
  list.addEventListener('touchend', end);
  list.addEventListener('touchcancel', () => { if (t) { reset(t.card); clearTimeout(t.timer); t = null; } });
  // Capture: runs before the open-on-click handler in main.js.
  list.addEventListener('click', (e) => { if (list.dataset.swiped) { e.stopPropagation(); e.preventDefault(); } }, true);
}
