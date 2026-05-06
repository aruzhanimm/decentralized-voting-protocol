// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ProtocolConfig is Ownable {
    uint256 public feePercentage;

    event FeeUpdated(uint256 oldFee, uint256 newFee);

    constructor() Ownable(msg.sender) {
        feePercentage = 100;
    }

    function updateFee(uint256 _newFee) external onlyOwner {
        uint256 oldFee = feePercentage;
        feePercentage = _newFee;

        emit FeeUpdated(oldFee, _newFee);
    }
}