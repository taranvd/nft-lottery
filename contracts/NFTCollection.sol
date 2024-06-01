// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTCollection is ERC721Enumerable {
    uint256 private _currentTokenId;
    /**
     * @dev Constructor for the contract.
     * @param name The name of the NFT collection.
     * @param symbol The symbol of the NFT collection.
     */
    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {}

    /**
     * @dev Function to mint a new token and transfer it to a user.
     * @param to The address to which the new token will be minted.
     */
    function mint(address to) external {
        _safeMint(to, _currentTokenId++);
    }

    /**
     * @dev Function to burn a token.
     * @param tokenId The ID of the token to be burned.
     */
    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }

    /**
     * @dev Function to mint tokens for an array of addresses.
     * @param addresses The array of addresses to which tokens will be minted.
     * This function is only for testing purposes and for speeding up the process,
     * and it's used solely within the scope of an educational project.
     */
    function mintTokensForAddresses(address[] memory addresses) external {
        for (uint256 i = 0; i < addresses.length; i++) {
            this.mint(addresses[i]);
        }
    }
}
