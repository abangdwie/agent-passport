# Agent Passport

Free commemorative mint for Binance Agent ID holders — entry for the
**Agent ID Hackathon** (Binance Wallet × BNB Chain, Nov 18 – Dec 9, 2026).

- **Collection:** Agent Passport (AGPASS), ERC-721, max supply 1,000
- **Claim:** free — caller pays only their own gas (~120k gas)
- **Gate:** caller must hold an Agent ID at claim time, checked on-chain
  against the SPACE ID Agent ID registry
  (`0x60b9262456de011f7d15a54cdd8c48baaa8b022f`, `balanceOf > 0`).
  One passport per holder address (Agent ID is non-transferable, so one
  address == one Agent ID). No tokenId lookup exists on the registry
  (`tokenOfOwner` / `tokenOfOwnerByIndex` do not exist; verified on BscScan),
  so the contract gates on `balanceOf` and records the holder address.
- **Tiers:** #1–10 Genesis (gold), #11–100 Pioneer (cyan), #101+ Agent (violet)
- **Art + metadata:** generated fully on-chain (SVG in `tokenURI`, base64 JSON).
  No IPFS, no server — the token renders even if the website disappears.
- **Trust:** no owner, no admin functions, no payable functions, no funds held.

## Hackathon fit

- Agent ID is the core of the product: the contract calls the registry on
  every claim (access control + identity). Depth is not a badge — without an
  Agent ID the transaction reverts.
- Real use: a verifiable, on-chain "I was here" proof for agents, with
  tiered scarcity that rewards early claimers.
- Costs: deploy aktual 3,733,512 gas (0,000246637 BNB ≈ $0,15 ≈ Rp2.653,
  19 Nov 2026); claim ~120–164k gas (~$0,004). Fits a $3 budget with margin.

## Layout

- `src/AgentPassport.sol` — the contract (Solidity 0.8.24, OpenZeppelin 5.4.0)
- `test/AgentPassport.t.sol` — 12 tests (claim rules, tiers, tokenURI, SVG)
- `web/` — static claim site (injected wallet only, no QR / WalletConnect)
- `preview/` — rendered SVG/PNG previews of #001 / #011 / #101

## Build & test

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge build
forge test            # 12 tests, all green
```

## Deploy (BNB Chain mainnet, chain 56)

**DEPLOYED 19 Nov 2026 17:07 WIB** — contract
`0x621d4Ee3Bb6239fb6a14120433df94Cd02538f69`
([BscScan](https://bscscan.com/address/0x621d4Ee3Bb6239fb6a14120433df94Cd02538f69)),
tx `0x3834cd2e8a93bca4d8c39ba543cdd2a5c5949ba8533a3ec4c9aa6891fb7c5518`
(block 134484446, status success). Gas aktual 3,733,512 (0,000246637 BNB ≈ $0,15).

Deployed from calmlet.ai (`0x3fF786B753427a71E42d6E220D01D6301606EC85`) via the
Binance Agentic Wallet CLI (`baw contract-call`) through the standard CREATE2
factory `0x4e59b44847b379578588920ca78fbf26c0b4956c` (salt 0) — `baw` cannot send
a contract-creation transaction directly, and the wallet key is held by Binance
(no exportable private key, no Foundry keystore). The deployed contract is
byte-for-byte the source in this repo. `CONFIG.passport` in `web/app.js` is set
to the deployed address.

## BscScan verification settings

- Compiler: **v0.8.24**, optimization **enabled, 200 runs**, **via-IR enabled**
- License: MIT. Constructor arg: Agent ID registry
  `0x60b9262456de011f7d15a54cdd8c48baaa8b022f`
- Flatten with `forge flatten` or verify via standard JSON input with the
  exact settings above.

## Fork test (mainnet, no real gas)

```bash
anvil --fork-url https://bsc-dataseed1.binance.org --port 8545 &
# deploy, then impersonate an Agent ID holder (e.g. calmlet.ai):
cast send <PASSPORT> "claim()" --rpc-url http://127.0.0.1:8545 \
  --unlocked --from 0x3fF786B753427a71E42d6E220D01D6301606EC85
```
