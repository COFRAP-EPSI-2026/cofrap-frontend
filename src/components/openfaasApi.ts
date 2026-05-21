/**
 * Client API du backend COFRAP (3 fonctions OpenFaaS).
 *
 * Les appels passent par `/api/*`, un chemin **relatif** :
 *  - en production : le nginx du pod proxifie `/api` vers le gateway OpenFaaS ;
 *  - en développement : Vite proxifie `/api` (cf. `vite.config.ts`).
 * Même origine dans les deux cas → aucun CORS, aucune URL absolue à configurer.
 *
 * Contrat de l'API : voir `docs/openapi.yaml` du dépôt backend.
 */
import axios, { AxiosError } from 'axios'

const api = axios.create({
  baseURL: '/api',
  headers: { 'Content-Type': 'application/json' },
  timeout: 30_000,
})

// --- Types de réponse ---------------------------------------------------------

export interface GeneratePasswordResponse {
  username: string
  /** Timestamp Unix (secondes) de génération. */
  gendate: number
  /** QR code PNG encodé en base64 — contient le mot de passe en clair (usage unique). */
  qrcode_png_base64: string
  /** Mot de passe en clair — présent uniquement au moment de la génération. */
  password?: string
}

export interface Generate2faResponse {
  username: string
  gendate: number
  /** URI `otpauth://totp/...` à importer dans une app authenticator. */
  otpauth_uri: string
  qrcode_png_base64: string
}

export interface AuthenticateResponse {
  authenticated: boolean
  expired: boolean
  /** Présent uniquement quand `authenticated === true`. */
  username?: string
  /** Présent quand `expired === true` — ex. `regenerate_password_and_2fa`. */
  action?: string
}

// --- Appels -------------------------------------------------------------------

/** Génère (ou réinitialise) le mot de passe d'un utilisateur. */
export async function generatePassword(username: string): Promise<GeneratePasswordResponse> {
  const { data } = await api.post<GeneratePasswordResponse>('/function/generate-password', {
    username,
  })
  return data
}

/** Génère le secret TOTP d'un utilisateur existant. */
export async function generate2fa(username: string): Promise<Generate2faResponse> {
  const { data } = await api.post<Generate2faResponse>('/function/generate-2fa', { username })
  return data
}

/**
 * Authentifie un utilisateur.
 *
 * Renvoie un objet 200 même si le compte est expiré (`expired: true` +
 * `action`). Lève une erreur (à capturer) pour les cas 401 / 404 / 409 / 422.
 */
export async function authenticate(
  username: string,
  password: string,
  otp: string,
): Promise<AuthenticateResponse> {
  const { data } = await api.post<AuthenticateResponse>('/function/authenticate-user', {
    username,
    password,
    otp,
  })
  return data
}

// --- Gestion d'erreur ---------------------------------------------------------

/**
 * Extrait un message lisible d'une erreur d'appel API.
 * Le backend renvoie ses erreurs sous la forme `{ "detail": "..." }` (FastAPI).
 */
export function apiErrorMessage(error: unknown): string {
  if (error instanceof AxiosError) {
    const detail = (error.response?.data as { detail?: unknown } | undefined)?.detail
    if (typeof detail === 'string') return detail
    if (error.response) return `HTTP ${error.response.status}`
    return error.message
  }
  return 'unexpected error'
}

export default api
