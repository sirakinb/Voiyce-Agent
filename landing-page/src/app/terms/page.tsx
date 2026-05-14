import type { Metadata } from "next";
import { LegalDocShell } from "@/components/LegalDocShell";

export const metadata: Metadata = {
  title: "Terms of Service — Voiyce",
  description: "Terms governing use of the Voiyce macOS application and services.",
};

export default function TermsPage() {
  return (
    <LegalDocShell title="Terms of Service" lastUpdated="May 14, 2026">
      <p>
        These Terms of Service (“Terms”) govern your access to and use of
        Voiyce, a macOS application and related services operated as an
        independent Voiyce platform (“we,” “us,” or “our”). By downloading,
        installing, or using Voiyce (“Service”), you agree to these Terms. If
        you do not agree, do not use the Service.
      </p>

      <h2>Contact</h2>
      <p>
        Voiyce
        <br />
        Philadelphia, Pennsylvania, United States
        <br />
        Email:{" "}
        <a
          href="mailto:support@voiyce.com"
          className="text-purple-400 underline-offset-2 hover:underline"
        >
          support@voiyce.com
        </a>
      </p>

      <h2>Eligibility</h2>
      <p>
        You represent that you have the legal capacity to enter into these Terms
        (including, if you are using the Service on behalf of an organization,
        that you have authority to bind that organization). If you are not
        permitted to use the Service under applicable law, you may not use the
        Service.
      </p>

      <h2>The Service</h2>
      <p>
        Voiyce provides voice dictation and related features for macOS. Features,
        limits, and availability may change. We may update the Service with or
        without notice. We do not guarantee uninterrupted or error-free
        operation.
      </p>

      <h2>Accounts</h2>
      <p>
        You may need an account to use certain features. Authentication and
        related account services may be provided through InsForge (or successor
        providers). You are responsible for safeguarding your credentials and for
        activity under your account.
      </p>

      <h2>Fees and subscriptions</h2>
      <p>
        <strong>Trial.</strong> We may offer a free trial of Voiyce Pro that
        lasts up to <strong>seven (7) days</strong> and includes up to{" "}
        <strong>2,500</strong> dictated words (or as otherwise stated in the
        app or checkout), whichever limit is reached first. Unless otherwise
        stated at signup, no payment method is required to begin the trial.
      </p>
      <p>
        <strong>Pro subscription.</strong> The Pro plan is offered at{" "}
        <strong>USD $12 per month</strong> or <strong>USD $120 per year</strong>{" "}
        (plus applicable taxes), unless a different price is shown at purchase.
        Paid subscriptions renew automatically until canceled.
      </p>
      <p>
        <strong>Payment processing.</strong> Payments are processed by Stripe.
        You agree to Stripe’s terms and privacy practices for payment
        processing. We do not store your full card number on our servers.
      </p>
      <p>
        <strong>Refunds.</strong> If you are not satisfied with your paid
        subscription, you may request a refund within{" "}
        <strong>thirty (30) days</strong> of your initial purchase by contacting
        us at the email above. Refunds are subject to verification and may be
        limited to the fees paid for the current subscription period as
        determined in our reasonable discretion. This refund policy does not
        affect any statutory rights that cannot be waived.
      </p>
      <p>
        <strong>Cancellation.</strong> You may cancel your subscription through
        the mechanism we provide (for example, account or billing settings) or by
        contacting us. Cancellation stops future renewals; you may retain access
        until the end of the current billing period unless otherwise stated.
      </p>

      <h2>Acceptable use</h2>
      <p>You agree not to:</p>
      <ul>
        <li>Use the Service in violation of law or third-party rights;</li>
        <li>
          Attempt to probe, scan, or test vulnerabilities, or breach security or
          authentication measures;
        </li>
        <li>
          Reverse engineer, decompile, or disassemble the Service except where
          applicable law permits;
        </li>
        <li>
          Use the Service to transmit malware, spam, or unlawful, harmful, or
          abusive content;
        </li>
        <li>
          Resell, sublicense, or commercially exploit the Service without our
          written consent; or
        </li>
        <li>
          Interfere with other users’ use of the Service or our networks or
          systems.
        </li>
      </ul>

      <h2>Your content</h2>
      <p>
        You retain rights in content you create. To operate the Service, you
        grant us a limited license to host, process, transmit, and display your
        content (including voice input and transcripts stored on our backend)
        solely to provide and improve the Service, as described in our Privacy
        Policy.
      </p>

      <h2>Third-party services</h2>
      <p>
        The Service integrates with third-party providers (for example, hosting,
        authentication, speech recognition, analytics, email, and payments).
        Their use is subject to their terms. We are not responsible for
        third-party services.
      </p>

      <h2>Disclaimers</h2>
      <p>
        THE SERVICE IS PROVIDED “AS IS” AND “AS AVAILABLE.” TO THE MAXIMUM
        EXTENT PERMITTED BY LAW, WE DISCLAIM ALL WARRANTIES, EXPRESS OR
        IMPLIED, INCLUDING MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND
        NON-INFRINGEMENT. DICTATION AND AI-ASSISTED FEATURES MAY PRODUCE
        INACCURATE OR INCOMPLETE OUTPUT; YOU ARE RESPONSIBLE FOR REVIEWING
        OUTPUT BEFORE RELYING ON IT.
      </p>

      <h2>Limitation of liability</h2>
      <p>
        TO THE MAXIMUM EXTENT PERMITTED BY LAW, WE WILL NOT BE LIABLE FOR ANY
        INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY
        LOSS OF PROFITS, DATA, OR GOODWILL. OUR TOTAL LIABILITY FOR ANY CLAIM
        ARISING OUT OF THESE TERMS OR THE SERVICE WILL NOT EXCEED THE GREATER OF
        (A) THE AMOUNTS YOU PAID US FOR THE SERVICE IN THE TWELVE (12) MONTHS
        BEFORE THE CLAIM OR (B) ONE HUNDRED U.S. DOLLARS (USD $100), EXCEPT WHERE
        PROHIBITED BY LAW.
      </p>

      <h2>Indemnity</h2>
      <p>
        You will defend and indemnify us and our affiliates, officers, and
        employees against third-party claims arising from your use of the
        Service, your content, or your violation of these Terms, except to the
        extent caused by our willful misconduct.
      </p>

      <h2>Termination</h2>
      <p>
        We may suspend or terminate access to the Service if you materially
        breach these Terms or if we must do so to comply with law or protect the
        Service. You may stop using the Service at any time. Provisions that by
        their nature should survive will survive termination.
      </p>

      <h2>Governing law</h2>
      <p>
        These Terms are governed by the laws of the{" "}
        <strong>Commonwealth of Pennsylvania</strong>, without regard to
        conflict-of-law principles, except that the Federal Arbitration Act
        governs arbitration as described below.
      </p>

      <h2>Dispute resolution; arbitration</h2>
      <p>
        <strong>Informal resolution.</strong> Before filing a claim, you agree
        to contact us at support@voiyce.com and attempt to resolve the
        dispute informally for at least thirty (30) days.
      </p>
      <p>
        <strong>Binding arbitration.</strong> If the dispute is not resolved
        informally, either party may elect to resolve the dispute exclusively
        through final and binding arbitration administered by the American
        Arbitration Association (“AAA”) under its Consumer Arbitration Rules
        (or Commercial Rules if applicable), except that either party may seek
        injunctive relief in court for intellectual property or misuse of the
        Service. The arbitration will be held in{" "}
        <strong>Philadelphia, Pennsylvania</strong>, unless the parties agree
        otherwise or AAA rules permit a different location. You and we waive any
        right to a jury trial for disputes subject to arbitration.
      </p>
      <p>
        <strong>Class action waiver.</strong> TO THE FULLEST EXTENT PERMITTED BY
        LAW, DISPUTES MUST BE BROUGHT ON AN INDIVIDUAL BASIS ONLY; CLASS,
        CONSOLIDATED, OR REPRESENTATIVE ACTIONS ARE NOT PERMITTED.
      </p>
      <p>
        If any part of this arbitration section is found unenforceable, the
        remainder remains in effect to the maximum extent permitted.
      </p>

      <h2>Changes to these Terms</h2>
      <p>
        We may modify these Terms by posting an updated version and updating the
        “Last updated” date. If a change is material, we will provide notice as
        required by law or as we reasonably determine. Continued use after the
        effective date constitutes acceptance of the updated Terms, except where
        prohibited by law.
      </p>

      <h2>Miscellaneous</h2>
      <p>
        These Terms constitute the entire agreement between you and us
        regarding the Service. If any provision is invalid, the remainder
        remains in effect. Our failure to enforce a provision is not a waiver.
        You may not assign these Terms without our consent; we may assign them
        in connection with a merger, acquisition, or sale of assets.
      </p>

      <p className="border-t border-white/10 pt-8 text-sm text-[#666666]">
        These Terms are provided for informational purposes and do not
        constitute legal advice. Consult qualified counsel for your specific
        situation.
      </p>
    </LegalDocShell>
  );
}
