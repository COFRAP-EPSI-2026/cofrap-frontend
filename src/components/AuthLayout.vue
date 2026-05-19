<template>
  <main class="auth-page">
    <AppHeader />

    <section class="auth-page__content">
      <article class="auth-layout">
        <p v-if="badge" class="auth-layout__badge">
          {{ badge }}
        </p>

        <h1 class="auth-layout__title">
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
import AppHeader from '@/components/AppHeader.vue'

defineProps<{
  badge?: string
  title: string
  description?: string
}>()
</script>
