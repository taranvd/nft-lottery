const { ethers, upgrades } = require("hardhat");
const CONFIG = require("../config");

async function main() {
  const rewards = [100, 75, 50, 25, 10];
  const gas = await ethers.provider.getGasPrice();

  const LotteryContract = await ethers.getContractFactory("Lottery");
  console.log("Deploying LotteryContract...");
  const lottery = await upgrades.deployProxy(
    LotteryContract,
    [process.env[CONFIG.TOKEN_REWARDS_ADDRESS], rewards],
    {
      gasPrice: gas,
      initializer: "initialize",
    }
  );
  await lottery.deployed();
  console.log("lottery deployed to:", lottery.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
