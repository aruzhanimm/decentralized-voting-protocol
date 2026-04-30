pragma solidity ^0.8.24;
import {Test, console} from "forge-std/Test.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";
import {TokenVesting} from "../src/TokenVesting.sol";
contract GovTokenTest is Test {
GovernanceToken public token;
TokenVesting public vesting;
address public deployer = address(this);
address public teamWallet = makeAddr("team");
address public treasuryWallet = makeAddr("treasury");
address public airdropWallet = makeAddr("airdrop");
address public liquidityWallet = makeAddr("liquidity");
address public user1 = makeAddr("user1");
address public user2 = makeAddr("user2");
uint256 constant TOTAL_SUPPLY = 100_000_000e18;
uint256 constant ONE_YEAR = 365 days;
function setUp() public {
token = new GovernanceToken();
vesting = new TokenVesting(address(token), teamWallet, block.timestamp, ONE_YEAR);
token.transfer(address(vesting), 40_000_000e18);
token.transfer(treasuryWallet, 30_000_000e18);
token.transfer(airdropWallet, 20_000_000e18);
token.transfer(liquidityWallet, 10_000_000e18);
}
function test_InitialDistribution() public view {
assertEq(token.balanceOf(address(vesting)), 40_000_000e18);
assertEq(token.balanceOf(treasuryWallet), 30_000_000e18);
assertEq(token.balanceOf(airdropWallet), 20_000_000e18);
assertEq(token.balanceOf(liquidityWallet), 10_000_000e18);
assertEq(token.totalSupply(), TOTAL_SUPPLY);
}
function test_DelegationActivatesVotingPower() public {
vm.startPrank(treasuryWallet);
assertEq(token.getVotes(treasuryWallet), 0);
token.delegate(treasuryWallet);
assertEq(token.getVotes(treasuryWallet), 30_000_000e18);
vm.stopPrank();
}
function test_VotingPowerSnapshots() public {
vm.prank(treasuryWallet);
token.delegate(treasuryWallet);
uint256 block1 = block.number;
vm.roll(block.number + 100);
vm.prank(treasuryWallet);
token.transfer(user1, 5_000_000e18);
assertEq(token.getPastVotes(treasuryWallet, block1), 30_000_000e18);
assertEq(token.getVotes(treasuryWallet), 25_000_000e18);
}
function test_PermitSignature() public {
(address owner, uint256 privateKey) = makeAddrAndKey("owner");
vm.prank(airdropWallet);
token.transfer(owner, 1000e18);
uint256 nonce = token.nonces(owner);
uint256 deadline = block.timestamp + 1 days;
uint256 amount = 500e18;
bytes32 structHash = keccak256(abi.encode(keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"), owner, user1, amount, nonce, deadline));
bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
(uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
token.permit(owner, user1, amount, deadline, v, r, s);
assertEq(token.allowance(owner, user1), amount);
}
function test_VestingNoReleaseBeforeStart() public {
vm.expectRevert(TokenVesting.NothingToRelease.selector);
vesting.release();
}
function test_VestingPartialRelease() public {
vm.warp(block.timestamp + (ONE_YEAR / 2));
vesting.release();
assertEq(token.balanceOf(teamWallet), 20_000_000e18);
assertEq(vesting.released(), 20_000_000e18);
}
function test_VestingFullRelease() public {
vm.warp(block.timestamp + ONE_YEAR);
vesting.release();
assertEq(token.balanceOf(teamWallet), 40_000_000e18);
}
function test_VestingMultipleReleases() public {
vm.warp(block.timestamp + (ONE_YEAR / 4));
vesting.release();
assertEq(token.balanceOf(teamWallet), 10_000_000e18);
vm.warp(block.timestamp + ONE_YEAR);
vesting.release();
assertEq(token.balanceOf(teamWallet), 40_000_000e18);
}
}