import { Wallet } from "zksync-web3";
import { verifier } from "./zksyn-general/general-interaction-tips";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import dotenv from "dotenv";
dotenv.config();
//NOTICE : this script deploys a willAccount Independently not from the factoryjust for providing source code in testnet
export default async function (hre: HardhatRuntimeEnvironment) {
  const privateKey: string = process.env.private_key!;
  const wallet = new Wallet(privateKey);
  const deployer = new Deployer(hre, wallet);
  const aaArtifact = await deployer.loadArtifact("WillAccount");
  const willAddress = process.env.will_address_testnet;
  const randomWallet = Wallet.createRandom();
  const owner = randomWallet.address;
  const willAccount = await deployer.deploy(
    aaArtifact,
    [owner, willAddress],
    undefined,
    []
  );
  /// verify :
  await verifier(
    hre,
    willAccount.address,
    "contracts/WillAccount.sol:WillAccount",
    [owner, willAddress]
  );
  console.log(`will account source code deployed at  : ${willAccount.address}`);
}
