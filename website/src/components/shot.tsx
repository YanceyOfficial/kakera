/**
 * An iPhone screenshot in both appearances: public/shots/<name>.webp and <name>-dark.webp (made by `bun run shots`).
 * The page's theme (`data-theme` on <html>) shows one; the other stays hidden and, being lazy, is never fetched.
 */
export function Shot(props: { name: string; alt: string; class?: string; eager?: boolean }) {
  const loading = props.eager ? 'eager' : 'lazy'
  return (
    <>
      <img
        src={`/shots/${props.name}.webp`}
        alt={props.alt}
        width={1206}
        height={2622}
        loading={loading}
        class={`shot only-light ${props.class ?? ''}`}
      />
      <img
        src={`/shots/${props.name}-dark.webp`}
        alt={props.alt}
        width={1206}
        height={2622}
        loading={loading}
        class={`shot only-dark ${props.class ?? ''}`}
      />
    </>
  )
}
