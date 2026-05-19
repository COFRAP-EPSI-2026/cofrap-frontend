<template>
  <AuthLayout badge="Inscription" :title="stepContent.title" :description="stepContent.description">
    <div class="steps">
      <span :class="['steps__item', { 'steps__item--active': step >= 1 }]">1 Identifiant</span>
      <span :class="['steps__item', { 'steps__item--active': step >= 2 }]">2 Mot de passe</span>
      <span :class="['steps__item', { 'steps__item--active': step >= 3 }]">3 2FA</span>
      <span :class="['steps__item', { 'steps__item--active': step >= 4 }]">4 Connexion</span>
    </div>

    <form v-if="step === 1" class="auth-form" @submit.prevent="generatePassword">
      <div class="auth-form__group">
        <label for="username">Identifiant souhaité</label>
        <input id="username" v-model="username" type="text" placeholder="prenom.nom" />
      </div>

      <button class="auth-button auth-button--primary" type="submit">
        Générer mon mot de passe
      </button>
    </form>

    <div v-if="step === 2" class="register-panel">
      <img :src="passwordQr" alt="QR mot de passe" class="qr-image" />

      <div class="secret-box">
        <span>{{ password }}</span>
        <button type="button" @click="copyPassword">
          <span v-if="copied">
            <span class="copy-check">✓</span>
            Copié
          </span>

          <span v-else> Copier </span>
        </button>
      </div>

      <p class="warning-box">Conservez-le maintenant : il ne sera pas affiché de nouveau.</p>

      <button class="auth-button auth-button--primary" type="button" @click="step = 3">
        Continuer vers la 2FA
      </button>
    </div>

    <div v-if="step === 3" class="register-panel">
      <img :src="totpQr" alt="QR 2FA" class="qr-image" />

      <div class="auth-form__group">
        <label for="totp">Entrez le code à 6 chiffres</label>
        <input id="totp" v-model="totp" type="text" placeholder="123456" />
      </div>

      <button class="auth-button auth-button--primary" type="button" @click="activateAccount">
        Vérifier et activer mon compte
      </button>
    </div>

    <div v-if="step === 4" class="success-panel">
      <div class="success-panel__icon">✓</div>

      <h2>Compte activé avec succès</h2>

      <p>
        Bienvenue, <strong>{{ username }}</strong
        >. Votre mot de passe et votre double authentification sont opérationnels.
      </p>

      <RouterLink class="auth-button auth-button--primary" to="/login">
        Accéder à mes applicatifs
      </RouterLink>
    </div>

    <template #footer>
      <div class="auth-footer">
        <RouterLink to="/">Retour accueil</RouterLink>
        <RouterLink to="/login">Déjà un compte ?</RouterLink>
      </div>
    </template>
  </AuthLayout>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import * as OTPAuth from 'otpauth'
import QRCode from 'qrcode'

import AuthLayout from '@/components/AuthLayout.vue'

const step = ref(1)
const username = ref('')
const totp = ref('')

const password = ref('')
const passwordQr = ref('')

const totpSecret = ref('')
const totpQr = ref('')

const copied = ref(false)

const stepContent = computed(() => {
  if (step.value === 1) {
    return {
      title: 'Créer votre compte',
      description:
        'Votre mot de passe sera généré automatiquement et transmis via un QR code à usage unique.',
    }
  }

  if (step.value === 2) {
    return {
      title: 'Votre mot de passe',
      description: 'Scannez le QR code avec un gestionnaire de mots de passe pour l’enregistrer.',
    }
  }

  if (step.value === 3) {
    return {
      title: 'Activer la double authentification',
      description: 'Scannez ce QR code avec votre application TOTP puis saisissez le code généré.',
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
