window.__ModuleLoader__.load({
    id: '@ohamlab/harness-voice',

    factory: (require) => {
        const module = { exports: {} };

        const React = require('react');
        const h = React.createElement;

        const inject = ['slots'];

        // --------------------------------------------------
        // Microphone button
        // --------------------------------------------------

        function VoiceMicrophoneButton() {

            return h(
                'button',
                {
                    type: 'button',

                    title: 'OhamLab VoiceStudio (coming soon)',

                    'aria-label': 'OhamLab VoiceStudio microphone',

                    'data-ohamlab-voice': 'microphone',

                    disabled: true,

                    style: {
                        display: 'inline-flex',
                        alignItems: 'center',
                        justifyContent: 'center',

                        width: '34px',
                        height: '34px',

                        padding: 0,

                        border: 'none',
                        borderRadius: '8px',

                        background: 'transparent',

                        color: 'var(--dsh-text-secondary, currentColor)',

                        opacity: 0.65,

                        cursor: 'not-allowed'
                    }
                },

                h(
                    'svg',
                    {
                        width: 19,
                        height: 19,
                        viewBox: '0 0 24 24',
                        fill: 'none',
                        stroke: 'currentColor',
                        strokeWidth: 1.8,
                        strokeLinecap: 'round',
                        strokeLinejoin: 'round',
                        'aria-hidden': true
                    },

                    h('rect', {
                        x: 9,
                        y: 2,
                        width: 6,
                        height: 12,
                        rx: 3
                    }),

                    h('path', {
                        d: 'M5 10a7 7 0 0 0 14 0'
                    }),

                    h('path', {
                        d: 'M12 17v5'
                    }),

                    h('path', {
                        d: 'M8 22h8'
                    })
                )
            );
        }

        // --------------------------------------------------
        // Plugin registration
        // --------------------------------------------------

        function apply(ctx) {

            console.log('[OHAMLAB VOICE] Registering composer microphone');

            ctx.slots.inject(
                'conversation.input.right',

                () => ctx.slots.register(
                    {
                        name: 'conversation.input.right',

                        id: 'ohamlab-voice-microphone',

                        order: 50
                    },

                    VoiceMicrophoneButton
                )
            );
        }

        module.exports = {
            name: '@ohamlab/harness-voice',
            inject,
            apply
        };

        return module.exports;
    }
});
