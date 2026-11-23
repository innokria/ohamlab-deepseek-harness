/**
 * OhamLab Voice — browser-only MVP with Send "how are you" button.
 * Uses Web Speech APIs; does not transmit microphone audio to VoiceStudio.
 * Designed to be mounted by a Harness client entrypoint.
 */
const ROOT_ID = 'ohamlab-harness-voice';
const SpeechRecognition = typeof window !== 'undefined' && (window.SpeechRecognition || window.webkitSpeechRecognition);

function findComposer() {
  const candidates = [...document.querySelectorAll('textarea, [contenteditable="true"], input[type="text"]')]
    .filter(el => el.getBoundingClientRect().width > 180 && el.getBoundingClientRect().height > 0);
  return candidates.at(-1) || null;
}
function setComposerText(el, text) {
  if (!el) return false;
  el.focus();
  if (el.isContentEditable) {
    el.textContent = text;
    el.dispatchEvent(new InputEvent('input', {bubbles:true, inputType:'insertText', data:text}));
  } else {
    const proto = el.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
    const setter = Object.getOwnPropertyDescriptor(proto, 'value')?.set;
    setter?.call(el, text);
    el.dispatchEvent(new Event('input', {bubbles:true}));
    el.dispatchEvent(new Event('change', {bubbles:true}));
  }
  return true;
}

/**
 * NEW: Function to send a pre-defined message to the harness
 */
function sendPredefinedMessage(message) {
  const composer = findComposer();
  if (!composer) return false;
  setComposerText(composer, message);
  // Dispatch event to trigger send/enter key
  const event = new KeyboardEvent('keydown', { key: 'Enter', bubbles: true });
  composer.dispatchEvent(event);
  return true;
}

export function installVoiceControls() {
  if (typeof document === 'undefined') return () => {};
  if (document.getElementById(ROOT_ID)) return () => {};
  const root = document.createElement('section');
  root.id = ROOT_ID;
  root.setAttribute('aria-label','OhamLab Voice controls');
  root.style.cssText = 'position:fixed;bottom:20px;right:20px;z-index:2147483000;background:#fff;color:#111827;border:1px solid #d1d5db;border-radius:16px;padding:12px;box-shadow:0 8px 28px #0003;max-width:300px;font:14px system-ui';
  root.innerHTML = `<div style="display:flex;align-items:center;justify-content:space-between;gap:10px;margin-bottom:9px"><strong>🎙 OhamLab Voice</strong><button type="button" data-action="close" aria-label="Close voice controls">×</button></div>
<div style="display:flex;gap:7px;flex-wrap:wrap">
  <button type="button" data-action="send-how-are-you">💬 How Are You</button>
  <button type="button" data-action="record">🎤 Speak</button>
  <button type="button" data-action="stop">■ Stop</button>
  <button type="button" data-action="read">🔊 Read reply</button>
</div>
<label style="display:block;margin-top:9px">Recognition language <select data-action="language"><option value="hi-IN">Hindi</option><option value="en-US">English</option><option value="te-IN">Telugu</option><option value="ta-IN">Tamil</option></select></label>
<label style="display:block;margin-top:8px"><input type="checkbox" data-action="auto-read"> Auto-read new agent replies (experimental)</label>
<p data-action="status" role="status" style="margin:9px 0 0;font-size:12px;color:#4b5563">Ready</p>`;
  for (const b of root.querySelectorAll('button')) b.style.cssText = 'border:1px solid #cbd5e1;border-radius:8px;padding:6px 9px;background:#f8fafc;color:#111827;cursor:pointer';
  const status = msg => {root.querySelector('[data-action="status"]').textContent = msg;};
  const lang = root.querySelector('[data-action="language"]');
  let recognition, closed = false, lastSpoken = '', lastSeen = '';
  const speak = text => {
    if (!('speechSynthesis' in window)) return status('Speech synthesis unavailable in this browser');
    if (!text) return status('Cannot find an agent reply. Use a supported Harness message selector.');
    speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(text.slice(0, 4000));
    utterance.lang = lang.value;
    utterance.rate = 1;
    utterance.onerror = () => status('Speech playback failed');
    speechSynthesis.speak(utterance);
    lastSpoken = text;
    status('Speaking agent reply');
  };
  const stop = () => {recognition?.stop(); speechSynthesis?.cancel(); status('Stopped');};
  const onClick = e => {
    const action = e.target.closest('[data-action]')?.dataset.action;
    if (action === 'close') cleanup();
    if (action === 'stop') stop();
    if (action === 'read') speak(getLatestAgentText());
    if (action === 'record') {
      if (!SpeechRecognition) return status('Speech recognition unsupported. Try Chrome or Edge.');
      recognition?.abort();
      recognition = new SpeechRecognition();
      recognition.lang = lang.value;
      recognition.continuous = false;
      recognition.interimResults = false;
      recognition.onresult = event => {
        const transcript = [...event.results].map(r => r[0]?.transcript || '').join(' ').trim();
        const composer = findComposer();
        if (!setComposerText(composer, transcript)) return status('Chat composer not found');
        status('Transcribed into composer — review and press Send');
      };
      recognition.onerror = event => status(`Microphone error: ${event.error}`);
      recognition.onstart = () => status('Listening…');
      try { recognition.start(); } catch (error) {status(error.message);}
    }
    if (action === 'send-how-are-you') {
      // Send the predefined "how are you" message
      if (sendPredefinedMessage('how are you')) {
        status('Sent: "how are you"');
      } else {
        status('Chat composer not found');
      }
    }
  };
  root.addEventListener('click', onClick);
  document.body.append(root);
  // Observe only to discover replies. A real Harness message-event integration is preferred.
  const observer = new MutationObserver(() => {
    if (closed || !root.querySelector('[data-action="auto-read"]').checked) return;
    const text = getLatestAgentText();
    if (text && text !== lastSeen) {
      lastSeen = text;
      clearTimeout(pending);
      pending = setTimeout(() => {
        const current = getLatestAgentText();
        if (current === text && current !== lastSpoken) speak(current);
      }, 1800);
    }
  });
  let pending;
  observer.observe(document.body, {childList:true, subtree:true, characterData:true});
  function cleanup() {closed=true; clearTimeout(pending); observer.disconnect(); stop(); root.remove();}
  return cleanup;
}
// Auto-mount only in browser contexts where this client bundle is loaded.
if (typeof document !== 'undefined') {
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', installVoiceControls, {once:true});
  else installVoiceControls();
}
