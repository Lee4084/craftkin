import {readFile,writeFile} from 'node:fs/promises';
const root=new URL('./',import.meta.url);
const adapter=(await readFile(new URL('legacy.mjs',root),'utf8')).replaceAll('export async function','async function').replaceAll('export function','function');
const worker=(await readFile(new URL('worker.mjs',root),'utf8')).replace("import {legacyStartup} from './legacy.mjs';\n",'').replace('export function decideActivity','function decideActivity');
await writeFile(new URL('deploy.mjs',root),adapter+'\n'+worker);
