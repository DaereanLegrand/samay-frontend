# Auth buttons — Google + Sign in with Apple (logo-only)

**Status:** living document. Describes the social sign-in controls on the login
screen (`lib/features/auth/screens/login_screen.dart`) and the **vendor rules
they must satisfy**. The UI is the source of truth; this records *why* it is
shaped the way it is so the constraints are not lost on the next edit.

Both controls are **icon-only** (logo-only) on purpose: a single compact row
above "Create account". The Apple control is a **custom** button — Apple's
system-provided `ASAuthorizationAppleIDButton` / `SignInWithAppleButton` / web
button *always* carry a title, so a logo-only Apple button must be built by hand
from Apple's downloadable artwork.

---

## 1. Vendor rules

### Apple — "Creating a custom Sign in with Apple button"

- **Prominence:** "Make a Sign in with Apple button **no smaller than other
  sign-in buttons**, and avoid making people scroll to see the button."
- **Artwork only:** use the logo files from **Apple Design Resources**; never
  draw a custom Apple logo.
- **Logo-only specifics:** 1:1 aspect ratio; the artwork already includes the
  correct padding — **don't crop it, don't add horizontal padding, don't use
  the bare logo as the button**. A **mask** may change the square into a circle
  or rounded rectangle.
- **PNG vs vector:** "Use the vector-based SVG and PDF formats for buttons of
  any size; use the PNG format only in buttons that measure 44×44 pt."
- **Margin:** at least **1/10 of the button's height** around the button.
- **Colours:** the logo is black or white; the background stays black or white.
- **Custom buttons:** "App Review evaluates all custom Sign in with Apple
  buttons."

### Google — "Sign in with Google Branding Guidelines"

- **Prominence:** "The Sign in with Google button should be displayed **at
  least as prominently as other third party sign-in options**… buttons should
  be **approximately the same size and have similar visual weight**."
- **Mark:** the standard-colour "G" **on a white background**; "you can't change
  the size or color of the Google 'G' logo" (scale it, don't distort it).
- **Icon-only:** allowed if the icon sits inside a **button boundary** (a
  white disc here), not the bare logo floating on the page.

### The common rule

Both vendors require **equal size and similar visual weight** for the sign-in
options. That is the constraint the layout is built around.

---

## 2. Sizing — the numbers

The marks do **not** fill their buttons equally — each vendor ships its own
built-in padding:

| Mark | Vendor's own proportion (measured) | Source |
|---|---|---|
| Apple logo (logo-only) | **≈43% of the button** (glyph 19pt in the 44pt square) | Apple Design Resources SVG/PDF; HIG `siwa-logo-masked-circle` (glyph 38px in an 88px circle) |
| Google "G" (icon button) | **≈47.5% of the button** | Google's own icon-only asset `branding_guideline_sample_lt_rd_sl.svg` (a 40×40 circle with an ~18.5px G) |

A common mistake is shrinking the **button** while keeping the Google "G" at
its supplied 18pt — a 18pt G in a 28pt disc is **64%**, far above Google's own
~47.5%, which makes the Apple mark look undersized next to it. Since the Apple
artwork's padding is fixed (it may not be cropped) and the Google "G" may not be
resized arbitrarily, the fix is a **larger shared button**, not a re-drawn mark.

**This app: both discs are 44pt** (Apple's recommended logo-only size) — Google
"G" 18pt (≈41%), Apple logo ≈19pt (≈43%). The Apple mark is no smaller than the
Google mark, and both sit at (or beside) their vendor proportion.

Measured on the iOS simulator (device pixels, 3×): both discs `132×132`
(= 44pt); Google "G" `54px` tall (18pt), Apple glyph `57px` tall (19pt).

---

## 3. Implementation

`lib/features/auth/screens/login_screen.dart`:

- **`_socialIconButton({label, onPressed, child})`** — one 44pt borderless,
  transparent `TextButton` (`CircleBorder` ripple), a `Semantics` label and a
  `Tooltip`, dimmed (no spinner) and inert while `_submitting`. Google and Apple
  both use it, so the two controls are guaranteed the same size.
- **`_googleSignInButton`** — white `CircleBorder` with the bundled official
  `assets/icons/google.png` at its supplied **18pt** (never recoloured or
  distorted).
- **`_appleSignInButton`** — white circle, `Clip.antiAlias`, holding the
  official **SVG** scaled so its 44pt square fills the 44pt disc and then
  clipped to a circle (Apple's sanctioned "circular mask"). The scale factor is
  `56 / 44` because the bundled SVG canvas is 56pt while its coloured square is
  44pt — this keeps the artwork's built-in proportion (never cropped).
- **Platform guard** — the Apple control shows only on iOS/macOS
  (`defaultTargetPlatform`); elsewhere only Google is shown.
- **Accessibility** — `Semantics(button: true, label: …)` + `Tooltip`; the
  label comes from l10n (`authContinueWithApple` / `authContinueWithGoogle`).
  The Apple logo-only button is still announced as "Sign in with Apple".

### Assets & provenance

- `assets/icons/apple_logo_only.svg` — Apple's official "Logo - SIWA -
  Logo-only - Black" (white square + black logo), bundled **verbatim** (SHA-256
  `7ee1bc17…`). Provenance and the Developer Artwork licence terms are recorded
  in `assets/icons/NOTICE`.
- `assets/icons/google.png` (+ `2.0x`/`3.0x`) — the official Google "G", see
  `assets/icons/NOTICE`.
- Rendered with `flutter_svg` (vector required for a non-44×44 logo-only button).

---

## 4. Pitfalls

- **Do not switch the Apple mark to the PNG artwork** at this size — Apple
  sanctions PNG only at 44×44 pt; use the SVG.
- **Do not crop/scale the Apple artwork's padding** to make the logo bigger.
  Enlarge the *button* instead.
- **Do not drop the Google "G" below its supplied 18pt** or recolour it, and
  keep it on a white disc.
- **Keep the two buttons the same size.** Shrinking one reintroduces the
  "Apple smaller" failure.
- **Never hand-draw the Apple logo.**

---

## 5. Sources

1. Apple, *Human Interface Guidelines* → **Sign in with Apple** (Creating a
   custom Sign in with Apple button) —
   <https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple>
2. Apple, *Apple Design Resources* → **Sign in with Apple Logo** (PNG/PDF/SVG)
   — <https://developer.apple.com/design/resources/> (`Logo-Sign-in-with-Apple.dmg`)
3. Apple, *Sign in with Apple usage guidelines for websites and other platforms*
   — <https://developer.apple.com/sign-in-with-apple/usage-guidelines-for-websites-and-other-platforms/>
4. Google, **Sign in with Google Branding Guidelines** —
   <https://developers.google.com/identity/branding-guidelines>
5. Google's own icon-only button assets (40×40, G ≈47.5%) —
   <https://developers.google.com/static/identity/images/branding_guideline_sample_lt_rd_sl.svg>
6. Community record of the "no smaller" rule (Stack Overflow *"App submission
   rejected because of Apple login button"*, Reddit r/UI_Design) —
   <https://stackoverflow.com/questions/61243303/>

A vendor-agnostic version of this guidance (reusable by other Qallariy apps) is
kept at the umbrella root: `AUTH-BUTTON-GUIDELINES.md` under
`/Users/daerean/Codes/apps/` (that root is not a Git repo).
