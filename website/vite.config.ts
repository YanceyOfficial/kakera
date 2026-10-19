import tailwindcss from '@tailwindcss/vite'
import { tanstackStart } from '@tanstack/solid-start/plugin/vite'
import { nitro } from 'nitro/vite'
import { defineConfig } from 'vite'
import solidPlugin from 'vite-plugin-solid'

// The Start plugin comes before Solid's (route generation and server functions need it first); Nitro builds the
// server output Vercel deploys (vercel.json).
export default defineConfig({
  resolve: { tsconfigPaths: true },
  plugins: [nitro(), tailwindcss(), tanstackStart(), solidPlugin({ ssr: true })]
})
