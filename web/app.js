// Agent Passport — claim dApp (injected wallet only; no QR, no WalletConnect).
// Fill CONTRACT_ADDRESS after the mainnet deploy, then redeploy the site.
const CONFIG = {
  chainId: 56,
  chainIdHex: "0x38",
  rpcUrl: "https://bsc-dataseed.binance.org",
  agentIdRegistry: "0x60b9262456de011f7d15a54cdd8c48baaa8b022f",
  passport: "0x621d4Ee3Bb6239fb6a14120433df94Cd02538f69", // deployed 19 Nov 2026
  bscscan: "https://bscscan.com",
};

const PASSPORT_ABI = [
  "function claim()",
  "function totalSupply() view returns (uint256)",
  "function MAX_SUPPLY() view returns (uint256)",
  "function claimed(address) view returns (bool)",
  "function tokenURI(uint256) view returns (string)",
  "event Claimed(address indexed claimer, uint256 indexed tokenId, uint256 timestamp)",
];
const REGISTRY_ABI = ["function balanceOf(address) view returns (uint256)"];

const $ = (id) => document.getElementById(id);
const els = {
  supply: $("supply"), wallet: $("wallet"), agentId: $("agentId"),
  claimState: $("claimState"), status: $("status"),
  connectBtn: $("connectBtn"), claimBtn: $("claimBtn"), switchBtn: $("switchBtn"),
  contractLink: $("contractLink"), claimedArt: $("claimedArt"), claimedImg: $("claimedImg"),
};

let provider = null;      // read-only (public RPC)
let browserProvider = null;
let signer = null;
let account = null;
let passportRead = null;
let registryRead = null;

function showStatus(kind, msg) {
  els.status.className = "status " + kind;
  els.status.textContent = msg;
}
function clearStatus() { els.status.className = "status"; els.status.textContent = ""; }

function shortAddr(a) { return a ? a.slice(0, 6) + "…" + a.slice(-4) : "—"; }

async function refreshSupply() {
  try {
    const [supply, max] = await Promise.all([passportRead.totalSupply(), passportRead.MAX_SUPPLY()]);
    els.supply.textContent = supply.toString() + " / " + max.toString() + " minted";
    return { supply, max };
  } catch (e) {
    els.supply.textContent = "contract not deployed yet";
    return null;
  }
}

async function refreshAccountState() {
  if (!account) return;
  try {
    const [holds, already] = await Promise.all([
      registryRead.balanceOf(account),
      passportRead.claimed(account),
    ]);
    els.agentId.textContent = holds > 0n ? "Held ✓" : "Not held";
    if (holds === 0n) {
      els.claimState.textContent = "—";
      els.claimBtn.disabled = true;
      showStatus("warn", "This wallet holds no Agent ID. Claim your .ai name in the Binance App (Wallet > Agent ID), then come back.");
      return;
    }
    if (already) {
      els.claimState.textContent = "Claimed ✓";
      els.claimBtn.disabled = true;
      showStatus("ok", "You already claimed your passport. Check BscScan for your token.");
      return;
    }
    els.claimState.textContent = "Eligible";
    els.claimBtn.disabled = false;
    clearStatus();
  } catch (e) {
    showStatus("warn", "Could not read on-chain state: " + (e.reason || e.message || e));
  }
}

async function connect() {
  if (!window.ethereum) {
    showStatus("warn", "No injected wallet found. Install MetaMask or the Binance Wallet extension, then reload.");
    return;
  }
  try {
    browserProvider = new ethers.BrowserProvider(window.ethereum);
    const accounts = await browserProvider.send("eth_requestAccounts", []);
    account = accounts[0];
    signer = await browserProvider.getSigner();
    els.wallet.textContent = shortAddr(account);
    els.connectBtn.textContent = "Connected ✓";
    els.connectBtn.disabled = true;
    await checkNetwork();
    await refreshAccountState();
  } catch (e) {
    showStatus("warn", "Connection failed: " + (e.reason || e.message || e));
  }
}

async function checkNetwork() {
  const net = await browserProvider.getNetwork();
  if (Number(net.chainId) !== CONFIG.chainId) {
    els.switchBtn.style.display = "block";
    els.claimBtn.disabled = true;
    showStatus("info", "Wrong network — switch to BNB Chain (56) to claim.");
    return false;
  }
  els.switchBtn.style.display = "none";
  return true;
}

async function switchNetwork() {
  try {
    await browserProvider.send("wallet_switchEthereumChain", [{ chainId: CONFIG.chainIdHex }]);
    els.switchBtn.style.display = "none";
    await refreshAccountState();
  } catch (e) {
    showStatus("warn", "Could not switch network: " + (e.reason || e.message || e));
  }
}

async function claim() {
  if (!signer || !account) return;
  if (!(await checkNetwork())) return;
  els.claimBtn.disabled = true;
  els.claimBtn.textContent = "Waiting for signature…";
  try {
    const passport = new ethers.Contract(CONFIG.passport, PASSPORT_ABI, signer);
    const tx = await passport.claim();
    els.claimBtn.textContent = "Claiming…";
    showStatus("info", "Transaction sent: " + tx.hash + " — waiting for confirmation…");
    const receipt = await tx.wait();
    let tokenId = null;
    for (const log of receipt.logs) {
      try {
        const parsed = passport.interface.parseLog(log);
        if (parsed && parsed.name === "Claimed") tokenId = parsed.args.tokenId;
      } catch (_) { /* not our event */ }
    }
    if (tokenId === null) {
      const supply = await passportRead.totalSupply();
      tokenId = supply; // last minted
    }
    els.claimState.textContent = "Claimed ✓ #" + tokenId.toString();
    showStatus("ok", "Passport #" + tokenId.toString() + " is yours! Tx: " + CONFIG.bscscan + "/tx/" + tx.hash);
    try {
      const uri = await passportRead.tokenURI(tokenId);
      const meta = JSON.parse(atob(uri.split(",")[1]));
      els.claimedImg.src = meta.image;
      els.claimedArt.style.display = "block";
    } catch (_) { /* art is optional */ }
    await refreshSupply();
  } catch (e) {
    const msg = (e.reason || e.message || String(e)).slice(0, 200);
    showStatus("warn", "Claim failed: " + msg);
  } finally {
    els.claimBtn.textContent = "Claim passport";
    await refreshAccountState();
  }
}

async function init() {
  if (CONFIG.passport === "0x0000000000000000000000000000000000000000") {
    els.supply.textContent = "contract not deployed yet";
    els.contractLink.textContent = "contract deploys with the hackathon submission";
    els.contractLink.removeAttribute("href");
  } else {
    els.contractLink.textContent = CONFIG.passport;
    els.contractLink.href = CONFIG.bscscan + "/address/" + CONFIG.passport + "#code";
  }
  try {
    provider = new ethers.JsonRpcProvider(CONFIG.rpcUrl);
    passportRead = new ethers.Contract(CONFIG.passport, PASSPORT_ABI, provider);
    registryRead = new ethers.Contract(CONFIG.agentIdRegistry, REGISTRY_ABI, provider);
    await refreshSupply();
  } catch (_) { /* read provider optional until deploy */ }

  els.connectBtn.addEventListener("click", connect);
  els.claimBtn.addEventListener("click", claim);
  els.switchBtn.addEventListener("click", switchNetwork);
  if (window.ethereum) {
    window.ethereum.on("accountsChanged", () => location.reload());
    window.ethereum.on("chainChanged", () => location.reload());
  }
}

document.addEventListener("DOMContentLoaded", init);
