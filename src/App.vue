<template>
  <RouterView />
</template>

<script setup lang="ts">
import { setupAudioReading } from '@/composables/useAudioReading'

setupAudioReading()
</script>
