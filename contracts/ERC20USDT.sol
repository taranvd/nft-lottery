// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ERC20USDT is ERC20, AccessControl {
    constructor() ERC20("Tether", "USDt") {
        // Set the initial supply to 100,000,000 tokens
        uint256 initialSupply = 100_000_000;
        // Mint the initial supply to the contract deployer
        _mint(address(this), initialSupply);
        // Assign the DEFAULT_ADMIN_ROLE to the contract deployer
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Mints new tokens and assigns them to the specified account.
     * @dev This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
     * @param to The account to which new tokens will be minted.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount * 10 ** decimals());
    }

    /**
     * @notice Burns a specific amount of tokens from the specified account.
     * @dev This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
     * @param from The account from which tokens will be burned.
     * @param amount The amount of tokens to burn.
     */
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}
