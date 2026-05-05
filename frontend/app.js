const CONTRACTS = {
  token: "0x88AE1264dFa66DcB21346dcaC2dB6206B18c3608",
  governor: "0x956F161e019E786a017BC03a82d2D424346f2F3F",
  box: "0x340Ef896b9FAB6109A4A123056e1500AC0b504Aa"
};

const TOKEN_ABI = [
  "function balanceOf(address account) view returns (uint256)",
  "function getVotes(address account) view returns (uint256)",
  "function delegates(address account) view returns (address)",
  "function delegate(address delegatee) returns ()"
];

const GOVERNOR_ABI = [
  "function propose(address[] targets,uint256[] values,bytes[] calldatas,string description) returns (uint256)",
  "function state(uint256 proposalId) view returns (uint8)",
  "function castVote(uint256 proposalId,uint8 support) returns (uint256)",
  "function proposalVotes(uint256 proposalId) view returns (uint256 againstVotes,uint256 forVotes,uint256 abstainVotes)",
  "event ProposalCreated(uint256 proposalId,address proposer,address[] targets,uint256[] values,string[] signatures,bytes[] calldatas,uint256 voteStart,uint256 voteEnd,string description)"
];

const BOX_ABI = [
  "function store(uint256 newValue)"
];

const PROPOSAL_STATES = [
  "Pending",
  "Active",
  "Canceled",
  "Defeated",
  "Succeeded",
  "Queued",
  "Expired",
  "Executed"
];

let provider;
let signer;
let account;
let tokenContract;
let governorContract;
let boxInterface;

const connectWalletBtn = document.getElementById("connectWalletBtn");
const refreshInfoBtn = document.getElementById("refreshInfoBtn");
const delegateBtn = document.getElementById("delegateBtn");
const createProposalBtn = document.getElementById("createProposalBtn");
const loadProposalBtn = document.getElementById("loadProposalBtn");
const voteAgainstBtn = document.getElementById("voteAgainstBtn");
const voteForBtn = document.getElementById("voteForBtn");
const voteAbstainBtn = document.getElementById("voteAbstainBtn");
const loadResultsBtn = document.getElementById("loadResultsBtn");

function setText(id, value) {
  document.getElementById(id).textContent = value;
}

function log(message) {
  const statusLog = document.getElementById("statusLog");
  statusLog.textContent = `${new Date().toLocaleTimeString()} - ${message}\n${statusLog.textContent}`;
}

function formatGov(value) {
  return `${ethers.formatUnits(value, 18)} GOV`;
}

function getProposalId() {
  const proposalId = document.getElementById("proposalIdInput").value.trim();
  if (!proposalId) {
    throw new Error("Please enter a proposal ID.");
  }
  return proposalId;
}

async function connectWallet() {
  if (!window.ethereum) {
    alert("MetaMask is not installed.");
    return;
  }

  provider = new ethers.BrowserProvider(window.ethereum);
  await provider.send("eth_requestAccounts", []);
  signer = await provider.getSigner();
  account = await signer.getAddress();

  tokenContract = new ethers.Contract(CONTRACTS.token, TOKEN_ABI, signer);
  governorContract = new ethers.Contract(CONTRACTS.governor, GOVERNOR_ABI, signer);
  boxInterface = new ethers.Interface(BOX_ABI);

  const network = await provider.getNetwork();
  if (Number(network.chainId) !== 11155111) {
    alert("Please switch MetaMask to Ethereum Sepolia network.");
    setText("network", `${network.name} (${network.chainId})`);
    return;
  }

  setText("account", account);
  setText("network", `${network.name} (${network.chainId})`);
  document.getElementById("delegateInput").value = account;

  log("Wallet connected.");
  await refreshWalletInfo();
}

async function refreshWalletInfo() {
  if (!tokenContract || !account) {
    alert("Connect wallet first.");
    return;
  }

  const balance = await tokenContract.balanceOf(account);
  const votes = await tokenContract.getVotes(account);
  const delegate = await tokenContract.delegates(account);

  setText("tokenBalance", formatGov(balance));
  setText("votingPower", formatGov(votes));
  setText("delegateAddress", delegate);

  log("Wallet information refreshed.");
}

