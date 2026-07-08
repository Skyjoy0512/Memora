# Handoff: Memora UI/UX 全面刷新 (v6)

## Overview
Memora is a voice-recording / meeting-transcription mobile app (companion to a PLAUD hardware recorder). This package hands off a full-app redesign: monotone "PLAUD-style" flat UI (no Liquid Glass), a 4-tab structure (Home / Tasks / Ask / Settings), a Dynamic-Island-based system for live recording + Ask AI, and a new Onboarding → Login → Paywall flow.

## About the Design Files
The bundled HTML files (`Memora Redesign v6.dc.html` and earlier v3–v5) are **interactive design references** built as a self-contained prototyping format (custom "DC" component runtime, inline styles, a single JS state-machine class). They are NOT production code and must not be copied verbatim into a codebase. Your task is to **recreate this design in Memora's actual app codebase** (iOS/SwiftUI, Android, React Native, Flutter — whichever the existing app uses) using its established navigation, state-management, and component patterns. If no codebase exists yet, choose the framework best suited to a native-feeling mobile companion app and implement fresh.

Treat v6 as canonical; v3–v5 are kept only as history of how the design evolved (see the "Files" section). All content is currently in Japanese — keep copy as-is unless told otherwise.

## Fidelity
**High-fidelity.** Colors, typography, spacing, radii, and micro-interactions (recording waveform, live transcript streaming, Dynamic-Island morph/expand, sheet animations, toasts) are all intentional and should be recreated pixel-for-pixel where feasible, adapted to native platform idioms (e.g. real Dynamic Island API on iOS instead of the simulated one in the HTML).

## Design Tokens
- Background (canvas/app bg): `#ECECEC` (docs page bg is `#EDEBE6`, phone screens are white `#FFFFFF`)
- Primary text / ink: `#0D0D0D`
- Secondary text: `#3A3A3C`
- Tertiary / muted text: `#6E6E80`, `#8E8EA0`
- Hairline / divider: `#E5E5EA`
- Neutral border (wireframe): `#C7C7CC`
- Light fill: `#F5F5F5` / `#F3F3F3`
- Accent red (record button / live state): `#FF3030`
- Dark pill / Dynamic Island surface: near-black with translucency, e.g. `linear-gradient(180deg, rgba(38,38,42,.68), rgba(16,16,18,.68))` + `backdrop-filter: blur(26px)`
- Font family: `-apple-system, 'SF Pro', system-ui, sans-serif` (iOS system font stack) — use SF Pro / platform default, no custom webfont
- Type scale used across screens: 30px/700 (page H1), 12px/600 uppercase eyebrow labels (letter-spacing .04em), 14.5–17px/400 body, 11–13px for meta/caption text
- Radius scale: 5–6px (small chips/fields), 10–14px (buttons/cards), 24–34px (pills, Dynamic Island, FAB)
- Shadows: soft, low-opacity only (no glow/glass) — e.g. `0 1px 2px rgba(0,0,0,.06)` style single soft shadow, never colored/glass shadows
- Keyframes referenced: `fadein`, `sheetUp` (bottom sheet slide-in), `popIn` (scale+fade for cards), `toastIn` (snackbar), `pulseDot`/`wavepulse` (recording waveform), `fabItemIn` (FAB menu stagger), `spin` (loading)

## Screens / Views

### 1. Onboarding (3 slides)
- Purpose: first-run intro before login.
- Layout: full-screen white, centered mini illustration (monotone geometric mock of the real UI, no photos/illustration art), headline, 1-line description, page dots, primary button (bottom, full-width, black, r=14, h=52).
- Slide 1: "録音するだけ" — record button visual. Slide 2: "AI が要約・タスク化" — summary card visual. Slide 3: "Ask AI に聞くだけ" — Dynamic Island capsule visual.
- Skip link top-right on every slide. Last slide's button reads "はじめる" (Start) instead of "次へ" (Next) and proceeds to Login.

### 2. Login
- Layout top-to-bottom: logo/app name "Memora" (700/32px) + 1-line tagline → button stack → terms footnote.
- Buttons (full-width, r=14, h=52, in order): "Apple でサインイン" (black bg/white text + Apple mark — must be top per Apple HIG), "Google で続ける" (white bg, 1px border `#E5E5EA`, G mark), "メールアドレスで続ける" (bg `#F5F5F5`).
- Email path: tapping email → email input screen → "確認コードを送信" → 6-digit code entry (6 boxed digits) → any 6 digits accepted in prototype → success.
- On success: Dynamic-Island snackbar "ログインしました" → routes to Paywall.
- No "skip/later" link — login is required. Footnote "続行すると利用規約とプライバシーポリシーに同意したことになります" is required under the button stack.

