import '@fontsource-variable/instrument-sans/wdth.css'
import '@fontsource/zen-old-mincho/400.css'
import '@fontsource/zen-old-mincho/700.css'
import { createRootRoute, HeadContent, Scripts } from '@tanstack/solid-router'
import type { JSX } from 'solid-js'
import { Suspense } from 'solid-js'
import { HydrationScript } from 'solid-js/web'

import { SITE_URL } from '../site'
import { THEME_SCRIPT } from '../theme'

import styles from '../styles.css?url'

const title = 'Kakera: flashcards for hard words, in English and Japanese'
const description =
  'An iPhone flashcard app that writes each card with AI on your own key and schedules every review with FSRS-6. No account; your deck syncs through your own iCloud.'

export const Route = createRootRoute({
  head: () => ({
    meta: [
      { charSet: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      { title },
      { name: 'description', content: description },
      { name: 'theme-color', content: '#F7F7F5', media: '(prefers-color-scheme: light)' },
      { name: 'theme-color', content: '#141416', media: '(prefers-color-scheme: dark)' },
      { name: 'color-scheme', content: 'light dark' },
      { property: 'og:title', content: title },
      { property: 'og:description', content: description },
      { property: 'og:url', content: SITE_URL },
      { property: 'og:image', content: `${SITE_URL}/shots/revealed.webp` },
      { name: 'twitter:card', content: 'summary_large_image' }
    ],
    links: [
      { rel: 'stylesheet', href: styles },
      { rel: 'icon', type: 'image/svg+xml', href: '/favicon.svg' },
      { rel: 'icon', type: 'image/png', href: '/favicon.png' },
      { rel: 'apple-touch-icon', href: '/apple-touch-icon.png' },
      { rel: 'canonical', href: SITE_URL }
    ]
  }),
  shellComponent: RootDocument
})

function RootDocument(props: { children: JSX.Element }) {
  return (
    <html lang="en">
      <head>
        {/* Before anything paints: the stored light/dark choice, so the page never flashes the other one. */}
        <script innerHTML={THEME_SCRIPT} />
        <HydrationScript />
      </head>
      <body>
        <HeadContent />
        <Suspense>{props.children}</Suspense>
        <Scripts />
      </body>
    </html>
  )
}
