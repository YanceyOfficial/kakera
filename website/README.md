# Kakera website

The site at https://kakera.yancey.app: TanStack Start with Solid, rendered on the server (Nitro) and deployed to
Vercel (`vercel.json`). Two pages: the home page, `src/routes/index.tsx`, and the App Store privacy policy,
`src/routes/privacy.tsx`.

```sh
bun install            # in this folder (it is its own package, not a workspace)
bun run dev            # http://localhost:3000
bun run build          # .output/ — what Vercel deploys (set the project's root directory to website/)
bun run start          # the built server
bun run typecheck
bun run shots ../screenshots   # simulator captures → public/shots/*.webp (see shots.json)
bun scripts/icons.mjs          # favicons from the app icon's layers (kakera/Resources/AppIcon.icon)
```

- The App Store link lives in `src/site.ts` (`APP_STORE_URL`); until it is set the buttons say "Coming to the App
  Store".
- Screenshots come from the iPhone 17 Pro simulator, light and dark (`<name>.png`, `<name>-dark.png`), with the
  starter decks — never a personal deck.
- The mark (`src/mark.ts`) is the app icon's geometry from `scripts/generate_app_icon.swift`; change them together.
- The privacy policy describes what the app actually does with data. Update it in the same change as anything it
  describes (a new network service, a new kind of stored data).
