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
  <summary><a href="#6-defi-context">6. DeFi Context</a></summary>
  <ol>
    <li><a href="#the-oracle-problem-and-prediction-markets">The Oracle Problem (And Prediction Markets)</a></li>
    <li><a href="#why-people-actually-use-stablecoins">Why People Actually Use Stablecoins</a></li>
    <li><a href="#leverage">Leverage</a></li>
    <li><a href="#liquid-staking-and-other-collateral-types">Liquid Staking And Other Collateral Types</a></li>
    <li><a href="#pegging-to-something-other-than-usd">Pegging To Something Other Than USD</a></li>
    <li><a href="#ethenausdai-synthetic-dollar-designs">Ethena/USDAi: Synthetic Dollar Designs</a></li>
    <li><a href="#spark">Spark</a></li>
    <li><a href="#tokenized-assets--rwas">Tokenized Assets / RWAs</a></li>
    <li><a href="#crypto-cards">Crypto Cards</a></li>
  </ol>
</details>

<details>
  <summary><a href="#7-beyond-the-toy-cdp-what-production-stablecoins-solve">7. Beyond The Toy CDP: What Production Stablecoins Solve</a></summary>
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

One missing piece: how does a contract know the price of ETH? It needs an **oracle** — more on why that's its own hard problem in [Section 6](#the-oracle-problem-and-prediction-markets).

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

