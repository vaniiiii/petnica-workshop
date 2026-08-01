// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";

import {IUnstableUSD} from "../src/interfaces/IUnstableUSD.sol";
import {UnstableUSD} from "../src/UnstableUSD.sol";

contract UnstableUSDTest is Test {
    UnstableUSD internal stablecoin;

    address internal minter = makeAddr("minter");
    address internal user = makeAddr("user");

    function setUp() external {
        stablecoin = new UnstableUSD(minter);
    }

    function test_NameAndSymbol() external view {
        assertEq(stablecoin.name(), "Unstable USD");
        assertEq(stablecoin.symbol(), "UUSD");
        assertEq(stablecoin.minter(), minter);
    }

    function test_MinterCanMintAndBurn() external {
        vm.prank(minter);
        stablecoin.mint(user, 100 ether);
        assertEq(stablecoin.balanceOf(user), 100 ether);

        vm.prank(minter);
        stablecoin.burn(user, 40 ether);
        assertEq(stablecoin.balanceOf(user), 60 ether);
    }

    function test_RevertWhenNonMinterMints() external {
        vm.expectRevert(IUnstableUSD.OnlyMinter.selector);
        vm.prank(user);
        stablecoin.mint(user, 1 ether);
    }

    function test_RevertWhenNonMinterBurns() external {
        vm.prank(minter);
        stablecoin.mint(user, 1 ether);

        vm.expectRevert(IUnstableUSD.OnlyMinter.selector);
        vm.prank(user);
        stablecoin.burn(user, 1 ether);
    }

    function test_RevertWhenDeployedWithZeroMinter() external {
        vm.expectRevert(IUnstableUSD.ZeroAddress.selector);
        new UnstableUSD(address(0));
    }
}
