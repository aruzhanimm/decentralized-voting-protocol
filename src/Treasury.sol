// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
contract Treasury is Ownable {
    using SafeERC20 for IERC20;
    event Received(address indexed sender, uint256 amount);
    event EthReleased(address indexed to, uint256 amount);
    event Erc20Released(address indexed token, address indexed to, uint256 amount);
    constructor(address _owner) Ownable(_owner) {}
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
    function releaseEth(address payable _to, uint256 _amount) external onlyOwner {
        require(address(this).balance >= _amount, "Treasury: insufficient ETH balance");
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Treasury: ETH transfer failed");
        emit EthReleased(_to, _amount);
    }
    function releaseErc20(address _token, address _to, uint256 _amount) external onlyOwner {
        IERC20 token = IERC20(_token);
        require(token.balanceOf(address(this)) >= _amount, "Treasury: insufficient token balance");
        token.safeTransfer(_to, _amount);
        emit Erc20Released(_token, _to, _amount);
    }
}