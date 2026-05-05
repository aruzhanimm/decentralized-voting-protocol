# Verified Contracts on Sepolia

All DAO contracts were deployed and verified on Ethereum Sepolia testnet using Foundry.

## Command Used

    forge script script/DeployDAO.s.sol:DeployDAO --rpc-url $env:SEPOLIA_RPC_URL --broadcast --resume --verify --etherscan-api-key $env:ETHERSCAN_API_KEY --private-key $env:PRIVATE_KEY

## Verification Result

    All (7) contracts were verified!

## Verified Contract Links

| Contract | Address | Sepolia Etherscan Link |
|---|---|---|
| GovernanceToken | 0x88AE1264dFa66DcB21346dcaC2dB6206B18c3608 | https://sepolia.etherscan.io/address/0x88ae1264dfa66dcb21346dcac2db6206b18c3608 |
| TimelockController | 0xf9036d19dAf2b9Bec80B3a563bb8cB398f0C5CE2 | https://sepolia.etherscan.io/address/0xf9036d19daf2b9bec80b3a563bb8cb398f0c5ce2 |
| MyGovernor | 0x956F161e019E786a017BC03a82d2D424346f2F3F | https://sepolia.etherscan.io/address/0x956f161e019e786a017bc03a82d2d424346f2f3f |
| Treasury | 0xB1cbd4E250A84eED631631d8253f7Eb8b3d476b0 | https://sepolia.etherscan.io/address/0xb1cbd4e250a84eed631631d8253f7eb8b3d476b0 |
| Box | 0x340Ef896b9FAB6109A4A123056e1500AC0b504Aa | https://sepolia.etherscan.io/address/0x340ef896b9fab6109a4a123056e1500ac0b504aa |
| ProtocolConfig | 0xc983c729F451792a02b6d752C90aa79887918fFF | https://sepolia.etherscan.io/address/0xc983c729f451792a02b6d752c90aa79887918fff |
| TokenVesting | 0x2528eE7bF60485650552900293f134a4453437B0 | https://sepolia.etherscan.io/address/0x2528ee7bf60485650552900293f134a4453437b0 |

## Deployment Summary

The DAO system was deployed to Ethereum Sepolia testnet. The deployment included the following contracts:

1. GovernanceToken
2. TimelockController
3. MyGovernor
4. Treasury
5. Box
6. ProtocolConfig
7. TokenVesting

The deployment script also configured the governance permissions:

- Governor was granted the Timelock proposer role.
- `address(0)` was granted the Timelock executor role, allowing public execution of passed proposals.
- The deployer admin role was revoked from the Timelock.
- Treasury and Box were deployed with Timelock ownership.
- ProtocolConfig ownership was transferred to the Timelock.
- The initial token supply was distributed between vesting, treasury, community, and liquidity wallets.

## Verification Summary

All deployed DAO contracts were verified on Sepolia Etherscan. Verification confirms that the deployed bytecode matches the submitted Solidity source code, compiler version, optimizer settings, and constructor arguments.

This satisfies the production readiness requirement to verify all contracts on a testnet block explorer.
