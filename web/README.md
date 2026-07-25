# ClaudeNotch — Landing Page (Next.js)

Interactive marketing site for ClaudeNotch.

## Develop
```bash
cd web && npm install && npm run dev   # http://localhost:3000
```

## Build
```bash
npm run build && npm start
```

## Deploy
Deploy `web/` to Vercel (import the repo, root directory = `web/`). Standard Next.js build.

## Theming
The live theme switcher mirrors the app's 10 built-in themes; hex values in `lib/themes.ts`
are kept in sync with `Sources/ClaudeNotchApp/UI/Themes.swift` / `Palette.swift`.
