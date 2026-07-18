import type { Metadata } from "next";
import { LegalDocShell } from "@/components/LegalDocShell";
import { supportEmail, supportMailto } from "@/lib/voiyce-config";

export const metadata: Metadata = {
  title: "Privacy Policy — Voiyce",
  description: "How Voiyce collects, uses, and shares information.",
};

export default function PrivacyPage() {
  return (
    <LegalDocShell title="Privacy Policy" lastUpdated="May 18, 2026">
      <p>
        Voiyce (“we,” “us,” or “our”) operates the Voiyce macOS application and
        related services (collectively, the “Service”). Voiyce helps you capture
        work context, use voice workflows, and hand reusable memory to the AI
        tools you work with. This Privacy Policy describes how we collect, use,
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
        We collect basic information needed to run the Service, including:
      </p>
      <ul>
        <li>
          <strong>Account and authentication.</strong> When you sign up or sign
          in, we process credentials and profile information through our
          authentication provider (InsForge), such as your email address and
          identifiers associated with your account.
        </li>
        <li>
          <strong>Voice and dictation.</strong> Audio you provide for dictation
          or voice-agent sessions may be processed to produce text, respond to
          your request, or operate the feature you selected. Processing may use
          OpenAI speech or realtime services, including Whisper or similar
          technologies, as described in “How we process information.”
        </li>
        <li>
          <strong>Transcripts and text.</strong> Text produced by the Service
          may be stored on our backend (hosted on InsForge) so features like
          history, sync, or account recovery work as designed.
        </li>
        <li>
          <strong>Screen context and screenshots.</strong> If you grant Screen
          Recording permission and use screen-aware features, Voiyce may process
          screenshots, visible text, focused regions, and summaries so the app
          can answer questions about your current work or help with an action.
        </li>
        <li>
          <strong>Local memory.</strong> Voiyce may store searchable local
          records, summaries, screenshots, and user-readable Markdown notes on
          your Mac so you can reuse context across sessions and agents.
        </li>
        <li>
          <strong>Agent actions and support exports.</strong> Voiyce may record
          local Agent Log events such as mode changes, permission blockers,
          tool results, memory writes, and failures. If you choose to create or
          send a support export, that export may include redacted diagnostic
          information needed to troubleshoot the issue.
        </li>
        <li>
          <strong>Connected services.</strong> If you connect services such as
          Google Gmail or Google Calendar, we process the limited account and
          content data needed to perform the action you request.
        </li>
        <li>
          <strong>Usage and product analytics.</strong> We use PostHog (or
          similar tools) to understand how the Service is used, diagnose
          issues, and improve performance and features. This may include
          pseudonymous identifiers and event data (for example, feature usage and
          errors).
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
        <li>Provide, maintain, and improve the Service;</li>
        <li>Capture context, create memory, and support agent handoffs;</li>
        <li>Authenticate users and secure accounts;</li>
        <li>Operate Talk, Context, Act, screen-aware, and dictation features;</li>
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
          (speech, realtime, screen, and computer-use model processing), VideoDB
          (session memory and media indexing where enabled), Google APIs
          (connected Gmail and Calendar features), Cloudflare R2 (download
          hosting), Stripe (payments), Resend (email), and PostHog (analytics)
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
        We retain information for as long as your account is active or as needed
        to provide the Service, comply with legal obligations, resolve disputes,
        and enforce our agreements. Retention periods may vary depending on the
        type of data and legal requirements.
      </p>
      <p>
        Local memory is stored on your Mac as a structured searchable index and
        Voiyce-written Markdown notes. Summary retention controls include
        Session only, 30 days, 90 days, and Forever. Raw screenshots have a
        separate setting and may be Off, 30 days, 90 days, or Forever. Private
        Mode pauses durable memory and raw screenshot storage, and app/site
        exclusions skip matching memory writes. The in-app delete control
        removes the local memory index, raw screenshots, and Voiyce-written
        vault notes.
      </p>
      <p>
        Support exports are created only when you choose to generate or share
        them. Voiyce redacts known sensitive fields, but you should still review
        any export before sending it to support.
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
        <strong>Permissions and memory.</strong> You can control macOS
        permissions such as Microphone, Speech Recognition, Accessibility, and
        Screen Recording in System Settings. You can also pause capture, use
        Private Mode, exclude apps or sites, and delete Voiyce memory through
        the controls provided in the app where available.
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
        Service after changes means you accept the updated policy, to the extent
        permitted by law.
      </p>

      <p className="border-t border-white/10 pt-8 text-sm text-[#8A8A8A]">
        This policy is provided for informational purposes and does not
        constitute legal advice. Consult qualified counsel for your specific
        situation.
      </p>
    </LegalDocShell>
  );
}
