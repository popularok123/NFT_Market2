import { ethers, network } from "hardhat";
import { getDeployAddress } from "../utils/deployAddress";

async function main() {

    const [deployer] = await ethers.getSigners();

    const nftAddress = getDeployAddress(network.name, "MyNFT");

    if (!nftAddress) {
        throw new Error(`MyNFT contract address not found for network ${network.name}`);
    }

    const ntf = await ethers.getContractAt("MyNFT", nftAddress);

    const tx = await ntf.mint(deployer.address);
    await tx.wait();

    const tokenAmount = await  ntf.totalSupply();

    console.log(`Minted NFT with token ID ${tokenAmount} to address ${deployer.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});