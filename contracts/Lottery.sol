// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./NFTCollection.sol";

contract Lottery is ReentrancyGuard, Ownable {
    uint8 constant MIN_PARTICIPANTS = 4;
    uint256 constant LEVEL1_WINNERS_PERCENTAGE = 10;
    uint256 constant LEVEL2_WINNERS_PERCENTAGE = 100;
    uint256 constant LEVEL3_WINNERS_PERCENTAGE = 1000;

    // Map to store winners for each level
    mapping(uint256 => address[]) public winnersByLevel;

    // Address of the reward token
    IERC20 public tokenReward;

    // Reward amounts
    uint32[5] public rewards;

    // Flag to track whether rewards have been paid or not
    bool private rewardsPaid = false;

    // Map to track winners
    mapping(address => bool) internal winnersTracker;

    // Map to track burned tokens
    mapping(address => mapping(uint256 => bool)) private burntTokens;

    // Array to store NFT collections
    NFTCollection[] private collections;

    // Enumeration for lottery state
    enum LotteryState {
        Inactive,
        Active,
        Finished
    }

    struct Level {
        uint256 winnersCount;
        uint256 reward;
    }

    Level[] public levels;

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
    error CollectionAlreadyAdded();
    error CollectionNotFound();
    error LotteryAlreadyActive();
    error LotteryNotActive();
    error LotteryNotFinished();
    error NoCollectionsAdded();
    error TokenNotOwned();
    error TokenNotApproved();
    error NoParticipants();
    error RewardsAlreadyPaid();
    error IndexOutOfBounds();

    /**
     * @notice Modifier to ensure that rewards have not been paid yet
     * @dev This modifier ensures that the payRewards function can only be called once,
     * preventing the owner from distributing rewards multiple times.
     */
    modifier rewardsNotPaid() {
        require(!rewardsPaid, "Rewards already paid");
        _;
    }

    /**
     * @notice Constructor function
     * @dev Initializes the contract with the address of the reward token and reward amounts for each level.
     * @param _tokenReward Address of the reward token
     * @param _rewards Array of reward amounts for each level [jackpot, level1, level2, level3, burnReward]
     */
    constructor(address _tokenReward, uint32[5] memory _rewards) {
        lotteryState = LotteryState.Inactive;
        tokenReward = IERC20(_tokenReward);
        rewards = _rewards;
        levels.push(Level(1, rewards[0])); // jackpot
        levels.push(Level(0, rewards[1])); // Level 1
        levels.push(Level(0, rewards[2])); // Level 2
        levels.push(Level(0, rewards[3])); // Level 3
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
                revert CollectionAlreadyAdded();
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
        revert CollectionNotFound();
    }

    /**
     * @notice Starts the lottery
     * @dev This function starts the lottery if it is not already active and checks if any collections are added.
     */
    function startLottery() external onlyOwner {
        // Check if the lottery is already active
        if (lotteryState == LotteryState.Active) revert LotteryAlreadyActive();
        // Check if any collections are added
        if (collections.length == 0) revert NoCollectionsAdded();

        emit LotteryStarted(block.timestamp);
        lotteryState = LotteryState.Active;
    }

    function endLottery() external nonReentrant onlyOwner {
        // Check if the lottery is active
        if (lotteryState == LotteryState.Inactive) {
            revert LotteryNotActive();
        }

        // Get the total number of participants
        uint256 participantsCount = _getParticipantsCount();

        if (participantsCount <= MIN_PARTICIPANTS) revert NoParticipants();

        // Update the number of winners for each level
        _updateWinnersCount(participantsCount);

        address[][] memory winners = new address[][](levels.length);

        // Determine winners for each level
        for (uint256 i = 0; i < levels.length; i++) {
            winners[i] = _determineWinners(
                levels[i].winnersCount,
                participantsCount
            );
        }

        // Emit event with winners
        emit WinnersAnnounced(
            winners[0], // jackpotWinners
            winners[1], // level1Winners
            winners[2], // level2Winners
            winners[3] // level3Winners
        );

        // Store winners for each level
        for (uint256 i = 0; i < levels.length; i++) {
            winnersByLevel[i] = winners[i];
        }

        // Update lottery state
        lotteryState = LotteryState.Finished;
        emit LotteryEnded(block.timestamp);
    }

    function _updateWinnersCount(uint256 participantsCount) internal {
        for (uint256 i = 1; i < levels.length; i++) {
            if (i == 1) {
                levels[i].winnersCount =
                    (participantsCount * LEVEL1_WINNERS_PERCENTAGE) /
                    10000;
            }
            if (i == 2) {
                levels[i].winnersCount =
                    (participantsCount * LEVEL2_WINNERS_PERCENTAGE) /
                    10000;
            }
            if (i == 3) {
                levels[i].winnersCount =
                    (participantsCount * LEVEL3_WINNERS_PERCENTAGE) /
                    10000;
            }
        }
    }

    /**
     * @notice Pays rewards to the winners
     * @dev This function distributes rewards to the winners based on their respective reward levels.
     * It can only be called once to prevent multiple reward distributions.
     */
    function payRewards() external onlyOwner rewardsNotPaid {
        // Check if the lottery is ended
        if (lotteryState != LotteryState.Finished) {
            revert LotteryNotFinished();
        }

        // Distribute rewards for each level
        for (uint256 i = 0; i < levels.length; i++) {
            address[] memory winners = winnersByLevel[i];
            uint32 rewardAmount = uint32(levels[i].reward);

            // Distribute rewards to winners
            for (uint256 j = 0; j < winners.length; j++) {
                _sendReward(winners[j], rewardAmount);
            }
        }

        rewardsPaid = true;
    }

    /**
     * @notice Determines winners for a specific level
     * @dev This function randomly selects winners for a specific level based on the number of winners needed.
     * @param winnersCount Number of winners needed for the level
     * @param participantsCount Total number of participants
     * @return An array of winner addresses
     */
    function _determineWinners(uint256 winnersCount, uint256 participantsCount)
        internal
        returns (address[] memory)
    {
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
            unchecked {
                uint256 randomNumber = uint256(
                    keccak256(
                        abi.encodePacked(
                            blockhash(block.number),
                            offset + count
                        )
                    )
                );
                uint256 index = randomNumber % participantsCount;
                address participant = _getParticipantAtIndex(index);
                // Check if the participant has not already won
                if (
                    !winnersTracker[participant] && !_isTokenBurnt(participant)
                ) {
                    winners[count] = participant;
                    winnersTracker[participant] = true; // Mark participant as winner
                    count++;
                }
                offset++;
            }
        }
        return winners;
    }

    /**
     * @notice Gets the total number of participants in the lottery
     * @dev This function calculates the total number of participants by summing the total supply of tokens from all added collections.
     * @return Total number of participants
     */
    function _getParticipantsCount() internal view returns (uint256) {
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
    function _getParticipantAtIndex(uint256 index)
        internal
        view
        returns (address)
    {
        for (uint256 i = 0; i < collections.length; i++) {
            uint256 collectionTokens = collections[i].totalSupply();
            if (index < collectionTokens) {
                return
                    collections[i].ownerOf(collections[i].tokenByIndex(index));
            }
            index -= collectionTokens;
        }
        revert IndexOutOfBounds();
    }

    /**
     * @notice Sends reward to a recipient
     * @dev This function mints and sends the specified amount of ERC20 tokens to the recipient.
     * @param recipient Address of the recipient
     * @param amount Amount of reward to send
     */
    function _sendReward(address recipient, uint32 amount) internal {
        tokenReward.transfer(recipient, amount);

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
            revert TokenNotOwned();

        // Check if the caller has approval to burn the token
        if (
            NFTCollection(collectionAddress).getApproved(tokenId) !=
            address(this)
        ) revert TokenNotApproved();

        // Burn the NFT
        NFTCollection(collectionAddress).burn(tokenId);

        burntTokens[collectionAddress][tokenId] = true;

        // transfer burn reward to the caller
        tokenReward.transfer(msg.sender, rewards[4]);
        emit RewardPaid(msg.sender, rewards[4]);
    }

    /**
     * @notice Checks if the participant's token has been burned
     * @dev This function checks if the token has been burned for the specified participant in any of the added collections.
     * @param participant The address of the participant
     * @return bool A boolean value: true if the token has been burned, false if not.
     */

    function _isTokenBurnt(address participant) internal view returns (bool) {
        for (uint256 i = 0; i < collections.length; i++) {
            for (uint256 j = 0; j < collections[i].totalSupply(); j++) {
                uint256 tokenId = collections[i].tokenByIndex(j);
                if (collections[i].ownerOf(tokenId) != participant) {
                    continue;
                }
                if (burntTokens[address(collections[i])][tokenId]) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * @notice Gets the array of added NFT collections
     * @dev This function returns the array containing all added NFT collections.
     * @return Array of NFTCollection contracts
     */
    function _getCollections() public view returns (NFTCollection[] memory) {
        return collections;
    }
}
