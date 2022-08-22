import { ethers, upgrades } from "hardhat";

async function main() {
  const StoryFactory = await ethers.getContractFactory("StoryFactory");
  const StoryNFT = await ethers.getContractFactory("StoryNFT");
  const Finds = await ethers.getContractFactory("Finds");

  const storyBeacon = await upgrades.deployBeacon(StoryNFT);
  console.log(`StoryBeacon at: ${storyBeacon.address}`);
  await storyBeacon.deployed();

  const storyFactory = await upgrades.deployProxy(
    StoryFactory,
    [storyBeacon.address],
    { kind: "uups" }
  );
  console.log(`StoryFactory at: ${storyFactory.address}`);
  await storyFactory.deployed();

  const finds = await upgrades.deployProxy(Finds, { kind: "uups" });
  console.log(`Finds at: ${finds.address}`);
  await finds.deployed();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
