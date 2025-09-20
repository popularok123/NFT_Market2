import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    sepolia: {
      url: "https://sepolia.infura.io/v3/YOUR_INFURA_PROJECT_ID",
      accounts: ["f3959529443d3398377dcdd86a00bc8645d71d5cb3dfa5139f42be49a998cc54"],
    },
    localhost: {
      url: "http://127.0.0.1:8545",
    },
  },
};

export default config;
