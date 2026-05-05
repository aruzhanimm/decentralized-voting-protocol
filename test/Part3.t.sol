// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";
import {Treasury} from "../src/Treasury.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
contract Part3Test is Test {
    GovernanceToken public token;
    TimelockController public timelock;
    MyGovernor public governor;
    Box public box;
    Treasury public treasury;
    address public deployer = address(this);
    address public whale = makeAddr("whale");
    address public receiver = makeAddr("receiver");
    uint256 public constant MIN_DELAY = 2 days;
    uint256 public constant VOTING_DELAY = 7200;
    uint256 public constant VOTING_PERIOD = 50400;
    function setUp() public {
        // 1. Deploy Token
        token = new GovernanceToken();
        // 2. Deploy Timelock
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        timelock = new TimelockController(MIN_DELAY, proposers, executors, deployer);
        // 3. Deploy Governor
        governor = new MyGovernor(token, timelock);
        // 4. Grant Roles in Timelock
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);
        // 5. Deploy Controlled Contracts (Box & Treasury), owned by Timelock
        box = new Box(address(timelock));
        treasury = new Treasury(address(timelock));
        // 6. Give tokens to Whale and self-delegate
        token.transfer(whale, 20_000_000e18); // 20M to Whale
        vm.prank(whale);
        token.delegate(whale);
        _moveBlock(1);
        // Fund Treasury with ETH and Tokens
        vm.deal(address(treasury), 10 ether);
        token.transfer(address(treasury), 1_000_000e18);
    }
    // Helper functions for time travel
    function _moveBlock(uint256 blocks) internal {
        vm.roll(block.number + blocks);
    }
    function _moveTime(uint256 time) internal {
        vm.warp(block.timestamp + time);
    }

    // --- TEST 1: Box End-to-End ---
    function test_EndToEnd_BoxStore() public {
        assertEq(box.retrieve(), 0); // Initial value is 0
        address[] memory targets = new address[](1);
        targets[0] = address(box);
        uint256[] memory values = new uint256[](1); // No ETH sent
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("store(uint256)", 42); // Call Box.store(42)
        bytes32 descHash = keccak256(bytes("Proposal: Set Box to 42"));
        // 1. PROPOSE
        vm.prank(whale);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Proposal: Set Box to 42");
        // 2. VOTE
        _moveBlock(VOTING_DELAY + 1); // Advance to Active state
        vm.prank(whale);
        governor.castVote(proposalId, 1); // Vote For
        // 3. QUEUE
        _moveBlock(VOTING_PERIOD + 1); // Advance to Succeeded state
        governor.queue(targets, values, calldatas, descHash);
        // 4. EXECUTE
        _moveTime(MIN_DELAY + 1); // Advance past Timelock delay
        governor.execute(targets, values, calldatas, descHash);
        // 5. VERIFY
        assertEq(box.retrieve(), 42); // Value should now be 42
    }
    //  TEST 2: Treasury ETH Transfer End-to-End 
    function test_EndToEnd_TreasuryEthRelease() public {
        uint256 initialReceiverBalance = receiver.balance;
        uint256 transferAmount = 2 ether;
        address[] memory targets = new address[](1);
        targets[0] = address(treasury);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("releaseEth(address,uint256)", payable(receiver), transferAmount);
        bytes32 descHash = keccak256(bytes("Proposal: Release 2 ETH"));
        // Lifecycle
        vm.prank(whale);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Proposal: Release 2 ETH");
        _moveBlock(VOTING_DELAY + 1);
        vm.prank(whale);
        governor.castVote(proposalId, 1);
        _moveBlock(VOTING_PERIOD + 1);
        governor.queue(targets, values, calldatas, descHash);
        _moveTime(MIN_DELAY + 1);
        governor.execute(targets, values, calldatas, descHash);
        // Verify
        assertEq(receiver.balance, initialReceiverBalance + transferAmount);
    }
}