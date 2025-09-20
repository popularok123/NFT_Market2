import {ethers} from "hardhat"

console.log("Starting deployment of CCIP Simulator...");
async function main() {
  const [deployer] = await ethers.getSigners()
  console.log("Deploying contracts with the account:", deployer.address)

  const CCIPSimulator = await ethers.getContractFactory("CCIPLocalSimulator")
  const ccipSimulator = await CCIPSimulator.deploy()
  await ccipSimulator.waitForDeployment()

  console.log("CCIPSimulator deployed to:", ccipSimulator.getAddress())
}