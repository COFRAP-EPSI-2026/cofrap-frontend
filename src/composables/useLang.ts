import { reactive, ref } from 'vue'
import { fr } from '@/lang/fr'
import { en } from '@/lang/en'

type Lang = 'fr' | 'en'

const langs = { fr, en }
const currentLang = ref<Lang>((localStorage.getItem('cofrap-lang') as Lang) ?? 'fr')

// t est un objet réactif dont les clés sont remplacées à chaque changement de langue.
// Toutes les vues partagent la même référence — aucun changement nécessaire ailleurs.
const t = reactive({ ...langs[currentLang.value] })

document.documentElement.lang = currentLang.value

export function useLang() {
  const switchLang = () => {
    currentLang.value = currentLang.value === 'fr' ? 'en' : 'fr'
    localStorage.setItem('cofrap-lang', currentLang.value)
    document.documentElement.lang = currentLang.value
    Object.assign(t, langs[currentLang.value])
  }

  return { t, currentLang, switchLang }
}
