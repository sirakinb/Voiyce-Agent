import type { Metadata } from "next";
import { LegalDocShell } from "@/components/LegalDocShell";

export const metadata: Metadata = {
  title: "Privacy Policy — Voiyce",
  description: "How Voiyce collects, uses, and shares information.",
};

export default function PrivacyPage() {
  return (
    <LegalDocShell title="Privacy Policy" lastUpdated="March 28, 2026">
      <p>
        Pentridge Media (“we,” “us,” or “our”) operates Voiyce, a macOS voice
        dictation application and related services (collectively, the
        “Service”). This Privacy Policy describes how we collect, use, disclose,
        and protect information when you use the Service. By using the Service,
        you agree to this Privacy Policy.
      </p>

      <h2>Contact</h2>
      <p>
        Pentridge Media
        <br />
        Philadelphia, Pennsylvania, United States
        <br />
        Email:{" "}
        <a
          href="mailto:aki.b@pentridgemedia.com"
          className="text-purple-400 underline-offset-2 hover:underline"
        >
          aki.b@pentridgemedia.com
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
          may be processed to produce text. Processing may use speech
          recognition services (for example, Whisper or similar technologies) as
          described in “How we process information.”
        </li>
        <li>
          <strong>Transcripts and text.</strong> Text produced by the Service
          may be stored on our backend (hosted on InsForge) so features like
          history, sync, or account recovery work as designed.
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
        <li>Authenticate users and secure accounts;</li>
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
          Vercel (hosting), InsForge (backend and authentication), speech
          recognition (such as Whisper), Stripe (payments), Resend (email),
          PostHog (analytics)
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

      <p className="border-t border-white/10 pt-8 text-sm text-[#666666]">
        This policy is provided for informational purposes and does not
        constitute legal advice. Consult qualified counsel for your specific
        situation.
      </p>
    </LegalDocShell>
  );
}
