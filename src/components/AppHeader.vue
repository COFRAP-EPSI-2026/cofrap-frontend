<template>
  <header class="app-header">
    <div class="app-header__brand">
      <div class="app-header__logo">C</div>
      <span class="app-header__name">COFRAP</span>
      <span class="app-header__separator">·</span>
      <span class="app-header__subtitle">Cloud Identity</span>
    </div>

    <div role="toolbar" aria-label="Actions de la page" class="app-header__actions">
      <button type="button" :aria-label="t.header.langButtonLabel">FR</button>
      <button type="button" :aria-label="t.header.accessibilityButtonLabel">♿</button>
      <button type="button" :aria-label="t.header.helpButtonLabel">?</button>
    </div>
  </header>
</template>

<script setup lang="ts">
import { useLang } from '@/composables/useLang'

const { t } = useLang()
</script>
