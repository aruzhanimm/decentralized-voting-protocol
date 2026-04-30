// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
contract TokenVesting {
using SafeERC20 for IERC20;
IERC20 public immutable token;
address public immutable beneficiary;
uint256 public immutable start;
uint256 public immutable duration;
uint256 public released;
error NothingToRelease();
event TokensReleased(uint256 amount);
constructor(address _token, address _beneficiary, uint256 _startTimestamp, uint256 _durationSeconds) {
token = IERC20(_token);
beneficiary = _beneficiary;
start = _startTimestamp;
duration = _durationSeconds;
}
function release() external {
uint256 unreleased = vestedAmount() - released;
if (unreleased == 0) revert NothingToRelease();
released += unreleased;
token.safeTransfer(beneficiary, unreleased);
emit TokensReleased(unreleased);
}
function vestedAmount() public view returns (uint256) {
uint256 totalAllocation = token.balanceOf(address(this)) + released;
if (block.timestamp < start) {
return 0;
} else if (block.timestamp >= start + duration) {
return totalAllocation;
} else {
return (totalAllocation * (block.timestamp - start)) / duration;
}
}
}