import { createFileRoute, Link } from '@tanstack/solid-router'
import { createSignal, For } from 'solid-js'

import { AppStoreButton } from '../components/app-store-button'
import { Footer } from '../components/footer'
import { Header } from '../components/header'
import { Mark } from '../components/mark'
import { Shot } from '../components/shot'
import { CHART, curvePaths } from '../curve'
import { useScrollProgress } from '../scroll'

export const Route = createFileRoute('/')({ component: Home })

function Home() {
  return (
    <>
      <Header />
      <main>
        <Hero />
        <Schedule />
        <Card />
        <Japanese />
        <Tour />
        <Privacy />
      </main>
      <Footer />
    </>
  )
}

const h2 = 'mincho text-[clamp(2rem,4.2vw,3.1rem)] leading-[1.12] font-bold tracking-[-0.01em]'
const lead = 'mt-5 max-w-[36rem] text-[18px] leading-[1.65] text-muted'

/**
 * The opening scene, pinned while it plays: as the page scrolls, the words lift away and the phone rises from below
 * the fold into the middle of the screen (`--p`, see `.hero` in styles.css). With reduced motion it is a still layout.
 */
function Hero() {
  let hero: HTMLElement | undefined
  useScrollProgress(() => hero)
  return (
    <section ref={hero} class="hero">
      <div class="hero-stage">
        <div class="hero-copy wrap">
          <Mark assemble class="mx-auto w-[min(7.5rem,32%)]" title="Kakera" />
          <h1 class="mincho mx-auto mt-8 max-w-[34rem] text-[clamp(2.5rem,6.4vw,4.6rem)] leading-[1.06] font-bold tracking-[-0.02em]">
            Hard words, one piece at a time.
          </h1>
          <p class="mx-auto mt-5 max-w-[34rem] text-[clamp(16px,2vw,19px)] leading-[1.6] text-muted">
            A flashcard app for iPhone for the words that will not stick, in English and Japanese. AI writes each card
            on your own key; a memory model decides the day you see it again.
          </p>
          <div class="mt-7 flex flex-wrap items-center justify-center gap-x-5 gap-y-3">
            <AppStoreButton />
            <span class="text-[15px] text-muted">iPhone, iOS 17 or later. No account.</span>
          </div>
        </div>
        <div class="hero-phone">
          <Shot
            name="review"
            eager
            alt="The review screen: the front of a card with a word to recall, and a progress bar for the session."
          />
        </div>
      </div>
    </section>
  )
}

/** The review screen's rating bar, with the intervals it would show for a word seen once before. */
const GRADES = [
  { name: 'Again', when: '1 min', class: 'again' },
  { name: 'Hard', when: '10 min', class: '' },
  { name: 'Good', when: '3 days', class: 'good' },
  { name: 'Easy', when: '9 days', class: '' }
]

function Schedule() {
  const { reviewed, skipped, reviews, target } = curvePaths()
  return (
    <section id="schedule" class="border-rule border-t py-24">
      <div class="wrap grid gap-x-16 gap-y-12 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
        <div>
          <h2 class={`${h2} reveal`}>Review a word just before you would forget it.</h2>
          <p class={lead}>
            Every word keeps three numbers: how stable it is in your memory, how hard it is for
            you, and how likely you are to recall it today. Kakera schedules with FSRS-6, the
            open model behind modern Anki, and brings a word back when that chance falls to 90%.
          </p>
          <p class="mt-4 max-w-[36rem] text-[18px] leading-[1.65] text-muted">
            Each review you pass makes the curve flatter, so the gaps grow from days to weeks. Fail
            one and the word returns within the session.
          </p>
        </div>
        <figure class="reveal m-0 self-end">
          <svg
            viewBox={`-44 -14 ${CHART.width + 52} ${CHART.height + 46}`}
            class="w-full overflow-visible"
            role="img"
            aria-label="Recall probability over 90 days: it falls from 100% to 90% before each review, and each time it falls more slowly. Skipping the first review lets it fall to about 70% within three weeks."
          >
            <line
              x1="0"
              x2={CHART.width}
              y1={target}
              y2={target}
              class="stroke-rule"
              stroke-width="1.5"
              stroke-dasharray="3 5"
            />
            <text x="-10" y={target + 4} text-anchor="end" class="fill-muted text-[13px]">
              90%
            </text>
            <text x="-10" y="4" text-anchor="end" class="fill-muted text-[13px]">
              100%
            </text>
            <path d={skipped} fill="none" class="stroke-again" stroke-width="2" stroke-dasharray="5 6" opacity="0.7" />
            <path d={reviewed} fill="none" class="stroke-tokiwa" stroke-width="3" stroke-linejoin="round" />
            <For each={reviews}>
              {(review) => <circle cx={review.x} cy={review.y} r="5.5" class="fill-paper stroke-tokiwa" stroke-width="3" />}
            </For>
            <line x1="0" x2={CHART.width} y1={CHART.height} y2={CHART.height} class="stroke-ink" stroke-width="1.5" />
            <For each={[0, 30, 60, 90]}>
              {(day) => (
                <text
                  x={(day / CHART.days) * CHART.width}
                  y={CHART.height + 24}
                  text-anchor={day === 0 ? 'start' : day === 90 ? 'end' : 'middle'}
                  class="fill-muted text-[13px]"
                >
                  {day === 0 ? 'Day 0' : `${day}`}
                </text>
              )}
            </For>
          </svg>
          <figcaption class="mt-3 flex flex-wrap gap-x-6 gap-y-1 text-[14px] text-muted">
            <span>
              <span class="text-tokiwa">●</span> A review each time recall reaches 90%
            </span>
            <span>
              <span class="text-again">- -</span> The first review skipped
            </span>
          </figcaption>
        </figure>
      </div>
      <div class="wrap mt-20 grid items-center gap-x-16 gap-y-12 md:grid-cols-[minmax(0,22rem)_1fr]">
        <div class="drift mx-auto w-full max-w-[19rem]">
          <Shot
            name="revealed"
            alt="The back of a card: meaning, examples, and the four rating buttons, each showing its next interval."
          />
        </div>
        <div class="reveal">
          <h3 class="mincho text-[clamp(1.6rem,3vw,2.2rem)] leading-tight font-bold">
            You choose the next date, knowingly.
          </h3>
          <p class={lead}>
            Turn the card and rate how it went. Each button says when the word will come back, worked
            out for that word before you tap.
          </p>
          <div class="mt-8 grid max-w-[28rem] grid-cols-4 gap-2 text-[15px]" aria-label="The rating buttons">
            <For each={GRADES}>
              {(grade) => (
                <div class={`grade ${grade.class}`}>
                  {grade.name}
                  <small>{grade.when}</small>
                </div>
              )}
            </For>
          </div>
        </div>
      </div>
    </section>
  )
}

