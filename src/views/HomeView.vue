<template>
  <AuthLayout
    badge="Espace sécurisé"
    title="Bienvenue sur COFRAP Cloud"
    description="Accédez à vos applicatifs métier. Mot de passe généré et double authentification obligatoires pour toutes les nouvelles connexions."
  >
    <div class="auth-actions">
      <RouterLink class="auth-button auth-button--primary" to="/login"> Se connecter </RouterLink>

      <RouterLink class="auth-button auth-button--secondary" to="/register">
        Créer un compte
      </RouterLink>
    </div>

    <template #footer>
      <div class="auth-footer">
        <span>v2.4 · PoC serverless</span>
        <a href="#">Besoin d'aide ?</a>
      </div>
    </template>
  </AuthLayout>
</template>

<script setup lang="ts">
import AuthLayout from '@/components/AuthLayout.vue'
</script>
