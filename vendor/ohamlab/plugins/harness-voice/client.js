/**
 * OhamLab Voice — with audio icon next to skill picker.
 * Places a 🎙 voice button next to the skill picker in the UI.
 * Uses Web Speech APIs; does not transmit microphone audio to VoiceStudio.
 * Integrates with DSH skill-picker and conversation input framework.
 */

// Skill picker integration: the skill picker injects into "conversation.input.right" slot
// and has [data-dsh-skill-picker] marker in the DOM.

/**
 * Function to add audio button next to skill picker
 * This integrates with the existing DSH UI framework
 */
function addAudioButtonNextToSkillPicker() {
  // Wait for the skill picker to be ready
  const checkInterval = setInterval(() => {
    // Look for the skill picker container
    const skillPicker = document.querySelector('[data-dsh-skill-picker]');
    if (skillPicker) {
      // Create audio button
      const audioBtn = document.createElement('button');
      audioBtn.type = 'button';
      audioBtn.className = 'dsh-skill-picker__voice-btn';
      audioBtn.innerHTML = '🎙';
      audioBtn.title = 'OhamLab Voice';
      audioBtn.style.cssText = `
        position: relative;
        float: right;
        margin-left: 8px;
        padding: 6px 10px;
        background: #f8fafc;
        border: 1px solid #cbd5e1;
        border-radius: 6px;
        color: #111827;
        cursor: pointer;
        font-size: 16px;
        line-height: 1;
        transition: background 0.2s;
        z-index: 2147483000;
      `;
      audioBtn.onclick = function(e) {
        e.stopPropagation();
        // Toggle voice controls visibility
        const voicePanel = document.getElementById('ohamlab-harness-voice');
        if (voicePanel) {
          // Already exists - hide it
          voicePanel.style.display = 'none';
        } else {
          // Create and show voice controls
          showVoiceControls();
        }
      };
      
      // Insert after the skill picker element
      skillPicker.parentNode.insertBefore(audioBtn, skillPicker.nextSibling);
      
      // Also ensure our voice controls are at bottom-right as fallback
      createFallbackVoiceControls();
      
      clearInterval(checkInterval);
    }
  }, 200);
  
  // Stop checking after 10 seconds
  setTimeout(() => clearInterval(checkInterval), 10000);
}

/**
 * Show the voice controls panel
 */
function showVoiceControls() {
  const root = document.createElement('section');
  root.id = 'ohamlab-harness-voice';
  root.setAttribute('aria-label', 'OhamLab Voice controls');
  root.style.cssText = `
    position: fixed;
    bottom: 20px;
    right: 20px;
    z-index: 2147483000;
    background: #fff;
    color: #111827;
    border: 1px solid #d1d5db;
    border-radius: 16px;
    padding: 12px;
    box-shadow: 0 8px 28px #0003;
    max-width: 300px;
    font: 14px system-ui;
    display: block;
  `;
  root.innerHTML = `
    <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 9px;">
      <strong>🎙 OhamLab Voice</strong>
      <button type="button" data-action="close" aria-label="Close voice controls">×</button>
    </div>
    <div style="display: flex; gap: 7px; flex-wrap: wrap;">
      <button type="button" data-action="send-how-are-you">💬 How Are You</button>
      <button type="button" data-action="record">🎤 Speak</button>
      <button type="button" data-action="stop">■ Stop</button>
      <button type="button" data-action="read">🔊 Read reply</button>
    </div>
    <label style="display: block; margin-top: 9px;">
      Recognition language 
      <select data-action="language">
        <option value="hi-IN">Hindi</option>
        <option value="en-US">English</option>
        <option value="te-IN">Telugu</option>
        <option value="ta-IN">Tamil</option>
      </select>
    </label>
    <label style="display: block; margin-top: 8px;">
      <input type="checkbox" data-action="auto-read"> Auto-read new agent replies (experimental)
    </label>
    <p data-action="status" role="status" style="margin: 9px 0 0; font-size: 12px; color: #4b5563">Ready</p>
  `;
  
  document.body.append(root);
  
  // Initialize event listeners (reuse the existing logic)
  initVoiceControls(root);
}

/**
 * Initialize voice controls event listeners
 */
