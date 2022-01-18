// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "OpenZeppelin/openzeppelin-contracts@4.4.2/contracts/token/ERC721/ERC721.sol";

contract ExampleNFT is ERC721 {
    constructor() ERC721("example NFT", "eNFT") {}

    uint256 private _tokenId;

    function mint() external returns (uint256) {
        _tokenId++;
        _mint(msg.sender, _tokenId);
        return _tokenId;
    }
}