### 3. Paywall ("Memora Pro")
- Trigger points: immediately after first login; from Settings "プラン管理"; from the attachment "クラウド保存は Pro で ›" upsell.
- Header: close (×) top-left — free tier remains available, never hide this.
- Heading "Memora Pro" + subhead "すべての記録を、どこからでも".
- Feature comparison list (4–5 rows, checkmark style): 文字起こし 月1200分 (free: 300分) / クラウド保存・全デバイス同期 (free: この端末のみ) / ライフログ自動セグメント無制限 / Ask AI 無制限 (free: 1日10回).
- Plan cards (2, side by side): Annual ¥9,800/yr (¥817/mo, "2ヶ月分お得" badge) — selected/default, black border emphasis; Monthly ¥980/mo.
- CTA: full-width black "7日間無料で試す" + caption "いつでもキャンセルできます" below.
- Footer: small links "購入を復元" / "利用規約" / "プライバシー".
- Closing (×) keeps user on free tier → Home. Confirming purchase → Dynamic-Island snackbar "Pro へようこそ" → Home, Settings plan row updates to Pro, the attachment cloud-upsell badge becomes "クラウド".

### 4. Home
- Header: device connection status ("PLAUD Note Pro ●" connected, or grey dot + "接続" link when not).
- Segmented filter inside Home (not separate tabs): Files / Projects / (life-log alt view). Search/ask bar doubles as "Memoraに質問・検索".
- List of recordings/files as flat rows separated by hairlines (no cards/borders) — PLAUD-style: white bg, generous whitespace, underline-style active tab indicator, large heading typography.
- Empty state (0 recordings): large record button + 1-line guidance "最初の録音をはじめる" — shown right after onboarding.
- Floating record button (FAB) → opens full-screen Recording.
- Life-log view: date nav (今日 ◀ ▶), list of time-stamped "moments" with highlight flag on key ones; tapping a moment opens File Detail with the moment's own title (not a generic filename).

### 5. Recording (full-screen, modal)
- Live elapsed-time counter, animated waveform reacting to (simulated) audio levels, streaming transcript lines appearing progressively.
- Controls: pause/resume, discard (with confirm), highlight actions (photo / note / mark — captured photos should attach to the resulting file).
- Minimize (∨) top-left, discard (×) top-right — deliberately NOT symmetric/adjacent, to avoid mis-taps.
- Ending a recording routes into Generation Progress.

### 6. Generation Progress
- Circular indeterminate progress + status line while summary/transcript generate asynchronously; "skip" available to jump straight to transcript-only view. On completion, should animate to 100% and fire a Dynamic-Island completion snackbar (not a hardcoded static 55%).

### 7. File Detail
- Header: file name, tabs "要約 / 文字起こし / メモ" — centered in header (not below), share icon → export sheet (Notion / ChatGPT / Markdown / etc).
- Summary tab: structured 決定事項 (decisions) / 次のアクション (next actions) — not free text.
- Transcript tab: contains an inline player synced to timestamps; tapping a transcript line seeks the player; chapters/overview list at top with timestamp jump.
- Memo tab: freeform markdown-ish notes, editable.
- Persistent "Ask AI" bar fixed at the bottom of every tab, scoped to this file's content.
- Attachments: real image previews (not placeholder boxes) — support user-supplied images.
- Floating mini-player appears when scrolled past the main player.

### 8. Tasks
- Tasks always show their source recording/meeting (linked chip), grouped by due state: overdue / today / done.
- "Add task" sheet: due-date quick picks today/tomorrow/next-week + a proper date picker (not just 3 presets).

### 9. Ask (tab)
- Full conversation view, scoped by "general / project / file" context.
- Visual treatment should read as a plain document/chat (question = small grey text, answer = body text with small "source" chips linking back to the originating recording) rather than rounded chat bubbles — consistent with the Dynamic-Island Ask answer style.

### 10. Settings
- Account row: shows login email + current plan (Free/Pro), links to Paywall ("プラン管理").
- Device row: connect/manage PLAUD hardware, battery.
- Logout row → returns to Login.
- Notification toggle, delete-account confirm flow.

