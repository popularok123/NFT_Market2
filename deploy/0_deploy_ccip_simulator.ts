import {ethers} from "hardhat"

console.log("Starting deployment of CCIP Simulator...");
async function main() {
  const [deployer] = await ethers.getSigners()
  console.log("Deploying contracts with the account:", deployer.address)

  const CCIPSimulator = await ethers.getContractFactory("CCIPSimulator")
  const ccipSimulator = await CCIPSimulator.deploy()
  await ccipSimulator.waitForDeployment()

  const address = await ccipSimulator.getAddress()

  console.log("CCIPSimulator deployed to:", address)
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});