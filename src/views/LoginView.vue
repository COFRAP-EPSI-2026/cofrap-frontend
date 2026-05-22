<template>
  <AuthLayout
    :badge="t.login.badge"
    :title="loginSuccess ? t.login.successTitle : stepContent.title"
    :description="loginSuccess ? t.login.successDescription : stepContent.description"
    :spacious="loginStep === 2 || loginSuccess"
  >
    <!-- ── Étape 1 : identifiant + mot de passe ─────────────────────────────── -->
    <form v-if="!loginSuccess && loginStep === 1" class="auth-form" @submit.prevent="goToTotpStep">
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

      <button class="auth-button auth-button--primary" type="submit">
        {{ t.login.nextButton }}
      </button>
    </form>

    <!-- ── Étape 2 : code TOTP ──────────────────────────────────────────────── -->
    <form v-if="!loginSuccess && loginStep === 2" class="auth-form" @submit.prevent="handleLogin">
      <!-- Bouton accès direct app TOTP — uniquement si l'URI a été sauvegardée
           lors de l'inscription/renouvellement, et uniquement sur mobile (CSS). -->
      <a
        v-if="savedTotpUri"
        :href="savedTotpUri"
        class="totp-open-btn"
        target="_blank"
        rel="noopener noreferrer"
      >
        <Smartphone :size="15" aria-hidden="true" />
        {{ t.login.openInAppButton }}
      </a>

      <div class="login-identity-recap">
        <span class="login-identity-recap__label">{{ t.login.usernameLabel }}</span>
        <strong class="login-identity-recap__value">{{ form.username }}</strong>
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

      <button v-if="!isLocked" type="button" class="back-step-btn" @click="backToCredentials">
        ← {{ t.login.backToCredentials }}
      </button>
    </form>

    <!-- ── Succès ────────────────────────────────────────────────────────────── -->
    <div v-if="loginSuccess" class="success-panel">
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
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { AxiosError } from 'axios'
import { Smartphone } from '@lucide/vue'

import AuthLayout from '@/components/AuthLayout.vue'
import PasswordInput from '@/components/PasswordInput.vue'
import { authenticate } from '@/components/openfaasApi'
import { useLang } from '@/composables/useLang'

const router = useRouter()
const { t } = useLang()

const MAX_ATTEMPTS = 3
const LOCK_DURATION_MS = 5 * 60 * 1000

const loginStep = ref<1 | 2>(1)

// URI TOTP sauvegardée lors de l'inscription/renouvellement — permet d'ouvrir
// directement l'app d'authentification depuis l'étape 2 de connexion.
const savedTotpUri = computed(
  () => localStorage.getItem(`cofrap-totp-${form.username.trim()}`) ?? '',
)

const form = reactive({
  username: '',
  password: '',
  totp: '',
})

const loading = ref(false)
const errorMessage = ref('')
const isLocked = ref(false)
const loginSuccess = ref(false)

const stepContent = computed(() => {
  if (loginStep.value === 1)
    return { title: t.login.step1Title, description: t.login.step1Description }
  return { title: t.login.step2Title, description: t.login.step2Description }
})

// ── Persistance mobile — survie aux aller-retours vers l'app TOTP ─────────────

const LOGIN_SESSION_KEY = 'cofrap-login-draft'

watch([loginStep, () => form.username, () => form.password], () => {
  if (loginSuccess.value) {
    sessionStorage.removeItem(LOGIN_SESSION_KEY)
    return
  }
  // On ne sauvegarde qu'à partir de l'étape 2 (identifiants saisis)
  if (loginStep.value < 2) {
    sessionStorage.removeItem(LOGIN_SESSION_KEY)
    return
  }
  sessionStorage.setItem(
    LOGIN_SESSION_KEY,
    JSON.stringify({
      loginStep: loginStep.value,
      username: form.username,
      password: form.password,
    }),
  )
})

onMounted(() => {
  const saved = sessionStorage.getItem(LOGIN_SESSION_KEY)
  if (!saved) return
  try {
    const data = JSON.parse(saved) as {
      loginStep?: number
      username?: string
      password?: string
    }
    if (data.loginStep !== 2) return
    form.username = data.username ?? ''
    form.password = data.password ?? ''
    loginStep.value = 2
  } catch {
    sessionStorage.removeItem(LOGIN_SESSION_KEY)
  }
})

// Gestion du focus lors des transitions d'étapes
watch(loginStep, async (newStep) => {
  await nextTick()
  if (newStep === 2) {
    document.getElementById('totp')?.focus()
  } else {
    document.querySelector<HTMLElement>('.auth-layout__title')?.focus()
  }
})

watch(loginSuccess, async (val) => {
  if (val) {
    await nextTick()
    document.querySelector<HTMLElement>('.auth-layout__title')?.focus()
  }
})

// --- Verrouillage anti-bruteforce (côté client) ------------------------------

const getLoginSecurity = (): { attempts: number; lockedUntil: number | null } => {
  const storedSecurity = localStorage.getItem('cofrap-login-security')
  if (!storedSecurity) return { attempts: 0, lockedUntil: null }
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

/** Étape 1 → 2 : valide que les champs identifiant et mot de passe sont remplis. */
const goToTotpStep = () => {
  if (!form.username.trim() || !form.password) return

  // Vérifier si le compte est déjà verrouillé avant d'avancer
  const security = getLoginSecurity()
  if (security.lockedUntil && Date.now() < security.lockedUntil) {
    errorMessage.value = t.login.errorLockedCheck
    isLocked.value = true
    return
  }

  loginStep.value = 2
}

/** Étape 2 → 1 : revenir à la saisie des identifiants. */
const backToCredentials = () => {
  loginStep.value = 1
  errorMessage.value = ''
  isLocked.value = false
  form.totp = ''
}

/** Étape 2 : authentification complète via le backend. */
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

    if (res.expired) {
      resetLoginSecurity()
      router.push('/renew')
      return
    }

    if (res.authenticated) {
      resetLoginSecurity()
      sessionStorage.removeItem(LOGIN_SESSION_KEY)
      loginSuccess.value = true
      return
    }

    registerFailedAttempt()
  } catch (error) {
    if (error instanceof AxiosError && (!error.response || error.response.status >= 500)) {
      errorMessage.value = t.login.errorServer
    } else {
      registerFailedAttempt()
    }
  } finally {
    loading.value = false
  }
}
</script>
