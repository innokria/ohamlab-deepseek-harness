// Type declarations for @ohamlab/harness-voice
declare module '@ohamlab/harness-voice' {
  export function installVoiceControls(): () => void;
  export { installVoiceControls };
}

// Client API types
declare global {
  interface Window {
    __dshVoiceInstalled?: boolean;
  }
}
