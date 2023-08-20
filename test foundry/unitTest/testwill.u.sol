//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {will} from "../../src/will.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
//////////////////// contracts for testing /////////////////////////////////////////////////////////////////////
import {AccountProxy} from "../utils/AccountProxy.sol";
import "../utils/token.sol";
import "../../src/utils/willLib.sol";
///////////////////////////////////////////////////////////////////////////////////////////////////////

contract testWill is Test {
    address constant ETH = 0x000000000000000000000000000000000000800A;
    will account;
    token1 token;
    will Will;
    address[] inheritors = [address(134234), address(3423432), address(4324643532)]; //random inheritors
    address owner = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    address mainInheritor = address(2333);
    uint256 fromLastUpdate = 1; // in days;
    uint256 duration = 365; //in days

    function setUp() public {
        // deploy the will contract
        Will = new will();
        // deploy the proxy , and set the will as the address of the contract.
        AccountProxy proxy = new AccountProxy();
        proxy.init(address(Will), duration, fromLastUpdate, mainInheritor, owner);
        account = will(address(proxy)); // to get the access of the functionality (sigs) of will .
        // deploy the token and mint to account  some token .
        token = new token1();
        token.mint(address(account), 1000000 ether);
        vm.deal(address(account), 10 ether);
    }

    function test__checkStateAfterSetup() public {
        //balance of Account :
        assertEq(address(account).balance, 10 ether);
        assertEq(token.balanceOf((address(account))), 1000000 ether);
        // check the state of the account and will :
        assertTrue(account.initiated(), "the contract not initiated yet");
        assertFalse(Will.initiated(), "the contract get iniated WTF ");
        // check the owner :
        assertTrue(account.owner() == owner, "owner is not the same in the account state");
        assertTrue(Will.owner() == address(0), "the owner of will should be zero , but it's not !");
        //check the mainInheritor:
        assertTrue(account.mainInheritor() == mainInheritor, "mainInheritor not the same.");
        assertTrue(Will.mainInheritor() == address(0), "mainInheritor is set in will , and it shouldn't");
        console.log(unicode"🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪 setUp assersion get checked 🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪");
    }

    // test the addInheritor function :
    function test__addInheritor(address randomAddr, uint8 num) public {
        assumeNotPrecompile(randomAddr);
        vm.assume(randomAddr != owner && randomAddr != address(account));
        vm.startPrank(owner);
        // add inheritor with the address zero as inheritor or _percentage zero value .shoud revert
        vm.expectRevert();
        account.addInheritor("should revert cause the inheritor is zero", address(0), 40);
        vm.expectRevert();
        account.addInheritor("should revert cause the percentage is zero", inheritors[0], 0);
        //add inheritor with non owner should revert :
        vm.stopPrank();
        vm.startPrank(randomAddr);
        vm.expectRevert();
        account.addInheritor("should revert cause the percentage is zero", inheritors[0], 45);
        vm.stopPrank();
        vm.startPrank(owner);
        // add inheritor with percentage that more then 100 should revert :
        {
            if (num > 100 || num == 0) {
                vm.expectRevert();
                account.addInheritor("should revert cause the percentage is zero", inheritors[0], num);
                console.log("this is the num ", num);
            } else {
                // should pass normally and change the available percentage, and the count inheritors :

                account.addInheritor("should pass inheritor and decrease the available percentage", inheritors[0], num);
                assertTrue(account.getInheritor(inheritors[0]).percentage == num);
                assertTrue(account.getInheritor(inheritors[0]).id == 0);
                assertTrue(account.getInheritorCount() == 1);
                assertTrue(account.getAvailablePercentage() == 100 - num);
                // add another inheritor ;
                if (account.getAvailablePercentage() != 0) {
                    //should revert if the inheritor already exist:
                    uint8 percentage = account.getAvailablePercentage();
                    vm.expectRevert();
                    account.addInheritor("should revert", inheritors[0], percentage);
                } else if (account.getAvailablePercentage() + num >= 100) {
                    // should revert  :
                    vm.expectRevert();
                    account.addInheritor("should revert", inheritors[1], num);
                } else {
                    // should decrease the account available percentage by the new percentage and increase the inheritors count.
                    uint8 per = account.getAvailablePercentage();
                    account.addInheritor("should pass", inheritors[1], num);
                    assertTrue(account.getInheritor(inheritors[1]).percentage == num);
                    assertTrue(account.getInheritor(inheritors[1]).id == 1);
                    assertFalse(account.getInheritorCount() == 2);
                    assertTrue(account.getAvailablePercentage() == per - num);
                }
            }
            vm.stopPrank();
        }
    }

    // test remove inheritor function :
    function test_removeInheritor(address randomInheritor, address randomOwner, uint8 num) public {
        /////// setup /////////
        assumeNotPrecompile(randomInheritor);
        assumeNotPrecompile(randomOwner);
        vm.assume(randomOwner != owner);
        vm.assume(num != 0 && num < 100);
        vm.prank(owner);
        account.addInheritor("", randomInheritor, num);
        // revert when the caller is not the owner,
        vm.prank(randomOwner);
        vm.expectRevert();
        account.removeInheritor(randomInheritor);
        //revert when the inheritor does not exist
        address nonExistEnheritor = address(324097534809);
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(WillError__NotInheritor.selector, nonExistEnheritor));
        account.removeInheritor(nonExistEnheritor);
        // update the available balance ;
        assertEq(account.getAvailablePercentage(), 100 - num);

        account.removeInheritor(randomInheritor);
        assertTrue(account.getAvailablePercentage() == 100);
    }
    // test the init function :

    function test_init() public {
        // should revert with error
        vm.prank(owner);
        vm.expectRevert("will already initialized");
        account.init(43, 5, mainInheritor, owner);
    }
    // test change duration ,change inheritor persentage , change fromLastupdate, change mainInheritor:

    function test_changes() public {
        // change duraction :
        vm.startPrank(owner);
        account.changeDuration(55);
        assertEq(account.getDuration(), 55 days);
        assertEq(account.getLastUpdate(), block.timestamp);
    }
    // test inheritorRequestToWithdraw,

    function test_requestWithdraw(address addr, address inheritor, uint64 timesPassed) public {
        vm.assume(type(uint256).max > block.timestamp + timesPassed);
        vm.assume(inheritor != address(0) && addr != address(0));
        assumeNotPrecompile(addr);
        assumeNotPrecompile(inheritor);
        vm.label(inheritor, "inheritor");
        vm.label(addr, "addres");
        vm.startPrank(owner);
        account.addInheritor("inheritor", inheritor, 54);
        account.addInheritor("inheritor", inheritors[0], 30);
        vm.stopPrank();
        vm.warp(block.timestamp + timesPassed);
        vm.startPrank(addr);
        if (addr != inheritor && addr != inheritors[0]) {
            console.log("addr != inheritor && timesPassed < fromLastUpdate");
            vm.expectRevert(abi.encodeWithSelector(WillError__NotInheritor.selector, addr));
        }
        if ((addr == inheritor || addr == inheritors[0]) && uint256(timesPassed) < fromLastUpdate) {
            console.log("addr == inheritor && timesPassed < fromLastUpdate");

            vm.expectRevert(WillError__NotAllowedYet.selector);
        }
        account.requestToWithdraw();
        // if the request get set correctly :
        if (account.getRequestWithdraw().requestExsit) {
            address caller = addr == inheritor ? inheritor : inheritors[0];
            vm.stopPrank();
            vm.startPrank(caller);
            vm.expectRevert(
                abi.encodeWithSelector(WillError__RequestAlreadyExist.selector, account.getRequestWithdraw().timestamp)
            );
            account.requestToWithdraw();
        }
    }
    // the call to will write function directly should always fail:

    function test_willCall(address addr) public {
        assumeNotPrecompile(addr);
        vm.startPrank(addr);
        vm.expectRevert("NonDelegateCall");
        Will.init(43, 4, mainInheritor, owner);
    }
    // the inheritors should get thier fair shares.
    // only the inheritors sould be able to withdraw.
    // the main inheritor should get all the remaining shares of any token when the last inherior withdraw.

    function test_withdrawMode() public {
        // setup for withdraw mode :
        withdrawSetUp();
        uint256 startedBalanceToken = token.balanceOf(address(account));
        uint256 startedBalanceEth = address(account).balance;
        uint256 inheritor0Token = startedBalanceToken * account.getInheritor(inheritors[0]).percentage / 100;
        uint256 inheritor1token = startedBalanceToken * account.getInheritor(inheritors[1]).percentage / 100;
        uint256 inheritor2token = startedBalanceToken * account.getInheritor(inheritors[2]).percentage / 100;
        uint256 inheritor0eth = startedBalanceEth * account.getInheritor(inheritors[0]).percentage / 100;
        uint256 inheritor1eth = startedBalanceEth * account.getInheritor(inheritors[1]).percentage / 100;
        uint256 inheritor2eth = startedBalanceEth * account.getInheritor(inheritors[2]).percentage / 100;

        ///////////////////////////////////////////////
        vm.startPrank(inheritors[0]);
        account.inheritorWithdraw(ETH);
        uint256 expectedBalance = startedBalanceEth - inheritor0eth;
        assertTrue(currentBalance(ETH) == expectedBalance);
        console.log("1 expected balance :", expectedBalance);
        account.inheritorWithdraw(address(token));
        vm.stopPrank();
        ////////////////////////////////////////////////////////////
        vm.startPrank(inheritors[1]);
        account.inheritorWithdraw(ETH);
        // erc20 withdraw check:
        account.inheritorWithdraw(address(token));
        expectedBalance = startedBalanceToken - inheritor0Token - inheritor1token;
        assertTrue(currentBalance(address(token)) == expectedBalance);
        assertTrue(currentBalance(ETH) == startedBalanceEth - inheritor0eth - inheritor1eth);
        vm.stopPrank();
        //////////////////////////////////////////////////////////////
        vm.startPrank(inheritors[2]);
        // should send the remaining balance to the mainInheritor.
        uint256 mainInheritorBalanceBefore = mainInheritor.balance;
        account.inheritorWithdraw(ETH);
        account.inheritorWithdraw(address(token));
        expectedBalance = startedBalanceToken - inheritor0Token - inheritor1token - inheritor2token;
        assertTrue(currentBalance(address(token)) == 0,"balance account not zero token");
        assertTrue(currentBalance(ETH) == 0,"balance account not zero eth");
        assertTrue(
            mainInheritorBalanceBefore + startedBalanceEth - inheritor0eth - inheritor1eth - inheritor2eth
                == mainInheritor.balance,"mainInheritor did not get it's shares eth"
        );
        assertTrue(token.balanceOf(mainInheritor) == expectedBalance,"mainInheritor did not get it's shares token");
        vm.stopPrank();
        /////////////////////////////////////////////////////////////////
        for (uint256 i; i < 3; i++) {
            assertTrue(account.didWithdraw(inheritors[i], address(token)));
            assertTrue(account.didWithdraw(inheritors[i], ETH));
        }
        assertEq(account.getAvailablePercentage(), 1);
    }
    //should revert .
    function test_nonInheritorWithdraw(address nonInheritor) public  {

        assumeNotPrecompile(nonInheritor);
        
        vm.assume(nonInheritor != inheritors[0] && nonInheritor != inheritors[1] && nonInheritor != inheritors[2] );
        withdrawSetUp();
        vm.startPrank(nonInheritor);
        vm.expectRevert();
        account.inheritorWithdraw(address(token));
        vm.expectRevert();
        account.inheritorWithdraw(ETH);


    }

    /////////////////////////// helper functions //////////////////////////////
    function withdrawSetUp() public {
        //add some inheritors .
        vm.startPrank(owner);
        account.addInheritor("inheritor1", inheritors[0], 34);
        account.addInheritor("inheritor2", inheritors[1], 50);
        account.addInheritor("inheritor3", inheritors[2], 15);
        assertTrue(account.getAvailablePercentage() == 1);
        // warp time to pass the fromLastUpdate
        vm.warp(block.timestamp + 2 days);
        // create a request withdraw .
        vm.stopPrank();
        vm.prank(inheritors[0]);
        account.requestToWithdraw();
        // warp time to allow the withdraw mood .
        vm.warp(block.timestamp + 400 days);
    }

    function currentBalance(address tok) internal view returns (uint256) {
        if (tok == ETH) return address(account).balance;
        return token1(tok).balanceOf(address(account));
    }
}
