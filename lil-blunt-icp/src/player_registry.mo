import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Char "mo:base/Char";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";

/// Lil Blunt — player registry canister (Layer 4).
///
/// Identity and role, nothing else. Deliberately NOT a save-game store: the
/// campaign save stays local (`user://save.json`) so the game keeps working
/// with no network, which is a standing project rule. This canister answers one
/// question — "who is this player, and what tier are they?" — and does it with
/// an authenticated principal instead of a client-supplied id.
///
/// ROLE POLICY (this is the part that is easy to get wrong):
///   - Roles NEVER gate gameplay content. Per the v1.2 GDD, unlocks come from
///     campaign completion; holdings may add cosmetics only. `#premium` here
///     means "show the cosmetic flourishes", not "can play level 5".
///   - The canister does not verify token holdings itself. Doing so would need
///     an HTTPS outcall per player per session, which is a cycles bill scaling
///     with playercount. Verification stays in the price/balance path and the
///     result is recorded here by an admin-controlled process.
persistent actor PlayerRegistry {

  public type Role = { #player; #premium; #admin };

  public type Profile = {
    principal_id : Principal;
    handle : Text;
    /// EVM address, or "" — PUBLIC data only. A key or seed phrase must never
    /// reach this canister; there is no field that could hold one.
    wallet : Text;
    role : Role;
    registered_at : Int;
    last_seen : Int;
  };

  public type Result = { #ok : Profile; #err : Text };
  public type UnitResult = { #ok : (); #err : Text };

  let MAX_HANDLE_LEN : Nat = 24;

  var profiles : [Profile] = [];
  var admin : ?Principal = null;

  // ---- helpers ------------------------------------------------------------

  func indexOf(p : Principal) : ?Nat {
    var i = 0;
    for (entry in profiles.vals()) {
      if (entry.principal_id == p) { return ?i };
      i += 1;
    };
    null;
  };

  func replaceAt(index : Nat, updated : Profile) {
    let buf = Buffer.fromArray<Profile>(profiles);
    buf.put(index, updated);
    profiles := Buffer.toArray(buf);
  };

  func sanitizeHandle(raw : Text) : Text {
    let trimmed = Text.trim(raw, #char ' ');
    if (Text.size(trimmed) == 0) { return "anon" };
    var out = "";
    var n = 0;
    for (c in Text.toIter(trimmed)) {
      // Alphanumerics, underscore and dash only. Everything else is dropped
      // rather than rejected, so a player with an emoji name still registers
      // instead of hitting an error they can't interpret.
      let code = Char.toNat32(c);
      let ok = (code >= 48 and code <= 57)
        or (code >= 65 and code <= 90)
        or (code >= 97 and code <= 122)
        or c == '_' or c == '-';
      if (ok and n < MAX_HANDLE_LEN) { out #= Text.fromChar(c); n += 1 };
    };
    if (out == "") { "anon" } else { out };
  };

  /// Accept only a well-formed 0x-prefixed 40-hex EVM address, or "".
  /// Anything else is rejected outright — this string ends up rendered in UI
  /// and passed to balance lookups, so it must not be free-form text.
  func validWallet(w : Text) : Bool {
    if (w == "") { return true };
    if (Text.size(w) != 42) { return false };
    if (not Text.startsWith(w, #text "0x")) { return false };
    var i = 0;
    for (c in Text.toIter(w)) {
      if (i >= 2) {
        let code = Char.toNat32(c);
        let isHex = (code >= 48 and code <= 57)
          or (code >= 97 and code <= 102)
          or (code >= 65 and code <= 70);
        if (not isHex) { return false };
      };
      i += 1;
    };
    true;
  };

  func isAdmin(caller : Principal) : Bool {
    switch (admin) { case (?a) { a == caller }; case null { false } };
  };

  // ---- public API ---------------------------------------------------------

  /// Register on first sign-in, or update the handle on later calls.
  /// Idempotent: calling twice does not create a second profile.
  public shared ({ caller }) func register(handle : Text, wallet : Text) : async Result {
    if (Principal.isAnonymous(caller)) {
      return #err("sign in with Internet Identity first");
    };
    if (not validWallet(wallet)) { return #err("wallet must be 0x + 40 hex, or empty") };

    let now = Time.now();
    switch (indexOf(caller)) {
      case (?i) {
        let existing = profiles[i];
        let updated : Profile = {
          principal_id = existing.principal_id;
          handle = sanitizeHandle(handle);
          wallet = wallet;
          // A player can never change their OWN role — that would make
          // #premium self-serve.
          role = existing.role;
          registered_at = existing.registered_at;
          last_seen = now;
        };
        replaceAt(i, updated);
        #ok(updated);
      };
      case null {
        let created : Profile = {
          principal_id = caller;
          handle = sanitizeHandle(handle);
          wallet = wallet;
          role = #player;
          registered_at = now;
          last_seen = now;
        };
        profiles := Array.append<Profile>(profiles, [created]);
        #ok(created);
      };
    };
  };

  public shared ({ caller }) func heartbeat() : async UnitResult {
    switch (indexOf(caller)) {
      case (?i) {
        let e = profiles[i];
        replaceAt(i, {
          principal_id = e.principal_id;
          handle = e.handle;
          wallet = e.wallet;
          role = e.role;
          registered_at = e.registered_at;
          last_seen = Time.now();
        });
        #ok(());
      };
      case null { #err("not registered") };
    };
  };

  public query func getProfile(p : Principal) : async ?Profile {
    switch (indexOf(p)) { case (?i) { ?profiles[i] }; case null { null } };
  };

  public shared query ({ caller }) func me() : async ?Profile {
    switch (indexOf(caller)) { case (?i) { ?profiles[i] }; case null { null } };
  };

  public query func count() : async Nat { profiles.size() };

  // ---- admin --------------------------------------------------------------

  public shared ({ caller }) func claimAdmin() : async UnitResult {
    if (Principal.isAnonymous(caller)) { return #err("anonymous cannot be admin") };
    switch (admin) {
      case (?_) { #err("admin already claimed") };
      case null { admin := ?caller; #ok(()) };
    };
  };

  /// Cosmetic tier only — see the role policy at the top of this file.
  public shared ({ caller }) func setRole(target : Principal, role : Role) : async UnitResult {
    if (not isAdmin(caller)) { return #err("not authorized") };
    switch (indexOf(target)) {
      case (?i) {
        let e = profiles[i];
        replaceAt(i, {
          principal_id = e.principal_id;
          handle = e.handle;
          wallet = e.wallet;
          role = role;
          registered_at = e.registered_at;
          last_seen = e.last_seen;
        });
        #ok(());
      };
      case null { #err("no such profile") };
    };
  };

  public query func getAdmin() : async ?Principal { admin };
};