### System-wide: Dynamic Island simulation
- A pill-shaped dark surface pinned to the top of the phone frame simulates iOS Dynamic Island: idle / recording-live / ask-listening / ask-answer / toast states, morphing between them.
- Ask AI answers shown here carry a source chip (e.g. "2025-01-24_エンジニア定例") tappable to open File Detail — must be visually consistent with the Ask tab's own source chips.
- Toast/snackbar messages route through this same island component (e.g. login success, Pro purchase, device connected).
- On real iOS this should be implemented against the actual Dynamic Island / Live Activity APIs where the OS allows; on Android/other platforms, treat as an in-app persistent status pill.

## Interactions & Behavior
- Tab switching resets any open modal/sheet (`activeTab` change clears `modal`/`exportOpen`).
- Recording → Generation → File Detail is one continuous flow; "skip" during generation drops straight to transcript-only.
- Bottom sheets animate in via translateY(100%→0) ("sheetUp"); cards/popovers via scale 0.94→1 fade ("popIn"); toasts slide+fade from bottom ("toastIn").
- A recording in progress must survive an Ask-AI interaction: after asking a question during `live-rec`, the state should return to `live-rec` (not reset to idle) once the answer dismisses.
- Backdrop under an open Ask/Island overlay must block underlying Home scroll (pointer-events), not just visually cover it.
- All auth/payment actions are simulated — see "Out of Scope" below.

## State Management
Reference the prototype's state shape as a guide for what the real app needs to track (names are prototype-internal, not required to match):
- Auth/onboarding flow: current stage (onboarding/login/paywall/done), onboarding slide index, login sub-step (buttons/email/code), entered email/code, selected plan, pro status.
- Navigation: active bottom tab, open modal/sheet (recording / file-detail / export / etc.), Home's Files/Projects/life-log filter.
- Recording session: elapsed time, paused flag, discard-confirm flag, live transcript lines, waveform amplitude samples, highlight/mark count.
- Generation: progress step/percentage, completion flag.
- File Detail: active tab (summary/transcript/memo), playback position/speed, attachments, memo text/edit mode.
- Tasks: list with id/title/source-recording/due-date/done, grouped by due bucket.
- Ask: per-scope (general/project/file) message history with role, text, timestamp, and source citations; pending/sending flag.
- Life-log: per-day moment list, day offset for date nav, device battery/connection.
- Global: toast/snackbar queue, Dynamic-Island mode + payload.

## Assets
- `refs/` — static PNG reference mocks used while designing (home states, file-detail template, device photos) — for visual reference only, not final assets.
- `refs/devices/` — PLAUD hardware device photography references.
- Device stock images referenced in-prototype (`assets/devices/note-pro-black.png`, `note-pro-champagne.png`) are placeholders — replace with real product photography from Memora's asset library.
- No custom icon set/illustration library is used — icons are inline SVG line-art in the prototype; source proper platform icon assets (SF Symbols on iOS, Material Symbols on Android, or the existing in-house icon set) matching the same visual weight (thin/regular stroke, monochrome).

## Screenshots
See `screenshots/` for representative captures: onboarding, login, paywall, home (file list), recording, file detail, tasks, ask, and settings.

## Out of Scope (not implemented in the prototype — build for real)
- Real Apple/Google Sign-In SDK integration, real email delivery/OTP verification.
- Real in-app purchase / subscription billing (StoreKit / Play Billing) — prototype's "confirm purchase" is a state flip only.
- A/B variants of the Paywall.
- Real Dynamic-Island / Live Activity OS integration (prototype fakes it with an in-DOM pill).

## Files
- `Memora Redesign v6.dc.html` — current/final design (use this one).
- `Memora Redesign v3.dc.html`, `v4.dc.html`, `v5.dc.html` — earlier iterations, kept for history only.
- `改修プラン_v6.md`, `改修プラン_v5.md`, `改修プラン_v4_DynamicIsland.md` — original Japanese planning docs behind each revision; useful background on rationale and open items (v6's doc also lists a prioritized backlog of remaining polish items in section B/C).
- `refs/` — visual reference screenshots.
- To view the interactive prototype: open `Memora Redesign v6.dc.html` in a browser (it's self-contained aside from `support.js` and `image-slot.js` in the same folder).
