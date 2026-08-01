// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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
