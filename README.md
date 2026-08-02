# Petnica Ethereum Workshop 2026

The contracts build one concept at a time:

1. `StreamingContractV1`: linearly vest and withdraw ETH.
2. `StreamingContractV2`: add ERC20 streams and cancellation.
3. `StreamingContractV3`: make the stream claim a transferable ERC721.
4. `MicroCDP`: deposit ETH, borrow Unstable USD (`UUSD`), repay, withdraw collateral, and liquidate unsafe positions.

Start each exercise from its API in `src/interfaces/`, then compare the students' implementation with the corresponding contract in `src/`. The tests also interact with deployments through these interfaces.

The contracts are intentionally small teaching examples. In particular, `MicroCDP` omits interest, governance, debt ceilings, oracle fallbacks, partial liquidation, and bad-debt handling.

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

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

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
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
