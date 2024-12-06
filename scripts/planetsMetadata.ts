import { ethers } from "hardhat";

async function PlanetsMetadata() {

  const nftContract = await ethers.getContractFactory("PlanetsMetadata");

  const contract = await nftContract.deploy();

  console.log("Contract deployed at:", contract.target)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
PlanetsMetadata().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
