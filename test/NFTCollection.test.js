const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("NFTCollection", function () {
  let NFTCollection;
  let nftCollection;
  let owner;
  let addr1;
  let addr2;
  let addrs;

  beforeEach(async function () {
    NFTCollection = await ethers.getContractFactory("NFTCollection");
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    nftCollection = await NFTCollection.deploy("MyNFT", "NFT");
    await nftCollection.deployed();
  });

  it("Should mint a new token", async function () {
    await nftCollection.mint(addr1.address);
    const balance = await nftCollection.balanceOf(addr1.address);
    expect(balance).to.equal(1);
  });

  it("Should burn a token", async function () {
    await nftCollection.mint(addr1.address);
    await nftCollection.burn(0);
    const balance = await nftCollection.balanceOf(addr1.address);
    expect(balance).to.equal(0);
  });
});
