// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";
import {MyGovernorDemo} from "../src/MyGovernorDemo.sol";
import {Treasury} from "../src/Treasury.sol";
import {Box} from "../src/Box.sol";
import {ProtocolConfig} from "../src/ProtocolConfig.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract DeployDemoDAO is Script {
    uint256 private constant MIN_DELAY = 60;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

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

        MyGovernorDemo governor = new MyGovernorDemo(token, timelock);
        Treasury treasury = new Treasury(address(timelock));
        Box box = new Box(address(timelock));
        ProtocolConfig config = new ProtocolConfig();

        config.transferOwnership(address(timelock));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        token.transfer(address(treasury), 30_000_000e18);
        token.transfer(deployer, 30_000_000e18);

        vm.stopBroadcast();

        console2.log("Demo GovernanceToken:", address(token));
        console2.log("Demo TimelockController:", address(timelock));
        console2.log("Demo MyGovernorDemo:", address(governor));
        console2.log("Demo Treasury:", address(treasury));
        console2.log("Demo Box:", address(box));
        console2.log("Demo ProtocolConfig:", address(config));
        console2.log("Demo Deployer:", deployer);
    }
}