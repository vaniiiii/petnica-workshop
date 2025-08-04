<div align="center">
<h1>Petnica Ethereum Workshop <br>| Edition 2025 - Day 2 |</h1>
</div>

# Table of Contents

<details>
  <summary><a href="#section-0-foundry-modern-smart-contract-development">Section 0: Foundry - Modern Smart Contract Development</a></summary>
  <ol>
    <li><a href="#what-is-foundry">What is Foundry?</a></li>
    <li><a href="#why-foundry">Why Foundry?</a></li>
    <li><a href="#installation">Installation</a></li>
  </ol>
</details>

<details>
  <summary><a href="#section-1-understanding-blockchain-assets">Section 1: Understanding Blockchain Assets</a></summary>
  <ol>
    <li><a href="#tokens-vs-coins">Tokens vs Coins</a></li>
    <li><a href="#eips-vs-ercs">EIPs vs ERCs</a></li>
    <li><a href="#stablecoins">Stablecoins</a></li>
  </ol>
</details>

<details>
  <summary><a href="#section-2-token-standards">Section 2: Token Standards</a></summary>
  <ol>
    <li><a href="#erc20-fungible-tokens">ERC20 - Fungible Tokens</a></li>
    <li><a href="#erc721-non-fungible-tokens">ERC721 - Non-Fungible Tokens</a></li>
  </ol>
</details>

<details>
  <summary><a href="#section-3-task-solutions">Section 3: Task Solutions</a></summary>
  <ol>
    <li><a href="#phase-2-solution">Phase 2 Solution</a></li>
    <li><a href="#phase-3-solution">Phase 3 Solution</a></li>
  </ol>
</details>

<hr style="border: 1px dashed #ccc;">

# Section 0: Foundry - Modern Smart Contract Development

## What is Foundry?

Foundry is the best environment today for developing smart contracts. It's a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.

### Key Components:
- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools)
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network
- **Chisel**: Fast, utilitarian, and verbose solidity REPL

## Why Foundry?

1. **Speed**: Written in Rust, Foundry is incredibly fast for compilation and testing
2. **Native Solidity Testing**: Write your tests in Solidity, not JavaScript
3. **Powerful Testing Features**: 
   - Fuzz testing
   - Property-based testing
   - Fork testing
   - Gas snapshots
4. **Built-in Tools**: Everything you need in one package
5. **Great Developer Experience**: Intuitive commands and excellent debugging

## Installation

Visit the official Foundry website for installation instructions:

🔗 [https://getfoundry.sh/](https://getfoundry.sh/)

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash

# Then run
foundryup
```

<p align="right">(<a href="#table-of-contents">back to top</a>) ⬆️</p>

# Section 1: Understanding Blockchain Assets

## Tokens vs Coins

Understanding the difference between tokens and coins is fundamental in blockchain:

### Coins (Native Cryptocurrencies)
- **Definition**: Digital assets native to their own blockchain
- **Examples**: Bitcoin (BTC), Ether (ETH), Solana (SOL)
- **Purpose**: Used for transaction fees, network security, and as a medium of exchange
- **Key Feature**: Operate on their own independent blockchain

### Tokens
- **Definition**: Digital assets built on top of existing blockchains
- **Examples**: USDC, SHIB, UNI (all built on Ethereum)
- **Purpose**: Can represent anything - utility, governance rights, assets, etc.
- **Key Feature**: Use the underlying blockchain's infrastructure

📚 Learn more: [Crypto Coins vs Tokens: What's the Difference?](https://www.kraken.com/learn/crypto-coins-tokens-difference)

## EIPs vs ERCs

### EIP (Ethereum Improvement Proposal)
- **What it is**: A design document providing information to the Ethereum community
- **Purpose**: Describes new features or processes for Ethereum
- **Types**: Core, Networking, Interface, Meta, and Informational

### ERC (Ethereum Request for Comments)
- **What it is**: A subset of EIPs that define standards
- **Purpose**: Ensures compatibility and interoperability
- **Examples**: 
  - ERC-20: Fungible token standard
  - ERC-721: Non-fungible token standard
  - ERC-1155: Multi-token standard

📚 Deep dive: [What the Heck are EIPs and ERCs?](https://dev.to/githaiga22/what-the-heck-are-eips-and-ercs-a-beginners-guide-to-4-ethereum-upgrades-youve-never-heard-of-c75)

## Stablecoins

Stablecoins are cryptocurrencies designed to maintain a stable value relative to a reference asset (usually USD).

### Centralized Stablecoins
- **Backed by**: Traditional assets held in reserves
- **Examples**: 
  - **USDC**: Backed by US dollars in bank accounts
  - **USDT (Tether)**: Backed by various assets including USD
- **Pros**: Simple, reliable peg, widely accepted
- **Cons**: Requires trust in the issuer, can be frozen

### Decentralized Stablecoins
- **Backed by**: Crypto collateral or algorithmic mechanisms
- **Examples**:
  - **DAI**: Over-collateralized by crypto assets
  - **LUSD**: Backed by ETH only
  - **BOLD**: Newer decentralized stablecoin
  - **USDbC**: Decentralized synthetic dollar
- **Pros**: Censorship resistant, transparent, no central authority
- **Cons**: More complex, can be less stable during market volatility

📚 Learn more: [What Are Stablecoins?](https://www.investopedia.com/terms/s/stablecoin.asp)

<p align="right">(<a href="#table-of-contents">back to top</a>) ⬆️</p>

# Section 2: Token Standards

## ERC20 - Fungible Tokens

ERC20 is the most widely used token standard on Ethereum, defining a common interface for fungible tokens.

### What are Fungible Tokens?
- Each token is identical and interchangeable
- Like traditional currencies - one dollar equals any other dollar
- Divisible into smaller units

### Key Functions:
```solidity
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
```

### Common Use Cases:
- Utility tokens
- Governance tokens
- Wrapped tokens (wETH, wBTC)
- Stablecoins

## ERC721 - Non-Fungible Tokens

ERC721 defines the standard for Non-Fungible Tokens (NFTs), where each token is unique.

### What are Non-Fungible Tokens?
- Each token has unique properties
- Not interchangeable on a 1:1 basis
- Represents ownership of unique items

### Key Functions:
```solidity
interface IERC721 {
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function setApprovalForAll(address operator, bool _approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}
```

### Common Use Cases:
- Digital art and collectibles
- Gaming items
- Real estate tokens
- Identity tokens
- Financial positions (like our streaming contract!)

<p align="right">(<a href="#table-of-contents">back to top</a>) ⬆️</p>

# Section 3: Task Solutions

## Phase 2 Solution

Phase 2 extends the basic streaming contract with ERC20 token support and cancellation functionality.

### Key Additions:
- Support for any ERC20 token (not just ETH)
- Stream cancellation by sender
- SafeERC20 for secure token transfers

📁 [View Phase 2 Solution](../streaming-contract-solution/phase-2-solution/)

## Phase 3 Solution

Phase 3 transforms streams into tradeable NFTs using the ERC721 standard.

### Key Additions:
- Each stream is an NFT
- Streams can be transferred/sold
- New recipient automatically receives payments

📁 [View Phase 3 Solution](../streaming-contract-solution/phase-3-solution/)

<p align="right">(<a href="#table-of-contents">back to top</a>) ⬆️</p>