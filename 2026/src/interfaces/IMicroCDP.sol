// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {AggregatorV3Interface} from "./AggregatorV3Interface.sol";
import {IUnstableUSD} from "./IUnstableUSD.sol";

/// @title IMicroCDP
/// @notice The complete external API for the workshop's ETH-backed CDP.
interface IMicroCDP {
    error AmountExceedsCollateral();
    error AmountExceedsDebt();
    error EthTransferFailed();
    error InvalidOraclePrice();
    error OraclePriceStale();
    error PositionHasNoDebt();
    error PositionNotFound();
    error PositionNotHealthy();
    error PositionNotLiquidatable();
    error UnsupportedOracleDecimals();
    error ZeroAddress();
    error ZeroAmount();

    struct Position {
        uint256 collateral;
        uint256 debt;
    }

    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event DebtBorrowed(address indexed user, uint256 amount);
    event DebtRepaid(address indexed user, uint256 amount);
    event Liquidated(
        address indexed liquidator,
        address indexed user,
        uint256 debtRepaid,
        uint256 collateralSeized,
        uint256 collateralRemaining
    );

    function depositCollateral() external payable;

    function depositCollateralAndBorrow(uint256 borrowAmount) external payable;

    function borrow(uint256 amount) external;

    function repay(uint256 amount) external;

    function closePosition() external;

    function withdrawCollateral(uint256 amount) external;

    function liquidate(address user) external;

    function isPositionHealthy(address user) external view returns (bool);

    function collateralPrice() external view returns (uint256);

    function positions(address user) external view returns (uint256 collateral, uint256 debt);

    function stablecoin() external view returns (IUnstableUSD);

    function priceFeed() external view returns (AggregatorV3Interface);

    function oracleDecimals() external view returns (uint8);

    function MIN_COLLATERAL_RATIO() external view returns (uint256);

    function LIQUIDATION_BONUS() external view returns (uint256);

    function MAX_PRICE_AGE() external view returns (uint256);
}
