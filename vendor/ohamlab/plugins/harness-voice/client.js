
/**
 * OhamLab Voice — browser-only voice integration.
 *
 * Features:
 * - Microphone icon next to skill picker
 * - Floating microphone fallback
 * - Speech recognition
 * - Text-to-speech
 * - Send predefined message
 * - Auto-read agent replies
 * - ES module compatibility with DSH Harness
 */

const ROOT_ID = 'ohamlab-harness-voice';
const BUTTON_ID = 'ohamlab-voice-button';

const SpeechRecognition =
  typeof window !== 'undefined'
    ? window.SpeechRecognition ||
      window.webkitSpeechRecognition
    : null;

let activeCleanup = null;

// ============================================================
// CHAT COMPOSER
// ============================================================

function findComposer() {
  const candidates = [
    ...document.querySelectorAll(
      'textarea, [contenteditable="true"], input[type="text"]'
    )
  ].filter(el => {
    const rect = el.getBoundingClientRect();
    return rect.width > 180 && rect.height > 0;
  });

  return candidates.at(-1) || null;
}

function setComposerText(el, text) {
  if (!el) return false;

  el.focus();

  if (el.isContentEditable) {
    el.textContent = text;

    el.dispatchEvent(
      new InputEvent('input', {
        bubbles: true,
        inputType: 'insertText',
        data: text
      })
    );
  } else {
    const proto =
      el.tagName === 'TEXTAREA'
        ? HTMLTextAreaElement.prototype
        : HTMLInputElement.prototype;

    const setter = Object.getOwnPropertyDescriptor(
      proto,
      'value'
    )?.set;

    setter?.call(el, text);

    el.dispatchEvent(
      new Event('input', { bubbles: true })
    );

    el.dispatchEvent(
      new Event('change', { bubbles: true })
    );
  }

  return true;
}

// ============================================================
// SEND PREDEFINED MESSAGE
// ============================================================

function sendPredefinedMessage(message) {
  const composer = findComposer();

  if (!composer) return false;

  setComposerText(composer, message);

  composer.dispatchEvent(
    new KeyboardEvent('keydown', {
      key: 'Enter',
      code: 'Enter',
      bubbles: true,
      cancelable: true
    })
  );

  return true;
}

// ============================================================
// FIND LATEST AGENT REPLY
// ============================================================

function getLatestAgentText() {
  const selectors = [
    '[data-role="assistant"]',
    '[data-message-role="assistant"]',
    '[data-testid*="assistant"]',
    '.assistant-message'
  ];

  for (const selector of selectors) {
    const items = [
      ...document.querySelectorAll(selector)
    ];

    if (items.length) {
      return items.at(-1).innerText?.trim() || '';
    }
  }

  return '';
}

// ============================================================
// MAIN VOICE PLUGIN
// IMPORTANT: Named ES module export required by index.js
// ============================================================

