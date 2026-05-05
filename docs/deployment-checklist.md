# DAO Deployment Checklist and Monitoring Plan

## 1. Purpose

This document describes the post-deployment verification checklist and monitoring plan for the DAO governance system.

It covers:

- deployed contract address checks;
- Timelock role verification;
- Governor parameter verification;
- ownership verification;
- token distribution verification;
- Etherscan verification status;
- monitoring events and metrics after deployment.

## 2. Deployed Network

Network: Ethereum Sepolia Testnet  
Chain ID: 11155111  
Deployment tool: Foundry  
Deployment script: script/DeployDAO.s.sol

## 3. Deployed Contract Addresses

| Contract | Address |
|---|---|
| GovernanceToken | 0x88AE1264dFa66DcB21346dcaC2dB6206B18c3608 |
| TokenVesting | 0x2528eE7bF60485650552900293f134a4453437B0 |
| TimelockController | 0xf9036d19dAf2b9Bec80B3a563bb8cB398f0C5CE2 |
| MyGovernor | 0x956F161e019E786a017BC03a82d2D424346f2F3F |
| Treasury | 0xB1cbd4E250A84eED631631d8253f7Eb8b3d476b0 |
| Box | 0x340Ef896b9FAB6109A4A123056e1500AC0b504Aa |
| ProtocolConfig | 0xc983c729F451792a02b6d752C90aa79887918fFF |

## 4. Post-Deployment Verification Checklist

### 4.1 Contract Deployment Check

Status: Completed

Actions:

- Confirm that each contract has a non-zero address.
- Confirm that all addresses are visible on Sepolia Etherscan.
- Confirm that the deployment transaction for each contract succeeded.
- Confirm that the deployment script output matches the addresses saved in documentation.

Expected result:

All seven DAO contracts should be deployed successfully on Sepolia.

### 4.2 Source Code Verification Check

Status: Completed

Actions:

- Verify GovernanceToken on Sepolia Etherscan.
- Verify TimelockController on Sepolia Etherscan.
- Verify MyGovernor on Sepolia Etherscan.
- Verify Treasury on Sepolia Etherscan.
- Verify Box on Sepolia Etherscan.
- Verify ProtocolConfig on Sepolia Etherscan.
- Verify TokenVesting on Sepolia Etherscan.

Expected result:

Each contract page should show that the contract source code is verified.

Actual result:

All seven contracts were successfully verified.

### 4.3 Timelock Role Check

Status: Required after deployment

The Timelock must be configured so that the Governor controls proposal scheduling and execution.

Required checks:

- Governor has PROPOSER_ROLE.
- `address(0)` has EXECUTOR_ROLE.
- Deployer does not have DEFAULT_ADMIN_ROLE after deployment.
- Timelock keeps its self-admin role.

Expected configuration:

| Role | Expected Account |
|---|---|
| PROPOSER_ROLE | MyGovernor |
| EXECUTOR_ROLE | address(0) |
| DEFAULT_ADMIN_ROLE | TimelockController |
| DEFAULT_ADMIN_ROLE | Not deployer |

Suggested command examples:

    cast call 0xf9036d19dAf2b9Bec80B3a563bb8cB398f0C5CE2 "PROPOSER_ROLE()(bytes32)" --rpc-url $env:SEPOLIA_RPC_URL

    cast call 0xf9036d19dAf2b9Bec80B3a563bb8cB398f0C5CE2 "EXECUTOR_ROLE()(bytes32)" --rpc-url $env:SEPOLIA_RPC_URL

    cast call 0xf9036d19dAf2b9Bec80B3a563bb8cB398f0C5CE2 "DEFAULT_ADMIN_ROLE()(bytes32)" --rpc-url $env:SEPOLIA_RPC_URL

The returned role identifiers can be used with hasRole.

### 4.4 Timelock Delay Check

Status: Required after deployment

The assignment requires a 2-day Timelock delay.

Expected value:

    172800 seconds

Suggested command:

    cast call 0xf9036d19dAf2b9Bec80B3a563bb8cB398f0C5CE2 "getMinDelay()(uint256)" --rpc-url $env:SEPOLIA_RPC_URL

Expected result:

    172800

This confirms that the Timelock delay is correctly configured.

### 4.5 Governor Parameter Check

Status: Required after deployment

The Governor should use the following parameters:

| Parameter | Expected Value |
|---|---|
| votingDelay | 7200 blocks |
| votingPeriod | 50400 blocks |
| proposalThreshold | 1000000 GOV |
| quorum | 4% of total supply |

Suggested commands:

    cast call 0x956F161e019E786a017BC03a82d2D424346f2F3F "votingDelay()(uint256)" --rpc-url $env:SEPOLIA_RPC_URL

    cast call 0x956F161e019E786a017BC03a82d2D424346f2F3F "votingPeriod()(uint256)" --rpc-url $env:SEPOLIA_RPC_URL

    cast call 0x956F161e019E786a017BC03a82d2D424346f2F3F "proposalThreshold()(uint256)" --rpc-url $env:SEPOLIA_RPC_URL

Expected results:

    votingDelay = 7200
    votingPeriod = 50400
    proposalThreshold = 1000000000000000000000000

### 4.6 Ownership Check

Status: Required after deployment

The Timelock should own the controlled contracts.

Required ownership checks:

| Contract | Expected Owner |
|---|---|
| Treasury | TimelockController |
| Box | TimelockController |
| ProtocolConfig | TimelockController |

