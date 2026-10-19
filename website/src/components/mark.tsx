import { For } from 'solid-js'

import { BANDS, HORIZON, MARK_VIEWBOX } from '../mark'

/**
 * The sliced sun in the page's colours. `assemble` plays the page's one moment of motion: the bands arrive from
 * alternate sides and close into the sun, the way the cards of a deck add up to a language.
 */
export function Mark(props: { class?: string; assemble?: boolean; title?: string }) {
  return (
    <svg
      viewBox={MARK_VIEWBOX}
      class={`mark ${props.assemble ? 'mark-assemble' : ''} ${props.class ?? ''}`}
      role={props.title ? 'img' : undefined}
      aria-label={props.title}
      aria-hidden={props.title ? undefined : 'true'}
    >
      <For each={BANDS}>
        {(d, index) => <path d={d} class="mark-band" style={{ '--i': index() }} />}
      </For>
      <rect
        x={HORIZON.x}
        y={HORIZON.y}
        width={HORIZON.width}
        height={HORIZON.height}
        rx={HORIZON.height / 2}
        class="mark-horizon"
      />
    </svg>
  )
}
