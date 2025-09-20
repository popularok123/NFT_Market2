import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import '@nomicfoundation/hardhat-ethers';
import '@openzeppelin/hardhat-upgrades';
// import 'hardhat-deploy';
// import 'hardhat-deploy-ethers';

import * as envEnc from "@chainlink/env-enc";
envEnc.config();

const PRIVATE_KEY = process.env.PRIVATE_KEY as string
const SEPOLIA_URL = process.env.SEPOLIA_RPC_URL as string
const AMOY_URL = process.env.AMOY_RPC_URL as string

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: "0.8.28",
  networks: {
    sepolia: {
      url: SEPOLIA_URL,
      chainId:11155111,
      accounts: [PRIVATE_KEY],
    },
    amoy: {
      url: AMOY_URL,
      chainId:80002,
      accounts: [PRIVATE_KEY],
    },
    hardhat: {
      chainId: 31337,
    },
    localhost: {
      url: "http://127.0.0.1:8545",
    },
  },
};

export default config;