export function installVoiceControls() {
  // Safe when imported by the Node.js server.
  if (
    typeof window === 'undefined' ||
    typeof document === 'undefined'
  ) {
    return () => {};
  }

  // Prevent duplicate initialization.
  if (activeCleanup) {
    return activeCleanup;
  }

  let recognition = null;
  let closed = false;
  let pending = null;
  let lastSpoken = '';
  let lastSeen = '';

  let root = null;
  let audioButton = null;
  let observer = null;
  let mountObserver = null;

  // ==========================================================
  // STATUS
  // ==========================================================

  function status(message) {
    const el = root?.querySelector(
      '[data-action="status"]'
    );

    if (el && el.textContent !== message) {
      el.textContent = message;
    }
  }

  function getLanguage() {
    return (
      root?.querySelector(
        '[data-action="language"]'
      )?.value || 'hi-IN'
    );
  }

  // ==========================================================
  // TEXT TO SPEECH
  // ==========================================================

  function speak(text) {
    if (!('speechSynthesis' in window)) {
      return status(
        'Speech synthesis unavailable'
      );
    }

    if (!text) {
      return status(
        'Cannot find an agent reply'
      );
    }

    window.speechSynthesis.cancel();

    const utterance =
      new SpeechSynthesisUtterance(
        text.slice(0, 4000)
      );

    utterance.lang = getLanguage();
    utterance.rate = 1;

    utterance.onerror = () => {
      status('Speech playback failed');
    };

    utterance.onend = () => {
      status('Playback finished');
    };

    lastSpoken = text;

    window.speechSynthesis.speak(utterance);

    status('Speaking agent reply');
  }

  // ==========================================================
  // STOP AUDIO
  // ==========================================================

  function stop() {
    try {
      recognition?.stop();
    } catch (_) {}

    window.speechSynthesis?.cancel();

    status('Stopped');
  }

  // ==========================================================
  // SPEECH RECOGNITION
  // ==========================================================

  function startRecognition() {
    if (!SpeechRecognition) {
      return status(
        'Speech recognition unsupported. Try Chrome or Edge.'
      );
    }

    recognition?.abort();

    recognition = new SpeechRecognition();

    recognition.lang = getLanguage();
    recognition.continuous = false;
    recognition.interimResults = false;

    recognition.onresult = event => {
      const transcript = [
        ...event.results
      ]
        .map(r => r[0]?.transcript || '')
        .join(' ')
        .trim();

      const composer = findComposer();

      if (!setComposerText(composer, transcript)) {
        return status('Chat composer not found');
      }

      status(
        'Transcribed into composer — review and press Send'
      );
    };

    recognition.onerror = event => {
      status(`Microphone error: ${event.error}`);
    };

    recognition.onstart = () => {
      status('Listening…');
    };

    try {
      recognition.start();
    } catch (error) {
      status(error.message);
    }
  }

  // ==========================================================
  // CREATE VOICE PANEL
  // ==========================================================

  function createVoicePanel() {
    if (root) return root;

    root = document.createElement('section');

    root.id = ROOT_ID;

    root.setAttribute(
      'aria-label',
      'OhamLab Voice controls'
    );

    root.style.cssText = `
      position: fixed;
      bottom: 20px;
      right: 20px;
      z-index: 2147483000;
      background: #ffffff;
      color: #111827;
      border: 1px solid #d1d5db;
      border-radius: 16px;
      padding: 12px;
      box-shadow: 0 8px 28px #0003;
      max-width: 300px;
      font: 14px system-ui;
      display: none;
    `;

    root.innerHTML = `
      <div style="
        display:flex;
        align-items:center;
        justify-content:space-between;
        gap:10px;
        margin-bottom:9px
      ">
        <strong>🎙 OhamLab Voice</strong>

        <button
          type="button"
          data-action="close"
          aria-label="Close voice controls"
        >×</button>
      </div>

      <div style="
        display:flex;
        gap:7px;
        flex-wrap:wrap
      ">
        <button
          type="button"
          data-action="send-how-are-you"
        >💬 How Are You</button>

        <button
          type="button"
          data-action="record"
        >🎤 Speak</button>

        <button
          type="button"
          data-action="stop"
        >■ Stop</button>

        <button
          type="button"
          data-action="read"
        >🔊 Read reply</button>
      </div>

      <label style="
        display:block;
        margin-top:9px
      ">
        Recognition language

        <select data-action="language">
          <option value="hi-IN">Hindi</option>
          <option value="en-US">English</option>
          <option value="te-IN">Telugu</option>
          <option value="ta-IN">Tamil</option>
        </select>
      </label>

      <label style="
        display:block;
        margin-top:8px
      ">
        <input
          type="checkbox"
          data-action="auto-read"
        >
        Auto-read new agent replies
      </label>

      <p
        data-action="status"
        role="status"
        style="
          margin:9px 0 0;
          font-size:12px;
          color:#4b5563
        "
      >Ready</p>
    `;

    for (const button of root.querySelectorAll('button')) {
      button.style.cssText = `
        border: 1px solid #cbd5e1;
        border-radius: 8px;
        padding: 6px 9px;
        background: #f8fafc;
        color: #111827;
        cursor: pointer;
      `;
    }

    root.addEventListener('click', event => {
      const action = event.target
        .closest('[data-action]')
        ?.dataset.action;

      switch (action) {
        case 'close':
          root.style.display = 'none';
          audioButton?.setAttribute(
            'aria-expanded',
            'false'
          );
          stop();
          break;

        case 'stop':
          stop();
          break;

        case 'read':
          speak(getLatestAgentText());
          break;

        case 'record':
          startRecognition();
          break;

        case 'send-how-are-you':
          if (
            sendPredefinedMessage('how are you')
          ) {
            status('Message submitted to composer');
          } else {
            status('Chat composer not found');
          }
          break;
      }
    });

    document.body.append(root);

    return root;
  }

  // ==========================================================
  // TOGGLE VOICE PANEL
  // ==========================================================

  function toggleVoicePanel() {
    const panel = createVoicePanel();

    const visible =
      panel.style.display !== 'none';

    panel.style.display =
      visible ? 'none' : 'block';

    audioButton?.setAttribute(
      'aria-expanded',
      String(!visible)
    );
  }

  // ==========================================================
  // CREATE MICROPHONE ICON
  // ==========================================================

  function createAudioButton() {
    if (audioButton) return audioButton;

    audioButton = document.createElement('button');

    audioButton.id = BUTTON_ID;
    audioButton.type = 'button';
    audioButton.title = 'OhamLab Voice';

    audioButton.setAttribute(
      'aria-label',
      'OhamLab Voice'
    );

    audioButton.setAttribute(
      'aria-expanded',
      'false'
    );

    audioButton.innerHTML = `
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="18"
        height="18"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.8"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <rect
          x="9"
          y="2"
          width="6"
          height="12"
          rx="3"
        />
        <path d="M5 10v2a7 7 0 0 0 14 0v-2"/>
        <path d="M12 19v3"/>
        <path d="M8 22h8"/>
      </svg>
    `;

    audioButton.addEventListener(
      'click',
      event => {
        event.preventDefault();
        event.stopPropagation();

        toggleVoicePanel();
      }
    );

    return audioButton;
  }

  // ==========================================================
  // PLACE ICON NEXT TO SKILL PICKER
  // ==========================================================

  function mountAudioButton() {
    if (closed || !document.body) return;

    const button = createAudioButton();

    const skillPicker = document.querySelector(
      '[data-dsh-skill-picker]'
    );

    if (skillPicker?.parentNode) {
      // Avoid unnecessary DOM changes.
      if (
        button.parentNode !== skillPicker.parentNode ||
        button.nextSibling !== skillPicker
      ) {
        // Insert microphone BEFORE the skill picker.
        skillPicker.parentNode.insertBefore(
          button,
          skillPicker
        );
      }

      button.style.cssText = `
        position: relative;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 32px;
        height: 32px;
        flex-shrink: 0;
        margin-right: 4px;
        padding: 4px;
        background: transparent;
        color: inherit;
        border: none;
        border-radius: 8px;
        cursor: pointer;
      `;

      return;
    }

    // Fallback when skill picker is not available.
    if (!button.isConnected) {
      document.body.append(button);
    }

    button.style.cssText = `
      position: fixed;
      bottom: 80px;
      right: 20px;
      z-index: 2147483000;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 40px;
      height: 40px;
      border: none;
      border-radius: 50%;
      background: #2563eb;
      color: white;
      cursor: pointer;
      box-shadow: 0 4px 12px #0003;
    `;
  }

  // ==========================================================
  // OBSERVE AGENT REPLIES
  // ==========================================================

  function observeReplies() {
    observer = new MutationObserver(() => {
      if (closed || !root) return;

      const autoRead = root.querySelector(
        '[data-action="auto-read"]'
      );

      if (!autoRead?.checked) return;

      const text = getLatestAgentText();

      if (!text || text === lastSeen) return;

      lastSeen = text;

      clearTimeout(pending);

      pending = setTimeout(() => {
        if (closed || !autoRead.checked) return;

        const current = getLatestAgentText();

        if (
          current === text &&
          current !== lastSpoken
        ) {
          speak(current);
        }
      }, 1800);
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true,
      characterData: true
    });
  }

  // ==========================================================
  // INITIALIZE
  // ==========================================================

  function mount() {
    if (closed || !document.body) return;

    createVoicePanel();
    mountAudioButton();
    observeReplies();

    // Handle Harness SPA navigation and UI re-rendering.
    mountObserver = new MutationObserver(() => {
      const skillPicker = document.querySelector(
        '[data-dsh-skill-picker]'
      );

      if (
        !audioButton?.isConnected ||
        (
          skillPicker?.parentNode &&
          (
            audioButton.parentNode !== skillPicker.parentNode ||
            audioButton.nextSibling !== skillPicker
          )
        ) ||
        (
          !skillPicker &&
          audioButton?.parentNode !== document.body
        )
      ) {
        if (!skillPicker && audioButton) {
          document.body.append(audioButton);
        }

        mountAudioButton();
      }
    });

    mountObserver.observe(document.body, {
      childList: true,
      subtree: true
    });

    console.info(
      '[OHAMLAB VOICE] Voice controls initialized'
    );
  }

  // ==========================================================
  // CLEANUP
  // ==========================================================

  function cleanup() {
    if (closed) return;

    closed = true;

    clearTimeout(pending);

    document.removeEventListener(
      'DOMContentLoaded',
      mount
    );

    observer?.disconnect();
    mountObserver?.disconnect();

    try {
      recognition?.abort();
    } catch (_) {}

    window.speechSynthesis?.cancel();

    root?.remove();
    audioButton?.remove();

    activeCleanup = null;

    console.info(
      '[OHAMLAB VOICE] Voice controls removed'
    );
  }

  activeCleanup = cleanup;

  if (document.readyState === 'loading') {
    document.addEventListener(
      'DOMContentLoaded',
      mount,
      { once: true }
    );
  } else {
    mount();
  }

  return cleanup;
}

// ============================================================
// AUTO-MOUNT IN BROWSER ONLY
// ============================================================

if (
  typeof window !== 'undefined' &&
  typeof document !== 'undefined'
) {
  installVoiceControls();
}
