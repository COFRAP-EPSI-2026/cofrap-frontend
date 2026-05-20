<template>
  <AuthLayout
    :badge="t.renew.badge"
    :title="stepContent.title"
    :description="stepContent.description"
  >
    <div v-if="step === 1" class="register-panel">
      <p class="warning-box">{{ t.renew.warning }}</p>

      <button class="auth-button auth-button--primary" type="button" :disabled="loading" :class="{ 'auth-button--loading': loading }" @click="renewCredentials">
        {{ t.renew.renewButton }}
      </button>
    </div>

    <div v-if="step === 2" class="register-panel">
      <p class="warning-box">{{ t.renew.warning }}</p>

      <img :src="passwordQr" :alt="t.renew.passwordQrAlt" class="qr-image" />

      <div class="secret-box">
        <span>{{ password }}</span>

        <button
          type="button"
          :aria-label="copied ? t.renew.copiedButton : t.renew.copyButton"
          @click="copyPassword"
        >
          <span v-if="copied">
            <span class="copy-check">✓</span>
            Copié
          </span>
          <span v-else>Copier</span>
        </button>
      </div>

      <button class="auth-button auth-button--primary" type="button" @click="step = 3">
        {{ t.renew.continueButton }}
      </button>
    </div>

    <form v-if="step === 3" class="register-panel" @submit.prevent="activateRenewal">
      <img :src="totpQr" :alt="t.renew.totpQrAlt" class="qr-image" />

      <div class="auth-form__group">
        <label for="totp">{{ t.renew.totpLabel }}</label>
        <input
          id="totp"
          v-model="totp"
          type="text"
          :placeholder="t.renew.totpPlaceholder"
          inputmode="numeric"
          :aria-invalid="!!totpError"
          :aria-describedby="totpError ? 'totp-error' : undefined"
        />
      </div>

      <div aria-live="polite" aria-atomic="true">
        <p v-if="totpError" id="totp-error" class="error-box" role="alert">
          {{ totpError }}
        </p>
      </div>

      <button class="auth-button auth-button--primary" type="submit" :disabled="loading" :class="{ 'auth-button--loading': loading }">
        {{ t.renew.activateButton }}
      </button>
    </form>

    <div v-if="step === 4" class="success-panel">
      <div class="success-panel__icon" aria-hidden="true">✓</div>

      <h2>{{ t.renew.successTitle }}</h2>

      <p>{{ t.renew.successMessage }}</p>

      <RouterLink class="auth-button auth-button--primary" to="/login">
        {{ t.renew.successButton }}
      </RouterLink>
    </div>

    <template #footer>
      <div class="auth-footer">
        <RouterLink to="/">{{ t.renew.footerBackHome }}</RouterLink>
        <RouterLink to="/login">{{ t.renew.footerLogin }}</RouterLink>
      </div>
    </template>
  </AuthLayout>
</template>

<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'
import QRCode from 'qrcode'

import AuthLayout from '@/components/AuthLayout.vue'
import { useLang } from '@/composables/useLang'
import { useA11y } from '@/composables/useA11y'

const { t } = useLang()
const { audioReading } = useA11y()

const step = ref(1)
const loading = ref(false)

const focusTitle = async () => {
  await nextTick()
  document.querySelector<HTMLElement>('.auth-layout__title')?.focus()
}

watch(step, async (newStep) => {
  await nextTick()
  if (newStep === 3) {
    document.getElementById('totp')?.focus()
  } else {
    document.querySelector<HTMLElement>('.auth-layout__title')?.focus()
  }
})
const password = ref('')
const passwordQr = ref('')
const totpSecret = ref('')
const totpQr = ref('')
const totp = ref('')

watch(totp, (val) => {
  if (step.value === 3 && /^\d{6}$/.test(val)) activateRenewal()
})
const copied = ref(false)
const totpError = ref('')

const stepContent = computed(() => {
  if (step.value === 1) return { title: t.renew.step1Title, description: t.renew.step1Description }
  if (step.value === 2) return { title: t.renew.step2Title, description: t.renew.step2Description }
  if (step.value === 3) return { title: t.renew.step3Title, description: t.renew.step3Description }
  return { title: '', description: '' }
})

const generateSecurePassword = () => {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*'
  return Array.from({ length: 24 }, () => chars[Math.floor(Math.random() * chars.length)]).join('')
}

const generateTotpSecret = () => {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
  return Array.from({ length: 32 }, () => chars[Math.floor(Math.random() * chars.length)]).join('')
}

const renewCredentials = async () => {
  const storedUser = localStorage.getItem('cofrap-user')

  if (!storedUser) return

  loading.value = true

  const user = JSON.parse(storedUser)

  password.value = generateSecurePassword()
  totpSecret.value = generateTotpSecret()

  passwordQr.value = await QRCode.toDataURL(`PASSWORD:${user.username}:${password.value}`)

  totpQr.value = await QRCode.toDataURL(
    `otpauth://totp/COFRAP:${user.username}?secret=${totpSecret.value}&issuer=COFRAP`,
  )

  step.value = 2
  loading.value = false
}

const activateRenewal = async () => {
  if (loading.value) return
  loading.value = true
  await nextTick()
  totpError.value = ''

  if (!totp.value.trim()) {
    totpError.value = t.renew.totpError
    loading.value = false
    return
  }

  const storedUser = localStorage.getItem('cofrap-user')
  if (!storedUser) {
    loading.value = false
    return
  }

  const user = JSON.parse(storedUser)

  localStorage.setItem(
    'cofrap-user',
    JSON.stringify({
      ...user,
      password: password.value,
      totpSecret: totpSecret.value,
      createdAt: Date.now(),
      expired: false,
    }),
  )

  step.value = 4
  loading.value = false
}

const copyPassword = async () => {
  await navigator.clipboard.writeText(password.value)
  copied.value = true
  if (audioReading.value && window.speechSynthesis) {
    const lang = document.documentElement.lang === 'fr' ? 'fr-FR' : 'en-US'
    const msg = lang === 'fr-FR' ? 'Mot de passe copié' : 'Password copied'
    const u = new SpeechSynthesisUtterance(msg)
    u.lang = lang
    window.speechSynthesis.cancel()
    window.speechSynthesis.speak(u)
  }
}
</script>
