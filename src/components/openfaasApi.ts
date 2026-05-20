/**
 * openfaasApi.ts
 * Couche d'abstraction pour les appels vers les fonctions OpenFaaS.
 * Actuellement en mode "localStorage mock" pour le PoC.
 * Remplacer les implémentations par de vrais appels fetch() lors de l'intégration.
 */

import axios from 'axios'

// Base URL OpenFaaS — à configurer via variable d'environnement
const BASE_URL = import.meta.env.VITE_OPENFAAS_URL ?? ''

// ── Types ─────────────────────────────────────────────────────────────────────

export interface RegisterPayload {
  username: string
  password: string
  totpSecret: string
}

export interface LoginPayload {
  username: string
  password: string
  totpToken: string
}

export interface RenewPayload {
  username: string
  newPassword: string
  newTotpSecret: string
  totpToken: string
}

export interface ApiResult<T = void> {
  success: boolean
  data?: T
  error?: string
}

// ── Helpers ───────────────────────────────────────────────────────────────────

async function post<T>(path: string, payload: unknown): Promise<ApiResult<T>> {
  try {
    const { data } = await axios.post<T>(`${BASE_URL}/function/${path}`, payload)
    return { success: true, data }
  } catch (err: unknown) {
    if (axios.isAxiosError(err)) {
      return { success: false, error: err.response?.data?.message ?? err.message }
    }
    return { success: false, error: 'Erreur réseau' }
  }
}

// ── API Functions ─────────────────────────────────────────────────────────────

/**
 * Enregistre un nouvel utilisateur.
 * Stocke les credentials en localStorage pour le PoC.
 */
export async function registerUser(payload: RegisterPayload): Promise<ApiResult> {
  if (!BASE_URL) {
    // Mode PoC — mock localStorage
    localStorage.setItem(
      'cofrap-user',
      JSON.stringify({
        username: payload.username,
        password: payload.password,
        totpSecret: payload.totpSecret,
        createdAt: Date.now(),
        expired: false,
      }),
    )
    return { success: true }
  }
  return post('cofrap-register', payload)
}

/**
 * Authentifie un utilisateur avec son mot de passe et son code TOTP.
 */
export async function loginUser(payload: LoginPayload): Promise<ApiResult<{ username: string }>> {
  if (!BASE_URL) {
    // Mode PoC — validation locale (voir LoginView.vue)
    return { success: true, data: { username: payload.username } }
  }
  return post('cofrap-login', payload)
}

/**
 * Renouvelle les credentials d'un utilisateur existant.
 */
export async function renewCredentials(payload: RenewPayload): Promise<ApiResult> {
  if (!BASE_URL) {
    // Mode PoC — mock localStorage
    const stored = localStorage.getItem('cofrap-user')
    if (!stored) return { success: false, error: 'Utilisateur introuvable' }
    const user = JSON.parse(stored)
    localStorage.setItem(
      'cofrap-user',
      JSON.stringify({
        ...user,
        password: payload.newPassword,
        totpSecret: payload.newTotpSecret,
        createdAt: Date.now(),
        expired: false,
      }),
    )
    return { success: true }
  }
  return post('cofrap-renew', payload)
}

/**
 * Vérifie si un compte existe et s'il est expiré.
 */
export async function checkAccount(username: string): Promise<ApiResult<{ exists: boolean; expired: boolean }>> {
  if (!BASE_URL) {
    const stored = localStorage.getItem('cofrap-user')
    if (!stored) return { success: true, data: { exists: false, expired: false } }
    const user = JSON.parse(stored)
    return {
      success: true,
      data: { exists: user.username === username, expired: user.expired ?? false },
    }
  }
  return post('cofrap-check', { username })
}
