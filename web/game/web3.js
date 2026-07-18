// Lil Blunt — browser-side Web3 bridge (Layer Shift / Movie Layer).
// Plain window.ethereum JSON-RPC + fetch. NO external library (ethers) so it
// works inside itch.io's sandbox with no CDN/CSP issues. Godot's Web3Bridge
// autoload calls window.LilBluntWeb3.* via JavaScriptBridge.eval.
//
// This exposes ZERO secrets — wallet actions are user-signed in their own
// extension; backend calls (Mistral etc.) go to the game's proxy which holds
// the keys. If there's no wallet, every call fails soft and the game plays on.
(function () {
  const W = {
    addr: "",
    _hasEth() { return typeof window.ethereum !== "undefined"; },

    // Request accounts. Writes the first account to W.addr for Godot to poll.
    async connect() {
      W.addr = "";
      if (!W._hasEth()) return "";
      try {
        const accts = await window.ethereum.request({ method: "eth_requestAccounts" });
        W.addr = (accts && accts[0]) ? accts[0] : "";
      } catch (e) { W.addr = ""; }
      return W.addr;
    },

    // ERC-20 balanceOf(address) via eth_call. Returns a decimal STRING of the
    // raw integer balance (Godot converts). 18-decimals-agnostic: any >0 means
    // "holds" for the perk checks. Returns "0" on any failure.
    balanceOf(token, owner) {
      try {
        if (!W._hasEth() || !token || !owner) return "0";
        // selector for balanceOf(address) = 0x70a08231, arg = 32-byte address
        const data = "0x70a08231" + owner.replace(/^0x/, "").toLowerCase().padStart(64, "0");
        // eth_call is async; we return a promise-resolved cached value pattern.
        // Godot polls synchronously, so kick the call and cache into W._bal.
        window.ethereum.request({
          method: "eth_call",
          params: [{ to: token, data: data }, "latest"],
        }).then((hex) => {
          W._bal = W._bal || {};
          W._bal[token] = hex && hex !== "0x" ? BigInt(hex).toString() : "0";
        }).catch(() => {});
        W._bal = W._bal || {};
        return W._bal[token] || "0";
      } catch (e) { return "0"; }
    },

    // Mint the Survivor badge — calls mint() (selector 0x1249c58b, no args) on
    // the badge contract, signed by the user. Free-to-write contracts only
    // charge gas. No-op if no wallet.
    mintBadge(contract) {
      if (!W._hasEth() || !W.addr || !contract) return;
      const data = "0x1249c58b"; // mint()
      window.ethereum.request({
        method: "eth_sendTransaction",
        params: [{ from: W.addr, to: contract, data: data }],
      }).catch(() => {});
    },

    // Open an external link (funnel / explorer) in a new tab.
    open(url) { if (url) window.open(url, "_blank", "noopener"); },
  };
  window.LilBluntWeb3 = W;
})();
