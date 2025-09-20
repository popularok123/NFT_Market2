import hre from "hardhat"
import {developmentChains} from "../helper-hardhat-config"
import "./utils/deployAddress"  // Ensure utils is imported if needed
import { saveDeployAddress } from "../utils/deployAddress";

console.log("Starting deployment of CCIP Simulator...");
async function main() {
  const { ethers } = hre;
  if (!developmentChains.includes(hre.network.name)) {
    console.log("Not a development chain. Skipping...");
    return;
  }
  const [deployer] = await ethers.getSigners()
  console.log("Deploying contracts with the account:", deployer.address)

  const CCIPSimulator = await ethers.getContractFactory("CCIPSimulator")
  const ccipSimulator = await CCIPSimulator.deploy()
  await ccipSimulator.waitForDeployment()

  const address = await ccipSimulator.getAddress()

  console.log("CCIPSimulator deployed to:", address)

  saveDeployAddress(hre.network.name, "CCIPSimulator", address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});