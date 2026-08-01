// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";

import {AggregatorV3Interface} from "../src/interfaces/AggregatorV3Interface.sol";
import {IMicroCDP} from "../src/interfaces/IMicroCDP.sol";
import {IUnstableUSD} from "../src/interfaces/IUnstableUSD.sol";
import {MicroCDP} from "../src/MicroStable.sol";

contract MockPriceFeed is AggregatorV3Interface {
    uint8 private immutable _decimals;
    int256 private _answer;
    uint80 private _roundId = 1;
    uint256 private _updatedAt;

    constructor(uint8 decimals_, int256 answer_) {
        _decimals = decimals_;
        _answer = answer_;
        _updatedAt = block.timestamp;
    }

    function setAnswer(int256 answer_) external {
        _roundId++;
        _answer = answer_;
        _updatedAt = block.timestamp;
    }

    function setUpdatedAt(uint256 updatedAt_) external {
        _updatedAt = updatedAt_;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function description() external pure returns (string memory) {
        return "Mock ETH / USD";
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function getRoundData(uint80)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _answer, _updatedAt, _updatedAt, _roundId);
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _answer, _updatedAt, _updatedAt, _roundId);
    }
}

contract MicroCDPTest is Test {
    IMicroCDP internal cdp;
    MockPriceFeed internal priceFeed;
    IUnstableUSD internal stablecoin;

    address internal borrower = makeAddr("borrower");
    address internal liquidator = makeAddr("liquidator");

    function setUp() external {
        vm.warp(10 days);

        priceFeed = new MockPriceFeed(8, 2_000e8);
        cdp = new MicroCDP(address(priceFeed));
        stablecoin = cdp.stablecoin();

        vm.deal(borrower, 10 ether);
        vm.deal(liquidator, 10 ether);
    }

    function test_DepositCollateralAndBorrowInOneTransaction() external {
        vm.prank(borrower);
        cdp.depositCollateralAndBorrow{value: 1 ether}(1_000 ether);

        (uint256 collateral, uint256 debt) = cdp.positions(borrower);
        assertEq(collateral, 1 ether);
        assertEq(debt, 1_000 ether);
        assertEq(stablecoin.balanceOf(borrower), 1_000 ether);
        assertTrue(cdp.isPositionHealthy(borrower));
    }

    function test_DepositOnlyThenBorrowLater() external {
        vm.prank(borrower);
        cdp.depositCollateral{value: 1 ether}();

        vm.prank(borrower);
        cdp.borrow(500 ether);

        (uint256 collateral, uint256 debt) = cdp.positions(borrower);
        assertEq(collateral, 1 ether);
        assertEq(debt, 500 ether);
    }

    function test_RepayPartOfDebt() external {
        _openBorrowerPosition(1_000 ether);

        vm.prank(borrower);
        cdp.repay(400 ether);

        (, uint256 debt) = cdp.positions(borrower);
        assertEq(debt, 600 ether);
        assertEq(stablecoin.balanceOf(borrower), 600 ether);
    }

    function test_ClosePositionRepaysAllDebtAndReturnsAllCollateral() external {
        _openBorrowerPosition(1_000 ether);

        vm.prank(borrower);
        cdp.closePosition();

        (uint256 collateral, uint256 debt) = cdp.positions(borrower);
        assertEq(collateral, 0);
        assertEq(debt, 0);
        assertEq(stablecoin.balanceOf(borrower), 0);
        assertEq(borrower.balance, 10 ether);
    }

    function test_WithdrawOnlyExcessCollateral() external {
        _openBorrowerPosition(1_000 ether);

        vm.prank(borrower);
        cdp.withdrawCollateral(0.25 ether);

        (uint256 collateral,) = cdp.positions(borrower);
        assertEq(collateral, 0.75 ether);

        vm.expectRevert(IMicroCDP.PositionNotHealthy.selector);
        vm.prank(borrower);
        cdp.withdrawCollateral(1);
    }

    function test_RepayAllThenWithdrawCollateralSeparately() external {
        _openBorrowerPosition(1_000 ether);

        vm.prank(borrower);
        cdp.repay(1_000 ether);
        vm.prank(borrower);
        cdp.withdrawCollateral(1 ether);

        (uint256 collateral, uint256 debt) = cdp.positions(borrower);
        assertEq(collateral, 0);
        assertEq(debt, 0);
    }

    function test_LiquidationPaysFixedBonusAndLeavesRemainingCollateral() external {
        _openBorrowerPosition(1_000 ether);
        vm.prank(borrower);
        assertTrue(stablecoin.transfer(liquidator, 1_000 ether));

        priceFeed.setAnswer(1_400e8);

        uint256 expectedSeized = (uint256(1_100) * 1 ether) / 1_400;
        uint256 expectedRemaining = 1 ether - expectedSeized;

        vm.expectEmit(true, true, false, true);
        emit IMicroCDP.Liquidated(liquidator, borrower, 1_000 ether, expectedSeized, expectedRemaining);
        vm.prank(liquidator);
        cdp.liquidate(borrower);

        (uint256 collateral, uint256 debt) = cdp.positions(borrower);
        assertEq(collateral, expectedRemaining);
        assertEq(debt, 0);
        assertEq(liquidator.balance, 10 ether + expectedSeized);
        assertEq(stablecoin.balanceOf(liquidator), 0);

        vm.prank(borrower);
        cdp.withdrawCollateral(expectedRemaining);
        assertEq(borrower.balance, 9 ether + expectedRemaining);
    }

    function test_RevertWhenLiquidatingHealthyPosition() external {
        _openBorrowerPosition(1_000 ether);
        vm.prank(borrower);
        assertTrue(stablecoin.transfer(liquidator, 1_000 ether));

        vm.expectRevert(IMicroCDP.PositionNotLiquidatable.selector);
        vm.prank(liquidator);
        cdp.liquidate(borrower);
    }

    function test_RevertWhenPriceIsStale() external {
        vm.warp(block.timestamp + cdp.MAX_PRICE_AGE() + 1);

        vm.expectRevert(IMicroCDP.OraclePriceStale.selector);
        cdp.collateralPrice();
    }

    function test_RevertWhenOraclePriceIsNotPositive() external {
        priceFeed.setAnswer(0);

        vm.expectRevert(IMicroCDP.InvalidOraclePrice.selector);
        cdp.collateralPrice();
    }

    function test_RevertWhenBorrowWouldBeUndercollateralized() external {
        vm.expectRevert(IMicroCDP.PositionNotHealthy.selector);
        vm.prank(borrower);
        cdp.depositCollateralAndBorrow{value: 1 ether}(1_334 ether);
    }

    function _openBorrowerPosition(uint256 debt) private {
        vm.prank(borrower);
        cdp.depositCollateralAndBorrow{value: 1 ether}(debt);
    }
}
