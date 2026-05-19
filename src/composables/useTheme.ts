import { ref } from 'vue'

const stored = localStorage.getItem('cofrap-theme')
const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
const isDark = ref(stored ? stored === 'dark' : prefersDark)

function applyTheme(dark: boolean) {
  document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light')
}

export function useTheme() {
  applyTheme(isDark.value)

  const toggleTheme = () => {
    isDark.value = !isDark.value
    localStorage.setItem('cofrap-theme', isDark.value ? 'dark' : 'light')
    applyTheme(isDark.value)
  }

  return { isDark, toggleTheme }
}
