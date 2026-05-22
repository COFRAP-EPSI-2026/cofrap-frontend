<template>
  <article class="auth-card">
    <p class="auth-card__badge">Espace sécurisé</p>

    <h1 class="auth-card__title">
      Bienvenue sur<br />
      COFRAP Cloud
    </h1>

    <p class="auth-card__description">
      Accédez à vos applicatifs métier. Mot de passe généré et double authentification obligatoires
      pour toutes les nouvelles connexions.
    </p>

    <div class="auth-card__actions">
      <RouterLink class="auth-card__button auth-card__button--primary" to="/login">
        Se connecter
      </RouterLink>

      <RouterLink class="auth-card__button auth-card__button--secondary" to="/register">
        Créer un compte
      </RouterLink>
    </div>

    <footer class="auth-card__footer">
      <span>v{{ version }} · PoC serverless</span>
      <a href="#">Besoin d'aide ?</a>
    </footer>
  </article>
</template>

<script setup lang="ts">
const version = __APP_VERSION__
</script>
