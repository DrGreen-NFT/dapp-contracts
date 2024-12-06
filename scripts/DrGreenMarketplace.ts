import { ethers, upgrades } from "hardhat";

async function DrGreenMarketplace() {
  const DrGreenMarketplace = await ethers.getContractFactory(
    "DrGreenMarketplace"
  );
  const marketplace = await DrGreenMarketplace.deploy(
    "0x4758FFb3EF10bf657d4264AEd72db6Db564a9e11"
  );
  await marketplace.waitForDeployment();
  console.log("Marketplace deployed to:", await marketplace.getAddress());
}

DrGreenMarketplace().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
