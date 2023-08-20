//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../utils/AccountProxy.sol";
import "../../src/will.sol";
import "./handler.sol";

contract InveriantWill is Test {
    Handler handler;
    will Will;
    will account;
    AccountProxy proxy;
    address _mainInheritor = address(2333);

    function setUp() public {
        // deploy will contract :
        Will = new will();
        // deploy the AccountProxy
        proxy = new AccountProxy( );
        //deploy the handler contract
        handler = new Handler(address(proxy),address(Will));
        proxy.init(address(Will), 32, 3, _mainInheritor, address(handler));
        // this will make it is to call the will functionality .
        account = will(address(proxy));
        targetContract(address(handler));
    }

    ///////////////////////////// assumptions ///////////////////////
    // the contract availablePercentage should be always less or equal then 100.
    // the sum of of the percentage of all the inheritors  + the available percentage should always ==  100.
    function invariant_PercentageCheck() public {
        address[] memory inheritors = handler.getInheritors();
        uint256 perc;
        for (uint256 i; i < inheritors.length; i++) {
            perc += account.getInheritor(inheritors[i]).percentage;
        }
        assertTrue(perc <= 100);
        assertTrue(account.getAvailablePercentage() <= 100);
    }
    // the owner can't add an inheritor that already exist.
    // the owner can't remove inheritor that not exist.

    function invariant_checkInheritors() public {
        address[] memory inheritors = handler.getInheritors();

        for (uint256 i; i < inheritors.length; i++) {
            assertTrue(handler.inheritorCount(inheritors[i]) == 1);
        }
    }

    // all inheritors should have more then 0 percentage:
    function invariant_NonZeroPercentage() public {
        address[] memory inheritors = handler.getInheritors();
        for (uint256 i; i < inheritors.length; i++) {
            assertTrue(account.getInheritor(inheritors[i]).percentage > 0);
        }
    }

    // the call to init function should fail if the contract alreadi initiated
    function invariant_initCall() public {
        assertTrue(handler.initcall() == 1);
    }
    // if the call from the owner should always update the lastUpdate var.

    function invariant_UpdateState() public {
        assertTrue(account.getLastUpdate() == block.timestamp);
    }
}
