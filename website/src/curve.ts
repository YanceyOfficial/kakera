/**
 * The forgetting curve the review screen schedules by — FSRS-6's power curve with its default decay (w[20]):
 * R(t) = (1 + factor · t / S) ^ −decay, where factor makes R = 0.9 exactly when t = S. Reviews land where recall
 * falls to 0.9, and each one makes the next curve flatter (a larger stability S).
 */
const DECAY = 0.1542
const FACTOR = Math.pow(0.9, -1 / DECAY) - 1
export const retrievability = (t: number, stability: number) =>
  Math.pow(1 + (FACTOR * t) / stability, -DECAY)

/** A word reviewed "Good" each time it comes due: stabilities in days (illustrative, from FSRS-6's default weights). */
export const STABILITIES = [2.3, 7.9, 21, 52]

export const CHART = { width: 640, height: 260, days: 90, floor: 0.7 }

const x = (day: number) => (day / CHART.days) * CHART.width
const y = (r: number) => ((1 - r) / (1 - CHART.floor)) * CHART.height

/** The reviewed path (a saw: down to 0.9, back to 1), the review days, and where memory goes if the next is skipped. */
export function curvePaths() {
  let start = 0
  let reviewed = ''
  const reviews: { x: number; y: number }[] = []
  for (const s of STABILITIES) {
    const end = Math.min(start + s, CHART.days)
    for (let d = start; d <= end + 1e-9; d += 0.25) {
      reviewed += `${reviewed ? 'L' : 'M'}${x(d).toFixed(1)} ${y(retrievability(d - start, s)).toFixed(1)}`
    }
    if (start + s < CHART.days) reviews.push({ x: x(start + s), y: y(0.9) })
    start += s
  }
  // Skip the first review: the first curve carried on.
  let skipped = ''
  for (let d = STABILITIES[0]; d <= 21; d += 0.25) {
    skipped += `${skipped ? 'L' : 'M'}${x(d).toFixed(1)} ${y(retrievability(d, STABILITIES[0])).toFixed(1)}`
  }
  return { reviewed, skipped, reviews, target: y(0.9) }
}
