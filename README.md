# kUSD Stablecoin

A fiat-backed stablecoin smart contract modeled after [USDC (Centre FiatToken)](https://github.com/circlefin/stablecoin-evm). Built with [Foundry](https://book.getfoundry.sh/) and [OpenZeppelin Contracts v5](https://docs.openzeppelin.com/contracts/5.x/).

## Features

| Feature | Description |
|---|---|
| **ERC-20** | Standard token interface with **6 decimals** (same as USDC) |
| **EIP-2612 Permit** | Gasless approvals via off-chain signatures |
| **Configurable Minters** | Master minter can add/remove minters with per-minter allowances |
| **Burning** | Minters can burn tokens from their own balance |
| **Pausable** | Pauser role can freeze all transfers, mints, burns, and approvals |
| **Blacklisting** | Blacklister role can block addresses from sending, receiving, or approving |
| **Two-Step Ownership** | Safe ownership transfer requiring explicit acceptance |
| **ERC-20 Rescue** | Owner can recover tokens accidentally sent to the contract |

## Roles

| Role | Permissions |
|---|---|
| **Owner** | Update pauser, blacklister, master minter; transfer ownership; rescue tokens |
| **Pauser** | Pause / unpause all token operations |
| **Blacklister** | Blacklist / unblacklist addresses |
| **Master Minter** | Configure minters and their allowances; remove minters |
| **Minter** | Mint (up to allowance) and burn tokens |

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Install

```bash
git clone <repo-url> && cd kusd-token
forge install
```

### Build

```bash
forge build
```

### Test

```bash
forge test -vvv
```

### Deploy

Set the following environment variables, then run the deploy script:

```bash
export OWNER=0x...
export PAUSER=0x...
export BLACKLISTER=0x...
export MASTER_MINTER=0x...

forge script script/Deploy.s.sol:DeploykUSD \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify \
    -vvvv
```

## Project Structure

```
src/
  kUSD.sol          – Main stablecoin contract
script/
  Deploy.s.sol      – Deployment script
test/
  kUSD.t.sol        – Comprehensive test suite (60 tests incl. fuzz)
```

## License

MIT
