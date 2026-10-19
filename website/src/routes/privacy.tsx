import { createFileRoute } from '@tanstack/solid-router'

import { Footer } from '../components/footer'
import { Header } from '../components/header'
import { CONTACT_EMAIL, ISSUES_URL, SITE_URL } from '../site'

export const Route = createFileRoute('/privacy')({
  head: () => ({
    meta: [
      { title: 'Privacy policy · Kakera' },
      { name: 'description', content: 'What Kakera stores, where it goes, and what it never collects.' }
    ],
    links: [{ rel: 'canonical', href: `${SITE_URL}/privacy` }]
  }),
  component: PrivacyPolicy
})

/** The App Store privacy policy. Keep it true to the app: change it in the same commit as anything it describes. */
function PrivacyPolicy() {
  return (
    <>
      <Header />
      <main class="wrap pt-10 md:pt-16">
        <article class="prose-page max-w-2xl">
          <h1 class="mincho text-[clamp(2.4rem,5vw,3.4rem)] leading-[1.1] font-bold tracking-[-0.01em]">
            Privacy policy
          </h1>
          <p class="mt-4">Last updated October 19, 2026.</p>
          <p>
            Kakera is a flashcard app for iPhone made by an independent developer. This
            policy explains what the app stores, where data goes when you use it, and what it never
            collects. In short: <strong>Kakera has no servers and no account, and collects nothing
              about you.</strong>
          </p>

          <h2>What the app stores</h2>
          <p>
            Your words and cards, your review history, daily stories and your settings are stored on
            your iPhone. If you are signed in to iCloud, your words, review history and stories are
            also kept in <strong>your own private iCloud database</strong> (Apple's CloudKit), so they
            appear on your other devices. That database belongs to your Apple Account: the developer
            cannot read it. Apple's handling of iCloud data is described in Apple's privacy policy.
          </p>
          <p>
            The API key you enter for an AI provider is stored in the iPhone's{' '}
            <strong>Keychain</strong>. It is never sent anywhere except to that provider.
          </p>

          <h2>What leaves your iPhone, and when</h2>
          <ul>
            <li>
              <strong>To the AI provider you choose</strong> (Anthropic for Claude, or OpenAI), only
              when you ask Kakera to write cards or a daily story: the words involved and the
              instructions for the card, sent with your own API key. The provider's own privacy policy
              and terms apply to that request. Without a key, nothing is sent.
            </li>
            <li>
              <strong>To Youdao's dictionary audio service</strong> (dict.youdao.com), to play a
              word's pronunciation: the text of the word or sentence being read. If it has no audio,
              your iPhone's built-in voice reads it instead, on the device.
            </li>
            <li>
              <strong>To iCloud</strong>, as described above, if you use iCloud.
            </li>
          </ul>
          <p>Nothing else is sent.</p>

          <h2>What the app never collects</h2>
          <p>
            Kakera contains no analytics, no advertising, no tracking and no third-party SDKs. It does
            not collect your name, email address, location, contacts or device identifiers, and the
            developer receives no data from it.
          </p>

          <h2>Notifications</h2>
          <p>
            Review reminders are local notifications scheduled on your iPhone. No push server is
            involved, and you can turn them off in Settings at any time.
          </p>

          <h2>Diagnostics</h2>
          <p>
            Kakera keeps a short log on the device to help diagnose problems (Settings → Diagnostics).
            It is never sent automatically; it leaves the device only if you share it yourself.
          </p>

          <h2>Deleting your data</h2>
          <p>
            Delete words in the app, or delete the app to remove everything stored on the iPhone. To
            remove the iCloud copy, go to iOS Settings → your name → iCloud → Storage, and delete
            Kakera's data.
          </p>

          <h2>Children</h2>
          <p>Kakera does not knowingly collect any information from anyone, children included.</p>

          <h2>Changes and contact</h2>
          <p>
            If this policy changes, the new version will be posted here with a new date. Questions are
            welcome at <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a> or on{' '}
            <a href={ISSUES_URL}>GitHub Issues</a>.
          </p>
        </article>
      </main>
      <Footer />
    </>
  )
}
