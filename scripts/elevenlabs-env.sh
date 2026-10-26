#!/usr/bin/env bash
# Load both ElevenLabs keys for an asset run. Source it, do not run it:  . scripts/elevenlabs-env.sh
# Keys live in ~/.config/gm-game (mode 600), one per file; nothing is printed.
#   elevenlabs.key   -> speech (text-to-speech, the voices)     ELEVENLABS_SPEECH_API_KEY
#   elevenlabs2.key  -> sound effects                            ELEVENLABS_SFX_API_KEY
# Change the two mappings below if the keys are used for other functions.
d="${GM_KEYS_DIR:-$HOME/.config/gm-game}"
_load() {                                  # _load <file> <var>: export only a real secret (sk_...), never an ID
	local v
	[ -s "$d/$1" ] || { echo "elevenlabs-env: $1 missing" >&2; return 1; }
	v="$(cat "$d/$1")"
	case "$v" in
		sk_*) export "$2=$v"; return 0 ;;
		*) echo "elevenlabs-env: $1 does not hold an sk_ secret (it is an ID or a partial paste); not loaded" >&2; return 1 ;;
	esac
}
_load elevenlabs.key ELEVENLABS_SPEECH_API_KEY
_load elevenlabs2.key ELEVENLABS_SFX_API_KEY
[ -n "${ELEVENLABS_SPEECH_API_KEY:-}" ] && export ELEVENLABS_API_KEY="$ELEVENLABS_SPEECH_API_KEY"
unset -f _load
echo "elevenlabs-env: speech=$([ -n "${ELEVENLABS_SPEECH_API_KEY:-}" ] && echo loaded || echo MISSING) sfx=$([ -n "${ELEVENLABS_SFX_API_KEY:-}" ] && echo loaded || echo MISSING)"