function Card() {
  return (
    <section id="cards" class="border-rule border-t py-24">
      <div class="wrap grid items-start gap-x-16 gap-y-12 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
        <div>
          <h2 class={`${h2} reveal`}>A card that explains the word, not just translates it.</h2>
          <p class={lead}>
            Paste a list of words and Kakera writes a card for each one: the meaning in Chinese and
            in English, examples, where the word comes from, its parts, the words it is confused
            with, and the phrases it lives in.
          </p>
          <p class="mt-4 max-w-[36rem] text-[18px] leading-[1.65] text-muted">
            It runs on your own Claude or OpenAI key, kept in the iPhone's Keychain. Pick any model
            your key can use.
          </p>
        </div>
        <article class="entry drift p-7 md:p-9" aria-label="An example card">
          <header class="flex flex-wrap items-baseline gap-x-4 gap-y-1">
            <h3 class="mincho m-0 text-[2.6rem] leading-none font-bold">ephemeral</h3>
            <span class="text-[17px] text-muted">/ɪˈfem(ə)rəl/</span>
          </header>
          <p class="mt-3 text-[17px]">
            <span class="text-muted">adj.</span> 短暂的；转瞬即逝的
          </p>
          <dl class="mt-7 grid gap-5 text-[16px]">
            <div>
              <dt>Mnemonic</dt>
              <dd>A mayfly is an ephemeron: it lives for a single day.</dd>
            </div>
            <div>
              <dt>Etymology</dt>
              <dd>
                Greek <i>ephēmeros</i>, “lasting only a day”, from <i>epi</i> “on” and{' '}
                <i>hēmera</i> “day”.
              </dd>
            </div>
            <div>
              <dt>Collocations</dt>
              <dd>ephemeral fame · an ephemeral pleasure</dd>
            </div>
            <div>
              <dt>Confused with</dt>
              <dd>ethereal, which means light and delicate, not short-lived.</dd>
            </div>
          </dl>
        </article>
      </div>
    </section>
  )
}

function Japanese() {
  return (
    <section id="japanese" class="border-rule border-t py-24">
      <div class="wrap grid items-center gap-x-16 gap-y-12 md:grid-cols-[1fr_minmax(0,22rem)]">
        <div>
          <p lang="ja" class="slide-x mincho m-0 text-[clamp(4rem,10vw,7rem)] leading-[1.3] font-bold">
            <ruby class="ruby">
              木漏<rt>こも</rt>
            </ruby>
            れ
            <ruby class="ruby">
              日<rt>び</rt>
            </ruby>
          </p>
          <p class="text-muted text-[15px]">Sunlight through the leaves of trees.</p>
          <h2 class={`${h2} reveal mt-10`}>Japanese, with the readings on top.</h2>
          <p class={lead}>
            Switch the deck to Japanese and every sentence carries furigana. Cards give the kana
            reading with its pitch accent, split the word into morae, and take the kanji apart. In a
            quiz, hiragana and katakana count as the same answer.
          </p>
          <p class="mt-4 max-w-[36rem] text-[18px] leading-[1.65] text-muted">
            English and Japanese keep separate decks, reviews and stories. Hide the readings once you
            no longer need them.
          </p>
        </div>
        <div class="drift mx-auto w-full max-w-[19rem]">
          <Shot
            name="revealed-ja"
            alt="A Japanese card: 懐かしい with its reading and pitch accent, and example sentences with furigana."
          />
        </div>
      </div>
    </section>
  )
}

