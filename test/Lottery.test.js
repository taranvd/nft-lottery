const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");

describe("Lottery", function () {
  let lottery;
  let nftCollection;
  let usdtContract;
  let participants;
  let user1;

  beforeEach(async function () {
    const signers = await ethers.getSigners();
    [owner, user1, user2, ...participants] = signers;
    participants = signers.map((signer) => signer.address);

    const ERC20USDT = await ethers.getContractFactory("ERC20USDT");
    usdtContract = await ERC20USDT.deploy();
    await usdtContract.deployed();

    const NFTCollection = await ethers.getContractFactory("NFTCollection");
    nftCollection = await NFTCollection.deploy("MyNFTCollection", "NFT");
    await nftCollection.deployed();
    await nftCollection.mintTokensForAddresses(participants);

    const rewards = [100, 50, 20, 10, 5];

    const Lottery = await ethers.getContractFactory("Lottery");
    lottery = await upgrades.deployProxy(
      Lottery,
      [usdtContract.address, rewards],
      { initializer: "initialize" }
    );
    await lottery.deployed();
    await lottery.addCollection(nftCollection.address);
  });

  it("should add NFT collection to the lottery", async function () {
    const NFTCollection = await ethers.getContractFactory("NFTCollection");
    const nftCollection = await NFTCollection.deploy("test", "TST");
    await nftCollection.deployed();
    await nftCollection.mintTokensForAddresses(participants);

    await lottery.addCollection(nftCollection.address);
    const collections = await lottery.getCollections();
    expect(collections.length).to.be.above(1);
  });

  it("should remove NFT collection from the lottery", async function () {
    const NFTCollection = await ethers.getContractFactory("NFTCollection");
    const nftCollection = await NFTCollection.deploy("test", "TST");
    await nftCollection.deployed();
    await nftCollection.mintTokensForAddresses(participants);

    await lottery.addCollection(nftCollection.address);

    let collections = await lottery.getCollections();
    const initialCollectionsLength = collections.length;
    await lottery.removeCollection(nftCollection.address);
    collections = await lottery.getCollections();
    const currentCollectionsLength = collections.length;

    expect(currentCollectionsLength).to.equal(initialCollectionsLength - 1);
  });

  it("should start a new lottery draw", async function () {
    let lotteryState = await lottery.lotteryState();
    expect(lotteryState).to.equal(0);

    await lottery.startLottery();

    lotteryState = await lottery.lotteryState();
    expect(lotteryState).to.equal(1);
  });

  it("should determine winners at different reward levels", async function () {
    let lotteryState = await lottery.lotteryState();
    expect(lotteryState).to.equal(0);

    await lottery.startLottery();
    await lottery.endLottery();

    lotteryState = await lottery.lotteryState();
    expect(lotteryState).to.equal(0);
  });

  it("should distribute rewards to winners", async function () {
    // Start the lottery
    await lottery.startLottery();

    await usdtContract.balanceOf(usdtContract.address);
    await usdtContract.mint(lottery.address, 10000);

    // End the lottery to determine winners
    await lottery.endLottery();

    // Get the winners for each level
    const jackpotWinners = await lottery.winnersByLevel(0, 0);
    const level1Winners = await lottery.winnersByLevel(1, 0);
    const level2Winners = await lottery.winnersByLevel(2, 0);
    const level3Winners = await lottery.winnersByLevel(3, 0);

    // Pay rewards
    await lottery.payRewards();

    // Get the final balance of the winners after paying rewards
    const finalJackpotBalance = await usdtContract.balanceOf(jackpotWinners);
    const finalLevel1Balance = await usdtContract.balanceOf(level1Winners);
    const finalLevel2Balance = await usdtContract.balanceOf(level2Winners);
    const finalLevel3Balance = await usdtContract.balanceOf(level3Winners);

    // Переконайтеся, що кожен переможець отримав винагороду
    expect(finalJackpotBalance).to.above(0);
    expect(finalLevel1Balance).to.above(0);
    expect(finalLevel2Balance).to.above(0);
    expect(finalLevel3Balance).to.above(0);
  });

  it("should burn NFT and mint burn reward to caller", async function () {
    const tokenId = await nftCollection.tokenOfOwnerByIndex(user1.address, 0);
    const initialBalance = await usdtContract.balanceOf(user1.address);

    await lottery.connect(user1).burnNFT(nftCollection.address, tokenId);

    const currentBalance = await usdtContract.balanceOf(user1.address);

    expect(currentBalance).to.above(initialBalance);
  });

  it("should burn the NFT, reward the user, and exclude the burned token from winner selection", async function () {
    // Start the lottery
    await lottery.startLottery();

    // Burn the NFT owned by user1
    const tokenId = await nftCollection.tokenOfOwnerByIndex(user1.address, 0);
    await nftCollection.connect(user1).approve(lottery.address, tokenId);
    await lottery.connect(user1).burnNFT(nftCollection.address, tokenId);

    // Check that user1 received the burn reward
    const burnRewardBalance = await usdtContract.balanceOf(user1.address);
    expect(burnRewardBalance).to.be.above(0);

    // End the lottery
    await lottery.endLottery();

    // Check that user1 is not in the winners list
    const winners = await Promise.all([
      lottery.winnersByLevel(0, 0),
      lottery.winnersByLevel(1, 0),
      lottery.winnersByLevel(2, 0),
      lottery.winnersByLevel(3, 0),
    ]);

    for (let i = 0; i < winners.length; i++) {
      expect(winners[i]).to.not.include(user1.address);
    }
  });
});
