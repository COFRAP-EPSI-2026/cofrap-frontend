import { watch } from 'vue'
import { useRoute } from 'vue-router'
import { useLang } from '@/composables/useLang'

const APP_NAME = 'COFRAP Cloud'

/**
 * Maintient `document.title` synchronisé avec la route courante ET la langue
 * active. Améliore le SEO (chaque route a son propre titre indexable) et
 * l'UX onglets navigateur (titres lisibles « Connexion — COFRAP Cloud »).
 *
 * Les libellés vivent dans `src/lang/{fr,en}.ts` sous `pageTitles.<route>` —
 * le job `i18n-parity` garantit la parité fr/en.
 *
 * À appeler une seule fois dans `App.vue` (au mount global).
 */
export function useDocumentTitle() {
  const route = useRoute()
  const { t, currentLang } = useLang()

  const apply = () => {
    const titles = (t as unknown as { pageTitles?: Record<string, string> }).pageTitles ?? {}
    const name = typeof route.name === 'string' ? route.name : ''
    const label = titles[name]
    document.title = label ? `${label} — ${APP_NAME}` : APP_NAME
  }

  // Réagir aux changements de route ET de langue.
  watch(() => route.name, apply, { immediate: true })
  watch(currentLang, apply)
}
