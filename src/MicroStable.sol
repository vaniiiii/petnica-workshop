// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";
import {IMicroCDP} from "./interfaces/IMicroCDP.sol";
import {IUnstableUSD} from "./interfaces/IUnstableUSD.sol";

/// @notice The deliberately optimistic stablecoin minted by MicroCDP.
contract UnstableUSD is ERC20, IUnstableUSD {
    address public immutable override minter;

    modifier onlyMinter() {
        if (msg.sender != minter) revert OnlyMinter();
        _;
    }

    constructor(address minter_) ERC20("Unstable USD", "UUSD") {
        if (minter_ == address(0)) revert ZeroAddress();
        minter = minter_;
    }

    function mint(address recipient, uint256 amount) external override onlyMinter {
        _mint(recipient, amount);
    }

    function burn(address account, uint256 amount) external override onlyMinter {
        _burn(account, amount);
    }
}

/// @title MicroCDP
/// @notice A deliberately small ETH-backed stablecoin system for teaching CDP concepts.
/// @dev Educational code: one collateral type, no interest, governance, debt ceiling, or bad-debt handling.
contract MicroCDP is IMicroCDP {
    uint256 public constant override MIN_COLLATERAL_RATIO = 1.5e18;
    uint256 public constant override LIQUIDATION_BONUS = 0.1e18;
    uint256 public constant override MAX_PRICE_AGE = 1 hours;
    uint256 private constant WAD = 1e18;

    IUnstableUSD public immutable override stablecoin;
    AggregatorV3Interface public immutable override priceFeed;
    uint8 public immutable override oracleDecimals;

    mapping(address user => Position position) public override positions;

    constructor(address priceFeed_) {
        if (priceFeed_ == address(0)) revert ZeroAddress();

        uint8 decimals = AggregatorV3Interface(priceFeed_).decimals();
        if (decimals > 18) revert UnsupportedOracleDecimals();

        priceFeed = AggregatorV3Interface(priceFeed_);
        oracleDecimals = decimals;
        stablecoin = new UnstableUSD(address(this));
    }

    function depositCollateral() external payable override {
        _depositCollateral(msg.sender, msg.value);
    }

    function depositCollateralAndBorrow(uint256 borrowAmount) external payable override {
        _depositCollateral(msg.sender, msg.value);
        _borrow(msg.sender, borrowAmount);
    }

    function borrow(uint256 amount) external override {
        _borrow(msg.sender, amount);
    }

    function repay(uint256 amount) external override {
        if (amount == 0) revert ZeroAmount();

        Position storage position = positions[msg.sender];
        if (position.debt == 0) revert PositionHasNoDebt();
        if (amount > position.debt) revert AmountExceedsDebt();

        position.debt -= amount;
        stablecoin.burn(msg.sender, amount);

        emit DebtRepaid(msg.sender, amount);
    }

    function closePosition() external override {
        Position memory position = positions[msg.sender];
        if (position.collateral == 0 && position.debt == 0) revert PositionNotFound();

        delete positions[msg.sender];

        if (position.debt != 0) {
            stablecoin.burn(msg.sender, position.debt);
            emit DebtRepaid(msg.sender, position.debt);
        }

        if (position.collateral != 0) {
            _sendEth(msg.sender, position.collateral);
            emit CollateralWithdrawn(msg.sender, position.collateral);
        }
    }

    function withdrawCollateral(uint256 amount) external override {
        if (amount == 0) revert ZeroAmount();

        Position storage position = positions[msg.sender];
        if (amount > position.collateral) revert AmountExceedsCollateral();

        uint256 remainingCollateral = position.collateral - amount;
        if (position.debt != 0 && !_isHealthy(remainingCollateral, position.debt, collateralPrice())) {
            revert PositionNotHealthy();
        }

        position.collateral = remainingCollateral;
        _sendEth(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, amount);
    }

    function liquidate(address user) external override {
        Position storage position = positions[user];
        uint256 debt = position.debt;
        if (debt == 0) revert PositionHasNoDebt();

        uint256 price = collateralPrice();
        if (_isHealthy(position.collateral, debt, price)) revert PositionNotLiquidatable();

        uint256 collateralToSeize = Math.mulDiv(debt, WAD + LIQUIDATION_BONUS, price);
        if (collateralToSeize > position.collateral) collateralToSeize = position.collateral;

        uint256 remainingCollateral = position.collateral - collateralToSeize;
        position.debt = 0;
        position.collateral = remainingCollateral;

        stablecoin.burn(msg.sender, debt);
        _sendEth(msg.sender, collateralToSeize);

        emit Liquidated(msg.sender, user, debt, collateralToSeize, remainingCollateral);
    }

    function isPositionHealthy(address user) external view override returns (bool) {
        Position memory position = positions[user];
        if (position.debt == 0) return true;
        return _isHealthy(position.collateral, position.debt, collateralPrice());
    }

    function collateralPrice() public view override returns (uint256) {
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();

        if (roundId == 0 || answer <= 0 || updatedAt == 0 || updatedAt > block.timestamp || answeredInRound < roundId) {
            revert InvalidOraclePrice();
        }
        if (block.timestamp - updatedAt > MAX_PRICE_AGE) revert OraclePriceStale();

        return SafeCast.toUint256(answer) * (10 ** (18 - oracleDecimals));
    }

    function _depositCollateral(address user, uint256 amount) private {
        if (amount == 0) revert ZeroAmount();

        positions[user].collateral += amount;
        emit CollateralDeposited(user, amount);
    }

    function _borrow(address user, uint256 amount) private {
        if (amount == 0) revert ZeroAmount();

        Position storage position = positions[user];
        uint256 newDebt = position.debt + amount;
        if (!_isHealthy(position.collateral, newDebt, collateralPrice())) revert PositionNotHealthy();

        position.debt = newDebt;
        stablecoin.mint(user, amount);

        emit DebtBorrowed(user, amount);
    }

    function _isHealthy(uint256 collateral, uint256 debt, uint256 price) private pure returns (bool) {
        if (debt == 0) return true;
        return Math.mulDiv(collateral, price, debt) >= MIN_COLLATERAL_RATIO;
    }

    function _sendEth(address recipient, uint256 amount) private {
        (bool success,) = recipient.call{value: amount}("");
        if (!success) revert EthTransferFailed();
    }
}


// oracle problem? (prediction markets)
// why people use the stablecoin for?
// leverage? 
// liquid staking? different collaterals
// stable to some other token, we use dex/exchange.
// ethena/usdai
// spark
// tokenized assets/tokenization
// crypto cards
