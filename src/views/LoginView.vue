<template>
  <AuthLayout
    :badge="t.login.badge"
    :title="loginSuccess ? t.login.successTitle : t.login.title"
    :description="loginSuccess ? t.login.successDescription : t.login.description"
  >
    <form v-if="!loginSuccess" class="auth-form" @submit.prevent="handleLogin">
      <div class="auth-form__group">
        <label for="username">{{ t.login.usernameLabel }}</label>
        <input
          id="username"
          v-model="form.username"
          type="text"
          :placeholder="t.login.usernamePlaceholder"
          autocomplete="username"
        />
      </div>

      <div class="auth-form__group">
        <label for="password">{{ t.login.passwordLabel }}</label>
        <PasswordInput
          id="password"
          v-model="form.password"
          :placeholder="t.login.passwordPlaceholder"
          autocomplete="current-password"
        />
      </div>

      <div class="auth-form__group">
        <label for="totp">{{ t.login.totpLabel }}</label>
        <input
          id="totp"
          v-model="form.totp"
          type="text"
          :placeholder="t.login.totpPlaceholder"
          autocomplete="one-time-code"
          inputmode="numeric"
        />
      </div>

      <div aria-live="polite" aria-atomic="true">
        <p v-if="errorMessage" class="error-box" role="alert">
          {{ errorMessage }}
        </p>
      </div>

      <RouterLink v-if="isLocked" class="auth-button auth-button--secondary" to="/">
        {{ t.login.backHomeButton }}
      </RouterLink>

      <button
        v-if="!isLocked"
        class="auth-button auth-button--primary"
        type="submit"
        :disabled="loading"
      >
        {{ t.login.submitButton }}
      </button>
    </form>

    <div v-else class="success-panel">
      <div class="success-panel__icon" aria-hidden="true">✓</div>

      <p>
        {{ t.login.welcomePrefix }} <strong>{{ form.username }}</strong
        >.
      </p>

      <RouterLink class="auth-button auth-button--primary" to="/">
        {{ t.login.backHomeButton }}
      </RouterLink>
    </div>

    <template #footer>
      <div class="auth-footer">
        <RouterLink to="/">{{ t.login.footerBackHome }}</RouterLink>
        <RouterLink to="/renew">{{ t.login.footerExpired }}</RouterLink>
      </div>
    </template>
  </AuthLayout>
</template>

<script setup lang="ts">
import { nextTick, reactive, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { AxiosError } from 'axios'

import AuthLayout from '@/components/AuthLayout.vue'
import PasswordInput from '@/components/PasswordInput.vue'
import { authenticate } from '@/components/openfaasApi'
import { useLang } from '@/composables/useLang'

const router = useRouter()
const { t } = useLang()

const MAX_ATTEMPTS = 3
const LOCK_DURATION_MS = 5 * 60 * 1000

const form = reactive({
  username: '',
  password: '',
  totp: '',
})

const loading = ref(false)
const errorMessage = ref('')
const isLocked = ref(false)
const loginSuccess = ref(false)

const focusTitle = async () => {
  await nextTick()
  document.querySelector<HTMLElement>('.auth-layout__title')?.focus()
}

watch(loginSuccess, (val) => {
  if (val) focusTitle()
})

// --- Verrouillage anti-bruteforce (côté client) ------------------------------
// Le backend `authenticate-user` valide réellement les identifiants ; ce
// compteur local fige juste l'UI après 3 échecs consécutifs pour décourager
// les tentatives répétées depuis ce navigateur.

const getLoginSecurity = (): { attempts: number; lockedUntil: number | null } => {
  const storedSecurity = localStorage.getItem('cofrap-login-security')

  if (!storedSecurity) {
    return { attempts: 0, lockedUntil: null }
  }

  return JSON.parse(storedSecurity)
}

const saveLoginSecurity = (attempts: number, lockedUntil: number | null) => {
  localStorage.setItem('cofrap-login-security', JSON.stringify({ attempts, lockedUntil }))
}

const resetLoginSecurity = () => {
  localStorage.removeItem('cofrap-login-security')
}

const registerFailedAttempt = () => {
  const security = getLoginSecurity()
  const attempts = security.attempts + 1

  if (attempts >= MAX_ATTEMPTS) {
    saveLoginSecurity(attempts, Date.now() + LOCK_DURATION_MS)
    errorMessage.value = t.login.errorLocked
    isLocked.value = true
    return
  }

  saveLoginSecurity(attempts, null)
  errorMessage.value = t.login.errorAttempts(MAX_ATTEMPTS - attempts)
}

/** Authentifie via le backend (identifiant + mot de passe + code TOTP). */
const handleLogin = async () => {
  errorMessage.value = ''
  isLocked.value = false

  const security = getLoginSecurity()
  if (security.lockedUntil && Date.now() < security.lockedUntil) {
    errorMessage.value = t.login.errorLockedCheck
    isLocked.value = true
    return
  }

  if (!form.username.trim() || !form.password || !form.totp.trim() || loading.value) return

  loading.value = true
  try {
    const res = await authenticate(form.username.trim(), form.password, form.totp.trim())

    // Compte expiré (rotation 6 mois) → renouvellement obligatoire.
    if (res.expired) {
      resetLoginSecurity()
      router.push('/renew')
      return
    }

    if (res.authenticated) {
      resetLoginSecurity()
      loginSuccess.value = true
      return
    }

    // Réponse 200 sans `authenticated` ni `expired` : traité comme un échec.
    registerFailedAttempt()
  } catch (error) {
    // Panne serveur / réseau : on n'incrémente pas le compteur d'échecs.
    if (error instanceof AxiosError && (!error.response || error.response.status >= 500)) {
      errorMessage.value = t.login.errorServer
    } else {
      // 401 / 404 / 409 / 422 → identifiants refusés.
      registerFailedAttempt()
    }
  } finally {
    loading.value = false
  }
}
</script>
