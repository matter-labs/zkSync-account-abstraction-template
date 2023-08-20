//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@matterlabs/zksync-contracts/l2/system-contracts/libraries/SystemContractsCaller.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/libraries/SystemContractHelper.sol";
import "./utils/willLib.sol";

/**
 *  @title Will 
 *  @author elhajin
 *  @dev Will Contract: This is a singleton contract to which all accounts delegate calls. It cannot be directly 
 *  called except for view functions, and serves as a central hub for managing inheritance and asset protection.
 *  @notice The allure of decentralized wealth draws many to cryptocurrencies, yet a critical concern shadows
 *  this excitement. In an era where individuals seek financial autonomy, the risk arises when unforeseen 
 *  circumstances strike, leaving their crypto assets locked and inaccessible. The lack of established mechanisms
 *  for inheritance poses a significant challenge. This dilemma casts a shadow over the otherwise promising 
 *  landscape of crypto adoption, prompting individuals to question whether the potential loss of their digital 
 *  fortunes outweighs the allure of decentralized living.
 *  @notice The Inheritance Will Smart Contract introduces a system that enables a contract owner to define 
 *  inheritors, allocate their respective percentages, and specify withdrawal conditions. The contract leverages
 *  a structured approach to manage the withdrawal process, optimizing the inheritor's knowledge of the owner's 
 *  behavior and minimizing the risk of unintended withdrawals.
 *  @notice The willAccount have all the functionality of a standard account and it will behave like any standard
    account exept that the owner have the ability to acitvate Or deactivate `WILLMODE` any time he want, if the will mode 
    is activated the owner have the ability to interact with all `WILL` functionality , otherwise is just a normal account.
*/
// address deployed will testnet : 0x86Aba3c3FfF48b8B1EaC81269a43262625Aa9cD3;
contract will {

    modifier onlyDelegatecall() {
        require(address(this) != SystemContractHelper.getCodeAddress());
        _;
    }

    function init(uint256 _duration, uint256 _fromLastUpdate, address _mainInheritor,address _owner) public onlyDelegatecall {
        willLib.init(_duration, _fromLastUpdate, _mainInheritor,_owner);
    }

    function addInheritor(string memory description, address _inheritor, uint8 _percentage) public onlyDelegatecall {
        willLib.addInheritor(description, _inheritor, _percentage);
    }

    function removeInheritor(address _inheritor) public onlyDelegatecall {
        willLib.removeInheritor(_inheritor);
    }

    function changeInheritorPersantage(address _inheritor, uint8 newPercentage) public onlyDelegatecall {
        willLib.changeInheritorPersantage(_inheritor, newPercentage);
    }

    function changeDuration(uint256 newDuration) public onlyDelegatecall {
        willLib.changeDuration(newDuration);
    }

    function changeFromLastUpdate(uint256 _fromLastUpdate) public onlyDelegatecall {
        willLib.changeFromLastUpdate(_fromLastUpdate);
    }

    function changeMainInheritor(address payable _mainInheritor) public onlyDelegatecall {
        willLib.changeMainInheritor(_mainInheritor);
    }

    function pauseWithdraw() public onlyDelegatecall {
        willLib.pauseWithdraw();
    }

    function requestToWithdraw() public onlyDelegatecall {
        willLib.requestToWithdraw();
    }

    function inheritorWithdraw(address[] memory  tokens) public onlyDelegatecall {
        for(uint i;i<tokens.length;i++){
        willLib.inheritorWithdraw(tokens[i]);
        }
    }

    function getYourCurrentAmount(address token) public view returns (uint256) {
        return willLib.getYourCurrentAmount(token);
    }

    function getInheritorPercentage(address _inheritor) public view returns (uint8) {
        return willLib.getInheritorPercentage(_inheritor);
    }

    function getInheritorCount() public view returns (uint8) {
        return willLib.getInheritorCount();
    }

    function getAvailablePercentage() public view returns (uint8) {
        return willLib.getAvailablePercentage();
    }

    function getRequestWithdraw() public view returns (RequestWithdraw memory) {
        return willLib.getRequestWithdraw();
    }

    function getInheritor(address add) public view returns (Inheritor memory) {
        return willLib.getInheritor(add);
    }

    function isWithdrawMode() public view returns (bool) {
        return willLib._isWithdrawMode();
    }
    ///////////////// helper function for testing ////////////////////////

    function initiated() public view returns (bool) {
        return willLib.s().initiated;
    }

    function owner() public view returns (address) {
        return willLib.s().owner;
    }

    function mainInheritor() public view returns (address) {
        return willLib.s().mainInheritor;
    }
}
