<template>
  <AuthLayout
    badge="Connexion"
    :title="loginSuccess ? 'Connexion réussie' : 'Se connecter'"
    :description="
      loginSuccess
        ? 'Vous êtes connecté à votre espace COFRAP Cloud.'
        : 'Authentifiez-vous avec votre identifiant, votre mot de passe généré et votre code 2FA.'
    "
  >
    <form v-if="!loginSuccess" class="auth-form" @submit.prevent="handleLogin">
      <div class="auth-form__group">
        <label for="username">Identifiant</label>
        <input id="username" v-model="form.username" type="text" placeholder="ex: michel.ranu" />
      </div>

      <div class="auth-form__group">
        <label for="password">Mot de passe</label>
        <input
          id="password"
          v-model="form.password"
          type="password"
          placeholder="Votre mot de passe"
        />
      </div>

      <div class="auth-form__group">
        <label for="totp">Code 2FA</label>
        <input id="totp" v-model="form.totp" type="text" placeholder="123456" />
      </div>

      <p v-if="errorMessage" class="error-box">
        {{ errorMessage }}
      </p>

      <RouterLink v-if="isLocked" class="auth-button auth-button--secondary" to="/">
        Retour à l'accueil
      </RouterLink>

      <button v-if="!isLocked" class="auth-button auth-button--primary" type="submit">
        Se connecter
      </button>
    </form>

    <div v-else class="success-panel">
      <div class="success-panel__icon">✓</div>

      <p>
        Bienvenue, <strong>{{ form.username }}</strong
        >.
      </p>

      <RouterLink class="auth-button auth-button--primary" to="/"> Retour à l’accueil </RouterLink>
    </div>

    <template #footer>
      <div class="auth-footer">
        <RouterLink to="/">Retour accueil</RouterLink>
        <RouterLink to="/renew">Mot de passe expiré ?</RouterLink>
      </div>
    </template>
  </AuthLayout>
</template>

<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import * as OTPAuth from 'otpauth'

import AuthLayout from '@/components/AuthLayout.vue'

const router = useRouter()

const MAX_ATTEMPTS = 3
const LOCK_DURATION_MS = 5 * 60 * 1000

const form = reactive({
  username: '',
  password: '',
  totp: '',
})

const errorMessage = ref('')
const isLocked = ref(false)
const loginSuccess = ref(false)

const getLoginSecurity = () => {
  const storedSecurity = localStorage.getItem('cofrap-login-security')

  if (!storedSecurity) {
    return {
      attempts: 0,
      lockedUntil: null,
    }
  }

  return JSON.parse(storedSecurity)
}

const saveLoginSecurity = (attempts: number, lockedUntil: number | null) => {
  localStorage.setItem(
    'cofrap-login-security',
    JSON.stringify({
      attempts,
      lockedUntil,
    }),
  )
}

const resetLoginSecurity = () => {
  localStorage.removeItem('cofrap-login-security')
}

const registerFailedAttempt = () => {
  const security = getLoginSecurity()
  const attempts = security.attempts + 1

  if (attempts >= MAX_ATTEMPTS) {
    saveLoginSecurity(attempts, Date.now() + LOCK_DURATION_MS)

    errorMessage.value =
      'Compte temporairement bloqué après 3 tentatives. Réessayez dans 5 minutes.'

    isLocked.value = true

    return
  }

  saveLoginSecurity(attempts, null)

  errorMessage.value = `Connexion refusée. Tentatives restantes : ${MAX_ATTEMPTS - attempts}.`
}

const handleLogin = () => {
  errorMessage.value = ''
  isLocked.value = false

  const security = getLoginSecurity()

  if (security.lockedUntil && Date.now() < security.lockedUntil) {
    errorMessage.value = 'Compte temporairement bloqué. Réessayez dans 5 minutes.'

    isLocked.value = true

    return
  }

  const storedUser = localStorage.getItem('cofrap-user')

  if (!storedUser) {
    errorMessage.value = 'Aucun compte activé trouvé.'
    return
  }

  const user = JSON.parse(storedUser)

  if (user.expired) {
    router.push('/renew')
    return
  }

  if (form.username !== user.username || form.password !== user.password) {
    registerFailedAttempt()
    return
  }

  const totp = new OTPAuth.TOTP({
    issuer: 'COFRAP',
    label: user.username,
    algorithm: 'SHA1',
    digits: 6,
    period: 30,
    secret: OTPAuth.Secret.fromBase32(user.totpSecret),
  })

  const delta = totp.validate({
    token: form.totp,
    window: 1,
  })

  if (delta === null) {
    registerFailedAttempt()
    return
  }

  resetLoginSecurity()

  loginSuccess.value = true
}
</script>
