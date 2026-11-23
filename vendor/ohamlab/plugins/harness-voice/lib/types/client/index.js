
// Main plugin entry point for harness-voice
// This is auto-loaded by the DSH harness framework

export { installVoiceControls } from './client.js';

// Default export for framework compatibility
const plugin = {
  name: '@ohamlab/harness-voice',
  version: '0.1.0',
  install: function(app, options) {
    // Called by DSH harness when plugin is loaded
    if (typeof window !== 'undefined') {
      installVoiceControls();
    }
  }
};

export default plugin;
