# SOCIAL LINKS — single source of truth

Confirmed by the founder 2026-07-19. **Every** in-game button, email footer,
share intent, and doc links THESE and only these. When one changes, update
this file first, then grep for the old value.

| Channel | URL | Used by |
|---|---|---|
| X | https://x.com/smokering25 (handle `@smokering25`) | snapshot-moment shares (`checkpoint.gd`), victory/milestone share intents, content-engine X drafts |
| Telegram | https://t.me/LilBluntdotWin | JOIN THE SMOKERING menu button (via `config.json.social.telegram`), email footers, newsletter CTAs |
| itch.io | https://youngstunners88.itch.io/lil-blunt-adventure | every Play CTA |
| Email sender | `smokering-notifications@agentmail.to` (LIVE — created 2026-07-19; becomes `notifications@smokering.game` after AgentMail plan upgrade + DNS) | AgentMail engine |
| Discord | — none yet (`config.json.social.discord` empty) | — |

Notes:
- The in-game JOIN button reads `config.json.social.telegram` at runtime —
  config is the wire, this file is the record.
- Old references to a generic `@SmokeRing` handle were replaced 2026-07-19.
- No Facebook/Instagram/TikTok by decision (see `marketing/03-decisions.md`).
