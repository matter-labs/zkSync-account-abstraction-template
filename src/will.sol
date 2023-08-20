//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./utils/willLib.sol";
/**
 * for test perposes with foundry we are using nother method to check delegatecall, since foundry not compatible with
 *  zksync evm. we cant use getAddress() method since it's uses a mimcCall that foundry does not support .
 */

contract will {
    address public immutable self;

    modifier onlyDelegatecall() {
        require(address(this) != self, "NonDelegateCall");
        _;
    }

    constructor() {
        self = address(this);
    }

    function init(uint256 _duration, uint256 _fromLastUpdate, address _mainInheritor, address _owner)
        public
        onlyDelegatecall
    {
        willLib.init(_duration, _fromLastUpdate, _mainInheritor, _owner);
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

    function inheritorWithdraw(address token) public onlyDelegatecall {
        willLib.inheritorWithdraw(token);
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

    function getDuration() public view returns (uint256) {
        return willLib.s().duration;
    }

    function getLastUpdate() public view returns (uint256) {
        return willLib.s().lastUpdate;
    }

    function didWithdraw(address inheritor, address token) public returns (bool) {
        return willLib.s().didWithraw[inheritor][token];
    }
}
