import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import '@nomicfoundation/hardhat-ethers';
import 'hardhat-deploy';
import 'hardhat-deploy-ethers';
import * as envEnc from "@chainlink/env-enc";
envEnc.config();


const PRIVATE_KEY = process.env.PRIVATE_KEY;
const SEPOLIA_URL = process.env.SEPOLIA_URL;
const AMOY_URL = process.env.AMOY_RPC_URL;

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    sepolia: {
      url: SEPOLIA_URL,
      chainId:11155111,
      accounts: [PRIVATE_KEY as string],
    },
    amoy: {
      url: AMOY_URL,
      chainId:80002,
      accounts: [PRIVATE_KEY as string],
    },
    localhost: {
      url: "http://127.0.0.1:8545",
    },
  },
};

export default config;
