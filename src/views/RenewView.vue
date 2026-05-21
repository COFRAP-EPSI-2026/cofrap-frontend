<template>
  <AuthLayout
    :badge="t.renew.badge"
    :title="stepContent.title"
    :description="stepContent.description"
    :spacious="step !== 2"
  >
    <form v-if="step === 1" class="register-panel" @submit.prevent="renewCredentials">
      <p class="warning-box">{{ t.renew.warning }}</p>

      <div class="auth-form__group">
        <label for="username">{{ t.renew.usernameLabel }}</label>
        <input
          id="username"
          v-model="username"
          type="text"
          :placeholder="t.renew.usernamePlaceholder"
          autocomplete="username"
        />
      </div>

      <div aria-live="polite" aria-atomic="true">
        <p v-if="apiError" class="error-box" role="alert">{{ apiError }}</p>
      </div>

      <button class="auth-button auth-button--primary" type="submit" :disabled="loading">
        {{ t.renew.renewButton }}
      </button>
    </form>

    <div v-if="step === 2" class="register-panel">
      <p class="warning-box">{{ t.renew.warning }}</p>

      <figure class="qr-figure">
        <img :src="passwordQr" :alt="t.renew.passwordQrAlt" class="qr-image" />
        <figcaption class="qr-caption">{{ t.renew.passwordQrCaption }}</figcaption>
      </figure>

      <div class="pwd-display">
        <div class="pwd-display__header">
          <span class="pwd-display__title">{{ t.login.passwordLabel }}</span>
          <button
            type="button"
            class="pwd-display__toggle"
            :aria-pressed="showPassword"
            @click="showPassword = !showPassword"
          >
            <EyeOff v-if="showPassword" :size="14" aria-hidden="true" />
            <Eye v-else :size="14" aria-hidden="true" />
            {{ showPassword ? t.renew.hideButton : t.renew.showButton }}
          </button>
        </div>
        <div class="pwd-display__box">
          <span
            class="pwd-display__value"
            :class="{ 'pwd-display__value--hidden': !showPassword }"
          >
            {{ showPassword ? (passwordText || t.renew.passwordUnavailable) : '●'.repeat(passwordText.length || 16) }}
          </span>
          <button
            type="button"
            class="pwd-display__copy"
            :disabled="!passwordText"
            :aria-label="copied ? t.renew.copiedButton : t.renew.copyButton"
            @click="copyPassword"
          >
            <Check v-if="copied" :size="14" class="copy-check" aria-hidden="true" />
            {{ copied ? t.renew.copiedButton : t.renew.copyButton }}
          </button>
        </div>
      </div>

      <div aria-live="polite" aria-atomic="true">
        <p v-if="apiError" class="error-box" role="alert">{{ apiError }}</p>
      </div>

      <button
        class="auth-button auth-button--primary"
        type="button"
        :disabled="loading"
        @click="goToTotp"
      >
        {{ t.renew.continueButton }}
      </button>
    </div>

    <form v-if="step === 3" class="register-panel register-panel--spacious" @submit.prevent="activateRenewal">
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

      <button
        class="auth-button auth-button--primary"
        type="submit"
        :disabled="loading"
        :class="{ 'auth-button--loading': loading }"
      >
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
import * as OTPAuth from 'otpauth'
import { Check, Copy, Eye, EyeOff } from 'lucide-vue-next'
import jsQR from 'jsqr'

import AuthLayout from '@/components/AuthLayout.vue'
import { generatePassword, generate2fa, apiErrorMessage } from '@/components/openfaasApi'
import { useLang } from '@/composables/useLang'

const { t } = useLang()

const step = ref(1)
const loading = ref(false)

watch(step, async (newStep) => {
  await nextTick()
  if (newStep === 3) {
    document.getElementById('totp')?.focus()
  } else {
    document.querySelector<HTMLElement>('.auth-layout__title')?.focus()
  }
})

const username = ref('')
const totp = ref('')

