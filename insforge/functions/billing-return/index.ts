const callbackBaseURL = 'voiyceagent://billing/refresh'

function escapeHTML(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;')
}

export default async function(req: Request): Promise<Response> {
  const url = new URL(req.url)
  const state = (url.searchParams.get('state') ?? 'refresh').toLowerCase()

  let title = 'Return to Voiyce'
  let message = 'Voiyce is ready to refresh your billing access.'

  if (state === 'success') {
    title = 'Subscription Activated'
    message = 'Stripe finished checkout. Return to Voiyce to unlock dictation.'
  } else if (state === 'cancelled') {
    title = 'Checkout Cancelled'
    message = 'No changes were made. Return to Voiyce if you want to try again.'
  } else if (state === 'portal') {
    title = 'Billing Updated'
    message = 'Your billing portal session is complete. Return to Voiyce to refresh access.'
  }

  const callbackURL = `${callbackBaseURL}?state=${encodeURIComponent(state)}`
  const safeTitle = escapeHTML(title)
  const safeMessage = escapeHTML(message)
  const safeCallbackURL = escapeHTML(callbackURL)

  return new Response(
    `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${safeTitle}</title>
    <style>
      body {
        margin: 0;
        min-height: 100vh;
        display: grid;
        place-items: center;
        background: #0e0e10;
        color: #e8e8ec;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      }
      main {
        width: min(420px, calc(100vw - 32px));
        padding: 32px;
        border-radius: 24px;
        background: #1e1e22;
        box-shadow: 0 30px 80px rgba(0, 0, 0, 0.35);
      }
      h1 {
        margin: 0 0 12px;
        font-size: 28px;
      }
      p {
        margin: 0 0 24px;
        color: #b6b6c5;
        line-height: 1.6;
      }
      a {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        padding: 12px 18px;
        border-radius: 999px;
        background: #9b6dff;
        color: #ffffff;
        text-decoration: none;
        font-weight: 600;
      }
    </style>
  </head>
  <body>
    <main>
      <h1>${safeTitle}</h1>
      <p>${safeMessage}</p>
      <a href="${safeCallbackURL}">Return to Voiyce</a>
    </main>
    <script>
      setTimeout(function () {
        window.location.href = ${JSON.stringify(callbackURL)};
      }, 350);
    </script>
  </body>
</html>`,
    {
      status: 200,
      headers: {
        'Content-Type': 'text/html; charset=utf-8'
      }
    }
  )
}
