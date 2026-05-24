// scripts/check-i18n.ts
//
// Vérifie la parité des clés entre `src/lang/fr.ts` et `src/lang/en.ts`.
// La règle bilingue (CLAUDE.md) impose que *toute* chaîne affichée existe dans
// les deux langues — ce script empêche les régressions silencieuses où une clé
// est ajoutée d'un seul côté.
//
// Usage : `yarn check:i18n` (via tsx). Exit 0 si tout est OK, 1 sinon.

import { en } from '../src/lang/en'
import { fr } from '../src/lang/fr'

type Translations = Record<string, unknown>

function collectKeys(obj: Translations, prefix = ''): string[] {
  const keys: string[] = []
  for (const [k, v] of Object.entries(obj)) {
    const path = prefix ? `${prefix}.${k}` : k
    if (v !== null && typeof v === 'object' && !Array.isArray(v)) {
      keys.push(...collectKeys(v as Translations, path))
    } else {
      keys.push(path)
    }
  }
  return keys.sort()
}

const frKeys = new Set(collectKeys(fr as Translations))
const enKeys = new Set(collectKeys(en as Translations))

const onlyInFr = [...frKeys].filter((k) => !enKeys.has(k))
const onlyInEn = [...enKeys].filter((k) => !frKeys.has(k))

if (onlyInFr.length === 0 && onlyInEn.length === 0) {
  console.log(`[i18n] OK — ${frKeys.size} clés synchronisées entre fr.ts et en.ts`)
  process.exit(0)
}

if (onlyInFr.length) {
  console.error(`\n[i18n] Clés manquantes dans en.ts (présentes dans fr.ts) — ${onlyInFr.length}:`)
  for (const k of onlyInFr) console.error(`  - ${k}`)
}
if (onlyInEn.length) {
  console.error(`\n[i18n] Clés manquantes dans fr.ts (présentes dans en.ts) — ${onlyInEn.length}:`)
  for (const k of onlyInEn) console.error(`  - ${k}`)
}
console.error(
  `\n[i18n] Échec — règle bilingue : toute clé doit exister dans fr.ts ET en.ts (cf. CLAUDE.md).`,
)
process.exit(1)