`MicroCDP` (in `src/MicroStable.sol`) is intentionally small — it omits interest, governance, debt ceilings, oracle fallbacks, partial liquidation, and bad-debt handling. See [Section 7](#7-beyond-the-toy-cdp-what-production-stablecoins-solve) for what that means in practice.

See `src/interfaces/IMicroCDP.sol`, `src/interfaces/IUnstableUSD.sol`, and `src/MicroStable.sol` / `src/UnstableUSD.sol`.

<p align="right">(<a href="#table-of-contents">back to top</a>) ⬆️</p>

# 6. DeFi Context

`MicroCDP` is a single, narrow example. Here's how it connects to the wider DeFi landscape.

## The Oracle Problem (And Prediction Markets)

Every price check in `MicroCDP` trusts one oracle (`collateralPrice()`), with a staleness check and nothing else — no fallback feed, no circuit breaker, no manipulation resistance. Real protocols worry about oracle delay, flash crashes, and manipulated single sources, and typically combine multiple feeds (e.g. Chainlink) with sanity checks.

This is the same underlying problem prediction markets face: how do you get real-world truth (a price, an election result, a game outcome) onto a deterministic chain in a way people can trust? Oracles and prediction market resolution mechanisms (like Polymarket's) are solving the same class of problem from different angles.

## Why People Actually Use Stablecoins

Not just "because crypto is volatile." Concretely: pricing salaries and invoices in a stable unit, a stable base for trading and collateral, a place to park value between trades, and settlement/payments that don't need a bank.

## Leverage

A CDP isn't just for spending — it's a leverage primitive:

```text
1. Deposit ETH.
2. Borrow stablecoin.
3. Buy more ETH with it.
4. Deposit that ETH too.
5. Borrow more.
```

Each loop increases ETH exposure, but also compresses the collateral ratio — a smaller price drop can now liquidate the position. Leverage amplifies both directions.

## Liquid Staking And Other Collateral Types

`MicroCDP` only accepts ETH as collateral. Production protocols accept many collateral types — wstETH/stETH (staked ETH that keeps earning yield while locked as collateral), cbBTC, sUSDe, and even other stablecoins — each with its own liquidity, oracle, and smart-contract risk profile.

## Pegging To Something Other Than USD

`UUSD` targets $1, but the underlying mechanism — mint against collateral, let arbitrage pull the price back to target — doesn't require the target to be USD. The same idea can peg to another token, a basket, or a commodity, maintained through DEX/exchange arbitrage rather than a dollar-specific mechanism.

## Ethena/USDAi: Synthetic Dollar Designs

`MicroCDP` is a simple overcollateralized CDP. Ethena's USDe and similar designs (USDAi) take a different synthetic-dollar approach: delta-neutral hedged positions (long spot collateral, short a matching perp) instead of pure overcollateralization. Same goal — a dollar without a bank — different risk model.

## Spark

Spark is Sky's (Maker's) own lending arm, built on top of the DAI/USDS stablecoin and its liquidity. It's a concrete example of a CDP stablecoin issuer expanding into lending markets rather than staying a single-purpose mint.

## Tokenized Assets / RWAs

BlackRock's BUIDL, Ondo's tokenized treasuries, and tokenized stocks (e.g. Robinhood's EU stock tokens, xStocks) bring traditional financial assets onchain so they can move and compose with DeFi the same way a stablecoin does.

## Crypto Cards

Stablecoins and other onchain assets still need to reach everyday spending. Crypto debit cards (Coinbase Card and similar) are the "last mile" — spend from an onchain balance as if it were a normal bank card.

<p align="right">(<a href="#table-of-contents">back to top</a>) ⬆️</p>

# 7. Beyond The Toy CDP: What Production Stablecoins Solve

It's tempting to describe `MicroCDP`'s gaps as "missing features." It's more accurate to say a production stablecoin protocol has to solve **ten mostly-independent economic problems**, each with its own real-world answers:

### 1. Solvency

**Is there enough collateral to back every outstanding stablecoin?** `MicroCDP` only has overcollateralization (150%) and liquidations (10% bonus) — no answer for oracle delay, flash crashes, or a liquidator simply refusing to touch an underwater position. Real protocols add a Stability Pool (Liquity), collateral auctions (Maker), debt redistribution (Liquity), a protocol surplus buffer, and debt auctions/recapitalization.

### 2. Peg Stability

**Why should 1 stablecoin = $1?** `MicroCDP` only relies on borrower arbitrage: below peg, borrowers buy UUSD to repay and burn it; above peg, users mint and sell it. That's exactly how old Maker worked. Modern protocols add stronger mechanisms: a Peg Stability Module (Maker, Sky/Spark), redemptions (Liquity), stability fees, and a savings rate (Sky).

### 3. Liquidation Liquidity

**Even when a position becomes unhealthy, who actually shows up with stablecoins to liquidate it?** `MicroCDP` just assumes a liquidator magically owns UUSD. Without deep liquidity, an unhealthy position can sit unliquidated indefinitely. Real solutions: a Stability Pool, keeper incentives, flash-loan liquidations, deep DEX liquidity, and dedicated auction keepers.

### 4. Stablecoin Demand

**Why hold it instead of selling it immediately?** This is probably the single biggest thing a toy CDP glosses over — every borrower mints because they want ETH/USDC/BTC, not UUSD, so every borrow creates immediate selling pressure. Demand has to come from somewhere: debt repayment, liquidations, savings yield, LP rewards, lending markets, trading pairs, payments, or use as collateral elsewhere.

### 5. Stablecoin Supply

**Who's allowed to create it?** `MicroCDP` only lets ETH borrowers mint, which caps growth. Real protocols expand supply through a PSM (mint 1:1 against another stablecoin), institutional credit lines (Sky/Spark), and additional collateral branches (Liquity).

### 6. Capital Efficiency

Safety and borrowing power trade off directly: if `MicroCDP` requires 150% collateral and a competitor only requires 110%, borrowers go where their capital works harder. Protocols are constantly tuning this dial — higher ratio is safer but less efficient; lower ratio is more capital-efficient but riskier.

### 7. Risk Management

`MicroCDP`'s risk model is "ETH, one Chainlink feed, done." Real protocols have to decide which collateral types to accept at all — ETH, wstETH, cbBTC, sUSDe, USDC, RWAs — and every addition brings its own liquidity risk, oracle risk, smart-contract risk, and (for wrapped/bridged assets) bridge risk.

### 8. Monetary Policy

`MicroCDP` has a 0% borrow rate, forever — which sounds generous but is actually dangerous, since borrowers never have any incentive to close a position. Real protocols use borrow interest, a savings rate, redemption fees, and stability fees to actively influence supply and demand.

### 9. Governance

Who's allowed to change the collateral ratio, the liquidation bonus, the oracle, the borrow rate, the debt ceiling, or which collateral is accepted? `MicroCDP` hardcodes all of it as immutable constants. In production, someone has to hold these levers — Maker's governance famously grew into something close to a central bank for its own stablecoin.

### 10. Protocol Revenue And Scalability

Where does the money come from to fund all of the above — the Stability Pool, the savings rate, protocol reserves? Borrow interest, liquidation penalties, PSM fees, and income from lending arms like Spark. And once the model works for ETH, the same scalability question repeats for every new collateral type: WBTC, LSTs, USDC, tokenized treasuries — each needs to be onboarded safely, not just added to a list.

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
