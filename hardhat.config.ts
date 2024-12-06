import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";
import '@openzeppelin/hardhat-upgrades';
import "@nomicfoundation/hardhat-toolbox";
require("dotenv").config();

const { ALCHEMY_API_URL, METAMASK_PRIVATE_KEY, ETHERSCAN_API_KEY } = process.env;

const config: HardhatUserConfig = {
  defaultNetwork: "sepolia",
  networks: {
    sepolia: {
      url: `${ALCHEMY_API_URL}`,
      accounts: [`${METAMASK_PRIVATE_KEY}`],
    },
  },
  solidity: {
    version: "0.8.22",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
    },
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY
  }
};

export default config;
