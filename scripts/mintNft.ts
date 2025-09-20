import { ethers } from "hardhat";

async function main() {

    const [deployer] = await ethers.getSigners();

    const nftAddress = "0x59b670e9fA9D0A427751Af201D676719a970857b"; // Replace with your deployed NFT contract address

    const ntf = await ethers.getContractAt("MyNFT", nftAddress);

    const tx = await ntf.mintNFT();
    await tx.wait();

    const tokenAmount = await  ntf.totalSupply();

    console.log(`Minted NFT with token ID ${tokenAmount} to address ${deployer.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});