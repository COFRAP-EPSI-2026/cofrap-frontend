import { ref, watch } from 'vue'

type FontSize = 'default' | 'large' | 'larger'

interface A11yState {
  fontSize: FontSize
  highContrast: boolean
  reduceMotion: boolean
  enhancedFocus: boolean
  increasedSpacing: boolean
  readableFont: boolean
}

const stored: Partial<A11yState> = JSON.parse(localStorage.getItem('cofrap-a11y') ?? '{}')

const fontSize = ref<FontSize>(stored.fontSize ?? 'default')
const highContrast = ref(stored.highContrast ?? false)
const reduceMotion = ref(stored.reduceMotion ?? false)
const enhancedFocus = ref(stored.enhancedFocus ?? false)
const increasedSpacing = ref(stored.increasedSpacing ?? false)
const readableFont = ref(stored.readableFont ?? false)

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

  localStorage.setItem(
    'cofrap-a11y',
    JSON.stringify({
      fontSize: fontSize.value,
      highContrast: highContrast.value,
      reduceMotion: reduceMotion.value,
      enhancedFocus: enhancedFocus.value,
      increasedSpacing: increasedSpacing.value,
      readableFont: readableFont.value,
    }),
  )
}

watch(
  [fontSize, highContrast, reduceMotion, enhancedFocus, increasedSpacing, readableFont],
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
  }

  return { fontSize, highContrast, reduceMotion, enhancedFocus, increasedSpacing, readableFont, reset }
}
