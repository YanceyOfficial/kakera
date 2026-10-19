// bun scripts/icons.mjs: the favicons (public/favicon.svg, favicon.png, apple-touch-icon.png, icon.png) from the app
// icon's own layers in ../kakera/Resources/AppIcon.icon — so the site's mark is always the app's.
import { readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

import sharp from 'sharp'

const root = new URL('..', import.meta.url).pathname
const assets = join(root, '../kakera/Resources/AppIcon.icon/Assets')
const inner = (file) => readFileSync(join(assets, file), 'utf8').replace(/^<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '')

// The light icon on a squircle-ish rounded square (iOS masks the real one; a browser tab needs its own corners).
const svg = (radius) =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">` +
  `<clipPath id="c"><rect width="1024" height="1024" rx="${radius}"/></clipPath><g clip-path="url(#c)">` +
  inner('background.svg') +
  inner('sun.svg').replaceAll('id="g"', 'id="s"').replaceAll('url(#g)', 'url(#s)') +
  inner('horizon.svg') +
  `</g></svg>`

writeFileSync(join(root, 'public/favicon.svg'), svg(230))
for (const [file, size, radius] of [
  ['favicon.png', 64, 230],
  ['icon.png', 256, 230],
  ['apple-touch-icon.png', 180, 0]
]) {
  await sharp(Buffer.from(svg(radius))).resize(size, size).png().toFile(join(root, 'public', file))
  console.log(file, size)
}
