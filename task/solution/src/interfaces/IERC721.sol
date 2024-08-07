// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IERC721 {
    function mint(address to) external;
    function balanceOf(address owner) external view returns (uint256);
}
