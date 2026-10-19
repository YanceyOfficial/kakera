import { Link } from '@tanstack/solid-router'
import { CONTACT_EMAIL, ISSUES_URL } from '../site'

export function Footer() {
  return (
    <footer class="wrap mt-28 pb-12">
      {/* The icon's horizon, the page's last line. */}
      <div class="bg-ink h-[3px] rounded-full" />
      <div class="mt-6 flex flex-wrap items-baseline justify-between gap-x-8 gap-y-3 text-[15px] text-muted">
        <p class="m-0">
          <span class="mincho text-ink">欠片</span> (kakera) is Japanese for a fragment.
        </p>
        <nav class="flex gap-6">
          <Link to="/privacy" class="underline-offset-4 hover:underline">
            Privacy
          </Link>
          <a href={`mailto:${CONTACT_EMAIL}`} class="underline-offset-4 hover:underline">
            Contact
          </a>
          <a href={ISSUES_URL} class="underline-offset-4 hover:underline">
            Support
          </a>
        </nav>
      </div>
    </footer>
  )
}
