import { utils, Wallet, Contract, Provider } from "zksync-web3";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import dotenv from "dotenv";
import { verifier } from "./zksyn-general/general-interaction-tips";
import * as ethers from "ethers";

dotenv.config();
// the address of will contract in testnet :
const willAddress: string = process.env.will_address_testnet!;
export default async function (hre: HardhatRuntimeEnvironment) {
  // the address of will contract in testnet :
  const provider = new Provider("https://zksync2-testnet.zksync.dev");
  // Private key of the account used to deploy
  const private_key: string = process.env.private_key!;
  // create a wallet with the private key.
  const wallet = new Wallet(private_key, provider);
  // create a deployer object that will deploy the contract to the zksync network:
  const deployer = new Deployer(hre, wallet);
  // get the factory of the contracts wanna deploy .
  const factoryArtifact = await deployer.loadArtifact("WillFactory");
  const aaArtifact = await deployer.loadArtifact("WillAccount");

  // Getting the bytecodeHash of the willAccount since we need to provide it in the factoryDeps feild .
  const aaCodeHash = utils.hashBytecode(aaArtifact.bytecode);

  // the constructor args :
  const constructorArgs = [aaCodeHash, willAddress];

  const factory = await deployer.deploy(
    factoryArtifact,
    constructorArgs,
    undefined,
    // Since the factory requires the code of the multisig to be available,
    // we should pass it here as well.
    [aaArtifact.bytecode]
  );

  // verify factory :
  await verifier(
    hre,
    factory.address,
    "contracts/factory.sol:WillFactory",
    constructorArgs
  );
  console.log(`will factory deployed at : ${factory.address}`);

  ///////////////////////////////////////////////////
  ////////////// deploy account : //////////////////
  /////////////////////////////////////////////////

  // create a factory contract object :
  const FactoryContract = new Contract(
    factory.address,
    factoryArtifact.abi,
    wallet
  );
  await deployAccount(FactoryContract, aaCodeHash);
}

//deploy an account using the factory :
async function deployAccount(contract: Contract, aaCodeHash: any) {
  const owner = "0x4948F43e559A38C1fDbeB2d7C5476d3c0Bda15E7";
  // create a salt :
  const salt = ethers.utils.randomBytes(32);
  // const deploy an account :
  const txDeployAccount = await contract.deployAccount(salt, owner);
  // wait for tx to be mined :
  await txDeployAccount.wait();
  console.log(txDeployAccount);
  console.log(`account get deployed ..\n .................\n............. \n `);
  //compute the address of the new created account :
  const Coder = new ethers.utils.AbiCoder();
  const accountAddress = utils.create2Address(
    contract.address,
    await contract.aaBytecodeHash(),
    salt,
    Coder.encode(["address", "address"], [owner, willAddress])
  );

  console.log(`account deployed at ${accountAddress}`);
}
