// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./NFTCollection.sol";
import "./ERC20USDT.sol";

contract Lottery is ReentrancyGuard, Ownable {
    using SafeMath for uint256;

    uint8 constant MIN_PARTICIPANTS = 4;
    uint constant LEVEL1_WINNERS_PERCENTAGE = 10;
    uint constant LEVEL2_WINNERS_PERCENTAGE = 100;
    uint constant LEVEL3_WINNERS_PERCENTAGE = 1000;

    // Map to store winners for each level
    mapping(uint256 => address[]) public winnersByLevel;

    // Address of the reward token
    ERC20USDT public tokenReward;

    // Reward amounts
    uint32[5] public rewards;

    // Map to track winners
    mapping(address => bool) internal winnersTracker;

    // Array to store NFT collections
    NFTCollection[] private collections;

    // Enumeration for lottery state
    enum LotteryState {
        Inactive,
        Active
    }

    // State variable to track lottery state
    LotteryState public lotteryState;

    // Events
    event WinnersAnnounced(
        address[] jackpotWinners,
        address[] level1Winners,
        address[] level2Winners,
        address[] level3Winners
    );
    event RewardPaid(address recipient, uint32 amount);
    event CollectionAdded(address collection);
    event LotteryStarted(uint256 timestamp);
    event LotteryEnded(uint256 timestamp);
    event CollectionRemoved(address collectionAddress);

    // Errors
    error CollectionAlreadyAdded(string message);
    error CollectionNotFound(string message);
    error LotteryAlreadyActive(string message);
    error LotteryNotActive(string message);
    error NoCollectionsAdded(string message);
    error TokenNotOwned(string message);
    error NoParticipants(string message);

    /**
     * @notice Constructor function
     * @dev Initializes the contract with the address of the reward token and reward amounts for each level.
     * @param _tokenReward Address of the reward token
     * @param _rewards Array of reward amounts for each level [jackpot, level1, level2, level3, burnReward]
     */
    constructor(address _tokenReward, uint32[5] memory _rewards) {
        lotteryState = LotteryState.Inactive;
        tokenReward = ERC20USDT(_tokenReward);
        rewards = _rewards;
    }

    /**
     * @notice Adds an NFT collection to the lottery
     * @dev This function allows the owner to add an NFT collection contract to the lottery for participation.
     * @param collectionAddress Address of the NFT collection contract
     */
    function addCollection(address collectionAddress) external onlyOwner {
        // Check if the collection is already added
        for (uint256 i = 0; i < collections.length; i++) {
            if (address(collections[i]) == collectionAddress)
                revert CollectionAlreadyAdded("Collection already added");
        }
        collections.push(NFTCollection(collectionAddress));
        emit CollectionAdded(collectionAddress);
    }

    /**
     * @notice Removes an NFT collection from the lottery
     * @dev This function allows the owner to remove an NFT collection contract from the lottery. It searches for the specified collection address in the collections array, and if found, removes it by shifting the elements and popping the last element. It emits a CollectionRemoved event upon successful removal.
     * @param collectionAddress Address of the NFT collection contract to remove
     */
    function removeCollection(address collectionAddress) external onlyOwner {
        // Check for the presence of the collection and remove it if found
        for (uint256 i = 0; i < collections.length; i++) {
            if (address(collections[i]) == collectionAddress) {
                // Remove the collection from the array
                for (uint256 j = i; j < collections.length - 1; j++) {
                    collections[j] = collections[j + 1];
                }
                collections.pop(); // Remove the last element (duplicate)
                emit CollectionRemoved(collectionAddress);
                return; // Exit the function after removal
            }
        }
        revert CollectionNotFound("Collection not found");
    }

    /**
     * @notice Starts the lottery
     * @dev This function starts the lottery if it is not already active and checks if any collections are added.
     */
    function startLottery() external onlyOwner {
        // Check if the lottery is already active
        if (lotteryState == LotteryState.Active)
            revert LotteryAlreadyActive("Lottery already active");
        // Check if any collections are added
        if (collections.length == 0)
            revert NoCollectionsAdded("No collections added for the lottery");

        emit LotteryStarted(block.timestamp);
        lotteryState = LotteryState.Active;
    }

    /**
     * @notice Ends the lottery and determines winners for each level
     * @dev This function ends the lottery, determines the winners for each level, and emits an event with the winners.
     */
    function endLottery() external nonReentrant onlyOwner {
        // Check if the lottery is active
        require(lotteryState == LotteryState.Active, "Lottery not active");

        // Get the total number of participants
        uint256 participantsCount = getParticipantsCount();

        if (participantsCount <= MIN_PARTICIPANTS)
            revert NoParticipants("Not enough participants!");

        // Determine the number of winners for each level
        uint256 jackpotWinnersCount = 1;
        uint256 level1WinnersCount = participantsCount
            .mul(LEVEL1_WINNERS_PERCENTAGE)
            .div(10000); // 0.1% of participants

        uint256 level2WinnersCount = participantsCount
            .mul(LEVEL2_WINNERS_PERCENTAGE)
            .div(10000); // 1% of participants

        uint256 level3WinnersCount = participantsCount
            .mul(LEVEL3_WINNERS_PERCENTAGE)
            .div(10000); // 10% of participants

        // Determine winners for each level
        address[] memory jackpotWinners = determineWinners(
            jackpotWinnersCount,
            participantsCount
        );
        address[] memory level1Winners = determineWinners(
            level1WinnersCount,
            participantsCount
        );
        address[] memory level2Winners = determineWinners(
            level2WinnersCount,
            participantsCount
        );
        address[] memory level3Winners = determineWinners(
            level3WinnersCount,
            participantsCount
        );

        // Emit event with winners
        emit WinnersAnnounced(
            jackpotWinners,
            level1Winners,
            level2Winners,
            level3Winners
        );

        // Store winners for each level
        winnersByLevel[0] = jackpotWinners;
        winnersByLevel[1] = level1Winners;
        winnersByLevel[2] = level2Winners;
        winnersByLevel[3] = level3Winners;

        // Update lottery state
        lotteryState = LotteryState.Inactive;
        emit LotteryEnded(block.timestamp);
    }

    /**
     * @notice Determines winners for a specific level
     * @dev This function randomly selects winners for a specific level based on the number of winners needed.
     * @param winnersCount Number of winners needed for the level
     * @param participantsCount Total number of participants
     * @return An array of winner addresses
     */
    function determineWinners(
        uint256 winnersCount,
        uint256 participantsCount
    ) internal returns (address[] memory) {
        // If winnersCount is less than 1, set it to 1
        if (winnersCount < 1) {
            winnersCount = 1;
        }

        address[] memory winners = new address[](winnersCount);
        uint256 count = 0;
        uint256 offset = uint256(
            keccak256(abi.encodePacked(blockhash(block.number)))
        );
        while (count < winnersCount) {
            uint256 randomNumber = uint256(
                keccak256(
                    abi.encodePacked(blockhash(block.number), offset + count)
                )
            );
            uint256 index = randomNumber % participantsCount;
            address participant = getParticipantAtIndex(index);
            // Check if the participant has not already won
            if (!winnersTracker[participant]) {
                winners[count] = participant;
                winnersTracker[participant] = true; // Mark participant as winner
                count++;
            }
            offset++;
        }
        return winners;
    }

    /**
     * @notice Gets the total number of participants in the lottery
     * @dev This function calculates the total number of participants by summing the total supply of tokens from all added collections.
     * @return Total number of participants
     */
    function getParticipantsCount() internal view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < collections.length; i++) {
            count += collections[i].totalSupply();
        }
        return count;
    }

    /**
     * @notice Gets the participant address at the specified index
     * @dev This function retrieves the participant address at the specified index by iterating through all added collections.
     * @param index Index of the participant
     * @return Participant address
     */
    function getParticipantAtIndex(
        uint256 index
    ) internal view returns (address) {
        for (uint256 i = 0; i < collections.length; i++) {
            uint256 collectionTokens = collections[i].totalSupply();
            if (index < collectionTokens) {
                return
                    collections[i].ownerOf(collections[i].tokenByIndex(index));
            }
            index -= collectionTokens;
        }
        revert("Index out of bounds");
    }

    /**
     * @notice Checks if a participant is already a winner
     * @dev This function checks if a participant is already a winner based on winnersTracker mapping.
     * @param participant Address of the participant
     * @return Boolean indicating whether the participant is already a winner
     */
    function isAlreadyWinner(address participant) internal view returns (bool) {
        return winnersTracker[participant];
    }

    /**
     * @notice Pays rewards to the winners
     * @dev This function distributes rewards to the winners based on their respective reward levels.
     */
    function payRewards() external onlyOwner {
        // Check if the lottery is ended
        require(lotteryState == LotteryState.Inactive, "Lottery must be ended");

        address[] memory jackpotWinners = winnersByLevel[0];
        address[] memory level1Winners = winnersByLevel[1];
        address[] memory level2Winners = winnersByLevel[2];
        address[] memory level3Winners = winnersByLevel[3];

        // Distribute rewards to winners
        sendReward(jackpotWinners[0], rewards[0]);
        for (uint256 i = 0; i < level1Winners.length; i++)
            sendReward(level1Winners[i], rewards[1]);
        for (uint256 i = 0; i < level2Winners.length; i++)
            sendReward(level2Winners[i], rewards[2]);
        for (uint256 i = 0; i < level3Winners.length; i++)
            sendReward(level3Winners[i], rewards[3]);
    }

    /**
     * @notice Sends reward to a recipient
     * @dev This function mints and sends the specified amount of ERC20 tokens to the recipient.
     * @param recipient Address of the recipient
     * @param amount Amount of reward to send
     */
    function sendReward(address recipient, uint32 amount) internal {
        tokenReward.mint(recipient, amount);
        emit RewardPaid(recipient, amount);
    }

    /**
     * @notice Burns an NFT and rewards the caller
     * @dev This function allows the caller to burn their NFT, receive a burn reward, and earn a lottery reward.
     * @param collectionAddress Address of the NFT collection contract
     * @param tokenId ID of the NFT to burn
     */
    function burnNFT(address collectionAddress, uint256 tokenId) external {
        // Check if the caller owns the token
        if (NFTCollection(collectionAddress).ownerOf(tokenId) != msg.sender)
            revert TokenNotOwned("Sender is not the owner of the token");

        // Burn the NFT
        NFTCollection(collectionAddress).burn(tokenId);

        // Mint burn reward to the caller
        tokenReward.mint(msg.sender, rewards[4]);
        emit RewardPaid(msg.sender, rewards[4]);
    }

    /**
     * @notice Gets the array of added NFT collections
     * @dev This function returns the array containing all added NFT collections.
     * @return Array of NFTCollection contracts
     */
    function getCollections() public view returns (NFTCollection[] memory) {
        return collections;
    }
}
