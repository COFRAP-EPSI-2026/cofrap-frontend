<template>
  <Teleport to="body">
    <Transition name="a11y-panel">
      <div
        v-if="open"
        id="a11y-panel"
        ref="panelRef"
        class="a11y-panel"
        role="dialog"
        aria-modal="true"
        :aria-label="t.a11y.panelTitle"
        @keydown.esc="$emit('close')"
      >
        <!-- En-tête -->
        <div class="a11y-panel__header">
          <h2 class="a11y-panel__title">
            <Accessibility :size="20" aria-hidden="true" />
            {{ t.a11y.panelTitle }}
          </h2>
          <button
            ref="closeRef"
            type="button"
            class="a11y-panel__close"
            :aria-label="t.a11y.close"
            @click="$emit('close')"
          >
            <X :size="18" aria-hidden="true" />
          </button>
        </div>

        <!-- Corps -->
        <div class="a11y-panel__body">
          <!-- Taille du texte -->
          <div class="a11y-font-size-section">
            <p class="a11y-section-label">{{ t.a11y.fontSize }}</p>
            <div class="a11y-font-size" role="group" :aria-label="t.a11y.fontSize">
              <button
                type="button"
                class="a11y-font-size__btn"
                :class="{ 'a11y-font-size__btn--active': fontSize === 'default' }"
                :aria-pressed="fontSize === 'default'"
                aria-label="Taille normale"
                @click="fontSize = 'default'"
              >
                A
              </button>
              <button
                type="button"
                class="a11y-font-size__btn a11y-font-size__btn--large"
                :class="{ 'a11y-font-size__btn--active': fontSize === 'large' }"
                :aria-pressed="fontSize === 'large'"
                aria-label="Taille grande"
                @click="fontSize = 'large'"
              >
                A
              </button>
              <button
                type="button"
                class="a11y-font-size__btn a11y-font-size__btn--larger"
                :class="{ 'a11y-font-size__btn--active': fontSize === 'larger' }"
                :aria-pressed="fontSize === 'larger'"
                aria-label="Taille très grande"
                @click="fontSize = 'larger'"
              >
                A
              </button>
            </div>
          </div>

          <div class="a11y-list">
            <!-- Contraste renforcé -->
            <div class="a11y-row">
              <label class="a11y-row__label" for="toggle-contrast">
                <SunMoon :size="16" aria-hidden="true" />
                {{ t.a11y.highContrast }}
              </label>
              <button
                id="toggle-contrast"
                type="button"
                class="a11y-switch"
                role="switch"
                :aria-checked="highContrast"
                @click="highContrast = !highContrast"
              >
                <span class="a11y-switch__thumb" />
              </button>
            </div>

            <!-- Réduire les animations -->
            <div class="a11y-row">
              <label class="a11y-row__label" for="toggle-motion">
                <Zap :size="16" aria-hidden="true" />
                {{ t.a11y.reduceMotion }}
              </label>
              <button
                id="toggle-motion"
                type="button"
                class="a11y-switch"
                role="switch"
                :aria-checked="reduceMotion"
                @click="reduceMotion = !reduceMotion"
              >
                <span class="a11y-switch__thumb" />
              </button>
            </div>

            <!-- Focus clavier renforcé -->
            <div class="a11y-row">
              <label class="a11y-row__label" for="toggle-focus">
                <Keyboard :size="16" aria-hidden="true" />
                {{ t.a11y.enhancedFocus }}
              </label>
              <button
                id="toggle-focus"
                type="button"
                class="a11y-switch"
                role="switch"
                :aria-checked="enhancedFocus"
                @click="enhancedFocus = !enhancedFocus"
              >
                <span class="a11y-switch__thumb" />
              </button>
            </div>

            <!-- Espacement augmenté -->
            <div class="a11y-row">
              <label class="a11y-row__label" for="toggle-spacing">
                <AlignJustify :size="16" aria-hidden="true" />
                {{ t.a11y.increasedSpacing }}
              </label>
              <button
                id="toggle-spacing"
                type="button"
                class="a11y-switch"
                role="switch"
                :aria-checked="increasedSpacing"
                @click="increasedSpacing = !increasedSpacing"
              >
                <span class="a11y-switch__thumb" />
              </button>
            </div>

            <!-- Police plus lisible -->
            <div class="a11y-row">
              <label class="a11y-row__label" for="toggle-font">
                <Type :size="16" aria-hidden="true" />
                {{ t.a11y.readableFont }}
              </label>
              <button
                id="toggle-font"
                type="button"
                class="a11y-switch"
                role="switch"
                :aria-checked="readableFont"
                @click="readableFont = !readableFont"
              >
                <span class="a11y-switch__thumb" />
              </button>
            </div>

            <!-- Lecture audio -->
            <div class="a11y-row">
              <label class="a11y-row__label" for="toggle-audio">
                <Volume2 :size="16" aria-hidden="true" />
                {{ t.a11y.audioReading }}
              </label>
              <button
                id="toggle-audio"
                type="button"
                class="a11y-switch"
                role="switch"
                :aria-checked="audioReading"
                @click="audioReading = !audioReading"
              >
                <span class="a11y-switch__thumb" />
              </button>
            </div>
          </div>

          <!-- Bandeau actif lecture audio -->
          <Transition name="audio-hint">
            <p v-if="audioReading" class="a11y-audio-hint" aria-live="polite">
              <Volume2 :size="13" aria-hidden="true" />
              {{ t.a11y.audioReadingActive }}
            </p>
          </Transition>

          <!-- Réinitialiser -->
          <button type="button" class="a11y-reset" @click="reset">
            <RotateCcw :size="14" aria-hidden="true" />
            {{ t.a11y.reset }}
          </button>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup lang="ts">
import { nextTick, ref, watch } from 'vue'
import {
  Accessibility,
  AlignJustify,
  Keyboard,
  RotateCcw,
  SunMoon,
  Type,
  Volume2,
  X,
  Zap,
} from 'lucide-vue-next'
import { useLang } from '@/composables/useLang'
import { useA11y } from '@/composables/useA11y'

const props = defineProps<{ open: boolean }>()
defineEmits<{ close: [] }>()

const { t } = useLang()
const {
  fontSize,
  highContrast,
  reduceMotion,
  enhancedFocus,
  increasedSpacing,
  readableFont,
  audioReading,
  reset,
} = useA11y()

const panelRef = ref<HTMLElement | null>(null)
const closeRef = ref<HTMLElement | null>(null)

// Focus le bouton fermer à l'ouverture
watch(
  () => props.open,
  async (val) => {
    if (val) {
      await nextTick()
      closeRef.value?.focus()
    }
  },
)
</script>
