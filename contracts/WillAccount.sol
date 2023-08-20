// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IAccount.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/libraries/TransactionHelper.sol";

import "@openzeppelin/contracts/interfaces/IERC1271.sol";

// Used for signature validation
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// Access zkSync system contracts for nonce validation via NONCE_HOLDER_SYSTEM_CONTRACT
import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";
// to call non-view function of system contracts
import "@matterlabs/zksync-contracts/l2/system-contracts/libraries/SystemContractsCaller.sol";
// import will lib :
import {willLib} from "./utils/willLib.sol";
/// address will account on testnet : 0xaEe85747772Ee755F0E767345D482e4333e7233C
contract WillAccount is IAccount, IERC1271 {
    event WillModeActivated(address indexed account);
    event WillModeDesactivated(address indexed account);

    // to get transaction hash
    using TransactionHelper for Transaction;
    bytes1 constant WILL_MODE = 0x01;
    bytes4 constant EIP1271_SUCCESS_RETURN_VALUE = 0x1626ba7e;
    address immutable WILL_ADDRESS ;
    // state variables for account .
    address owner;
    bytes1 mode;
   
    
    modifier onlyOwner() {
        require(msg.sender == address(this) || msg.sender == owner);
        _;
    }
    modifier onlyBootloader() {
        require(
            msg.sender == BOOTLOADER_FORMAL_ADDRESS,
            "Only bootloader can call this function"
        );
        // Continue execution if called from the bootloader.
        _;
    }

    constructor(address _owner,address will) {
        owner = _owner;
        WILL_ADDRESS = will;
    }

    function validateTransaction(
        bytes32,
        bytes32 _suggestedSignedHash,
        Transaction calldata _transaction
    ) external payable override onlyBootloader returns (bytes4 magic) {
        return _validateTransaction(_suggestedSignedHash, _transaction);
    }

    function _validateTransaction(
        bytes32 _suggestedSignedHash,
        Transaction calldata _transaction
    ) internal returns (bytes4 magic) {
        // Incrementing the nonce of the account.
        // Note, that reserved[0] by convention is currently equal to the nonce passed in the transaction
        SystemContractsCaller.systemCallWithPropagatedRevert(
            uint32(gasleft()),
            address(NONCE_HOLDER_SYSTEM_CONTRACT),
            0,
            abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce))
        );

        bytes32 txHash;
        // While the suggested signed hash is usually provided, it is generally
        // not recommended to rely on it to be present, since in the future
        // there may be tx types with no suggested signed hash.
        if (_suggestedSignedHash == bytes32(0)) {
            txHash = _transaction.encodeHash();
        } else {
            txHash = _suggestedSignedHash;
        }

        // The fact there is enough balance for the account
        // should be checked explicitly to prevent user paying for fee for a
        // transaction that wouldn't be included on Ethereum.
        uint256 totalRequiredBalance = _transaction.totalRequiredBalance();
        require(totalRequiredBalance <= address(this).balance, "Not enough balance for fee + value");

        if (isValidSignature(txHash, _transaction.signature) == EIP1271_SUCCESS_RETURN_VALUE) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
        } else {
            magic = bytes4(0);
        }
    }

    function executeTransaction(
        bytes32,
        bytes32,
        Transaction calldata _transaction
    ) external payable override onlyBootloader {
        _executeTransaction(_transaction);
    }

    function _executeTransaction(Transaction calldata _transaction) internal _updateIfWillMode{
        address to = address(uint160(_transaction.to));
        uint128 value = Utils.safeCastToU128(_transaction.value);
        bytes memory data = _transaction.data;

        if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            uint32 gas = Utils.safeCastToU32(gasleft());

            // Note, that the deployer contract can only be called
            // with a "systemCall" flag.
            SystemContractsCaller.systemCallWithPropagatedRevert(gas, to, value, data);
        } else {
            bool success;
            assembly {
                success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
            }
            require(success);
        }
    }

    function executeTransactionFromOutside(Transaction calldata _transaction)
        external
        payable
        _updateIfWillMode()
    {
        _validateTransaction(bytes32(0), _transaction);
        _executeTransaction(_transaction);
    }

    function isValidSignature(
        bytes32 _hash,
        bytes memory _signature
    ) public view override returns (bytes4 magic) {
        magic = EIP1271_SUCCESS_RETURN_VALUE;

        if (_signature.length != 65) {
            // Signature is invalid anyway, but we need to proceed with the signature verification as usual
            // in order for the fee estimation to work correctly
            _signature = new bytes(65);

            // Making sure that the signatures look like a valid ECDSA signature and are not rejected rightaway
            // while skipping the main verification process.
            _signature[64] = bytes1(uint8(27));
        }

        // extract ECDSA signature
        uint8 v;
        bytes32 r;
        bytes32 s;
        // Signature loading code
        // we jump 32 (0x20) as the first slot of bytes contains the length
        // we jump 65 (0x41) per signature
        // for v we load 32 bytes ending with v (the first 31 come from s) then apply a mask
        assembly {
            r := mload(add(_signature, 0x20))
            s := mload(add(_signature, 0x40))
            v := and(mload(add(_signature, 0x41)), 0xff)
        }

        if (v != 27 && v != 28) {
            magic = bytes4(0);
        }

        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (
            uint256(s) >
            0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
        ) {
            magic = bytes4(0);
        }

        address recoveredAddress = ecrecover(_hash, v, r, s);

        // Note, that we should abstain from using the require here in order to allow for fee estimation to work
        if (recoveredAddress != owner && recoveredAddress != address(0)) {
            magic = bytes4(0);
        }
    }

    function payForTransaction(
        bytes32,
        bytes32,
        Transaction calldata _transaction
    ) external payable override onlyBootloader {
        bool success = _transaction.payToTheBootloader();
        require(success, "Failed to pay the fee to the operator");
    }

    function prepareForPaymaster(
        bytes32, // _txHash
        bytes32, // _suggestedSignedHash
        Transaction calldata _transaction
    ) external payable override onlyBootloader {
        _transaction.processPaymasterInput();
    }

    ///////////////////// will functionality /////////////////////////////
    /**
     * @dev check if the contract is in will mode. 
     * @return boolean true if the contract is in willMode, and false otherwise.
     */
    function isWillMode () public view returns(bool){
        return mode & WILL_MODE != 0;
    }
    /**
     * @dev set account to willmode. 
     * @notice when the willMode is set,the will functions can be called in this account.
     * @param duration the duration that should pass so the inheritors can withdraw thier shares.
     * @param fromLastUpdate the duration that should pass from last interaction from the owner.
     * @param mainInheritor the main inheritor that will take the remained funds stuck in the contract when last inheritor withdraw.
     * @notice when the contract is in willMode;the lastUpdate variable and requestWithdraw will be updated when ever the owner (or account)
     * make an action with this account . 
     */
    function setWillMode(uint duration,uint fromLastUpdate,address mainInheritor) public onlyOwner {
        require(!isWillMode(),"account already on will mode");
        _setWillMode(duration ,fromLastUpdate, mainInheritor);
    }
    /**
     * @dev deactivate will mode,
     */
    function resetWillMode() public onlyOwner{
        require(isWillMode(),"the account is already in WillMode");
        mode = 0x00;
        emit WillModeDesactivated(address(this));
    }
    /**
     * @dev this function is setting the account to willMode , 
     * @notice when the willMode is set,the will functions can be called in this account.
     * @param duration the duration that should pass so the inheritors can withdraw thier shares.
     * @param fromLastUpdate the duration that should pass from last interaction from the owner.
     * @param mainInheritor the main inheritor that will take the remained funds stuck in the contract when last inheritor withdraw.
     * @notice when the contract is in willMode;the lastUpdate variable and requestWithdraw will be updated when ever the owner (or account)
     * make an action with this account . 
     * @notice the owner can activate the will mode and desactivate it when ever he want. so this function should check
     *  if the contract is initiated(means it's not the first time the owner set the will mode), it just gonna set willMode
     *  ,but if the account not initialized, it will initialize it and set the will willmode. 
     */
    function _setWillMode(uint duration,uint fromLastUpdate,address mainInheritor) internal {
        if (!willLib.s().initiated )
        {bytes memory data =
            abi.encodeWithSignature("init(uint256,uint256,address,address)", duration, fromLastUpdate, mainInheritor,owner);
        (bool seccuss,) = WILL_ADDRESS.delegatecall(data);
        require(seccuss);
       }else {
        // need to update since may be the owner set the willMode then desactivated it. 
        willLib._resetRequestIfExist();
        willLib.s().lastUpdate = block.timestamp;
       }
        mode= mode | WILL_MODE;
        emit WillModeActivated(address(this));
    }
    /**
     *@dev update the values when ever the owner interact with the account ,
      or when ever the account excute a transaction 
      @notice update only when the willMode is set. 
     */
    modifier _updateIfWillMode() {
        if(isWillMode()){
        willLib._resetRequestIfExist();
        willLib.s().lastUpdate = block.timestamp;
        }
        _;
    }
    /**
     * @dev the fallback function delegatecall to will address. if the willMode is activated, otherwise it's doesn't
     */

    //////////////////////////////// daily spending logic /////////////////////////////////
    fallback() external {
        // fallback of default account shouldn't be called by bootloader under no circumstances
        assert(msg.sender != BOOTLOADER_FORMAL_ADDRESS);
       
        if (isWillMode() ) {
        // delegate call to the will contract . 
        address facet = WILL_ADDRESS;
        assembly {
            //copy the data to the memory
            calldatacopy(0, 0, calldatasize())
            // delegate call with the data from memory to the facet address
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            // return the data from the call:
            returndatacopy(0, 0, returndatasize())
            // return the data from the call (reverted or not);
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
        }else {
            // behave like an EOA;

        }
    }

    receive() external payable {
        // If the contract is called directly, behave like an EOA.
        // Note, that is okay if the bootloader sends funds with no calldata as it may be used for refunds/operator payments
    }
}

