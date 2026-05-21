<template>
  <Teleport to="body">
    <Transition name="help-backdrop">
      <div
        v-if="open"
        class="help-backdrop"
        aria-hidden="true"
        @click="$emit('close')"
      />
    </Transition>

    <Transition name="help-panel">
      <div
        v-if="open"
        id="help-panel"
        ref="panelRef"
        class="help-panel"
        role="dialog"
        aria-modal="true"
        :aria-label="t.help.panelTitle"
        @keydown.esc="$emit('close')"
      >
        <div class="help-panel__header">
          <h2 class="help-panel__title">
            <HelpCircle :size="18" aria-hidden="true" />
            {{ t.help.panelTitle }}
          </h2>
          <button
            ref="closeRef"
            type="button"
            class="help-panel__close"
            :aria-label="t.help.close"
            @click="$emit('close')"
          >
            <X :size="16" aria-hidden="true" />
          </button>
        </div>

        <div class="help-panel__body">
          <div
            v-for="section in sections"
            :key="section.id"
            class="help-section"
          >
            <div class="help-section__icon-wrap" aria-hidden="true">
              <component :is="section.icon" :size="17" />
            </div>
            <div class="help-section__content">
              <h3 class="help-section__title">{{ section.title }}</h3>
              <p class="help-section__text">{{ section.text }}</p>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'
import { Accessibility, Clock, HelpCircle, ShieldAlert, ShieldCheck, X } from 'lucide-vue-next'
import { useLang } from '@/composables/useLang'

const props = defineProps<{ open: boolean }>()
defineEmits<{ close: [] }>()

const { t } = useLang()

const panelRef = ref<HTMLElement | null>(null)
const closeRef = ref<HTMLButtonElement | null>(null)

const sections = computed(() => [
  { id: 1, icon: ShieldCheck, title: t.help.section1Title, text: t.help.section1Text },
  { id: 2, icon: Clock, title: t.help.section2Title, text: t.help.section2Text },
  { id: 3, icon: ShieldAlert, title: t.help.section3Title, text: t.help.section3Text },
  { id: 4, icon: Accessibility, title: t.help.section4Title, text: t.help.section4Text },
])

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
