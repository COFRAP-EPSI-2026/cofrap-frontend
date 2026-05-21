<template>
  <header class="app-header">
    <div class="app-header__brand">
      <img
        src="/logo-cofrap.svg"
        alt="COFRAP"
        class="app-header__logo-img"
        width="147"
        height="40"
      />
      <div class="app-header__brand-text">
        <span class="app-header__title">{{ t.header.title }}</span>
        <span class="app-header__subtitle">{{ t.header.subtitle }}</span>
      </div>
    </div>

    <div role="toolbar" aria-label="Actions de la page" class="app-header__actions">
      <button type="button" :aria-label="t.header.langButtonLabel" @click="switchLang">
        <Languages :size="18" aria-hidden="true" />
        <span class="app-header__lang-label">{{ currentLang === 'fr' ? 'FR' : 'EN' }}</span>
      </button>

      <button
        type="button"
        :aria-label="isDark ? t.header.lightModeButton : t.header.darkModeButton"
        @click="toggleTheme"
      >
        <Sun v-if="isDark" :size="18" aria-hidden="true" />
        <Moon v-else :size="18" aria-hidden="true" />
      </button>

      <button
        type="button"
        class="app-header__a11y-btn"
        :aria-label="t.a11y.buttonLabel"
        :aria-expanded="a11yOpen"
        :aria-controls="'a11y-panel'"
        @click="a11yOpen = !a11yOpen"
      >
        <Accessibility :size="18" aria-hidden="true" />
        <span>{{ t.a11y.buttonLabel }}</span>
      </button>

      <button
        type="button"
        :aria-label="t.help.buttonLabel"
        :aria-expanded="helpOpen"
        :aria-controls="'help-panel'"
        @click="helpOpen = !helpOpen"
      >
        <HelpCircle :size="18" aria-hidden="true" />
      </button>
    </div>

    <A11yPanel :open="a11yOpen" @close="a11yOpen = false" />
    <HelpPanel :open="helpOpen" @close="helpOpen = false" />
  </header>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { Accessibility, HelpCircle, Languages, Moon, Sun } from 'lucide-vue-next'
import { useLang } from '@/composables/useLang'
import { useTheme } from '@/composables/useTheme'
import A11yPanel from '@/components/A11yPanel.vue'
import HelpPanel from '@/components/HelpPanel.vue'

const { t, currentLang, switchLang } = useLang()
const { isDark, toggleTheme } = useTheme()

const a11yOpen = ref(false)
const helpOpen = ref(false)
</script>
