// 1. we need to deploy will contract .
import { Wallet } from "zksync-web3";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import dotenv from "dotenv";
dotenv.config();
import { verifier } from "./zksyn-general/general-interaction-tips";

// export a default function
export default async function (hre: HardhatRuntimeEnvironment) {
  // Private key of the account used to deploy
  const private_key: string = process.env.private_key!;
  // create a wallet with the private key.
  const wallet = new Wallet(private_key);
  // create a deployer object that will deploy the contract to the zksync network:
  const deployer = new Deployer(hre, wallet);
  const willArtifact = await deployer.loadArtifact("will");
  // deploy will contract :
  const will = await deployer.deploy(willArtifact, [], undefined, []);
  //verify will contract :
  await verifier(hre, will.address, "contracts/will.sol:will", []);
  console.log(`will contract deployed at : ${will.address}`);
}
