require("@nomicfoundation/hardhat-toolbox");

const networks = {};
if (process.env.ARBITRUM_SEPOLIA_RPC_URL && process.env.DEPLOYER_PRIVATE_KEY) {
  networks.arbitrumSepolia = {
    url: process.env.ARBITRUM_SEPOLIA_RPC_URL,
    accounts: [process.env.DEPLOYER_PRIVATE_KEY]
  };
}

module.exports = {
  solidity: { version: "0.8.24", settings: { optimizer: { enabled: true, runs: 200 } } },
  paths: { sources: "./contracts", tests: "./test" },
  networks
};
