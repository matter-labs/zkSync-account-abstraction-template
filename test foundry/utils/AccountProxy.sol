//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// this is a contract that will represent the account in zksync era , it behaves normaly but it have a will feature
// this account don't have any functionality of an account cause we only use it to test will behavior.

contract AccountProxy {
    address implementation;

    function init(address logic, uint256 _duration, uint256 _fromLastUpdate, address _mainInheritor, address _owner)
        public
    {
        //consider to initiate the account before you set the implementation to avoid front running
        bytes memory data = abi.encodeWithSignature(
            "init(uint256,uint256,address,address)", _duration, _fromLastUpdate, _mainInheritor, _owner
        );
        (bool seccuss,) = logic.delegatecall(data);
        require(seccuss);
        implementation = logic;
    }

    fallback() external payable {
        // check that the contract have
        address facet = implementation;
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
    }

    receive() external payable {}
}
