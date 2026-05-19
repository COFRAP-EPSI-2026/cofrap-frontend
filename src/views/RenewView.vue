<template>
  <AuthLayout
    badge="Renouvellement"
    :title="stepContent.title"
    :description="stepContent.description"
  >
    <div v-if="step === 1" class="register-panel">
      <p class="warning-box">
        Vos identifiants ont expiré. Un nouveau mot de passe et une nouvelle double authentification
        vont être générés.
      </p>

      <button class="auth-button auth-button--primary" type="button" @click="renewCredentials">
        Renouveler mes identifiants
      </button>
    </div>

    <div v-if="step === 2" class="register-panel">
      <img :src="passwordQr" alt="QR nouveau mot de passe" class="qr-image" />

      <div class="secret-box">
        <span>{{ password }}</span>

        <button type="button" @click="copyPassword">
          <span v-if="copied">
            <span class="copy-check">✓</span>
            Copié
          </span>
          <span v-else>Copier</span>
        </button>
      </div>

      <button class="auth-button auth-button--primary" type="button" @click="step = 3">
        Continuer vers la 2FA
      </button>
    </div>

    <div v-if="step === 3" class="register-panel">
      <img :src="totpQr" alt="QR nouvelle 2FA" class="qr-image" />

      <div class="auth-form__group">
        <label for="totp">Entrez le code à 6 chiffres</label>
        <input id="totp" v-model="totp" type="text" placeholder="123456" />
      </div>

      <button class="auth-button auth-button--primary" type="button" @click="activateRenewal">
        Réactiver mon compte
      </button>
    </div>

    <div v-if="step === 4" class="success-panel">
      <div class="success-panel__icon">✓</div>

      <h2>Identifiants renouvelés</h2>

      <p>Votre compte est de nouveau actif.</p>

      <RouterLink class="auth-button auth-button--primary" to="/login">
        Retour à la connexion
      </RouterLink>
    </div>

    <template #footer>
      <div class="auth-footer">
        <RouterLink to="/">Retour accueil</RouterLink>
        <RouterLink to="/login">Connexion</RouterLink>
      </div>
    </template>
  </AuthLayout>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import QRCode from 'qrcode'

import AuthLayout from '@/components/AuthLayout.vue'

const step = ref(1)
const password = ref('')
const passwordQr = ref('')
const totpSecret = ref('')
const totpQr = ref('')
const totp = ref('')
const copied = ref(false)

const stepContent = computed(() => {
  if (step.value === 1) {
    return {
      title: 'Renouveler l’accès',
      description:
        'Vos identifiants doivent être renouvelés pour continuer à utiliser COFRAP Cloud.',
    }
  }

  if (step.value === 2) {
    return {
      title: 'Nouveau mot de passe',
      description: 'Scannez ou copiez votre nouveau mot de passe généré automatiquement.',
    }
  }

  if (step.value === 3) {
    return {
      title: 'Nouvelle double authentification',
      description: 'Scannez le QR code puis saisissez le code généré par votre application TOTP.',
    }
  }

  return {
    title: '',
    description: '',
  }
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

  const user = JSON.parse(storedUser)

  password.value = generateSecurePassword()
  totpSecret.value = generateTotpSecret()

  passwordQr.value = await QRCode.toDataURL(`PASSWORD:${user.username}:${password.value}`)

  totpQr.value = await QRCode.toDataURL(
    `otpauth://totp/COFRAP:${user.username}?secret=${totpSecret.value}&issuer=COFRAP`,
  )

  step.value = 2
}

const activateRenewal = () => {
  if (!totp.value.trim()) return

  const storedUser = localStorage.getItem('cofrap-user')
  if (!storedUser) return

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
}

const copyPassword = async () => {
  await navigator.clipboard.writeText(password.value)
  copied.value = true
}
</script>
