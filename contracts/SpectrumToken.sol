// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "OpenZeppelin/openzeppelin-contracts@4.4.2/contracts/token/ERC20/ERC20.sol";

contract SpectrumToken is ERC20 {
    constructor() ERC20("SpectrumToken", "ST") {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}
