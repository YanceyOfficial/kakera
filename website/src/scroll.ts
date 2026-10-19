import { onCleanup, onMount } from 'solid-js'

/** Whether the visitor asked for less motion; scroll-linked scenes then stay at rest. */
export const prefersReducedMotion = () =>
  typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches

/**
 * Tracks how far a tall section has been scrolled through its pinned stretch — 0 when its top reaches the top of the
 * viewport, 1 when its bottom reaches the bottom — writes it to `--p` on the element (for CSS transforms) and hands it
 * to `onProgress`. Read once per frame, so the page scrolls on the compositor and the scene follows on the next paint.
 */
export function useScrollProgress(element: () => HTMLElement | undefined, onProgress?: (progress: number) => void) {
  onMount(() => {
    const el = element()
    if (!el || prefersReducedMotion()) return
    let frame = 0
    const update = () => {
      frame = 0
      const rect = el.getBoundingClientRect()
      const distance = rect.height - innerHeight
      const progress = distance > 0 ? Math.min(1, Math.max(0, -rect.top / distance)) : 0
      el.style.setProperty('--p', progress.toFixed(4))
      onProgress?.(progress)
    }
    const schedule = () => {
      if (!frame) frame = requestAnimationFrame(update)
    }
    update()
    addEventListener('scroll', schedule, { passive: true })
    addEventListener('resize', schedule)
    onCleanup(() => {
      cancelAnimationFrame(frame)
      removeEventListener('scroll', schedule)
      removeEventListener('resize', schedule)
    })
  })
}
