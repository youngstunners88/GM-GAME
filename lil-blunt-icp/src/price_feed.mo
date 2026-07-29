import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Char "mo:base/Char";
import Cycles "mo:base/ExperimentalCycles";
import Error "mo:base/Error";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";

/// Lil Blunt — price feed canister (Layer 4).
///
/// Caches token prices fetched by HTTPS outcall so the game client never talks
/// to a price API directly. Two reasons that matters, and only one of them is
/// decentralisation:
///   1. The API key stays server-side. A Godot web export ships its whole
///      script bundle to the browser, so ANY key in the client is public.
///   2. One outcall serves every player, instead of every client hammering the
///      provider and burning the rate limit.
///
/// COST WARNING: HTTPS outcalls are the most expensive thing on the IC — they
/// run on every replica in the subnet. `refresh` is therefore admin-gated and
/// rate-limited, never something a player can trigger. An open refresh endpoint
/// is a cycles-drain attack.
persistent actor PriceFeed {

  public type Quote = {
    symbol : Text;
    price : Float;
    updated_at : Int;
  };

  public type Result = { #ok : (); #err : Text };

  /// Minimum gap between outcalls. Prices move slower than this and cycles
  /// don't grow on trees.
  let MIN_REFRESH_INTERVAL_NS : Int = 60_000_000_000;  // 60s
  /// Cap the response we're willing to pay to receive. Outcall cost scales
  /// with this number, so it is deliberately tight.
  let MAX_RESPONSE_BYTES : Nat64 = 4_000;
  /// Sanity ceiling on a single quote. Anything above this is a parse artifact
  /// or a hostile source, never a real token price.
  let MAX_PRICE : Float = 1.0e18;

  var quotes : [Quote] = [];
  var last_refresh : Int = 0;
  var admin : ?Principal = null;
  /// Where to fetch from. Configurable so the provider can change without a
  /// canister upgrade. Must be https — the IC refuses plain http outcalls.
  var source_url : Text = "";

  // ---- admin --------------------------------------------------------------

  public shared ({ caller }) func claimAdmin() : async Result {
    if (Principal.isAnonymous(caller)) { return #err("anonymous cannot be admin") };
    switch (admin) {
      case (?_) { #err("admin already claimed") };
      case null { admin := ?caller; #ok(()) };
    };
  };

  func isAdmin(caller : Principal) : Bool {
    switch (admin) { case (?a) { a == caller }; case null { false } };
  };

  public shared ({ caller }) func setSource(url : Text) : async Result {
    if (not isAdmin(caller)) { return #err("not authorized") };
    if (not Text.startsWith(url, #text "https://")) {
      return #err("source must be https");
    };
    source_url := url;
    #ok(());
  };

  // ---- HTTPS outcall ------------------------------------------------------

  public type HttpHeader = { name : Text; value : Text };
  public type HttpMethod = { #get; #post; #head };

  public type HttpResponsePayload = {
    status : Nat;
    headers : [HttpHeader];
    body : [Nat8];
  };

  public type TransformArg = {
    response : HttpResponsePayload;
    context : Blob;
  };

  public type CanisterHttpRequestArgs = {
    url : Text;
    max_response_bytes : ?Nat64;
    headers : [HttpHeader];
    body : ?[Nat8];
    method : HttpMethod;
    transform : ?{
      function : shared query TransformArg -> async HttpResponsePayload;
      context : Blob;
    };
  };

  let ic : actor {
    http_request : CanisterHttpRequestArgs -> async HttpResponsePayload;
  } = actor ("aaaaa-aa");

  /// Every replica must derive a BYTE-IDENTICAL response or consensus fails.
  /// Provider responses carry Date headers and rate-limit counters that differ
  /// per replica, so we strip headers entirely and keep only the body. This
  /// function existing is not optional — without it, outcalls to any real API
  /// fail consensus intermittently and look like random network flakiness.
  public query func transform(arg : TransformArg) : async HttpResponsePayload {
    {
      status = arg.response.status;
      headers = [];
      body = arg.response.body;
    };
  };

  /// Admin-gated, rate-limited refresh.
  public shared ({ caller }) func refresh() : async Result {
    if (not isAdmin(caller)) { return #err("not authorized") };
    if (source_url == "") { return #err("no source configured") };
    let now = Time.now();
    if (now - last_refresh < MIN_REFRESH_INTERVAL_NS) {
      return #err("rate limited — one refresh per 60s");
    };

    let request : CanisterHttpRequestArgs = {
      url = source_url;
      max_response_bytes = ?MAX_RESPONSE_BYTES;
      headers = [{ name = "User-Agent"; value = "lil-blunt-price-feed" }];
      body = null;
      method = #get;
      transform = ?{ function = transform; context = Blob.fromArray([]) };
    };

    try {
      // Outcalls must be paid for up front. Unused cycles are refunded.
      Cycles.add<system>(230_949_972_000);
      let response = await ic.http_request(request);
      if (response.status != 200) {
        return #err("source returned " # Nat.toText(response.status));
      };
      last_refresh := now;
      switch (Text.decodeUtf8(Blob.fromArray(response.body))) {
        case (?body) { ingest(body, now); #ok(()) };
        case null { #err("source body was not valid utf-8") };
      };
    } catch (e) {
      #err("outcall failed: " # Error.message(e));
    };
  };

  /// Parse `{"ETH":3456.78,"SMOKE":0.00042}` without a JSON library.
  ///
  /// Deliberately tolerant: an unparseable entry is SKIPPED, never written as
  /// zero. A zero price rendered in the HUD as "$0.00" reads as a crashed
  /// token, so a stale-but-real price beats a fresh-but-wrong one.
  func ingest(body : Text, now : Int) {
    var parsed : [Quote] = [];
    // Strip whitespace FIRST. Trimming '{' and '}' off a body that ends in a
    // newline removed nothing, so the final pair kept its "}" and failed to
    // parse — silently dropping the LAST symbol on every refresh. Trailing
    // newlines are normal in real API responses, and the tolerant-skip design
    // meant it vanished without any error at all.
    let clean = Text.trim(body, #predicate(func(c : Char) : Bool {
      c == ' ' or c == '\n' or c == '\r' or c == '\t'
    }));
    let trimmed = Text.trim(Text.trim(clean, #char '{'), #char '}');
    for (pair in Text.split(trimmed, #char ',')) {
      let kv = Text.split(pair, #char ':');
      switch (kv.next(), kv.next()) {
        case (?rawKey, ?rawVal) {
          let symbol = Text.trim(Text.trim(rawKey, #char ' '), #char '\"');
          switch (parseFloat(Text.trim(rawVal, #char ' '))) {
            case (?price) {
              // Upper bound matters as much as the lower one: parseFloat
              // accumulates without limit, and IEEE doubles do not trap on
              // overflow — they become +inf, which passes a bare `> 0.0`
              // guard, gets stored, and then poisons every later render.
              if (symbol != "" and price > 0.0 and price < MAX_PRICE) {
                parsed := Array.append<Quote>(parsed, [{
                  symbol = symbol;
                  price = price;
                  updated_at = now;
                }]);
              };
            };
            case null {};
          };
        };
        case _ {};
      };
    };
    if (parsed.size() > 0) { quotes := parsed };
  };

  func parseFloat(t : Text) : ?Float {
    var whole : Float = 0.0;
    var frac : Float = 0.0;
    var scale : Float = 0.1;
    var seenDigit = false;
    var afterPoint = false;
    for (c in Text.toIter(t)) {
      if (c == '.') {
        if (afterPoint) { return null };
        afterPoint := true;
      } else {
        let d = Char.toNat32(c);
        if (d < 48 or d > 57) { return null };
        seenDigit := true;
        let v = Float.fromInt(Nat32.toNat(d - 48));
        if (afterPoint) { frac += v * scale; scale *= 0.1 } else {
          whole := whole * 10.0 + v;
        };
      };
    };
    if (seenDigit) { ?(whole + frac) } else { null };
  };

  // ---- reads --------------------------------------------------------------

  public query func getQuotes() : async [Quote] { quotes };
  public query func lastRefresh() : async Int { last_refresh };

  // ---- HTTP read interface (what Godot actually calls) --------------------

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

  func jsonEscape(t : Text) : Text {
    var out = "";
    for (c in Text.toIter(t)) {
      out #= (
        switch (c) {
          case ('\"') { "\\\"" };
          case ('\\') { "\\\\" };
          case (_) { if (Char.toNat32(c) < 0x20) { "" } else { Text.fromChar(c) } };
        }
      );
    };
    out;
  };

  /// Render a Float with 8 decimal places. Motoko has no printf; sub-cent
  /// tokens like SMOKE need the precision, so we do it by hand rather than
  /// lose it to scientific notation.
  func floatToText(f : Float) : Text {
    if (f < 0.0) { return "0" };
    let whole = Float.toInt(Float.floor(f));
    var rem = f - Float.fromInt(whole);
    var digits = "";
    var i = 0;
    while (i < 8) {
      rem *= 10.0;
      let d = Float.toInt(Float.floor(rem));
      digits #= Int.toText(d);
      rem -= Float.fromInt(d);
      i += 1;
    };
    Int.toText(whole) # "." # digits;
  };

  func quotesJson() : Text {
    var body = "";
    var first = true;
    for (q in quotes.vals()) {
      if (not first) { body #= "," };
      body #= "\"" # jsonEscape(q.symbol) # "\":" # floatToText(q.price);
      first := false;
    };
    "{\"source\":\"icp\",\"updated_at\":" # Int.toText(last_refresh)
    # ",\"prices\":{" # body # "}}";
  };

  func json(status : Nat16, body : Text) : HttpResponse {
    {
      status_code = status;
      headers = [
        ("content-type", "application/json"),
        ("access-control-allow-origin", "*"),
      ];
      body = Text.encodeUtf8(body);
    };
  };

  func path(url : Text) : Text {
    let parts = Text.split(url, #char '?');
    switch (parts.next()) { case (?p) { p }; case null { url } };
  };

  public query func http_request(req : HttpRequest) : async HttpResponse {
    if (req.method != "GET") { return json(405, "{\"error\":\"reads only\"}") };
    let p = path(req.url);
    if (p == "/health") {
      return json(200, "{\"ok\":true,\"canister\":\"price_feed\",\"quotes\":"
        # Nat.toText(quotes.size()) # "}");
    };
    if (p == "/prices" or p == "/") { return json(200, quotesJson()) };
    json(404, "{\"error\":\"not found\"}");
  };
};
