import {ethers}  from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  //1.Deploy MyNFT contract
  const MyNFT = await ethers.getContractFactory("MyNFT");
  const myNFT = await MyNFT.deploy();
  await myNFT.waitForDeployment();
  console.log("MyNFT deployed to:", await myNFT.getAddress());

  //2.Deploy AuctionFactory implementation and proxy
  const AuctionFactory = await ethers.getContractFactory("AuctionFactory");
  const auctionFactory = await AuctionFactory.deploy();
  await auctionFactory.waitForDeployment();
  console.log("AuctionFactory deployed to:", await auctionFactory.getAddress());


  const ccipSimulatorDeployment = await ethers.deployContract("CCIPSimulator");
  const address = await ccipSimulatorDeployment.getAddress();
  const ccipSimulator = await ethers.getContractAt("CCIPSimulator",address);

  const ccipConfig = await ccipSimulator.configuration();
  const sourceChainRouter = ccipConfig.sourceRouter_;
  const linkToken = ccipConfig.linkToken_;

  //3.Deploy CrossChainMessenger
  const CrossChainMessenger = await ethers.getContractFactory("CrossChainMessager");
  const crossChainMessenger = await CrossChainMessenger.deploy(sourceChainRouter,linkToken);
  await crossChainMessenger.waitForDeployment();
  console.log("CrossChainMessager deployed to:", await crossChainMessenger.getAddress());
}


main().catch(console.error);