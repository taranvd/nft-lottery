// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTCollection is ERC721Enumerable {
    address[] accounts = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
        0x90F79bf6EB2c4f870365E785982E1f101E93b906,
        0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65,
        0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc,
        0x976EA74026E726554dB657fA54763abd0C3a0aa9,
        0x14dC79964da2C08b23698B3D3cc7Ca32193d9955,
        0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f,
        0xa0Ee7A142d267C1f36714E4a8F75612F20a79720,
        0xBcd4042DE499D14e55001CcbB24a551F3b954096,
        0x71bE63f3384f5fb98995898A86B02Fb2426c5788,
        0xFABB0ac9d68B0B445fB7357272Ff202C5651694a,
        0x1CBd3b2770909D4e10f157cABC84C7264073C9Ec,
        0xdF3e18d64BC6A983f673Ab319CCaE4f1a57C7097,
        0xcd3B766CCDd6AE721141F452C550Ca635964ce71,
        0x2546BcD3c84621e976D8185a91A922aE77ECEc30,
        0xbDA5747bFD65F08deb54cb465eB87D40e51B197E,
        0xdD2FD4581271e230360230F9337D5c0430Bf44C0,
        0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199
    ];

    uint256 private _currentTokenId;

    /**
     * @dev Constructor for the contract.
     * @param name The name of the NFT collection.
     * @param symbol The symbol of the NFT collection.
     */
    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
    {}

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

    function mintTokensForAddresses() external {
        for (uint256 i = 0; i < accounts.length; i++) {
            this.mint(accounts[i]);
        }
    }
}
