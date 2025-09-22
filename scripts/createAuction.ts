import { ethers, network } from "hardhat";
import { getDeployAddress, saveDeployAddress } from "../utils/deployAddress";


async function main() {
    const [deployer,seller] = await ethers.getSigners();
    const proxyAddress = getDeployAddress(network.name, "AuctionFactoryProxy");
    const nftAddress = getDeployAddress(network.name, "MyNFT");

    if (!proxyAddress||!nftAddress) {
        throw new Error(`AuctionFactoryProxy contract address not found for network ${network.name}`);
    }

    const auctionFactory = await ethers.getContractAt("AuctionFactory", proxyAddress);

    const ntf = await ethers.getContractAt("MyNFT", nftAddress);


    // console.log("Minting NFT to seller address:",seller.address);
    const txMint = await ntf.mint(seller.address);
    await txMint.wait();
    console.log("Minted NFT with token ID 1 to address",seller.address);

   const tokenId = await ntf.getTokenId();
    console.log("Next token ID is:",tokenId.toString());

    const pId = tokenId - 1n;

    // approve
    const txApprove = await ntf.connect(seller).approve(proxyAddress,pId);
    await txApprove.wait();
    console.log("Approved AuctionFactory to manage NFT with token ID 1");
  
   

    /* uint256 auctionId,
        address nftContract,
        uint256 tokenId,
        address bidToken,
        address priceFeed,
        uint256 startTime,
        uint256 endTime,
        address _router*/
     const now = Math.floor(Date.now() / 1000);
  const startTime = now + 10; // start in 10s
  const endTime = now + 86400; // end in 1 day

    const factoryAsSeller = auctionFactory.connect(seller);
    const tx = await  factoryAsSeller.createAuction(1,nftAddress,pId,ethers.ZeroAddress,"0x694AA1769357215DE4FAC081bf1f309aDC325306",startTime,endTime,ethers.ZeroAddress);
    const rec = await tx.wait();
    console.log("create auction success");

    const auctionProxy = await auctionFactory.getAuction(nftAddress,pId);

    saveDeployAddress(network.name, "LatestAuction", auctionProxy);

    const auctionControl = await ethers.getContractAt("AuctionController", auctionProxy);

    const acount = ethers.parseEther("1");

    const balance = await ethers.provider.getBalance(seller.address);
    console.log("Seller balance:",ethers.formatEther(balance));

    const bidTx = await  auctionControl.connect(seller).bid(acount,{value:acount});

    await bidTx.wait();

    console.log("Bid placed with 1 ETH by seller itself");

}


main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});