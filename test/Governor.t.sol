// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {ProtocolConfig} from "../src/ProtocolConfig.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract GovernorTest is Test {
    GovernanceToken public token;
    TimelockController public timelock;
    MyGovernor public governor;
    ProtocolConfig public config;

    address public deployer = address(this);
    address public whale = makeAddr("whale");
    address public delegator = makeAddr("delegator");
    address public delegatee = makeAddr("delegatee");
    address public receiver = makeAddr("receiver");
    uint256 public constant MIN_DELAY = 2 days; // 2 days timelock delay
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
        // 4. Grant Roles
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();
        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0)); // Anyone can execute
        timelock.revokeRole(adminRole, deployer); // Remove deployer admin
        // 5. Deploy Controlled Contract & transfer ownership to Timelock
        config = new ProtocolConfig();
        config.transferOwnership(address(timelock));
        // 6. Fund Treasury & Distribute Tokens
        token.transfer(address(timelock), 30_000_000e18); // 30M to Treasury
        token.transfer(whale, 10_000_000e18); // 10% to Whale (to pass proposals alone)
        token.transfer(delegator, 5_000_000e18); // 5% to Delegator
        // Activate voting power
        vm.prank(whale);
        token.delegate(whale);
        vm.roll(block.number + 1);
    }

    // --- HELPER FUNCTION ---
    // Fast forwards time and blocks
    function _moveBlock(uint256 blocks) internal {
        vm.roll(block.number + blocks);
    }
    function _moveTime(uint256 time) internal {
        vm.warp(block.timestamp + time);
    }

    // Test 1: Deployment & Roles Set Correctly
    function test_TimelockRolesAreCorrect() public view {
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();
        assertTrue(timelock.hasRole(proposerRole, address(governor)));
        assertFalse(timelock.hasRole(adminRole, deployer)); // Deployer no longer admin
    }
    // Test 2: Revert proposing without enough tokens (Threshold)
    function test_RevertProposeWithoutThreshold() public {
        address brokeUser = makeAddr("broke");
        address[] memory targets = new address[](1);
        targets[0] = address(config);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("updateFee(uint256)", 200);
        vm.startPrank(brokeUser);
        vm.expectRevert();
        governor.propose(targets, values, calldatas, "Fail to propose");
        vm.stopPrank();
    }
    // Test 3: Propose parameter change
    function test_ProposeParameterChange() public {
        address[] memory targets = new address[](1);
        targets[0] = address(config);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("updateFee(uint256)", 200);
        vm.prank(whale);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Change fee");
        assertEq(uint256(governor.state(proposalId)), 0); // State 0 = Pending
    }
    // Test 4: Propose transfer from treasury
    function test_ProposeTransferFromTreasury() public {
        address[] memory targets = new address[](1);
        targets[0] = address(token);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("transfer(address,uint256)", receiver, 1000e18);
        vm.prank(whale);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Fund receiver");
        assertEq(uint256(governor.state(proposalId)), 0);
    }
    // Test 5: Revert voting before Active
    function test_RevertVotingBeforeActive() public {
        address[] memory targets = new address[](1);
        targets[0] = address(config);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("updateFee(uint256)", 200);
        vm.prank(whale);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Test");
        vm.prank(whale);
        vm.expectRevert(); // Voting delay hasn't passed
        governor.castVote(proposalId, 1);
    }
    // Test 6: Delegatee votes on behalf of delegator
    function test_DelegateeVotesForDelegator() public {
        // Delegator gives power to delegatee
        vm.prank(delegator);
        token.delegate(delegatee);
        vm.roll(block.number + 1);
        assertEq(token.getVotes(delegatee), 5_000_000e18);
        // Whale proposes
        address[] memory targets = new address[](1);
        targets[0] = address(config);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("updateFee(uint256)", 200);
        vm.prank(whale);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Test");
        _moveBlock(VOTING_DELAY + 1);
        // Delegatee casts vote (using Delegator's tokens)
        vm.prank(delegatee);
        governor.castVote(proposalId, 1); // 1 = For
        (uint256 againstVotes, uint256 forVotes, ) = governor.proposalVotes(proposalId);
        assertEq(forVotes, 5_000_000e18);
        assertEq(againstVotes, 0);
    }
    // Test 7: Proposal failure - Quorum not met
    function test_ProposalFailsQuorumNotMet() public {
        // Propose
        address[] memory targets = new address[](1);
        targets[0] = address(config);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("updateFee(uint256)", 200);
        vm.prank(whale);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Test");
        _moveBlock(VOTING_DELAY + 1);
        // User with low tokens votes
        address tiny = makeAddr("tiny");
        token.transfer(tiny, 1000e18);
        vm.prank(tiny);
        token.delegate(tiny);
        vm.prank(tiny);
        governor.castVote(proposalId, 1); // For
        _moveBlock(VOTING_PERIOD + 1);
        assertEq(uint256(governor.state(proposalId)), 3); // State 3 = Defeated (no quorum)
    }
    // Test 8: Proposal failure - Defeated (Against > For)
    function test_ProposalDefeated() public {
        address[] memory targets = new address[](1);
        targets[0] = address(config);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("updateFee(uint256)", 200);
        vm.prank(whale);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Test");
        _moveBlock(VOTING_DELAY + 1);
        vm.prank(whale);
        governor.castVote(proposalId, 0); // 0 = Against
        _moveBlock(VOTING_PERIOD + 1);
        assertEq(uint256(governor.state(proposalId)), 3); // Defeated
    }

    // Test 9: Revert Queueing before Succeeded
    function test_RevertQueueingBeforeSucceeded() public {
        address[] memory targets = new address[](1);
        targets[0] = address(config);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("updateFee(uint256)", 200);
        bytes32 descHash = keccak256(bytes("Test"));
        vm.prank(whale);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Test");
        _moveBlock(VOTING_DELAY + 1);
        vm.prank(whale);
        governor.castVote(proposalId, 1);
        vm.expectRevert(); // Still active, can't queue
        governor.queue(targets, values, calldatas, descHash);
    }

    // Test 10: Revert Execution before Timelock delay passes
    function test_RevertExecuteBeforeDelay() public {
        address[] memory targets = new address[](1);
        targets[0] = address(config);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("updateFee(uint256)", 200);
        bytes32 descHash = keccak256(bytes("Test"));
        vm.prank(whale);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Test");
        _moveBlock(VOTING_DELAY + 1);
        vm.prank(whale);
        governor.castVote(proposalId, 1);
        _moveBlock(VOTING_PERIOD + 1);
        governor.queue(targets, values, calldatas, descHash);
        vm.expectRevert(); // Timelock hasn't passed
        governor.execute(targets, values, calldatas, descHash);
    }

    // Test 11: FULL LIFECYCLE - Parameter Change
    function test_FullLifecycleParameterChange() public {
        address[] memory targets = new address[](1);
        targets[0] = address(config);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("updateFee(uint256)", 350);
        bytes32 descHash = keccak256(bytes("Change Fee to 350"));
        // Propose
        vm.prank(whale);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Change Fee to 350");
        // Vote
        _moveBlock(VOTING_DELAY + 1);
        vm.prank(whale);
        governor.castVote(proposalId, 1);
        // Queue
        _moveBlock(VOTING_PERIOD + 1);
        governor.queue(targets, values, calldatas, descHash);
        // Execute
        _moveTime(MIN_DELAY + 1);
        governor.execute(targets, values, calldatas, descHash);
        // Assert
        assertEq(config.feePercentage(), 350);
    }
    // Test 12: FULL LIFECYCLE - Transfer Tokens from Treasury
    function test_FullLifecycleTransferTreasury() public {
        uint256 transferAmount = 5_000_000e18;
        address[] memory targets = new address[](1);
        targets[0] = address(token); // Targeting the token contract
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("transfer(address,uint256)", receiver, transferAmount);
        bytes32 descHash = keccak256(bytes("Fund receiver"));
        // Propose
        vm.prank(whale);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Fund receiver");
        // Vote
        _moveBlock(VOTING_DELAY + 1);
        vm.prank(whale);
        governor.castVote(proposalId, 1);
        // Queue
        _moveBlock(VOTING_PERIOD + 1);
        governor.queue(targets, values, calldatas, descHash);
        // Execute
        _moveTime(MIN_DELAY + 1);
        governor.execute(targets, values, calldatas, descHash);
        // Assert Treasury transfer
        assertEq(token.balanceOf(receiver), transferAmount);
    }
}