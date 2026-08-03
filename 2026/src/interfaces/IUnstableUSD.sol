// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IUnstableUSD
/// @notice The ERC20 debt token minted and burned exclusively by MicroCDP.
interface IUnstableUSD is IERC20 {
    error OnlyMinter();
    error ZeroAddress();

    function mint(address recipient, uint256 amount) external;

    function burn(address account, uint256 amount) external;

    function minter() external view returns (address);
}
