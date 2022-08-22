import { HardhatUserConfig } from "hardhat/config";
import "@openzeppelin/hardhat-upgrades";
import "@nomicfoundation/hardhat-toolbox";
const klaythPk = process.env["PRIVATE_KEY"];

const config: HardhatUserConfig = {
  solidity: "0.8.9",
  networks: {
    baobab: {
      url: "https://public-node-api.klaytnapi.com/v1/baobab",
      accounts: [klaythPk!],
    },
  },
};

export default config;
