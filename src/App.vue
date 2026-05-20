<template>
  <!-- Annonce de changement de page pour les lecteurs d'écran -->
  <div aria-live="polite" aria-atomic="true" class="sr-only">{{ pageAnnouncement }}</div>

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

setupAudioReading()

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
