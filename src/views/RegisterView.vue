<template>
  <AuthLayout
    :badge="t.register.badge"
    :title="stepContent.title"
    :description="stepContent.description"
  >
    <div class="steps" role="list" :aria-label="t.register.stepsAriaLabel">
      <span
        role="listitem"
        :class="['steps__item', { 'steps__item--active': step >= 1 }]"
        :aria-current="step === 1 ? 'step' : undefined"
      >{{ t.register.step1Label }}</span>
      <span
        role="listitem"
        :class="['steps__item', { 'steps__item--active': step >= 2 }]"
        :aria-current="step === 2 ? 'step' : undefined"
      >{{ t.register.step2Label }}</span>
      <span
        role="listitem"
        :class="['steps__item', { 'steps__item--active': step >= 3 }]"
        :aria-current="step === 3 ? 'step' : undefined"
      >{{ t.register.step3Label }}</span>
      <span
        role="listitem"
        :class="['steps__item', { 'steps__item--active': step >= 4 }]"
        :aria-current="step === 4 ? 'step' : undefined"
      >{{ t.register.step4Label }}</span>
    </div>

    <form v-if="step === 1" class="auth-form" @submit.prevent="generatePassword">
      <div class="auth-form__group">
        <label for="username">{{ t.register.usernameLabel }}</label>
        <input
          id="username"
          v-model="username"
          type="text"
          :placeholder="t.register.usernamePlaceholder"
          autocomplete="username"
        />
      </div>

      <button class="auth-button auth-button--primary" type="submit">
        {{ t.register.generateButton }}
      </button>
    </form>

    <div v-if="step === 2" class="register-panel">
      <img :src="passwordQr" :alt="t.register.passwordQrAlt" class="qr-image" />

      <div class="secret-box">
        <span>{{ password }}</span>
        <button
          type="button"
          :aria-label="copied ? t.register.copiedButton : t.register.copyButton"
          @click="copyPassword"
        >
          <span v-if="copied">
            <span class="copy-check">✓</span>
            Copié
          </span>

          <span v-else>Copier</span>
        </button>
      </div>

      <p class="warning-box">{{ t.register.warning }}</p>

      <button class="auth-button auth-button--primary" type="button" @click="step = 3">
        {{ t.register.continueButton }}
      </button>
    </div>

    <div v-if="step === 3" class="register-panel">
      <img :src="totpQr" :alt="t.register.totpQrAlt" class="qr-image" />

      <div class="auth-form__group">
        <label for="totp">{{ t.register.totpLabel }}</label>
        <input
          id="totp"
          v-model="totp"
          type="text"
          :placeholder="t.register.totpPlaceholder"
          inputmode="numeric"
        />
      </div>

      <button class="auth-button auth-button--primary" type="button" @click="activateAccount">
        {{ t.register.activateButton }}
      </button>
    </div>

    <div v-if="step === 4" class="success-panel">
      <div class="success-panel__icon" aria-hidden="true">✓</div>

      <h2>{{ t.register.successTitle }}</h2>

      <p>
        {{ t.register.successMessagePrefix }}
        <strong>{{ username }}</strong>{{ t.register.successMessageSuffix }}
      </p>

      <RouterLink class="auth-button auth-button--primary" to="/login">
        {{ t.register.successButton }}
      </RouterLink>
    </div>

    <template #footer>
      <div class="auth-footer">
        <RouterLink to="/">{{ t.register.footerBackHome }}</RouterLink>
        <RouterLink to="/login">{{ t.register.footerHaveAccount }}</RouterLink>
      </div>
    </template>
  </AuthLayout>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import * as OTPAuth from 'otpauth'
import QRCode from 'qrcode'

import AuthLayout from '@/components/AuthLayout.vue'
import { useLang } from '@/composables/useLang'

const { t } = useLang()

const step = ref(1)
const username = ref('')
const totp = ref('')

const password = ref('')
const passwordQr = ref('')

const totpSecret = ref('')
const totpQr = ref('')

const copied = ref(false)

const stepContent = computed(() => {
  if (step.value === 1) return { title: t.register.step1Title, description: t.register.step1Description }
  if (step.value === 2) return { title: t.register.step2Title, description: t.register.step2Description }
  if (step.value === 3) return { title: t.register.step3Title, description: t.register.step3Description }
  return { title: '', description: '' }
})

const generateSecurePassword = () => {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*'

  return Array.from({ length: 24 }, () => chars[Math.floor(Math.random() * chars.length)]).join('')
}

const generateTotpSecret = () => {
  return new OTPAuth.Secret({ size: 20 }).base32
}

const generatePassword = async () => {
  if (!username.value.trim()) return

  password.value = generateSecurePassword()

  totpSecret.value = generateTotpSecret()

  passwordQr.value = await QRCode.toDataURL(`PASSWORD:${username.value}:${password.value}`)

  totpQr.value = await QRCode.toDataURL(
    `otpauth://totp/COFRAP:${username.value}?secret=${totpSecret.value}&issuer=COFRAP`,
  )

  step.value = 2
}

const activateAccount = () => {
  const totpInstance = new OTPAuth.TOTP({
    issuer: 'COFRAP',
    label: username.value,
    algorithm: 'SHA1',
    digits: 6,
    period: 30,
    secret: OTPAuth.Secret.fromBase32(totpSecret.value),
  })

  const delta = totpInstance.validate({
    token: totp.value,
    window: 1,
  })

  if (delta === null) return

  localStorage.setItem(
    'cofrap-user',
    JSON.stringify({
      username: username.value,
      password: password.value,
      totpSecret: totpSecret.value,
      createdAt: Date.now(),
      expired: false,
    }),
  )

  step.value = 4
}

const copyPassword = async () => {
  await navigator.clipboard.writeText(password.value)
  copied.value = true
}
</script>
