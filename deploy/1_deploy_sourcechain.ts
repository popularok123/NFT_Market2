import hre from "hardhat";
import { developmentChains,networkConfig } from "../helper-hardhat-config";
import { any } from "hardhat/internal/core/params/argumentTypes";

async function main() { 

  const { ethers,upgrades,network } = hre;
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

     //1.Deploy MyNFT contract
  const MyNFT = await ethers.getContractFactory("MyNFT");
  const myNFT = await MyNFT.deploy();
  await myNFT.waitForDeployment();
  console.log("MyNFT deployed to:", await myNFT.getAddress());

  //2.Deploy AuctionController implementation and proxy
  const AuctionController = await ethers.getContractFactory("AuctionController");
  const auctionController = await AuctionController.deploy();
  await auctionController.waitForDeployment();
    const auctionAdress = await auctionController.getAddress();
  console.log("AuctionController deployed to:", auctionAdress);

  //3.Deploy AuctionFactory implementation and proxy
  const AuctionFactory = await ethers.getContractFactory("AuctionFactory");
  const auctionFactory = await AuctionFactory.deploy();
  await auctionFactory.waitForDeployment();
    const factoryAdress = await auctionFactory.getAddress();
  console.log("AuctionFactory deployed to:",factoryAdress);


  //4.Deploy factory proxy and initialize
  const auctionFactoryProxy = await upgrades.deployProxy(AuctionFactory,[factoryAdress,auctionAdress],{initializer:"initialize"});
  await auctionFactoryProxy.waitForDeployment();
  console.log("AuctionFactoryProxy deployed to:", await auctionFactoryProxy.getAddress());

  let sourceChainRouter:string;
  let linkToken:string;

  if(developmentChains.includes(network.name)){
    const ccipSimulatorDeployment = await ethers.deployContract("CCIPSimulator");
    const address = await ccipSimulatorDeployment.getAddress();
    const ccipSimulator = await ethers.getContractAt("CCIPSimulator",address);

    const ccipConfig = await ccipSimulator.configuration();
    sourceChainRouter = ccipConfig.sourceRouter_;
    linkToken = ccipConfig.linkToken_;
  } else {
        const chainId = network.config.chainId as number;
        sourceChainRouter = networkConfig[chainId].router;
        linkToken = networkConfig[chainId].linkToken;
  }
    
  //5.Deploy CrossChainMessenger
  const CrossChainMessenger = await ethers.getContractFactory("CrossChainMessager");
  const crossChainMessenger = await CrossChainMessenger.deploy(sourceChainRouter,linkToken);
  await crossChainMessenger.waitForDeployment();
  console.log("CrossChainMessager deployed to:", await crossChainMessenger.getAddress());
}

main().catch((error) => {   
    console.error(error);    
    process.exitCode = 1;
});