<div align="center">
<h1>Petnica Ethereum Workshop <br>| Edition 2026 |</h1>
</div>

# Table of Contents

<details>
  <summary><a href="#why-build-on-ethereum-today">Why Build On Ethereum Today</a></summary>
</details>

<details>
  <summary><a href="#what-were-building">What We're Building</a></summary>
</details>

<details>
  <summary><a href="#1-streaming-eth-v1">1. Streaming ETH (V1)</a></summary>
</details>

<details>
  <summary><a href="#2-erc20-streams-v2">2. ERC20 Streams (V2)</a></summary>
</details>

<details>
  <summary><a href="#3-nft-owned-streams-v3">3. NFT-Owned Streams (V3)</a></summary>
</details>

<details>
  <summary><a href="#4-stablecoins">4. Stablecoins</a></summary>
</details>

<details>
  <summary><a href="#5-microcdp-a-toy-collateralized-debt-position">5. MicroCDP: A Toy Collateralized Debt Position</a></summary>
</details>

<details>
  <summary><a href="#repo-structure">Repo Structure</a></summary>
</details>

<details>
  <summary><a href="#foundry">Foundry</a></summary>
</details>

<hr style="border: 1px dashed #ccc;">

## Disclaimer

> ⚠️ All code associated with this workshop is for demo purposes only. It has not been audited and should not be considered production ready. Please use at your own risk.

# Why Build On Ethereum Today

Ethereum is not the cheapest or fastest blockchain. Let's be honest about what it actually is:

- **Slow** — transactions take seconds to minutes, not milliseconds.
- **Expensive** — every operation costs gas.
- **Not the newest tech** — plenty of chains benchmark faster on paper.

So why build here? Because when you're building financial infrastructure, raw speed isn't the only thing that matters. Ethereum has had a decade to build something that's hard to copy quickly:

- mature developer tooling
- mature standards such as ERC20 and ERC721
- deep liquidity
- strong security culture
- a large app and user ecosystem
- credible neutrality and decentralization
- composability with existing DeFi protocols

For many applications, **Ethereum L2s** are the practical execution environment: cheaper and faster, while still connected to Ethereum's ecosystem, liquidity, and standards. Ethereum is not just one chain — it's an ecosystem and settlement network.

This is why a lot of real-world asset and finance activity happens on Ethereum or Ethereum L2s:

- BlackRock launched its first tokenized fund, BUIDL, on Ethereum in 2024.
- Robinhood launched stock tokens in the EU on Arbitrum, an Ethereum L2, and has announced plans for its own Arbitrum-based L2.
- Stablecoin/payment-focused infrastructure such as Tempo shows payments are becoming a major onchain use case in their own right — which doesn't mean a payments app needs its own chain, it means payment companies want things that are hard to guarantee at the application layer: predictable fees, stablecoin gas, fast finality, compliance hooks.

