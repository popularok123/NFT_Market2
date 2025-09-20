// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyNFT is ERC721, Ownable {
    uint256 public tokenCounter;

    constructor() ERC721("MyToken", "MTK") Ownable(msg.sender) {
        tokenCounter = 0;
    }

    function mintNFT() public returns (uint256) {
        tokenCounter = tokenCounter + 1;
        _safeMint(msg.sender, tokenCounter);
        return tokenCounter;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
