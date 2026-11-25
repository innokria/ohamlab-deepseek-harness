import { installVoiceControls } from './client.js';

export { installVoiceControls };

const plugin = {
  name: '@ohamlab/harness-voice',
  version: '0.1.0',

  install(app, options) {
    if (typeof window !== 'undefined') {
      return installVoiceControls();
    }
  }
};

export default plugin;