// QR codes renvoyés par le backend (data URL prête pour <img src>).
const passwordQr = ref('')
const totpQr = ref('')

// Mot de passe en clair renvoyé par le backend (disponible uniquement à la génération).
const passwordText = ref('')
const showPassword = ref(false)
const copied = ref(false)

// Instance TOTP reconstruite depuis l'`otpauth_uri` du backend — sert à
// vérifier côté client que l'utilisateur a bien scanné le nouveau QR.
const totpInstance = ref<OTPAuth.TOTP | null>(null)

const apiError = ref('')
const totpError = ref('')

const stepContent = computed(() => {
  if (step.value === 1) return { title: t.renew.step1Title, description: t.renew.step1Description }
  if (step.value === 2) return { title: t.renew.step2Title, description: t.renew.step2Description }
  if (step.value === 3) return { title: t.renew.step3Title, description: t.renew.step3Description }
  return { title: '', description: '' }
})

/**
 * Décode le contenu d'un QR code depuis une data URL (PNG base64).
 * Utilise jsQR — fonctionne sur tous les navigateurs (Chrome, Firefox, Safari…).
 */
const decodeQrFromDataUrl = async (dataUrl: string): Promise<string> => {
  try {
    const img = new Image()
    await new Promise<void>((resolve, reject) => {
      img.onload = () => resolve()
      img.onerror = () => reject(new Error('img load'))
      img.src = dataUrl
    })
    const canvas = document.createElement('canvas')
    canvas.width = img.naturalWidth || img.width
    canvas.height = img.naturalHeight || img.height
    const ctx = canvas.getContext('2d')
    if (!ctx) return ''
    ctx.drawImage(img, 0, 0)
    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
    const code = jsQR(imageData.data, imageData.width, imageData.height)
    return code?.data ?? ''
  } catch {
    return ''
  }
}

/** Copie le mot de passe dans le presse-papier et affiche la coche pendant 2 s. */
const copyPassword = async () => {
  if (!passwordText.value) return
  await navigator.clipboard.writeText(passwordText.value)
  copied.value = true
}

/** Étape 1 → le backend régénère le mot de passe et renvoie son QR. */
const renewCredentials = async () => {
  if (!username.value.trim() || loading.value) return
  apiError.value = ''
  loading.value = true
  try {
    const res = await generatePassword(username.value.trim())
    const dataUrl = `data:image/png;base64,${res.qrcode_png_base64}`
    passwordQr.value = dataUrl
    // Priorité : champs possibles du backend → décodage du QR en fallback.
    const raw = res as Record<string, unknown>
    passwordText.value =
      (raw.password as string | undefined) ??
      (raw.generated_password as string | undefined) ??
      (raw.plain_password as string | undefined) ??
      (await decodeQrFromDataUrl(dataUrl))
    step.value = 2
  } catch (error) {
    apiError.value = apiErrorMessage(error)
  } finally {
    loading.value = false
  }
}

/** Étape 2 → 3 : le backend régénère le secret TOTP et renvoie son QR. */
const goToTotp = async () => {
  if (loading.value) return
  apiError.value = ''
  loading.value = true
  try {
    const res = await generate2fa(username.value.trim())
    totpQr.value = `data:image/png;base64,${res.qrcode_png_base64}`
    totpInstance.value = OTPAuth.URI.parse(res.otpauth_uri) as OTPAuth.TOTP
    step.value = 3
  } catch (error) {
    apiError.value = apiErrorMessage(error)
  } finally {
    loading.value = false
  }
}

/** Étape 3 : vérifie le code TOTP saisi côté client (confirme le scan). */
const activateRenewal = () => {
  totpError.value = ''
  if (!totpInstance.value) return

  const delta = totpInstance.value.validate({ token: totp.value, window: 1 })
  if (delta === null) {
    totpError.value = t.renew.totpError
    loading.value = false
    return
  }

  step.value = 4
  loading.value = false
}
</script>
