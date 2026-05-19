<template>
  <AuthLayout :badge="t.home.badge" :title="t.home.title" :description="t.home.description">
    <div class="auth-actions">
      <RouterLink class="auth-button auth-button--primary" to="/login">
        {{ t.home.loginButton }}
      </RouterLink>

      <RouterLink class="auth-button auth-button--secondary" to="/register">
        {{ t.home.registerButton }}
      </RouterLink>
    </div>

    <template #footer>
      <div class="auth-footer">
        <span>{{ t.home.footerVersion }}</span>
        <a href="#">{{ t.home.footerHelp }}</a>
      </div>
    </template>
  </AuthLayout>
</template>

<script setup lang="ts">
import AuthLayout from '@/components/AuthLayout.vue'
import { useLang } from '@/composables/useLang'

const { t } = useLang()
</script>
