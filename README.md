# PHALANX — Landing Page

Static landing page for **PHALANX** (working title) — an arcade survival roguelite
about 300 Spartans, permanent losses, and the Persian God King.

> 300 Spartans. Blood. Glory.

Built as a single static site, deployed via GitHub Pages.

## Files

| File | Purpose |
|------|---------|
| `index.html` | Landing page |
| `styles.css` | Pixel-art theme (Spartan bronze + blood) |
| `script.js` | Mobile nav, scroll reveals, frontline pressure demo, signup form |
| `404.html`  | Themed not-found page |
| `favicon.svg` | Lambda shield favicon |
| `.github/workflows/pages.yml` | Auto-deploy to GitHub Pages on push to `main` |

## Local preview

```bash
python3 -m http.server 8080
# then open http://localhost:8080
```

## Deploy

Push to `main`. The GitHub Actions workflow builds and publishes to GitHub Pages.

In GitHub: **Settings → Pages → Source = GitHub Actions** (one-time).

Live URL (once enabled): https://dvdkrv.github.io/sponk/

## To-do / nice next steps

- Replace CSS-art placeholders with real pixel art (`assets/` folder).
- Replace the abstract frontline demo with real combat GIF/video clips.
- Add Open Graph image at `assets/og.png` (1200×630).
- Wire the email form to a real backend (Buttondown, Resend, or a Cloudflare Worker).
- Add a real Steam wishlist link once the app exists on Steamworks.
- Add Datadog RUM or Cloudflare Web Analytics (see project notes).