function initVoiceControls(root) {
  const status = msg => {
    root.querySelector('[data-action="status"]').textContent = msg;
  };
  const lang = root.querySelector('[data-action="language"]');
  let recognition, closed = false, lastSpoken = '', lastSeen = '';
  
  const speak = text => {
    if (!('speechSynthesis' in window)) return status('Speech synthesis unavailable');
    if (!text) return status('Cannot find an agent reply');
    speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(text.slice(0, 4000));
    utterance.lang = lang.value;
    utterance.rate = 1;
    utterance.onerror = () => status('Speech playback failed');
    speechSynthesis.speak(utterance);
    lastSpoken = text;
    status('Speaking agent reply');
  };
  
  const stop = () => {
    recognition?.stop();
    speechSynthesis?.cancel();
    status('Stopped');
  };
  
  const getLatestAgentText = () => {
    const selectors = [
      '[data-role="assistant"]',
      '[data-message-role="assistant"]',
      '[data-testid*="assistant"]',
      '.assistant-message'
    ];
    for (const selector of selectors) {
      const items = [...document.querySelectorAll(selector)];
      if (items.length) return items.at(-1).innerText?.trim() || '';
    }
    return '';
  };
  
  const onClick = e => {
    const action = e.target.closest('[data-action]')?.dataset.action;
    if (action === 'close') {
      closed = true;
      root.remove();
    }
    if (action === 'stop') stop();
    if (action === 'read') speak(getLatestAgentText());
    if (action === 'record') {
      if (!('SpeechRecognition' in window)) return status('Speech recognition unsupported');
      recognition?.abort();
      recognition = new SpeechRecognition();
      recognition.lang = lang.value;
      recognition.continuous = false;
      recognition.interimResults = false;
      recognition.onresult = event => {
        const transcript = [...event.results].map(r => r[0]?.transcript || '').join(' ').trim();
        const composer = findComposer();
        if (transcript && composer) {
          setComposerText(composer, transcript);
          status('Transcribed into composer — review and press Send');
        }
      };
      recognition.onerror = event => status(`Microphone error: ${event.error}`);
      recognition.onstart = () => status('Listening…');
      try { recognition.start(); } catch (error) { status(error.message); }
    }
    if (action === 'send-how-are-you') {
      if (sendPredefinedMessage('how are you')) {
        status('Sent: "how are you"');
      } else {
        status('Chat composer not found');
      }
    }
  };
  
  root.addEventListener('click', onClick);
  
  // Auto observe for new replies
  const observer = new MutationObserver(() => {
    if (closed) return;
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
  observer.observe(document.body, { childList: true, subtree: true, characterData: true });
  
  function cleanup() {
    closed = true;
    clearTimeout(pending);
    observer.disconnect();
    stop();
    root.remove();
  }
  
  return cleanup;
}

/**
 * Find the chat composer element
 */
function findComposer() {
  const candidates = [...document.querySelectorAll('textarea, [contenteditable="true"], input[type="text"]')]
    .filter(el => el.getBoundingClientRect().width > 180 && el.getBoundingClientRect().height > 0);
  return candidates.at(-1) || null;
}

/**
 * Set text in the composer
 */
function setComposerText(el, text) {
  if (!el) return false;
  el.focus();
  if (el.isContentEditable) {
    el.textContent = text;
    el.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: text }));
  } else {
    const proto = el.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
    const setter = Object.getOwnPropertyDescriptor(proto, 'value')?.set;
    setter?.call(el, text);
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  }
  return true;
}

/**
 * Send a predefined message to the harness
 */
function sendPredefinedMessage(message) {
  const composer = findComposer();
  if (!composer) return false;
  setComposerText(composer, message);
  const event = new KeyboardEvent('keydown', { key: 'Enter', bubbles: true });
  composer.dispatchEvent(event);
  return true;
}

/**
 * Create fallback voice controls at bottom-right
 */
function createFallbackVoiceControls() {
  // Only create if not already exists
  const existing = document.getElementById('ohamlab-harness-voice');
  if (existing) return;
  
  // Create a small floating button
  const floatingBtn = document.createElement('button');
  floatingBtn.id = 'ohamlab-voice-float-btn';
  floatingBtn.innerHTML = '🎤';
  floatingBtn.title = 'OhamLab Voice';
  floatingBtn.style.cssText = `
    position: fixed;
    bottom: 80px;
    right: 20px;
    z-index: 2147483000;
    width: 40px;
    height: 40px;
    border: none;
    border-radius: 50%;
    background: #2563eb;
    color: white;
    font-size: 18px;
    cursor: pointer;
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    transition: background 0.2s;
  `;
  floatingBtn.onclick = function() {
    // Toggle the voice panel
    const panel = document.getElementById('ohamlab-harness-voice');
    if (panel) {
      panel.style.display = panel.style.display === 'none' ? 'block' : 'none';
    } else {
      showVoiceControls();
    }
  };
  
  floatingBtn.onmouseover = function() {
    this.style.background = '#1d4ed8';
  };
  floatingBtn.onmouseout = function() {
    this.style.background = '#2563eb';
  };
  
  document.body.append(floatingBtn);
  
  // Position near the skill picker if visible
  setTimeout(() => {
    const skillPicker = document.querySelector('[data-dsh-skill-picker]');
    if (skillPicker) {
      const rect = skillPicker.getBoundingClientRect();
      const floatingBtn = document.getElementById('ohamlab-voice-float-btn');
      if (floatingBtn) {
        floatingBtn.style.bottom = `${rect.bottom + 8}px`;
      }
    }
  }, 500);
}

/**
 * Main initialization - called when DOM is ready
 */
function initializeVoiceIntegration() {
  // First: add audio button next to skill picker
  addAudioButtonNextToSkillPicker();
  
  // Second: ensure fallback controls can be accessed
  // The floating button will appear at bottom-right
  
  // Also auto-mount the original voice controls for backward compatibility
  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => {
        installVoiceControls();
      }, {once: true});
    } else {
      installVoiceControls();
    }
  }
}

// Auto-execute when DOM is ready
if (typeof window !== 'undefined') {
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeVoiceIntegration, {once: true});
  } else {
    initializeVoiceIntegration();
  }
}

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { initializeVoiceIntegration, addAudioButtonNextToSkillPicker, showVoiceControls, installVoiceControls };
}