async function delegateVotes() {
  if (!tokenContract) {
    alert("Connect wallet first.");
    return;
  }

  const delegateAddress = document.getElementById("delegateInput").value.trim();

  if (!ethers.isAddress(delegateAddress)) {
    alert("Invalid delegate address.");
    return;
  }

  log("Sending delegate transaction...");
  const tx = await tokenContract.delegate(delegateAddress);
  setText("delegateTx", tx.hash);

  await tx.wait();
  log("Delegate transaction confirmed.");

  await refreshWalletInfo();
}

async function createDemoProposal() {
  if (!governorContract) {
    alert("Connect wallet first.");
    return;
  }

  const targets = [CONTRACTS.box];
  const values = [0];
  const calldatas = [boxInterface.encodeFunctionData("store", [42])];
  const description = "Proposal: Set Box value to 42";

  log("Creating proposal...");
  const tx = await governorContract.propose(targets, values, calldatas, description);
  setText("proposalTx", tx.hash);

  const receipt = await tx.wait();
  const parsedLogs = receipt.logs
    .map((item) => {
      try {
        return governorContract.interface.parseLog(item);
      } catch {
        return null;
      }
    })
    .filter(Boolean);

  const proposalCreatedEvent = parsedLogs.find((item) => item.name === "ProposalCreated");

  if (!proposalCreatedEvent) {
    throw new Error("ProposalCreated event not found.");
  }

  const proposalId = proposalCreatedEvent.args.proposalId.toString();

  setText("createdProposalId", proposalId);
  document.getElementById("proposalIdInput").value = proposalId;

  localStorage.setItem("lastProposalId", proposalId);

  log(`Proposal created: ${proposalId}`);
  await loadProposalState();
}

async function loadProposalState() {
  if (!governorContract) {
    alert("Connect wallet first.");
    return;
  }

  const proposalId = getProposalId();
  const stateNumber = await governorContract.state(proposalId);
  const stateName = PROPOSAL_STATES[Number(stateNumber)] || `Unknown (${stateNumber})`;

  setText("proposalState", stateName);
  log(`Proposal state loaded: ${stateName}.`);
}

async function castVote(support) {
  if (!governorContract) {
    alert("Connect wallet first.");
    return;
  }

  const proposalId = getProposalId();

  log("Sending vote transaction...");
  const tx = await governorContract.castVote(proposalId, support);
  setText("voteTx", tx.hash);

  await tx.wait();
  log("Vote transaction confirmed.");

  await loadProposalResults();
}

async function loadProposalResults() {
  if (!governorContract) {
    alert("Connect wallet first.");
    return;
  }

  const proposalId = getProposalId();
  const [againstVotes, forVotes, abstainVotes] = await governorContract.proposalVotes(proposalId);

  setText("againstVotes", formatGov(againstVotes));
  setText("forVotes", formatGov(forVotes));
  setText("abstainVotes", formatGov(abstainVotes));

  log("Proposal results loaded.");
}

connectWalletBtn.addEventListener("click", connectWallet);
refreshInfoBtn.addEventListener("click", refreshWalletInfo);
delegateBtn.addEventListener("click", delegateVotes);
createProposalBtn.addEventListener("click", createDemoProposal);
loadProposalBtn.addEventListener("click", loadProposalState);
voteAgainstBtn.addEventListener("click", () => castVote(0));
voteForBtn.addEventListener("click", () => castVote(1));
voteAbstainBtn.addEventListener("click", () => castVote(2));
loadResultsBtn.addEventListener("click", loadProposalResults);

window.addEventListener("load", () => {
  const lastProposalId = localStorage.getItem("lastProposalId");
  if (lastProposalId) {
    document.getElementById("proposalIdInput").value = lastProposalId;
    setText("createdProposalId", lastProposalId);
  }
});
if (window.ethereum) {
  window.ethereum.on("chainChanged", () => {
    localStorage.clear();
    location.reload();
  });

  window.ethereum.on("accountsChanged", () => {
    localStorage.clear();
    location.reload();
  });
}