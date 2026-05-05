# DAO Governance System — Assignment 4

A complete on-chain DAO governance system built with Solidity, Foundry, and OpenZeppelin. Covers a governance token, full Governor + Timelock lifecycle, treasury management, a controlled contract, a minimal frontend, and a security audit.

---

## Project Structure

```
src/
  GovernanceToken.sol     — ERC20Votes + ERC20Permit governance token
  TokenVesting.sol        — Linear vesting for team allocation (12 months)
  MyGovernor.sol          — Full OpenZeppelin Governor with Timelock
  TimelockController      — deployed via OpenZeppelin (no custom file needed)
  Treasury.sol            — DAO treasury (ETH + ERC20), Timelock-controlled
  Box.sol                 — Minimal controlled contract (store/retrieve)
  ProtocolConfig.sol      — Fee parameter contract, Timelock-controlled

test/
  GovToken.t.sol          — 8 tests: token, delegation, snapshots, permit, vesting
  Governor.t.sol          — 12 tests: full governance lifecycle
  Part3.t.sol             — 2 end-to-end tests: Box.store + Treasury ETH release

script/
  DeployDAO.s.sol         — Full production deployment script (Sepolia)
  DeployDemoDAO.s.sol     — Demo deployment for local testing

frontend/
  index.html              — Minimal governance dApp
  app.js                  — Ethers.js wallet, token info, voting, delegation

docs/
  security-audit-report.md   — Manual + Slither findings (2-3 pages)
  slither-report.txt         — Raw Slither output
  deployment-checklist.md    — Post-deployment verification + monitoring plan
  verified-contracts.md      — Sepolia Etherscan links for all 7 contracts
```

---

## Governance Token (Part 1)

- Standard ERC20 with **ERC20Votes** (snapshot-based voting power) and **ERC20Permit** (EIP-2612 gasless approvals)
- Total supply: **100,000,000 GOV**
- Initial distribution handled in the deployment script:

| Allocation | % | Amount |
|---|---|---|
| Team (vested) | 40% | 40,000,000 GOV |
| Treasury | 30% | 30,000,000 GOV |
| Community airdrop | 20% | 20,000,000 GOV |
| Liquidity | 10% | 10,000,000 GOV |

Team tokens are locked in `TokenVesting.sol` and released linearly over 12 months.

---

## Governor & Timelock (Part 2)

| Parameter | Value |
|---|---|
| Voting delay | 7200 blocks (~1 day) |
| Voting period | 50400 blocks (~1 week) |
| Proposal threshold | 1,000,000 GOV (1% of supply) |
| Quorum | 4% of total supply |
| Timelock delay | 2 days (172800 seconds) |

**Governance flow:** `propose → voting delay → vote → queue → timelock delay → execute`

The Governor is the sole proposer on the Timelock. Execution is open to anyone (`EXECUTOR_ROLE` → `address(0)`). The deployer admin role is revoked after setup.

---

## Treasury & Controlled Contracts (Part 3)

- `Treasury.sol` holds ETH and ERC-20 tokens. Only the Timelock (via governance) can release funds.
- `Box.sol` is a simple contract owned by the Timelock with `store(uint256)` and `retrieve()`.
- `ProtocolConfig.sol` stores a fee parameter; ownership transferred to Timelock on deploy.

**Demonstrated proposal:** governance votes to call `Box.store(42)`, the value is verified after execution.

---

## Frontend (Part 4)

Open `frontend/index.html` directly in a browser (or use Live Server).

Features:
- Connect MetaMask wallet
- Display token balance, voting power, and current delegate
- Delegate votes to another address
- List active proposals with current state
- Cast vote (For / Against / Abstain) on any active proposal
- Display vote results after voting period ends

Requires MetaMask connected to **Sepolia testnet**.

---

## Build & Test

```bash
# Install dependencies
forge install

# Build
forge build

# Run all tests
forge test -v

# Run with gas report
forge test --gas-report

# Run a specific test file
forge test --match-contract GovTokenTest -v
forge test --match-contract GovernorTest -vvv
forge test --match-contract Part3Test -vvv
```

---

## Deployment (Part 5)

Create a `.env` file (never commit it):

```
PRIVATE_KEY=your_private_key
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/your_key
ETHERSCAN_API_KEY=your_etherscan_key
TEAM_WALLET=0x...
COMMUNITY_WALLET=0x...
LIQUIDITY_WALLET=0x...
```

Deploy and verify:

```bash
forge script script/DeployDAO.s.sol:DeployDAO \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

---

## Deployed Contracts — Sepolia Testnet

| Contract | Address | Etherscan |
|---|---|---|
| GovernanceToken | `0x88AE1264dFa66DcB21346dcaC2dB6206B18c3608` | [view](https://sepolia.etherscan.io/address/0x88ae1264dfa66dcb21346dcac2db6206b18c3608) |
| TimelockController | `0xf9036d19dAf2b9Bec80B3a563bb8cB398f0C5CE2` | [view](https://sepolia.etherscan.io/address/0xf9036d19daf2b9bec80b3a563bb8cb398f0c5ce2) |
| MyGovernor | `0x956F161e019E786a017BC03a82d2D424346f2F3F` | [view](https://sepolia.etherscan.io/address/0x956f161e019e786a017bc03a82d2d424346f2f3f) |
| Treasury | `0xB1cbd4E250A84eED631631d8253f7Eb8b3d476b0` | [view](https://sepolia.etherscan.io/address/0xb1cbd4e250a84eed631631d8253f7eb8b3d476b0) |
| Box | `0x340Ef896b9FAB6109A4A123056e1500AC0b504Aa` | [view](https://sepolia.etherscan.io/address/0x340ef896b9fab6109a4a123056e1500ac0b504aa) |
| ProtocolConfig | `0xc983c729F451792a02b6d752C90aa79887918fFF` | [view](https://sepolia.etherscan.io/address/0xc983c729f451792a02b6d752c90aa79887918fff) |
| TokenVesting | `0x2528eE7bF60485650552900293f134a4453437B0` | [view](https://sepolia.etherscan.io/address/0x2528ee7bf60485650552900293f134a4453437b0) |

All 7 contracts verified on Sepolia Etherscan.

---

## Security Audit Summary (Part 5)

A full audit report is in `docs/security-audit-report.md`. Key points:

- **No critical vulnerabilities** found
- Low/informational findings: missing zero-address checks in `TokenVesting` and `Treasury`, low-level ETH call in `Treasury`, timestamp dependency in vesting, naming conventions
- **Flash loan protection:** ERC20Votes snapshots voting power at a past block — tokens borrowed after snapshot creation cannot be used to vote
- **Whale risk:** a holder with >50% supply can pass proposals; mitigated by the 2-day Timelock delay, voting delay, and careful token distribution
- Slither output: `docs/slither-report.txt`

---

## Dependencies

- [Foundry](https://book.getfoundry.sh/)
- [OpenZeppelin Contracts v5](https://github.com/OpenZeppelin/openzeppelin-contracts)
- [forge-std](https://github.com/foundry-rs/forge-std)
- [Ethers.js v6](https://docs.ethers.org/v6/) (frontend)