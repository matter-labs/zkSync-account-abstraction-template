import { utils, Contract, Wallet, Provider } from "zksync-web3";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import dotenv from "dotenv";
import * as ethers from "ethers";
dotenv.config();

export default async function (hre: HardhatRuntimeEnvironment) {
  const addressAccount: string = process.env.willAccount_address_testnet!;
  // create a provider :
  const provider = new Provider("https://zksync2-testnet.zksync.dev");

  // create a wallet:
  const owner = new Wallet(process.env.account_private_key!, provider);
  // get the contract object :
  const contractInterface = await hre.artifacts.readArtifact("WillAccount");
  const willInterface = await hre.artifacts.readArtifact("will");
  // create a contract object and connect it to the owner :
  const contract = new Contract(addressAccount, contractInterface.abi, owner);
  const contract2 = new Contract(addressAccount, willInterface.abi, owner);
  const balanceAccount = await getBalance(
    addressAccount,
    provider,
    utils.ETH_ADDRESS
  );
  console.log(`balance Account : ${balanceAccount} ETH.`);
  // call a view function :
  const isWillMode = await contract.isWillMode();
  console.log(`isWillMode is : ${isWillMode}`);
}
// function to get balance of any account for a specific token :
export async function getBalance(
  addressAccount: string,
  provider: Provider,
  addresstoken: string
) {
  return await provider.getBalance(addressAccount, undefined, addresstoken);
}

// verifier ;
export async function verifier(
  hre: HardhatRuntimeEnvironment,
  address: string,
  path: string,
  args: any[]
) {
  // verify the contract on the zksyn testnet :
  const verificationId = await hre.run("verify:verify", {
    address: address,
    contract: path,
    constructorArguments: args,
  });
  console.log(` the verification id is : ${verificationId}`);
}
