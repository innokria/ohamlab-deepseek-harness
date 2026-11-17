import { build } from 'esbuild';
import { mkdirSync, writeFileSync } from 'node:fs';
mkdirSync('lib/types/client', { recursive: true });
await build({entryPoints:['src/index.js'],outfile:'lib/index.js',bundle:true,platform:'node',format:'esm',target:'es2022'});
await build({entryPoints:['src/client.js'],outfile:'lib/client.js',bundle:true,platform:'browser',format:'esm',target:'es2022'});
writeFileSync('lib/types/index.d.ts','export declare const name: string;\n');
writeFileSync('lib/types/client/index.d.ts','export declare function installVoiceControls(): () => void;\n');
console.log('Built @ohamlab/harness-voice');
