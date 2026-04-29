# Website To Paywall User Flow

This visual maps the current Voiyce journey from website landing through account creation, Mac download, in-app onboarding, trial usage, and the paywall trigger.

```mermaid
flowchart TD
    A[User lands on voiyce.com landing page] --> B{Which CTA do they choose?}
    B -->|Download| C[/auth?intent=download/]
    B -->|Monthly| D[/auth?intent=monthly/]
    B -->|Yearly| E[/auth?intent=yearly/]

    C --> F[Create account or sign in on website]
    D --> F
    E --> F

    F --> G{Email verification required?}
    G -->|Yes| H[Enter 6-digit email code]
    H --> I[/download?intent=.../]
    G -->|No| I[/download?intent=.../]

    I --> J{Website session valid?}
    J -->|No| F
    J -->|Yes| K[If monthly/yearly intent, save preferred plan]
    K --> L[Auto-start DMG download from Cloudflare R2]
    L --> M[User opens Downloads folder]
    M --> N[Drag Voiyce.app into Applications]
    N --> O[User opens Voiyce on Mac]

    O --> P{App already signed in?}
    P -->|No| Q[App AuthView prompts separate sign-in]
    P -->|Yes| R[Billing status refresh]
    Q --> R

    R --> S{Onboarding complete on this Mac?}
    S -->|No| T[Onboarding flow]
    T --> U[Grant microphone permission]
    U --> V[Grant speech recognition permission]
    V --> W[Choose onboarding preferences]
    W --> X[Run first dictation preview]
    X --> Y{Billing access active?}
    Y -->|No, signed out| Q
    Y -->|No, payment required| AB[Show paywall card during onboarding]
    Y -->|Yes| Z[Finish onboarding]
    S -->|Yes| AA[Open dashboard]
    Z --> AA

    AA --> AC[User dictates with hotkey]
    AC --> AD[Transcript returned]
    AD --> AE[Record word usage]
    AE --> AF{Trial still valid?}

    AF -->|Yes| AG[Stay active]
    AG --> AC

    AF -->|No: 7 days ended or 2,500 words reached| AH[accessState becomes paymentRequired]
    AH --> AI[App activates dashboard and surfaces billing status card]
    AI --> AJ{Preferred plan saved from website?}
    AJ -->|Yes| AK[Paywall copy references saved Monthly or Yearly plan]
    AJ -->|No| AL[User chooses plan in billing picker]
    AK --> AM[Open billing plan picker with saved plan preselected]
    AL --> AM

    AB --> AM
    AM --> AN[Open Stripe Checkout in browser]
    AN --> AO{Checkout outcome}
    AO -->|Cancelled| AP[Return to app with cancelled state]
    AO -->|Success| AQ[Stripe callback returns to app]
    AQ --> AR[Sync billing status from backend]
    AR --> AS{Subscription active?}
    AS -->|Yes| AT[Remove paywall and restore active access]
    AS -->|No| AI
    AP --> AI
```

## What this diagram reflects

- The website auth session and the app auth session are separate. The user must sign in again inside the Mac app.
- The website can capture plan intent (`monthly` or `yearly`) before download and save it for later checkout preselection.
- The app grants access during the trial with no card required up front.
- The paywall appears when the trial is exhausted by time or by word usage.
- The app sends the user to Stripe Checkout from the in-app billing picker and refreshes access after the callback returns.

## Source references

- Website intent, trial copy, and download URL: `/landing-page/src/lib/voiyce-config.ts`
- Website auth handoff: `/landing-page/src/components/AuthPageClient.tsx`
- Website download handoff: `/landing-page/src/components/DownloadPageClient.tsx`
- App auth/onboarding/dashboard routing: `/Voiyce-Agent/ContentView.swift`
- Paywall and trial logic: `/Voiyce-Agent/Services/Billing/BillingManager.swift`
- Onboarding gating: `/Voiyce-Agent/Features/Onboarding/OnboardingView.swift`
- Dashboard paywall surface: `/Voiyce-Agent/Features/Dashboard/DashboardView.swift`
- Word-usage trigger that flips access to payment required: `/Voiyce-Agent/Voiyce_AgentApp.swift`
