// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
contract Box is Ownable {
    uint256 private _value;
    event ValueChanged(uint256 newValue);
    constructor(address _timelockAddress) Ownable(_timelockAddress) {}
    function store(uint256 newValue) external onlyOwner {
        _value = newValue;
        emit ValueChanged(newValue);
    }
    function retrieve() external view returns (uint256) {
        return _value;
    }
}