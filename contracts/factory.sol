//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

//a factory contract the deploys willAccount: 
import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/libraries/SystemContractsCaller.sol";
// the address of the factory in testnet : 0x7b9438D33Cce890Ae6c000529D1d12eb66f5Ab74
contract WillFactory {
    address public immutable WILL_ADDRESS ;
    bytes32 public immutable aaBytecodeHash;
    event NewAccount(address indexed owner, address indexed account);
    
    /**
     * @dev provide the known byteCodehash by "KNOWN_CODE_STORAGE_CONTRACT" and the address of the deployed will contract.
     * @param _aaBytecodeHash the known bytecode hash of the accountWill.
     * @param _will  the address of the will contract .
     */
    constructor(bytes32 _aaBytecodeHash, address _will) {
        aaBytecodeHash = _aaBytecodeHash;
        WILL_ADDRESS = _will;
    }

    /**
     * @dev deploy a willAccount with create2 opcode, given the salt and the owner. 
     * @param salt the salt for create2 opcode
     * @param owner the owner of the account.
     */
    function deployAccount(
        bytes32 salt,
        address owner
    ) external returns (address accountAddress) {
        (bool success, bytes memory returnData) = SystemContractsCaller
            .systemCallWithReturndata(
                uint32(gasleft()),
                address(DEPLOYER_SYSTEM_CONTRACT),
                uint128(0),
                abi.encodeCall(
                    DEPLOYER_SYSTEM_CONTRACT.create2Account,
                    (
                        salt,
                        aaBytecodeHash,
                        abi.encode(owner,WILL_ADDRESS),
                         IContractDeployer.AccountAbstractionVersion.Version1

                    )
                )
            );
        require(success, "Deployment failed");

        (accountAddress) = abi.decode(returnData, (address));
        /// @dev In case of a revert, the zero address should be returned.
        require(accountAddress != address(0));
        emit NewAccount(owner,accountAddress);
    }
}

