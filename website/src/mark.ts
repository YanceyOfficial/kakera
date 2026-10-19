/**
 * The sliced sun, the app icon's geometry (scripts/generate_app_icon.swift, on its 1024 canvas): a sun cut by four
 * widening lines above a horizon. Each band is one fragment; together they make the sun. Change the two together.
 */
const cx = 512
const cy = 560
const r = 262
const cuts = [
  [548, 18],
  [608, 24],
  [672, 32],
  [744, 42]
] as const
export const HORIZON = { x: 170, y: 804, width: 684, height: 16 }

const fmt = (v: number) => v.toFixed(2)

/** The visible bands, top to bottom, each as one closed path between two horizontals of the circle. */
export const BANDS: string[] = (() => {
  const ranges: [number, number][] = []
  let top = cy - r
  for (const [y, h] of cuts) {
    ranges.push([top, y])
    top = y + h
  }
  ranges.push([top, HORIZON.y])
  const half = (y: number) => Math.sqrt(Math.max(0, r * r - (y - cy) * (y - cy)))
  return ranges.map(([t, b]) => {
    const [ht, hb] = [half(t), half(b)]
    return (
      `M${fmt(cx - ht)} ${fmt(t)}L${fmt(cx + ht)} ${fmt(t)}` +
      `A${r} ${r} 0 0 1 ${fmt(cx + hb)} ${fmt(b)}L${fmt(cx - hb)} ${fmt(b)}` +
      `A${r} ${r} 0 0 1 ${fmt(cx - ht)} ${fmt(t)}Z`
    )
  })
})()

/** The mark's box on the 1024 canvas: the sun's top to the horizon, side to side of the horizon. */
export const MARK_VIEWBOX = '170 290 684 540'
