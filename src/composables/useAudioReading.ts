import { watch } from 'vue'
import { useA11y } from '@/composables/useA11y'
import { useLang } from '@/composables/useLang'

// Balises et rôles dont on lit le contenu
const READABLE_TAGS = new Set(['P', 'H1', 'H2', 'H3', 'H4', 'LI', 'LABEL', 'SPAN', 'TD', 'TH'])
const INTERACTIVE_TAGS = new Set(['BUTTON', 'A', 'INPUT', 'SELECT', 'TEXTAREA'])

function getReadableText(el: HTMLElement): string {
  // Priorité : aria-label > aria-labelledby > placeholder > innerText
  const ariaLabel = el.getAttribute('aria-label')
  if (ariaLabel) return ariaLabel

  const labelledById = el.getAttribute('aria-labelledby')
  if (labelledById) {
    const labelEl = document.getElementById(labelledById)
    if (labelEl?.innerText) return labelEl.innerText
  }

  if (el instanceof HTMLInputElement && el.placeholder) return el.placeholder

  return el.innerText?.trim() ?? ''
}

function speak(text: string, lang: string) {
  if (!text || !window.speechSynthesis) return
  window.speechSynthesis.cancel()

  const utterance = new SpeechSynthesisUtterance(text)
  utterance.lang = lang === 'fr' ? 'fr-FR' : 'en-US'
  utterance.rate = 0.95
  utterance.pitch = 1

  window.speechSynthesis.speak(utterance)
}

export function setupAudioReading() {
  const { audioReading } = useA11y()
  const { currentLang } = useLang()

  function handleFocus(e: FocusEvent) {
    const el = e.target as HTMLElement
    const text = getReadableText(el)
    if (text) speak(text, currentLang.value)
  }

  function handleMouseEnter(e: MouseEvent) {
    const el = e.target as HTMLElement
    if (!READABLE_TAGS.has(el.tagName) && !INTERACTIVE_TAGS.has(el.tagName)) return
    const text = getReadableText(el)
    if (text) speak(text, currentLang.value)
  }

  watch(
    audioReading,
    (active) => {
      if (active) {
        document.addEventListener('focusin', handleFocus)
        document.addEventListener('mouseover', handleMouseEnter)
      } else {
        document.removeEventListener('focusin', handleFocus)
        document.removeEventListener('mouseover', handleMouseEnter)
        window.speechSynthesis?.cancel()
      }
    },
    { immediate: true },
  )
}
