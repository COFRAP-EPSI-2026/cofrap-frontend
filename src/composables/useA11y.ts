import { ref, watch } from 'vue'

type FontSize = 'default' | 'large' | 'larger'

// Charge la feuille OpenDyslexic à la demande — une seule fois pour toute la
// session. Évite de bloquer le 1er render pour 95 % des visiteurs qui ne
// l'activeront jamais. Cf. perf Lighthouse (`render-blocking-insight`).
const OPENDYSLEXIC_HREF = 'https://fonts.cdnfonts.com/css/opendyslexic'
let openDyslexicLoaded = false
function loadOpenDyslexic() {
  if (openDyslexicLoaded || typeof document === 'undefined') return
  openDyslexicLoaded = true
  // Pré-connexion DNS+TLS pour réduire le délai au prochain GET.
  const preconnect = document.createElement('link')
  preconnect.rel = 'preconnect'
  preconnect.href = 'https://fonts.cdnfonts.com'
  preconnect.crossOrigin = 'anonymous'
  document.head.appendChild(preconnect)

  const sheet = document.createElement('link')
  sheet.rel = 'stylesheet'
  sheet.href = OPENDYSLEXIC_HREF
  document.head.appendChild(sheet)
}

interface A11yState {
  fontSize: FontSize
  highContrast: boolean
  reduceMotion: boolean
  enhancedFocus: boolean
  increasedSpacing: boolean
  readableFont: boolean
  audioReading: boolean
}

const stored: Partial<A11yState> = JSON.parse(localStorage.getItem('cofrap-a11y') ?? '{}')

const fontSize = ref<FontSize>(stored.fontSize ?? 'default')
const highContrast = ref(stored.highContrast ?? false)
const reduceMotion = ref(stored.reduceMotion ?? false)
const enhancedFocus = ref(stored.enhancedFocus ?? false)
const increasedSpacing = ref(stored.increasedSpacing ?? false)
const readableFont = ref(stored.readableFont ?? false)
const audioReading = ref(stored.audioReading ?? false)

function flag(val: boolean) {
  return val ? 'on' : 'off'
}

function applyA11y() {
  const html = document.documentElement
  html.setAttribute('data-font-size', fontSize.value)
  html.setAttribute('data-contrast', highContrast.value ? 'high' : 'default')
  html.setAttribute('data-reduce-motion', flag(reduceMotion.value))
  html.setAttribute('data-enhanced-focus', flag(enhancedFocus.value))
  html.setAttribute('data-spacing', increasedSpacing.value ? 'large' : 'default')
  html.setAttribute('data-readable-font', flag(readableFont.value))

  // Charge la police OpenDyslexic uniquement quand l'option est activée.
  if (readableFont.value) loadOpenDyslexic()

  localStorage.setItem(
    'cofrap-a11y',
    JSON.stringify({
      fontSize: fontSize.value,
      highContrast: highContrast.value,
      reduceMotion: reduceMotion.value,
      enhancedFocus: enhancedFocus.value,
      increasedSpacing: increasedSpacing.value,
      readableFont: readableFont.value,
      audioReading: audioReading.value,
    }),
  )
}

watch(
  [
    fontSize,
    highContrast,
    reduceMotion,
    enhancedFocus,
    increasedSpacing,
    readableFont,
    audioReading,
  ],
  applyA11y,
  { immediate: true },
)

export function useA11y() {
  const reset = () => {
    fontSize.value = 'default'
    highContrast.value = false
    reduceMotion.value = false
    enhancedFocus.value = false
    increasedSpacing.value = false
    readableFont.value = false
    audioReading.value = false
  }

  return {
    fontSize,
    highContrast,
    reduceMotion,
    enhancedFocus,
    increasedSpacing,
    readableFont,
    audioReading,
    reset,
  }
}
