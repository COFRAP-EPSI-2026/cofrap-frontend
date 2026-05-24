#!/usr/bin/env node
// scripts/check-bundle-size.mjs
//
// Budget de taille pour le bundle Vite. Empêche une régression silencieuse
// (ajout d'une grosse dépendance, oubli d'un tree-shaking, etc.). Zéro
// dépendance : juste `node:fs`.
//
// Usage : `yarn check:bundle-size` (après `yarn build`). Exit 0 si OK, 1 sinon.
//
// Les budgets sont volontairement larges pour laisser de la marge au PoC ;
// les durcir au fur et à mesure que les vues se stabilisent.

import { readdirSync, statSync } from 'node:fs'
import { extname, join } from 'node:path'

const DIST_DIR = 'dist'

// Budgets en bytes (taille brute, non gzip). Adaptés à un PoC SPA Vue 3 + axios
// + lucide + jsqr + otpauth. Si tu durcis, vise plutôt la taille gzip.
const BUDGETS = {
  // Cumulé sur TOUS les fichiers de l'extension
  '.js': 800_000, // ~800 KB de JS au total (incluant chunks)
  '.css': 150_000, // ~150 KB de CSS au total
  // Par fichier individuel
  'per-file': {
    '.html': 10_000, // index.html doit rester petit
  },
}

function walk(dir) {
  const out = []
  for (const name of readdirSync(dir)) {
    const full = join(dir, name)
    const s = statSync(full)
    if (s.isDirectory()) out.push(...walk(full))
    else out.push({ path: full, size: s.size })
  }
  return out
}

function formatBytes(n) {
  if (n >= 1024 * 1024) return `${(n / (1024 * 1024)).toFixed(2)} MB`
  if (n >= 1024) return `${(n / 1024).toFixed(1)} KB`
  return `${n} B`
}

let files
try {
  files = walk(DIST_DIR)
} catch (err) {
  console.error(`[bundle-size] Échec : dossier '${DIST_DIR}' introuvable.`)
  console.error(`[bundle-size] Lance \`yarn build\` d'abord. (${err.message})`)
  process.exit(1)
}

// Agrégation par extension
const totals = new Map()
for (const f of files) {
  const ext = extname(f.path).toLowerCase()
  totals.set(ext, (totals.get(ext) ?? 0) + f.size)
}

let failed = false
console.log(`[bundle-size] Audit de ${files.length} fichiers dans '${DIST_DIR}/' :\n`)

// Vérifs cumulées
for (const [ext, budget] of Object.entries(BUDGETS)) {
  if (ext === 'per-file') continue
  const total = totals.get(ext) ?? 0
  const pct = ((total / budget) * 100).toFixed(0)
  const tag = total > budget ? '❌' : total > budget * 0.9 ? '⚠ ' : '✔ '
  console.log(`  ${tag} ${ext.padEnd(6)} ${formatBytes(total).padStart(10)} / ${formatBytes(budget)} (${pct}%)`)
  if (total > budget) failed = true
}

// Vérifs par fichier
for (const [ext, budget] of Object.entries(BUDGETS['per-file'])) {
  const candidates = files.filter((f) => extname(f.path).toLowerCase() === ext)
  for (const f of candidates) {
    const tag = f.size > budget ? '❌' : '✔ '
    console.log(`  ${tag} ${f.path.padEnd(40)} ${formatBytes(f.size).padStart(10)} / ${formatBytes(budget)}`)
    if (f.size > budget) failed = true
  }
}

if (failed) {
  console.error(`\n[bundle-size] Échec — budget dépassé. Optimise ou ajuste BUDGETS dans scripts/check-bundle-size.mjs.`)
  process.exit(1)
}
console.log(`\n[bundle-size] OK — tous les budgets respectés.`)
