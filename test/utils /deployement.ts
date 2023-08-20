import { Wallet, Contract, utils } from "zksync-web3";
import * as hre from "hardhat";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import { ethers } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
// deploy the factory contract , provide a wallet and the will address .
export async function deployFactory(
  wallet: Wallet,
  willAddress: string
): Promise<string> {
  let deployer: Deployer = new Deployer(hre, wallet);
  const factoryArtifact = await deployer.loadArtifact("WillFactory");
  const accountArtifact = await deployer.loadArtifact("WillAccount");
  const bytecodeHash = utils.hashBytecode(accountArtifact.bytecode);

  const factory = await deployer.deploy(
    factoryArtifact,
    [bytecodeHash, willAddress],
    undefined,
    [accountArtifact.bytecode]
  );
  return factory.address;
}

// deploy an account , provide a wallet to deploy the account, an owner, and factory address.
// returns an account that implement the willAccount.
export async function deployAccount(
  wallet: Wallet,
  owner: Wallet,
  factory_address: string
): Promise<Contract> {
  const factoryArtifact = await hre.artifacts.readArtifact("WillFactory");
  const factory = new Contract(factory_address, factoryArtifact.abi, wallet);

  const salt = ethers.constants.HashZero;
  const accountAddress = await (
    await factory.deployAccount(salt, owner.address)
  ).wait();

  const AbiCoder = new ethers.utils.AbiCoder();
  const account_address = utils.create2Address(
    factory.address,
    await factory.aaBytecodeHash(),
    salt,
    AbiCoder.encode(["address"], [owner.address])
  );
  const accountArtifact = await hre.artifacts.readArtifact("WillAccount");
  return new ethers.Contract(accountAddress, accountArtifact.abi, owner);
}
// returns an address of will .
export async function deployWill(
  wallet: Wallet,
  hre: HardhatRuntimeEnvironment
): Promise<string> {
  let deployer: Deployer = new Deployer(hre, wallet);
  const willArtifact = await deployer.loadArtifact("will");
  const will = await deployer.deploy(willArtifact, [], undefined, []);
  return will.address;
}
