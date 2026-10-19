import { Link } from '@tanstack/solid-router'
import { AppStoreButton } from './app-store-button'
import { Mark } from './mark'
import { ThemeSwitch } from './theme-switch'

export function Header() {
  return (
    <header class="wrap flex flex-wrap items-center justify-between gap-4 py-5">
      <Link to="/" class="flex items-center gap-2.5 no-underline" aria-label="Kakera home">
        <Mark class="h-7 w-auto" />
        <span class="mincho text-[22px] font-bold tracking-[-0.01em]">Kakera</span>
      </Link>
      <div class="flex items-center gap-3">
        <ThemeSwitch />
        <AppStoreButton class="max-sm:hidden" />
      </div>
    </header>
  )
}
