<template>
  <main class="auth-page">
    <section id="main-content" class="auth-page__content">
      <article :class="['auth-layout', { 'auth-layout--spacious': spacious }]">
        <p v-if="badge" class="auth-layout__badge">
          {{ badge }}
        </p>

        <h1 ref="titleRef" class="auth-layout__title" tabindex="-1">
          {{ title }}
        </h1>

        <p v-if="description" class="auth-layout__description">
          {{ description }}
        </p>

        <div class="auth-layout__body">
          <slot />
        </div>

        <footer v-if="$slots.footer" class="auth-layout__footer">
          <slot name="footer" />
        </footer>
      </article>
    </section>
  </main>
</template>

<script setup lang="ts">
import { ref } from 'vue'

defineProps<{
  badge?: string
  title: string
  description?: string
  spacious?: boolean
}>()

const titleRef = ref<HTMLElement | null>(null)

defineExpose({ titleRef })
</script>
