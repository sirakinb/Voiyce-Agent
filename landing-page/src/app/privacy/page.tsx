import type { Metadata } from "next";
import { LegalDocShell } from "@/components/LegalDocShell";
import { supportEmail, supportMailto } from "@/lib/voiyce-config";

export const metadata: Metadata = {
  title: "Privacy Policy — Voiyce",
  description: "How Voiyce collects, uses, and shares information.",
};

export default function PrivacyPage() {
  return (
    <LegalDocShell title="Privacy Policy" lastUpdated="July 26, 2026">
      <p>
        Voiyce (“we,” “us,” or “our”) operates the Voiyce macOS application and
        related services (collectively, the “Service”). Voiyce is a dictation
        app that helps you speak naturally and insert polished text into the apps
        you already use. This Privacy Policy describes how we collect, use,
        disclose, and protect information when you use the Service.
      </p>

      <h2>Contact</h2>
      <p>
        Voiyce
        <br />
        Philadelphia, Pennsylvania, United States
        <br />
        Email:{" "}
        <a
          href={supportMailto}
          className="text-purple-400 underline-offset-2 hover:underline"
        >
          {supportEmail}
        </a>
      </p>

      <h2>Information we collect</h2>
      <p>
        We collect information needed to run dictation, billing, and support,
        including:
      </p>
      <ul>
        <li>
          <strong>Account and authentication.</strong> When you sign up or sign
          in, we process credentials and profile information through our
          authentication provider (InsForge), such as your email address and
          identifiers associated with your account.
        </li>
        <li>
          <strong>Voice and dictation audio.</strong> When you dictate, Voiyce
          processes audio from your microphone to produce text. Audio may be sent
          to our backend transcription service, which uses OpenAI speech
          technologies (such as Whisper or similar models), to return transcribed
          text. We process audio to provide the dictation you request, enforce
          usage limits, and operate billing where applicable.
        </li>
        <li>
          <strong>Local transcript history.</strong> Voiyce stores dictation
          transcripts on your Mac, including the transcribed text, the app you
          dictated into, word counts, and session timing. This local history
          helps you review past dictations in the app. It is stored on your
          device and is not used for screen-context capture or agent memory.
          We may also process usage counts and related billing metadata on our
          backend so subscriptions, trials, and account limits work as
          designed.
        </li>
        <li>
          <strong>Device and app context.</strong> To insert dictated text and
          operate hotkeys system-wide, Voiyce uses macOS permissions you grant,
          including Microphone, Speech Recognition, and Accessibility. Voiyce
          does not require Screen Recording for dictation.
        </li>
        <li>
          <strong>Website analytics.</strong> We may use PostHog (or similar
          tools) on our public website to understand usage, diagnose issues, and
          improve performance. This may include pseudonymous identifiers and
          event data (for example, page views and errors).
        </li>
        <li>
          <strong>Billing.</strong> If you purchase a paid plan, payment
          information is processed by Stripe. We do not store your full payment
          card numbers on our servers; Stripe handles payment data according to
          its own terms and privacy policy.
        </li>
        <li>
          <strong>Communications.</strong> If you contact us or receive emails
          from us, we process your email address and message content. Marketing
          or product emails may be sent through Resend; you can opt out of
          marketing emails using the unsubscribe link in those messages where
          provided.
        </li>
      </ul>

      <h2>How we use information</h2>
      <p>We use information to:</p>
      <ul>
        <li>Provide, maintain, and improve dictation and related features;</li>
        <li>Authenticate users and secure accounts;</li>
        <li>Transcribe speech, insert text, and enforce usage or plan limits;</li>
        <li>Process subscriptions and payments;</li>
        <li>Send transactional messages and, where permitted, marketing;</li>
        <li>Monitor usage, troubleshoot, and improve reliability; and</li>
        <li>Comply with law and enforce our Terms of Service.</li>
      </ul>

      <h2>How we process information</h2>
      <p>
        The Service relies on subprocessors and infrastructure providers,
        including without limitation:{" "}
        <strong>
          Vercel (hosting), InsForge (backend and authentication), OpenAI
          (speech transcription), Cloudflare R2 (download hosting), Stripe
          (payments), Resend (email), and PostHog (analytics)
        </strong>
        , and other vendors we may use to operate the Service. These providers
        process data on our behalf under contractual safeguards appropriate to
        their role.
      </p>

      <h2>Legal bases (EEA, UK, and similar regions)</h2>
      <p>
        Where required by applicable law, we rely on appropriate legal bases
        such as: performance of a contract with you; our legitimate interests in
        operating and improving the Service (balanced against your rights);
        consent where we ask for it (for example, certain cookies or marketing
        where required); and compliance with legal obligations.
      </p>

      <h2>International users</h2>
      <p>
        We are based in the United States. If you use the Service from outside
        the United States, your information may be processed in the United
        States and other countries where we or our providers operate. Those
        countries may have different data protection laws than your country of
        residence.
      </p>

      <h2>Retention</h2>
      <p>
        We retain account and billing information for as long as your account
        is active or as needed to provide the Service, comply with legal
        obligations, resolve disputes, and enforce our agreements. Retention
        periods may vary depending on the type of data and legal requirements.
      </p>
      <p>
        Local transcript history stored on your Mac remains on your device until
        you delete it through the app or remove the app and its local data. We
        do not use that local history for screen-context capture or agent
        memory.
      </p>

      <h2>Your rights and choices</h2>
      <p>
        Depending on where you live, you may have rights to access, correct,
        delete, or export certain personal information, or to object to or
        restrict certain processing. You may also have the right to lodge a
        complaint with a supervisory authority. To exercise rights, contact us
        at the email above. We may need to verify your request.
      </p>
      <p>
        <strong>Marketing.</strong> You can opt out of marketing emails by
        following the instructions in those emails, where applicable.
      </p>
      <p>
        <strong>Permissions.</strong> You can control macOS permissions such as
        Microphone, Speech Recognition, and Accessibility in System Settings.
        Dictation requires the permissions you choose to grant for those
        features.
      </p>

      <h2>Children</h2>
      <p>
        The Service is not directed to children under 13, and we do not
        knowingly collect personal information from children under 13. If you
        believe we have collected information from a child under 13, please
        contact us and we will take appropriate steps.
      </p>

      <h2>Security</h2>
      <p>
        We implement reasonable technical and organizational measures designed
        to protect information. No method of transmission or storage is
        completely secure.
      </p>

      <h2>Changes to this policy</h2>
      <p>
        We may update this Privacy Policy from time to time. We will post the
        updated version and revise the “Last updated” date. Continued use of the
        Service after changes means you accept the updated policy, to the
        extent permitted by law.
      </p>

      <p className="border-t border-white/10 pt-8 text-sm text-[#8A8A8A]">
        This policy is provided for informational purposes and does not
        constitute legal advice. Consult qualified counsel for your specific
        situation.
      </p>
    </LegalDocShell>
  );
}
