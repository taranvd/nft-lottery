require("@nomiclabs/hardhat-waffle");
require("solidity-coverage");

module.exports = {
  solidity: "0.8.15",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
    },
  },
};
