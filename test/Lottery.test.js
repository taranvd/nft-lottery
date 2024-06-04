// const { ethers } = require("hardhat");
// const { expect } = require("chai");

// describe("Lottery", function () {
//   let lottery;
//   let nftCollection;
//   let usdtContract;
//   let participants;
//   let user1;

//   beforeEach(async function () {
//     const signers = await ethers.getSigners();
//     [owner, user1, user2, ...participants] = signers;
//     participants = signers.map((signer) => signer.address);

//     const ERC20USDT = await ethers.getContractFactory("ERC20USDT");
//     usdtContract = await ERC20USDT.deploy();
//     await usdtContract.deployed();

//     const NFTCollection = await ethers.getContractFactory("NFTCollection");
//     nftCollection = await NFTCollection.deploy("MyNFTCollection", "NFT");
//     await nftCollection.deployed();
//     await nftCollection.mintTokensForAddresses(participants);

//     const rewards = [10000, 5000, 2000, 1000, 50];

//     const Lottery = await ethers.getContractFactory("Lottery");
//     lottery = await Lottery.deploy(usdtContract.address, rewards);
//     await lottery.deployed();
//     await lottery.addCollection(nftCollection.address);
//   });

//   it("should add NFT collection to the lottery", async function () {
//     const NFTCollection = await ethers.getContractFactory("NFTCollection");
//     const nftCollection = await NFTCollection.deploy("test", "TST");
//     await nftCollection.deployed();
//     await nftCollection.mintTokensForAddresses(participants);

//     await lottery.addCollection(nftCollection.address);
//     const collections = await lottery.getCollections();
//     expect(collections.length).to.be.above(1);
//   });

//   it("should remove NFT collection from the lottery", async function () {
//     const NFTCollection = await ethers.getContractFactory("NFTCollection");
//     const nftCollection = await NFTCollection.deploy("test", "TST");
//     await nftCollection.deployed();
//     await nftCollection.mintTokensForAddresses(participants);

//     await lottery.addCollection(nftCollection.address);

//     let collections = await lottery.getCollections();
//     const initialCollectionsLength = collections.length;
//     await lottery.removeCollection(nftCollection.address);
//     collections = await lottery.getCollections();
//     const currentCollectionsLength = collections.length;

//     expect(currentCollectionsLength).to.equal(initialCollectionsLength - 1);
//   });

//   it("should start a new lottery draw", async function () {
//     let lotteryState = await lottery.lotteryState();
//     expect(lotteryState).to.equal(0);

//     await lottery.startLottery();

//     lotteryState = await lottery.lotteryState();
//     expect(lotteryState).to.equal(1);
//   });

//   it("should determine winners at different reward levels", async function () {
//     let lotteryState = await lottery.lotteryState();
//     expect(lotteryState).to.equal(0);

//     await lottery.startLottery();
//     await lottery.endLottery();

//     lotteryState = await lottery.lotteryState();
//     expect(lotteryState).to.equal(0);
//   });

//   it("should distribute rewards to winners", async function () {
//     // Start the lottery
//     await lottery.startLottery();

//     // End the lottery to determine winners
//     await lottery.endLottery();

//     // Get the winners for each level
//     const jackpotWinners = await lottery.winnersByLevel(0, 0);
//     const level1Winners = await lottery.winnersByLevel(1, 0);
//     const level2Winners = await lottery.winnersByLevel(2, 0);
//     const level3Winners = await lottery.winnersByLevel(3, 0);

//     // Get the initial balance of the jackpot winner before paying rewards
//     const initialJackpotBalance = await usdtContract.balanceOf(jackpotWinners);

//     // Get the initial balance of the level 1 winner before paying rewards
//     const initialLevel1Balance = await usdtContract.balanceOf(level1Winners);

//     // Get the initial balance of the level 2 winner before paying rewards
//     const initialLevel2Balance = await usdtContract.balanceOf(level2Winners);

//     // Get the initial balance of the level 3 winner before paying rewards
//     const initialLevel3Balance = await usdtContract.balanceOf(level3Winners);

//     // Pay rewards
//     await lottery.payRewards();

//     // Get the final balance of the jackpot winner after paying rewards
//     const finalJackpotBalance = await usdtContract.balanceOf(jackpotWinners);

//     // Get the final balance of the level 1 winner after paying rewards
//     const finalLevel1Balance = await usdtContract.balanceOf(level1Winners);

//     // Get the final balance of the level 2 winner after paying rewards
//     const finalLevel2Balance = await usdtContract.balanceOf(level2Winners);

//     // Get the final balance of the level 3 winner after paying rewards
//     const finalLevel3Balance = await usdtContract.balanceOf(level3Winners);

//     expect(finalJackpotBalance).to.above(initialJackpotBalance);
//     expect(finalLevel1Balance).to.above(initialLevel1Balance);
//     expect(finalLevel2Balance).to.above(initialLevel2Balance);
//     expect(finalLevel3Balance).to.above(initialLevel3Balance);
//   });

//   it("should burn NFT and mint burn reward to caller", async function () {
//     const tokenId = await nftCollection.tokenOfOwnerByIndex(user1.address, 0);
//     const initialBalance = await usdtContract.balanceOf(user1.address);

//     await lottery.connect(user1).burnNFT(nftCollection.address, tokenId);

//     const currentBalance = await usdtContract.balanceOf(user1.address);

//     expect(currentBalance).to.above(initialBalance);
//   });
// });
