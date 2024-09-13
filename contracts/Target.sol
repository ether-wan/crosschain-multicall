// SPDX-License-Identifier: MIT



pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract Target is Ownable {

    uint256 public value;

    event ValueChanged(uint256 newValue, address sender);

    constructor() Ownable(msg.sender){}
    

    function setValue(uint256 _value) public returns(uint256){
        value = _value;
        emit ValueChanged(_value, msg.sender);

        return value;
    }

}