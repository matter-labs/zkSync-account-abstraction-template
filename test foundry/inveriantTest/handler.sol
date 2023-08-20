// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../utils/AccountProxy.sol";
import "../../src/will.sol";

// this handler contract should store the state changes of the account
contract Handler is Test {
    will account;
    will Will;
    mapping(address => uint256) public inheritorIndex;
    address[] public inheritors; //keep tracking the inheritors .
    mapping(address => int256) public inheritorCount; // this track how many time the inheritor get added in the contract
    uint256 public initcall = 1; //should always be 1;

    constructor(address _account, address _will) {
        Will = will(_will);
        account = will(_account); // the address of the account.
    }

    function AddInheritor(string memory str, address inheritor, uint8 percentage) public {
        assumeNotPrecompile(inheritor);
        bound(percentage, 1, 100);
        require(account.getInheritor(inheritor).percentage == 0, "inheritor exist ");

        account.addInheritor(str, inheritor, percentage);
        inheritorIndex[inheritor] = inheritors.length; //store the inheritor id
        inheritors.push(inheritor); // store the inheritor in the lenght .
        inheritorCount[inheritor]++;
    }

    function removeInheritor(address inheritor) public {
        assumeNotPrecompile(inheritor);
        require(account.getInheritor(inheritor).percentage != 0);
        account.removeInheritor(inheritor);
        // delete the inheritor from the array of inheritors and decrease the length.
        inheritors[inheritors.length - 1] = inheritors[inheritorIndex[inheritor]]; // get inheritor index in array
        inheritors.pop(); // delete the inheritor
        inheritorCount[inheritor]--; //can't be underflow error since it will revert Earlier;
    }

    function initCalls(uint256 _duration, uint256 _fromLastUpdate, address _mainInheritor, address _owner) public {
        account.init(_duration, _fromLastUpdate, _mainInheritor, address(this));
        initcall++;
    }
    ///////////////////////// view function for testing ///////////////////

    function getInheritors() public view returns (address[] memory) {
        return inheritors;
    }
}
