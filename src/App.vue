<template>
  <!-- Lien d'évitement pour les lecteurs d'écran — doit être le premier élément focusable -->
  <a href="#main-content" class="skip-link">{{ t.skipLink }}</a>

  <!-- Annonce de changement de page pour les lecteurs d'écran -->
  <div aria-live="polite" aria-atomic="true" class="sr-only">{{ pageAnnouncement }}</div>

  <!-- Header persistant : monté une seule fois, survit aux changements de route -->
  <AppHeader />

  <RouterView v-slot="{ Component }">
    <Transition name="page" mode="out-in">
      <component :is="Component" :key="$route.path" />
    </Transition>
  </RouterView>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { setupAudioReading } from '@/composables/useAudioReading'
import AppHeader from '@/components/AppHeader.vue'
import { useLang } from '@/composables/useLang'

setupAudioReading()

const { t } = useLang()

const route = useRoute()
const pageAnnouncement = ref('')

watch(
  () => route.path,
  () => {
    // Délai pour laisser le titre se mettre à jour avant l'annonce
    setTimeout(() => {
      pageAnnouncement.value = document.title
    }, 100)
  },
)
</script>
