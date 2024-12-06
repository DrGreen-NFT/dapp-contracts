import { ethers } from "hardhat";

async function DrGreenNFT() {
  const nftContract = await ethers.getContractFactory("DrGreenNFT");

  const contract = await nftContract.deploy(
    "0xb3182Ae1069253DC69910F6475578878d3679DAc",
    "ipfs://QmNhYFSkkiWKAvL56iZkEfpLmvwubihNUroHqKSMsUQkWi/112_md/",
    "ipfs://Qma9B7dUc1FSnTjidRYNHx9R2KRGvXBWQsfmXnW8jpRNF8",
    "0x6397277046830b948B8029e2612d3CB23fB7c2b7",
    "0x32E71eD285659C4038c938c487C915fbc684ecf4"
  );
  console.log("Contract deployed at:", contract.target);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
DrGreenNFT().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