const SCREENS = [
  {
    name: 'words',
    title: 'Every word, one search away.',
    text: 'Search the deck, filter by tag, and add more by pasting a list: Kakera writes their cards together.',
    alt: 'The word list with a search field and tags.'
  },
  {
    name: 'detail',
    title: 'The whole card, and notes of your own.',
    text: 'Meaning, examples, similar words and collocations, with room for what the textbook leaves out.',
    alt: 'A word’s detail page with meaning, examples and similar words.'
  },
  {
    name: 'stats',
    title: 'Watch the forgetting curve flatten.',
    text: 'How well the deck is held today, how mature it is, what will slip this week, and your streak.',
    alt: 'The stats screen: streak, forgetting curve and memory maturity.'
  },
  {
    name: 'story',
    title: 'A story made of today’s words.',
    text: 'A short passage that uses what you just reviewed, each word a tap away from its card.',
    alt: 'The daily story with today’s words highlighted.'
  }
]

/**
 * The tour, as Apple's product pages tell one: the phone stays pinned while the captions scroll past it, and its
 * screen turns to the one each caption describes. On a narrow screen each caption simply carries its own picture.
 */
function Tour() {
  let tour: HTMLDivElement | undefined
  const [active, setActive] = createSignal(0)
  useScrollProgress(
    () => tour,
    (progress) => setActive(Math.min(SCREENS.length - 1, Math.round(progress * (SCREENS.length - 1))))
  )
  return (
    <section id="screens" class="border-rule border-t pt-24">
      <div class="wrap">
        <h2 class={`${h2} reveal`}>Everything else, briefly.</h2>
        <p class={`${lead} reveal`}>
          A home-screen widget with what is due, a daily reminder at the hour you pick, and quizzes after each session
          that feed the same schedule.
        </p>
      </div>
      <div ref={tour} class="tour wrap">
        <ol class="tour-steps">
          <For each={SCREENS}>
            {(screen, index) => (
              <li class="tour-step" classList={{ active: active() === index() }}>
                <div>
                  <h3 class="mincho text-[clamp(1.6rem,3vw,2.4rem)] leading-[1.15] font-bold">{screen.title}</h3>
                  <p class="mt-4 max-w-[26rem] text-[18px] leading-[1.6] text-muted">{screen.text}</p>
                  <div class="tour-inline mt-8 max-w-[17rem]">
                    <Shot name={screen.name} alt={screen.alt} />
                  </div>
                </div>
              </li>
            )}
          </For>
        </ol>
        <div class="tour-pin" aria-hidden="true">
          <div class="tour-phone">
            <For each={SCREENS}>
              {(screen, index) => (
                <div class="tour-screen" classList={{ active: active() === index() }}>
                  <Shot name={screen.name} alt="" />
                </div>
              )}
            </For>
          </div>
        </div>
      </div>
    </section>
  )
}

const PROMISES = [
  { title: 'No account', text: 'Open the app and start. There is nothing to sign up for.' },
  {
    title: 'Your iCloud',
    text: 'Your deck syncs between your devices through your own private iCloud database. We never see it.'
  },
  {
    title: 'Your key',
    text: 'The AI key lives in the Keychain and goes only to the provider you chose, when a card is written.'
  },
  { title: 'No tracking', text: 'No analytics, no ads, no third-party SDKs.' }
]

function Privacy() {
  return (
    <section id="privacy" class="border-rule border-t py-24">
      <div class="wrap grid gap-x-16 gap-y-12 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.3fr)]">
        <div>
          <h2 class={`${h2} reveal`}>Your words stay yours.</h2>
          <p class={lead}>
            Kakera has no server of its own. What you study is on your iPhone and in your iCloud.
          </p>
          <Link to="/privacy" class="mt-6 inline-block text-[16px] font-semibold text-tokiwa underline underline-offset-4">
            Read the privacy policy
          </Link>
        </div>
        <dl class="reveal m-0 grid gap-x-10 gap-y-8 sm:grid-cols-2">
          <For each={PROMISES}>
            {(promise) => (
              <div>
                <dt class="text-[17px] font-semibold">{promise.title}</dt>
                <dd class="m-0 mt-2 leading-relaxed text-muted">{promise.text}</dd>
              </div>
            )}
          </For>
        </dl>
      </div>
    </section>
  )
}
