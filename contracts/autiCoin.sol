// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "OpenZeppelin/openzeppelin-contracts@4.4.2/contracts/token/ERC20/ERC20.sol";

contract AutiCoin is ERC20 {
    constructor() ERC20("AutiCoin", "AC") {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}