Suggested commands:

    cast call 0xB1cbd4E250A84eED631631d8253f7Eb8b3d476b0 "owner()(address)" --rpc-url $env:SEPOLIA_RPC_URL

    cast call 0x340Ef896b9FAB6109A4A123056e1500AC0b504Aa "owner()(address)" --rpc-url $env:SEPOLIA_RPC_URL

    cast call 0xc983c729F451792a02b6d752C90aa79887918fFF "owner()(address)" --rpc-url $env:SEPOLIA_RPC_URL

Expected result:

Each command should return:

    0xf9036d19dAf2b9Bec80B3a563bb8cB398f0C5CE2

This confirms that the deployer cannot directly control treasury withdrawals or parameter changes.

### 4.7 Token Distribution Check

Status: Required after deployment

Initial token distribution should follow the assignment requirement:

| Allocation | Percentage | Expected Amount |
|---|---:|---:|
| Team vesting | 40% | 40,000,000 GOV |
| Treasury | 30% | 30,000,000 GOV |
| Community | 20% | 20,000,000 GOV |
| Liquidity | 10% | 10,000,000 GOV |

Suggested commands:

    cast call 0x88AE1264dFa66DcB21346dcaC2dB6206B18c3608 "balanceOf(address)(uint256)" 0x2528eE7bF60485650552900293f134a4453437B0 --rpc-url $env:SEPOLIA_RPC_URL

    cast call 0x88AE1264dFa66DcB21346dcaC2dB6206B18c3608 "balanceOf(address)(uint256)" 0xB1cbd4E250A84eED631631d8253f7Eb8b3d476b0 --rpc-url $env:SEPOLIA_RPC_URL

Expected results:

- TokenVesting should hold 40,000,000 GOV.
- Treasury should hold 30,000,000 GOV.

Because community and liquidity wallets were configured as the deployer wallet in this test deployment, the deployer wallet should hold the combined community and liquidity allocation.

## 5. Monitoring Plan

### 5.1 Events to Monitor

The following events should be monitored after production deployment.

#### Governance Events

From MyGovernor:

- ProposalCreated
- VoteCast
- VoteCastWithParams
- ProposalQueued
- ProposalExecuted
- ProposalCanceled

Why monitor:

These events show the full lifecycle of governance proposals and help detect suspicious or high-risk proposals.

#### Timelock Events

From TimelockController:

- CallScheduled
- CallExecuted
- Cancelled
- MinDelayChange
- RoleGranted
- RoleRevoked

Why monitor:

These events show when governance actions are scheduled, executed, cancelled, or when permissions change.

#### Treasury Events

From Treasury:

- Received
- EthReleased
- Erc20Released

Why monitor:

These events track treasury inflows and outflows. Any large withdrawal should be reviewed carefully.

#### Token Events

From GovernanceToken:

- Transfer
- DelegateChanged
- DelegateVotesChanged
- Approval

Why monitor:

These events show voting power movement, delegation changes, token concentration, and approvals.

#### Controlled Contract Events

From Box:

- ValueChanged

From ProtocolConfig:

- FeeUpdated

Why monitor:

These events confirm whether governance-controlled actions were executed successfully.

### 5.2 Metrics to Track

The following metrics should be tracked regularly:

| Metric | Reason |
|---|---|
| Number of active proposals | Shows governance activity |
| Proposal state changes | Tracks proposal lifecycle |
| Voting turnout | Measures governance participation |
| For / Against / Abstain votes | Shows voting distribution |
| Treasury token balance | Detects treasury fund changes |
| Treasury ETH balance | Detects ETH inflows and outflows |
| Largest token holder voting power | Detects whale risk |
| Delegation concentration | Shows if voting power is centralized |
| Queued Timelock operations | Gives time to react before execution |
| Role changes in Timelock | Detects permission changes |
| Fee changes in ProtocolConfig | Detects protocol parameter updates |
| Box value changes | Confirms controlled contract execution |

### 5.3 Monitoring Frequency

Recommended monitoring schedule:

| Item | Frequency |
|---|---|
| New proposals | Daily |
| Active votes | Daily during voting period |
| Queued proposals | Immediately after queueing |
| Treasury withdrawals | Immediately |
| Role changes | Immediately |
| Large token transfers | Daily |
| Large delegation changes | Daily |
| Contract verification status | After every deployment |
| Governor parameters | After every upgrade or redeployment |
| Timelock delay | After every deployment and parameter update |

### 5.4 Alert Conditions

Alerts should be triggered when:

- a new proposal is created;
- a proposal targets Treasury;
- a proposal transfers ERC20 tokens or ETH;
- a proposal changes protocol parameters;
- a proposal is queued in the Timelock;
- a proposal is executed;
- a large holder delegates or receives significant voting power;
- Timelock roles are granted or revoked;
- Timelock delay changes;
- Treasury releases ETH or tokens.

### 5.5 Response Plan

If a suspicious proposal is detected:

1. Review proposal target contracts and calldata.
2. Decode calldata to understand the exact action.
3. Check proposer voting power and token source.
4. Notify DAO members before the voting period ends.
5. If the proposal passes, monitor the Timelock queue.
6. Use the Timelock delay period to react before execution.
7. If available, coordinate community action or emergency response.

## 6. Production Readiness Summary

The DAO deployment has the main production readiness components:

- Foundry deployment script.
- Correct deployment order.
- Timelock-based ownership.
- Governor as Timelock proposer.
- Public Timelock execution.
- Deployer admin role revoked.
- Slither audit completed.
- Manual security review completed.
- Testnet deployment completed.
- Etherscan verification completed.
- Post-deployment verification checklist prepared.
- Monitoring plan prepared.

The DAO is suitable for testnet demonstration and frontend integration. Before mainnet deployment, the recommended security improvements from the audit report should be reviewed and applied where necessary.
