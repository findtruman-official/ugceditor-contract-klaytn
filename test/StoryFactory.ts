import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { TransactionResponse } from "@ethersproject/providers";
import { Contract, ContractFactory } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("StoryFactory", function () {
  let deployer: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;

  let StoryNFT: ContractFactory;
  let StoryNFT_TEST: ContractFactory;
  let StoryFactory: ContractFactory;
  let StoryFactory_TEST: ContractFactory;
  let Finds: ContractFactory;

  let storyFactory: Contract;
  let storyBeacon: Contract;
  let finds: Contract;

  it("setup", async () => {
    StoryFactory = await ethers.getContractFactory("StoryFactory");
    StoryFactory_TEST = await ethers.getContractFactory("StoryFactory_TEST");
    StoryNFT = await ethers.getContractFactory("StoryNFT");
    StoryNFT_TEST = await ethers.getContractFactory("StoryNFT_TEST");
    Finds = await ethers.getContractFactory("Finds");
    [deployer, addr1, addr2] = await ethers.getSigners();

    storyBeacon = await upgrades.deployBeacon(StoryNFT);
    storyFactory = await upgrades.deployProxy(
      StoryFactory,
      [storyBeacon.address],
      { kind: "uups" }
    );
    finds = await upgrades.deployProxy(Finds, { kind: "uups" });
  });

  describe("Publish Story", () => {
    it("publish story emits StoryUpdated event", async () => {
      await expect(storyFactory.connect(addr1).publishStory("CID"))
        .to.emit(storyFactory, "StoryUpdated")
        .withArgs(1, addr1.address);
    });
    it("story data is correct", async () => {
      const story = await storyFactory.stories(1);
      expect(story.id).eq(1);
      expect(story.cid).eq("CID");
      expect(story.author).eq(addr1.address);
    });
  });

  describe("Update Story", () => {
    it("only author can update story", async () => {
      await expect(
        storyFactory.connect(addr2).updateStory(1, "CID2")
      ).to.revertedWith("only author");
    });
    it("update story emits StoryUpdated event", async () => {
      await expect(storyFactory.connect(addr1).updateStory(1, "CID2"))
        .to.emit(storyFactory, "StoryUpdated")
        .withArgs(1, addr1.address);
    });
    it("story data is correct", async () => {
      const story = await storyFactory.stories(1);
      expect(story.id).eq(1);
      expect(story.cid).eq("CID2");
      expect(story.author).eq(addr1.address);
    });
  });

  describe("Publish Story NFT", () => {
    it("only author can publish story nft", async () => {
      await expect(
        storyFactory.connect(addr2).publishStoryNft(
          1, //uint256 id,
          "Story1", //string memory name,
          "Story", //string memory symbol,
          "BASE", // string memory base,
          finds.address, //address token,
          200,
          3,
          1
        )
      ).to.be.revertedWith("only author");
    });
    it("publish story nft emits StoryNftPublished", async () => {
      await expect(
        storyFactory.connect(addr1).publishStoryNft(
          1, //uint256 id,
          "Story1", //string memory name,
          "Story", //string memory symbol,
          "BASE", // string memory base,
          finds.address, //address token,
          200,
          3,
          1
        )
      )
        .to.emit(storyFactory, "StoryNftPublished")
        .withArgs(1);
    });
    it("sale data is correct", async () => {
      const data = await storyFactory.sales(1);
      expect(data.id).eq(1);
      expect(data.total).eq(3);
      expect(data.sold).eq(0);
      expect(data.authorReserved).eq(1);
      expect(data.authorClaimed).eq(0);
      expect(data.recv).eq(addr1.address);
      expect(data.token).eq(finds.address);
      expect(data.price).eq(200);
    });
    it("sale nft data is correct", async () => {
      const data = await storyFactory.sales(1);
      const nft = StoryNFT.attach(data.nft);
      expect(await nft.base()).eq("BASE");
      expect(await nft.symbol()).eq("Story");
      expect(await nft.name()).eq("Story1");
    });
    it("can not published nft second time", async () => {
      await expect(
        storyFactory.connect(addr1).publishStoryNft(
          1, //uint256 id,
          "Story1", //string memory name,
          "Story", //string memory symbol,
          "BASE", // string memory base,
          finds.address, //address token,
          200,
          100,
          20
        )
      ).to.be.revertedWith("sale exists");
    });
  });

  describe("Mint Story Nft", () => {
    it("need enought finds", async () => {
      await expect(
        storyFactory.connect(addr2).mintStoryNft(1)
      ).to.be.revertedWith("not enough token");
    });
    it("mint story nft emits StoryNftMinted", async () => {
      await finds.mint(addr2.address, 500);
      await finds.connect(addr2).approve(storyFactory.address, 100000);

      await expect(storyFactory.connect(addr2).mintStoryNft(1))
        .to.emit(storyFactory, "StoryNftMinted")
        .withArgs(1, addr2.address);
    });

    it("minter nft data is correct", async () => {
      const nft = StoryNFT.attach((await storyFactory.sales(1)).nft);
      expect(await nft.balanceOf(addr2.address)).eq(1);
      expect(await nft.tokenURI(1)).eq("BASE/1.json");
    });

    it("finds change is correct", async () => {
      expect(await finds.balanceOf(addr2.address)).eq(300);
      expect(await finds.balanceOf(addr1.address)).eq(200);
    });

    it("sale data is correct", async () => {
      const data = await storyFactory.sales(1);
      expect(data.id).eq(1);
      expect(data.total).eq(3);
      expect(data.sold).eq(1);
      expect(data.authorReserved).eq(1);
      expect(data.authorClaimed).eq(0);
      expect(data.recv).eq(addr1.address);
      expect(data.token).eq(finds.address);
      expect(data.price).eq(200);
    });

    it("nft will sold out", async () => {
      await finds.mint(addr2.address, 500);
      await storyFactory.connect(addr2).mintStoryNft(1);
      await expect(
        storyFactory.connect(addr2).mintStoryNft(1)
      ).to.be.revertedWith("sold out");
    });
  });

  describe("Upgradable Story Beacon", function () {
    let proxy1: Contract;
    let proxy2: Contract;

    it("beacon owner is deployer", async function () {
      expect(await storyBeacon.owner()).to.eq(deployer.address);
    });

    it("data is different betweet proxy 1 and proxy 2 ", async () => {
      proxy1 = await upgrades.deployBeaconProxy(storyBeacon, StoryNFT, [
        "NFT1",
        "N1",
        "Base1",
      ]);

      proxy2 = await upgrades.deployBeaconProxy(storyBeacon, StoryNFT, [
        "NFT2",
        "N2",
        "Base2",
      ]);

      expect(proxy1.address).to.not.eq(proxy2.address);

      expect(await proxy1.name()).to.eq("NFT1");
      expect(await proxy1.symbol()).to.eq("N1");
      expect(await proxy1.base()).to.eq("Base1");

      expect(await proxy2.name()).to.eq("NFT2");
      expect(await proxy2.symbol()).to.eq("N2");
      expect(await proxy2.base()).to.eq("Base2");
    });

    it("beacon upgrade is available", async () => {
      await upgrades.upgradeBeacon(storyBeacon, StoryNFT_TEST);

      expect(await proxy1.tokenURI(1)).to.eq("");
      expect(await proxy2.tokenURI(1)).to.eq("");

      // // manual check tx gasUsed
      // await Promise.all((await getAllTransactions()).map(showTxGasUsed));
    });
  });

  describe("Upgradable Story Factory", () => {
    it("upgrade story factory", async () => {
      const upgraded = await upgrades.upgradeProxy(
        storyFactory,
        StoryFactory_TEST
      );
      expect(upgraded.address).eq(storyFactory.address);

      expect(await upgraded.nftBeacon()).eq(storyBeacon.address);
      expect(await upgraded.magic()).eq(523);
    });
  });
});

async function getAllTransactions() {
  const height = await ethers.provider.getBlockNumber();
  let txs: TransactionResponse[] = [];
  for (let h = 1; h <= height; h++) {
    const { transactions } = await ethers.provider.getBlockWithTransactions(h);
    txs = [...txs, ...transactions];
  }
  return txs;
}

async function showTxGasUsed(tx: TransactionResponse) {
  const { gasUsed } = await ethers.provider.getTransactionReceipt(tx.hash);
  console.log(`b ${tx.blockNumber} tx ${tx.hash} gas used ${gasUsed}`);
}
