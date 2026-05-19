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
        <input
          id="password"
          v-model="form.password"
          type="password"
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

      <button v-if="!isLocked" class="auth-button auth-button--primary" type="submit">
        {{ t.login.submitButton }}
      </button>
    </form>

    <div v-else class="success-panel">
      <div class="success-panel__icon" aria-hidden="true">✓</div>

      <p>
        {{ t.login.welcomePrefix }} <strong>{{ form.username }}</strong>.
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
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import * as OTPAuth from 'otpauth'

import AuthLayout from '@/components/AuthLayout.vue'
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

    errorMessage.value = t.login.errorLocked

    isLocked.value = true

    return
  }

  saveLoginSecurity(attempts, null)

  errorMessage.value = t.login.errorAttempts(MAX_ATTEMPTS - attempts)
}

const handleLogin = () => {
  errorMessage.value = ''
  isLocked.value = false

  const security = getLoginSecurity()

  if (security.lockedUntil && Date.now() < security.lockedUntil) {
    errorMessage.value = t.login.errorLockedCheck

    isLocked.value = true

    return
  }

  const storedUser = localStorage.getItem('cofrap-user')

  if (!storedUser) {
    errorMessage.value = t.login.errorNoAccount
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
