// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";
import {TokenVesting} from "../src/TokenVesting.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Treasury} from "../src/Treasury.sol";
import {Box} from "../src/Box.sol";
import {ProtocolConfig} from "../src/ProtocolConfig.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract DeployDAO is Script {
    uint256 private constant MIN_DELAY = 2 days;
    uint256 private constant VESTING_DURATION = 365 days;
    uint256 private constant TEAM_ALLOCATION = 40_000_000e18;
    uint256 private constant TREASURY_ALLOCATION = 30_000_000e18;
    uint256 private constant COMMUNITY_ALLOCATION = 20_000_000e18;
    uint256 private constant LIQUIDITY_ALLOCATION = 10_000_000e18;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address teamWallet = vm.envAddress("TEAM_WALLET");
        address communityWallet = vm.envAddress("COMMUNITY_WALLET");
        address liquidityWallet = vm.envAddress("LIQUIDITY_WALLET");

        vm.startBroadcast(deployerPrivateKey);

        GovernanceToken token = new GovernanceToken();

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);

        TimelockController timelock = new TimelockController(
            MIN_DELAY,
            proposers,
            executors,
            deployer
        );

        MyGovernor governor = new MyGovernor(token, timelock);
        Treasury treasury = new Treasury(address(timelock));
        Box box = new Box(address(timelock));
        ProtocolConfig config = new ProtocolConfig();

        TokenVesting vesting = new TokenVesting(
            address(token),
            teamWallet,
            block.timestamp,
            VESTING_DURATION
        );

        config.transferOwnership(address(timelock));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        require(token.transfer(address(vesting), TEAM_ALLOCATION), "Team transfer failed");
        require(token.transfer(address(treasury), TREASURY_ALLOCATION), "Treasury transfer failed");
        require(token.transfer(communityWallet, COMMUNITY_ALLOCATION), "Community transfer failed");
        require(token.transfer(liquidityWallet, LIQUIDITY_ALLOCATION), "Liquidity transfer failed");

        vm.stopBroadcast();

        console2.log("GovernanceToken:", address(token));
        console2.log("TokenVesting:", address(vesting));
        console2.log("TimelockController:", address(timelock));
        console2.log("MyGovernor:", address(governor));
        console2.log("Treasury:", address(treasury));
        console2.log("Box:", address(box));
        console2.log("ProtocolConfig:", address(config));
        console2.log("Deployer:", deployer);
        console2.log("TeamWallet:", teamWallet);
        console2.log("CommunityWallet:", communityWallet);
        console2.log("LiquidityWallet:", liquidityWallet);
    }
}