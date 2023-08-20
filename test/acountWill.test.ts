import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import { expect } from "chai";
import dotenv from "dotenv";
import * as ethers from "ethers";
import * as hre from "hardhat";
import { utils, Contract, Provider, Wallet } from "zksync-web3";
import { deployAccount, deployFactory, deployWill } from "./utils /deployement";
import { rich_wallets } from "./utils /richWallets";

// env vars from the .env file.
dotenv.config();

describe("Account Will", async () => {
  // create two wallets :
  //@TODO ,
});
