// The one summarize prompt. `t` is a resolved {label, style, length} object —
// builtin TEMPLATES[key] or a custom_templates row, the caller does not matter here.

import { TEMPLATES } from './templates.js';
import { FACT_RULES } from './memory.js';
import { AREAS } from './areas.js';

const WEEKDAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

// "2026-11-14 (Saturday)": the anchor the model needs to turn "by Tuesday" into a date.
export function dateAnchor(ms) {
  if (!Number.isFinite(ms)) return '';
  const d = new Date(ms);
  return `${d.toISOString().slice(0, 10)} (${WEEKDAYS[d.getUTCDay()]})`;
}

// What counts as an action item, who owns it and when it is due. Kept apart from the JSON shape so
// the rules can be read (and tested) on their own.
export const ACTION_RULES = [
  'ACTION ITEMS are pending commitments or explicit reminders only, each one something a person must still DO.',
  '- task: start with an imperative verb (Send, Review, Schedule, Call, Draft, Pay, Book). Never a topic or summary like "Discussed billing". One short sentence, self-contained, naming the thing and the other party if there is one, so it makes sense on a list with no context.',
  '- owner: the speaker label or name of whoever must do it, exactly as labeled. Someone says "I\'ll send it" -> that speaker. "Can you send it?" answered yes -> the person asked. Use null only when truly nobody is named; do not drop the item.',
  '- due: an ISO date YYYY-MM-DD when the transcript gives a deadline or a relative one ("tomorrow", "by Tuesday", "next week" -> resolve against the recording date below; "next week" with no day means that week\'s Friday, "end of month" the last day). Otherwise null. Never invent a date nobody said.',
  '- when: the verbatim time phrase from the transcript ("by Tuesday afternoon", "before the client call"), or null. Fill it even when you could not resolve a due date.',
  '- tentative: true when the commitment is soft or conditional ("I\'ll try", "maybe I\'ll", "if there\'s time", "we should probably") or has no clear owner or deadline AND sounds optional; false for a firm promise or a direct request that was accepted.',
  '- evidence: a short verbatim quote from the transcript showing who committed to it.',
  'Do NOT include: casual musing or hypotheticals ("we could maybe look at..."), things already done ("I already sent that"), general discussion, or one item twice. Fewer, real items beat many vague ones. An empty list is correct when nothing was committed to.',
].join('\n');

export function buildSystemPrompt(t, recordedAt) {
  t = t || TEMPLATES.meeting;
  const anchor = dateAnchor(recordedAt);
  return [
    'You turn raw conversation transcripts into structured notes.',
    `Style: ${t.style}.`,
    t.label === 'Medical visit'
      ? 'You are a scribe only. Never diagnose, never recommend treatment.'
      : '',
    'Reply with ONLY a JSON object, no prose around it:',
    '{"summary":"<markdown, ' + (t.length || '150-300 words') + '>"',
    ' "action_items":[{"task":"...","owner":"..."|null,"due":"YYYY-MM-DD"|null,"when":"..."|null,"tentative":false,"evidence":"..."}],',
    ' "mindmaps":{"topic":"<markdown outline, subject-matter tree: one # root, then ## branches with nested - bullets>",',
    '  "driver":"<markdown outline, decisions/actions/owners tree: one # root, then ## branches with nested - bullets>",',
    '  "people":"<markdown outline, who-said-what/relationships tree: one # root, then ## branches with nested - bullets>"},',
    ' "area":"' + AREAS.join('|') + '",',
    ' "unanswered":["<a question someone asked that never got a clear answer>"],',
    ' "facts":[{"kind":"commitment|decision|preference|relationship|fact","person":"Name"|null,"text":"<one short sentence>","quote":"<verbatim from the transcript>"}]}',
    `area is which part of the speaker's life this is about: work (jobs, colleagues, clients, business), personal (family, friends, home, errands, hobbies, media), health (medical, therapy, fitness, nutrition, sleep), learning (lectures, courses, studying, research). Pick the best single one from the content, whatever the style above.`,
    ACTION_RULES,
    anchor ? `The conversation was recorded on ${anchor}. Resolve every relative date against it.` : '',
    FACT_RULES,
    'Speakers labeled "Unknown 1", "Unknown 2" etc. are unidentified. Refer to them by that exact label everywhere (summary, action item owners, outlines). Never give an Unknown speaker a name, even if a name is mentioned in the conversation; only a speaker whose label is already a name is named.',
    'Use "" or [] when a field genuinely has no content. Never invent facts or speakers.',
  ].filter(Boolean).join('\n');
}