Sources: [BlackRock BUIDL launch](https://www.businesswire.com/news/home/20240320771318/en/BlackRock-Launches-Its-First-Tokenized-Fund-BUIDL-on-the-Ethereum-Network) · [Robinhood stock tokens and Arbitrum](https://robinhood.com/us/en/newsroom/robinhood-launches-stock-tokens-reveals-layer-2-blockchain-and-expands-crypto-suite-in-eu-and-us-with-perpetual-futures-and-staking/) · [Tempo](https://tempo.xyz/)

<p align="right">(<a href="#table-of-contents">back to top</a>) ⬆️</p>

# What We're Building

We'll build one concept at a time, where every new contract answers a practical limitation of the previous one:

1. **`StreamingContractV1`** — lock ETH and let a recipient withdraw it as it vests linearly.
2. **`StreamingContractV2`** — stream ERC20 tokens (like stablecoins), and let the sender cancel.
3. **`StreamingContractV3`** — make the stream claim a transferable ERC721.
4. **`MicroCDP`** — deposit ETH, borrow a stablecoin (`UUSD`) against it, repay, withdraw collateral, and liquidate unsafe positions.

Start each exercise from its API in `src/interfaces/`, then compare against the corresponding contract in `src/`. The tests interact with deployments through these same interfaces.

<p align="right">(<a href="#table-of-contents">back to top</a>) ⬆️</p>

# 1. Streaming ETH (V1)

**Question:** how can Ethereum hold money and release it over time, without anyone having to trust the payer?

Alice wants to pay Bob 1 ETH over 10 days. Instead of Alice promising to pay, she locks ETH in a contract. Bob can withdraw only what has vested so far — after 3 days, that's 0.3 ETH.

Core concepts: `msg.value`, contract custody, `block.timestamp`, checks-effects-interactions, events, and testing time with Foundry.

**Main point:** smart contracts aren't just scripts — they're shared financial agreements with custody.

See `src/interfaces/IStreamingContractV1.sol` and `src/StreamingContractV1.sol`.

<p align="right">(<a href="#table-of-contents">back to top</a>) ⬆️</p>

# 2. ERC20 Streams (V2)

**Question:** ETH is useful, but what if we want to stream dollars or project tokens instead?

Salary in ETH is volatile — most people want salary in dollars, so we stream a stablecoin like USDC instead. ERC20 introduces a different transfer model than ETH:

```text
ETH is sent with msg.value.
ERC20 tokens are pulled with transferFrom, after the sender approves the contract.
```

V2 also adds **cancellation**: the sender freezes the recipient's vested claim and gets the unvested remainder refunded.

**Main point:** Ethereum isn't only about ETH. ETH is the native gas/currency asset, but ERC20s are how most application-level assets (including stablecoins) are represented.

See `src/interfaces/IStreamingContractV2.sol` and `src/StreamingContractV2.sol`.

<p align="right">(<a href="#table-of-contents">back to top</a>) ⬆️</p>

# 3. NFT-Owned Streams (V3)

**Question:** if a stream is valuable, can I transfer it, sell it, or see it in my wallet?

Bob has a stream that will pay 1,000 USDC over the next month. That right has value. In V3, `ownerOf(streamId)` — not a fixed `recipient` field — controls withdrawal rights. If Bob sells or transfers the NFT to Carol, Carol now owns the right to withdraw the remaining stream.

**Main point:** NFTs aren't only images. They can represent ownership over any unique financial position in a contract — the NFT is the key, not the money itself.

See `src/interfaces/IStreamingContractV3.sol` and `src/StreamingContractV3.sol`.

<p align="right">(<a href="#table-of-contents">back to top</a>) ⬆️</p>

# 4. Stablecoins

We've now seen how to distribute Ethereum's native currency and ERC20s like USDC/USDT. But what if we want to create our own dollar?

**Centralized stablecoins** (USDC, USDT) are the simplest answer: you have a bank account, people deposit real dollars into it, and you mint the same amount onchain. This is a *fiat-backed stablecoin*. It's simple and liquid, but it involves banks, custodians, and central authorities — which cuts against decentralization. Freezes and compliance controls are part of the deal.

So — what if we don't want a bank in the loop? The usual approach is a **synthetic dollar**: there are no real dollars backing the system. Instead, the currency *acts* like a dollar, backed by digital assets (like ETH) and a set of programmatic rules. Ethena, Liquity, Maker/DAI, and USDAi are all different takes on this idea — we're going to build the vanilla version ourselves.

Think about how a bank issues credit: you own some assets, the bank assesses them, and gives you money based on your credit. We want to recreate something similar onchain, except the "bank" is a smart contract executing deterministic, programmatic rules instead of a loan officer's judgment.

The idea: deposit ETH into the protocol, and the protocol gives you a stablecoin based on that ETH's value. How much? A real bank estimates your assets and lends against them conservatively. We need to do the same, except crypto assets are far more volatile than a house or a paycheck, so the protocol needs *more* value locked than it lends out, in case the price drops. The crypto we lock as security is called **collateral** — like a mortgage. The stablecoin the protocol creates is credit: the protocol gives you tokens, but you owe the system a matching **debt**.

This design — mint a stablecoin against locked collateral, track it as debt — is called a **Collateralized Debt Position (CDP)**.

One missing piece: how does a contract know the price of ETH? It needs an **oracle** — that turns out to be its own hard problem.

<p align="right">(<a href="#table-of-contents">back to top</a>) ⬆️</p>

# 5. MicroCDP: A Toy Collateralized Debt Position

Worked example:

```text
ETH price: $2,000
Alice deposits 1 ETH
Minimum collateral ratio: 150%
Max mint = 2000 / 1.5 = 1,333 UUSD
```

If Alice mints 1,000 UUSD, her collateral ratio is `2000 / 1000 = 200%` — safe.

If ETH falls to $1,400, her ratio becomes `1400 / 1000 = 140%` — now unsafe. Any liquidator can repay Alice's 1,000 UUSD debt and receive ETH collateral worth that debt plus a 10% bonus. Whatever collateral is left over stays withdrawable by Alice.

The position lifecycle is intentionally small:

- deposit collateral, with or without borrowing in the same transaction
- borrow more while the position stays healthy
- repay some debt
- withdraw excess collateral
- close the position (repay all debt, withdraw all collateral, atomically)
- liquidate an unhealthy position

Concepts: collateral, debt, oracle price, collateral ratio, liquidation threshold, liquidation incentive, bad debt.

**Main point:** a CDP stablecoin is lending in reverse. Instead of borrowing an existing stablecoin from lenders, the protocol *mints* debt against collateral.

`MicroCDP` (in `src/MicroStable.sol`) is intentionally small — it omits interest, governance, debt ceilings, oracle fallbacks, partial liquidation, and bad-debt handling.

See `src/interfaces/IMicroCDP.sol`, `src/interfaces/IUnstableUSD.sol`, and `src/MicroStable.sol` / `src/UnstableUSD.sol`.

<p align="right">(<a href="#table-of-contents">back to top</a>) ⬆️</p>

# Repo Structure

```text
src/            contracts (StreamingV1/V2/V3, MicroCDP, UnstableUSD)
src/interfaces/ the API each exercise starts from
test/           one test file per contract
script/         deployment scripts
lib/            dependencies (forge-std, OpenZeppelin)
```

<p align="right">(<a href="#table-of-contents">back to top</a>) ⬆️</p>

# Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

Docs: https://book.getfoundry.sh/

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

<p align="right">(<a href="#table-of-contents">back to top</a>) ⬆️</p>
