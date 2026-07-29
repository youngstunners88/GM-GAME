import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Char "mo:base/Char";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Order "mo:base/Order";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";

/// Lil Blunt — tamper-evident leaderboard canister (Layer 4).
///
/// WHY THIS CANISTER FIRST: the Cloudflare Worker backend already serves
/// scores, and it is cheap and fast. What it cannot do is *prove* it isn't
/// lying. Anyone (including us) can rewrite a row in KV. On ICP the score list
/// is replicated state produced by public code, so "the scoreboard is honest"
/// stops being a promise and becomes something a player can check.
///
/// SECURITY POSTURE (matches docs/security/GAME_SECURITY_CHECKLIST.md):
///  - `caller` is the authenticated Internet Identity principal. It is NOT
///    supplied by the client, so a player cannot submit as someone else.
///  - The anonymous principal is rejected outright — no drive-by writes.
///  - Sanity ceilings + per-principal cooldown blunt the obvious score
///    injection. This is deliberately NOT presented as full anti-cheat: a
///    client-authoritative game can always lie about its own score. What this
///    buys is attribution and an auditable history, which is the honest claim.
///  - No secrets, no keys, no wallet addresses live in here.
persistent actor Leaderboard {

  public type Entry = {
    player : Principal;
    handle : Text;
    level : Nat;
    score : Nat;
    at : Int;
  };

  public type SubmitResult = {
    #ok : { rank : Nat; accepted : Bool };
    #err : Text;
  };

  /// Highest score the game can legitimately produce, with headroom for the
  /// 5x combo multiplier. Anything above this is a forged payload, not a run.
  let MAX_SCORE : Nat = 5_000_000;
  let MAX_LEVEL : Nat = 12;
  let MAX_HANDLE_LEN : Nat = 24;
  /// Board depth. Bounded on purpose: an unbounded board is an unbounded
  /// cycles bill, and nobody reads past the first page anyway.
  let TOP_N : Nat = 100;
  /// One submission per principal per 10s. A real run cannot finish faster.
  let SUBMIT_COOLDOWN_NS : Int = 10_000_000_000;

  var entries : [Entry] = [];
  var cooldowns : [(Principal, Int)] = [];
  /// Set once, by the first caller to claim it (the deployer). Admin can only
  /// REMOVE entries — it can never mint or edit a score, so the worst a
  /// compromised admin key can do is delete, never fabricate.
  var admin : ?Principal = null;

  // ---- helpers ------------------------------------------------------------

  func byScoreDesc(a : Entry, b : Entry) : Order.Order {
    if (a.score > b.score) { #less } else if (a.score < b.score) { #greater } else {
      // Stable tiebreak: whoever got there first ranks higher.
      Int.compare(a.at, b.at);
    };
  };

  func lastSubmitOf(p : Principal) : Int {
    switch (Array.find<(Principal, Int)>(cooldowns, func((q, _)) { q == p })) {
      case (?(_, t)) { t };
      case null { 0 };
    };
  };

  /// Record this principal's submission time, and EVICT every entry whose
  /// cooldown has already expired.
  ///
  /// The eviction is the point. Without it this array grew once per unique
  /// principal, forever, and never shrank — principals are free to mint, so it
  /// was an unbounded-state and unbounded-cycles surface, and every `submit`
  /// paid an O(n) scan over it. The board itself is capped at TOP_N; this was
  /// the uncapped thing hiding behind it. An expired entry is semantically
  /// dead, so dropping it costs nothing.
  func touchCooldown(p : Principal, now : Int) {
    let kept = Array.filter<(Principal, Int)>(
      cooldowns,
      func((q, t)) { q != p and now - t < SUBMIT_COOLDOWN_NS },
    );
    let buf = Buffer.fromArray<(Principal, Int)>(kept);
    buf.add((p, now));
    cooldowns := Buffer.toArray(buf);
  };

  /// Remove a player's existing entry for a level, so one strong player cannot
  /// wallpaper the board with near-identical entries.
  ///
  /// NOTE: this drops the entry unconditionally. Callers that want
  /// "keep the best" must compare first — see `bestScoreFor` and its use in
  /// `submit`. An earlier version of this file claimed in a comment that it
  /// kept the best run and did not, so a worse resubmission silently erased a
  /// better score.
  func withoutPriorRun(list : [Entry], p : Principal, level : Nat) : [Entry] {
    Array.filter<Entry>(list, func(e) { not (e.player == p and e.level == level) });
  };

  /// The player's current score for a level, or null if they have none.
  func bestScoreFor(p : Principal, level : Nat) : ?Nat {
    for (e in entries.vals()) {
      if (e.player == p and e.level == level) { return ?e.score };
    };
    null;
  };

  func sanitizeHandle(raw : Text) : Text {
    let trimmed = Text.trim(raw, #char ' ');
    if (Text.size(trimmed) == 0) { return "anon" };
    if (Text.size(trimmed) <= MAX_HANDLE_LEN) { return trimmed };
    // Truncate rather than reject: a long name is clumsiness, not an attack.
    var out = "";
    var n = 0;
    for (c in Text.toIter(trimmed)) {
      if (n < MAX_HANDLE_LEN) { out #= Text.fromChar(c); n += 1 };
    };
    out;
  };

  // ---- public API ---------------------------------------------------------

  /// Submit a run. Returns the resulting rank (1-based) when it made the board.
  public shared ({ caller }) func submit(level : Nat, score : Nat, handle : Text) : async SubmitResult {
    if (Principal.isAnonymous(caller)) {
      return #err("sign in with Internet Identity before submitting a score");
    };
    if (level == 0 or level > MAX_LEVEL) { return #err("level out of range") };
    if (score > MAX_SCORE) { return #err("score above the game's maximum") };

    let now = Time.now();
    if (now - lastSubmitOf(caller) < SUBMIT_COOLDOWN_NS) {
      return #err("slow down — one submission per 10 seconds");
    };
    touchCooldown(caller, now);

    let entry : Entry = {
      player = caller;
      handle = sanitizeHandle(handle);
      level = level;
      score = score;
      at = now;
    };

    // Keep the BEST run, not the latest. Without this, a player who replays a
    // level and does worse wipes their own record off the board — and a
    // double-submitting client could erase a real score with a zero.
    switch (bestScoreFor(caller, level)) {
      case (?existing) {
        if (score <= existing) {
          return #ok({ rank = 0; accepted = false });
        };
      };
      case null {};
    };

    let buf = Buffer.fromArray<Entry>(withoutPriorRun(entries, caller, level));
    buf.add(entry);
    let sorted = Array.sort<Entry>(Buffer.toArray(buf), byScoreDesc);
    entries := if (sorted.size() > TOP_N) {
      Array.subArray<Entry>(sorted, 0, TOP_N);
    } else { sorted };

    // Rank is only meaningful if the entry survived the TOP_N cut.
    var rank = 0;
    var i = 0;
    for (e in entries.vals()) {
      i += 1;
      if (e.player == caller and e.level == level and e.at == now) { rank := i };
    };
    #ok({ rank = rank; accepted = rank > 0 });
  };

  /// Public read. Anyone, including an unauthenticated browser, can verify the
  /// board — that is the entire point of putting it here.
  public query func top(limit : Nat) : async [Entry] {
    let n = if (limit == 0 or limit > entries.size()) { entries.size() } else { limit };
    Array.subArray<Entry>(entries, 0, n);
  };

  public query func topForLevel(level : Nat, limit : Nat) : async [Entry] {
    let filtered = Array.filter<Entry>(entries, func(e) { e.level == level });
    let n = if (limit == 0 or limit > filtered.size()) { filtered.size() } else { limit };
    Array.subArray<Entry>(filtered, 0, n);
  };

  public query func size() : async Nat { entries.size() };

  /// One-time, first-come claim by the deployer. After that it is fixed.
  public shared ({ caller }) func claimAdmin() : async Result {
    if (Principal.isAnonymous(caller)) { return #err("anonymous cannot be admin") };
    switch (admin) {
      case (?_) { #err("admin already claimed") };
      case null { admin := ?caller; #ok(()) };
    };
  };

  public type Result = { #ok : (); #err : Text };

  /// Moderation only — removes an entry. There is deliberately no "set score".
  public shared ({ caller }) func removeEntry(player : Principal, level : Nat) : async Result {
    switch (admin) {
      case (?a) {
        if (a != caller) { return #err("not authorized") };
        entries := withoutPriorRun(entries, player, level);
        #ok(());
      };
      case null { #err("no admin claimed yet") };
    };
  };

  public query func getAdmin() : async ?Principal { admin };

  // ---- HTTP read interface ------------------------------------------------
  //
  // Godot's HTTPRequest speaks plain HTTP, not Candid. Exposing http_request
  // lets the game GET https://<canister-id>.icp0.io/top and parse JSON with
  // zero extra client libraries — the same shape the Cloudflare Worker already
  // returns, so icp_backend.gd can fall back between them without branching.
  //
  // READS ONLY, by design. Writes stay Candid update calls so they carry an
  // authenticated caller; an HTTP POST here would arrive anonymous and defeat
  // the entire point of moving the board on-chain.

  public type HeaderField = (Text, Text);

  public type HttpRequest = {
    method : Text;
    url : Text;
    headers : [HeaderField];
    body : Blob;
  };

  public type HttpResponse = {
    status_code : Nat16;
    headers : [HeaderField];
    body : Blob;
  };

  /// Minimal JSON string escaper. `handle` is player-supplied, so it is the
  /// one field here that could break out of the document — everything else is
  /// a Nat/Int we render ourselves.
  func jsonEscape(t : Text) : Text {
    var out = "";
    for (c in Text.toIter(t)) {
      out #= (
        switch (c) {
          case ('\"') { "\\\"" };
          case ('\\') { "\\\\" };
          case ('\n') { "\\n" };
          case ('\r') { "\\r" };
          case ('\t') { "\\t" };
          case (_) {
            // Drop C0 controls rather than emit raw bytes into the JSON.
            if (Char.toNat32(c) < 0x20) { "" } else { Text.fromChar(c) };
          };
        }
      );
    };
    out;
  };

  func entryToJson(e : Entry) : Text {
    "{\"player\":\"" # Principal.toText(e.player)
    # "\",\"handle\":\"" # jsonEscape(e.handle)
    # "\",\"level\":" # Nat.toText(e.level)
    # ",\"score\":" # Nat.toText(e.score)
    # ",\"at\":" # Int.toText(e.at) # "}";
  };

  func listToJson(list : [Entry]) : Text {
    var body = "";
    var first = true;
    for (e in list.vals()) {
      if (not first) { body #= "," };
      body #= entryToJson(e);
      first := false;
    };
    "{\"source\":\"icp\",\"count\":" # Nat.toText(list.size()) # ",\"entries\":[" # body # "]}";
  };

  /// Pull a numeric query param out of `?a=1&b=2`. Returns `fallback` for a
  /// missing or non-numeric value — a malformed URL should degrade to the
  /// default board, not error.
  func queryNat(url : Text, key : Text, fallback : Nat) : Nat {
    let parts = Text.split(url, #char '?');
    ignore parts.next();
    switch (parts.next()) {
      case null { fallback };
      case (?qs) {
        for (pair in Text.split(qs, #char '&')) {
          let kv = Text.split(pair, #char '=');
          switch (kv.next()) {
            case (?k) {
              if (k == key) {
                switch (kv.next()) {
                  case (?v) {
                    var acc : Nat = 0;
                    var ok = Text.size(v) > 0;
                    for (c in Text.toIter(v)) {
                      let d = Char.toNat32(c);
                      if (d >= 48 and d <= 57) {
                        acc := acc * 10 + Nat32.toNat(d - 48);
                      } else { ok := false };
                    };
                    if (ok) { return acc };
                  };
                  case null {};
                };
              };
            };
            case null {};
          };
        };
        fallback;
      };
    };
  };

  func path(url : Text) : Text {
    let parts = Text.split(url, #char '?');
    switch (parts.next()) { case (?p) { p }; case null { url } };
  };

  func json(status : Nat16, body : Text) : HttpResponse {
    {
      status_code = status;
      headers = [
        ("content-type", "application/json"),
        // The game is served from itch.io / Vercel, not from the canister
        // origin, so the board is explicitly public-readable cross-origin.
        // Safe precisely because this interface exposes no writes.
        ("access-control-allow-origin", "*"),
      ];
      body = Text.encodeUtf8(body);
    };
  };

  public query func http_request(req : HttpRequest) : async HttpResponse {
    if (req.method != "GET") {
      return json(405, "{\"error\":\"reads only — submit scores via Candid\"}");
    };
    let p = path(req.url);
    let limit = queryNat(req.url, "limit", 25);
    if (p == "/health") {
      return json(200, "{\"ok\":true,\"canister\":\"leaderboard\",\"entries\":" # Nat.toText(entries.size()) # "}");
    };
    if (p == "/top" or p == "/") {
      let level = queryNat(req.url, "level", 0);
      let list = if (level == 0) { entries } else {
        Array.filter<Entry>(entries, func(e) { e.level == level });
      };
      let n = if (limit == 0 or limit > list.size()) { list.size() } else { limit };
      return json(200, listToJson(Array.subArray<Entry>(list, 0, n)));
    };
    json(404, "{\"error\":\"not found\"}");
  };
};
