extends RefCounted
class_name ScorecardGrant
## Local scorecard bookkeeping for the protocol portals.
##
## This class NEVER mints, never networks and never calls Meshy or any wallet:
## it only records that a completed run earned a scorecard slot, in
## user://portal_scorecards.json, keyed by the protocol token id.
## A later, human-run step may read load_all() and mint out of band.

const SignalsScript := preload("res://src/protocol_portals/PortalSignals.gd")

const SAVE_PATH: String = "user://portal_scorecards.json"


## Marks a finished session eligible. Returns the record that was written, or an
## empty dictionary when the session is not (or no longer) eligible.
## The parameter is typed RefCounted so this file does not depend on the global
## PortalSession class name being registered in headless runs.
static func mark_eligible(session: RefCounted) -> Dictionary:
    if session == null:
        return {}
    if not bool(session.call("eligible_for_scorecard")):
        return {}

    # The scorecard is only "pending" until the mint actually happens offline.
    session.set("pending_icp", true)

    var token: String = String(session.get("nft_token_id"))
    if token.is_empty():
        var protocol: String = String(session.get("protocol"))
        token = String(SignalsScript.TOKEN_IDS.get(protocol, ""))
    if token.is_empty():
        return {}

    var all: Dictionary = load_all()
    var record: Dictionary = session.call("to_dict")
    record["eligible"] = true
    record["minted"] = false
    record["minted_at"] = ""
    all[token] = record
    _write_all(all)
    return record


## Every recorded scorecard entry, keyed by token id. Empty when nothing has
## been recorded yet (or the file is unreadable/malformed).
static func load_all() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return {}
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        push_warning("ScorecardGrant: could not open %s (err %d)"
            % [SAVE_PATH, FileAccess.get_open_error()])
        return {}
    var text: String = file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("ScorecardGrant: %s does not contain a JSON object" % SAVE_PATH)
        return {}
    return parsed


## Merges the whole table back to disk. Local file only — nothing leaves the
## machine here.
static func _write_all(all: Dictionary) -> void:
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_warning("ScorecardGrant: could not write %s (err %d)"
            % [SAVE_PATH, FileAccess.get_open_error()])
        return
    file.store_string(JSON.stringify(all, "  "))
    file.close()
