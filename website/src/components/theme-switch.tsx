import type { JSX } from 'solid-js'
import { createSignal, For, onMount } from 'solid-js'

import { readTheme, setTheme, type ThemeChoice } from '../theme'

const MODES: { value: ThemeChoice; label: string; icon: () => JSX.Element }[] = [
  { value: 'system', label: 'Match the system', icon: SystemIcon },
  { value: 'light', label: 'Light', icon: SunIcon },
  { value: 'dark', label: 'Dark', icon: MoonIcon }
]

/** Light, dark or the system's, as exodus's appearance switch: one row of three, the chosen one filled. */
export function ThemeSwitch() {
  const [choice, setChoice] = createSignal<ThemeChoice>('system')
  onMount(() => setChoice(readTheme()))
  return (
    <div class="theme-switch" role="radiogroup" aria-label="Appearance">
      <For each={MODES}>
        {(mode) => (
          <button
            type="button"
            role="radio"
            aria-checked={choice() === mode.value}
            aria-label={mode.label}
            title={mode.label}
            onClick={() => {
              setChoice(mode.value)
              setTheme(mode.value)
            }}
          >
            {mode.icon()}
          </button>
        )}
      </For>
    </div>
  )
}

function SystemIcon() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true">
      <rect
        x="3"
        y="4.5"
        width="18"
        height="12"
        rx="1.5"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
      />
      <path d="M9 20h6M12 16.5V20" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
    </svg>
  )
}

function SunIcon() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true">
      <circle cx="12" cy="12" r="4" fill="none" stroke="currentColor" stroke-width="2" />
      <path
        d="M12 2.5v2.5M12 19v2.5M2.5 12H5M19 12h2.5M5.3 5.3l1.8 1.8M16.9 16.9l1.8 1.8M5.3 18.7l1.8-1.8M16.9 7.1l1.8-1.8"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
      />
    </svg>
  )
}

function MoonIcon() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true">
      <path
        d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5Z"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linejoin="round"
      />
    </svg>
  )
}
