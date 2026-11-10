import { copyFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const diagrams = join(dirname(fileURLToPath(import.meta.url)), '..', 'Chapter 3 Diagrams');
const archive = join(diagrams, '_Archive', 'Previous ERD Versions');
copyFileSync(join(archive, '05-gym-erd-public-only.svg'), join(diagrams, '05-gym-erd-editable.svg'));
copyFileSync(join(archive, '05-gym-erd-public-only.drawio'), join(diagrams, '05-gym-erd-editable.drawio'));
const preview = '<!doctype html><meta charset="utf-8"><style>html,body{margin:0;background:#e8edf3}img{display:block;width:1400px;height:auto;margin:20px auto;background:#fff;box-shadow:0 2px 12px #68778b55}</style><img src="../05-gym-erd-editable.svg" alt="Public schema ERD with 12 tables">';
writeFileSync(join(diagrams, '_Sources', '05-gym-erd-public-preview.html'), preview, 'utf8');
console.log('Restored the 12-table public-schema ERD and editable Draw.io source. Private tables remain documented in separate figures.');
