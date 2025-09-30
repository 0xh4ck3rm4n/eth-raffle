# Ethereum Raffle Lottery (Chainlink VRF v2.5)

A decentralized raffle lottery built on Ethereum, powered by **Chainlink VRF v2.5** for provably fair randomness.  
Participants enter by paying an ETH entrance fee, and a random winner is automatically selected at regular intervals.

---

## Features

- **Provably fair randomness** via Chainlink VRF v2.5
- **Automated upkeep** (winner selection triggered after time interval)
- **Fully tested with Foundry** (unit + integration tests)
- **Modular deployment scripts** for local & Sepolia networks
- **Configurable entrance fee, interval, and gas limits**

---

## Quickstart

### 1️⃣ Install dependencies
```
make install
```

### 2️⃣ Build contracts
```
make build
```

### 3️⃣ Run tests
```
make test
```

### 4️⃣ Deploy locally (Anvil)
```
forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url http://localhost:8545 --broadcast
```

### 5️⃣ Deploy to Sepolia

Make sure you have set your `.env` file with:

SEPOLIA_RPC_URL=<your_rpc_url>
ETHERSCAN_API_KEY=<your_api_key>

Then run:
```
make deploy-sepolia
```

---

## Testing

This repo uses [Foundry](https://book.getfoundry.sh/) for testing.

**Unit test examples:**

- Check initial raffle state is **OPEN**
- Verify entrance fee requirement
- Ensure players are added correctly
- Validate upkeep conditions
- Simulate random winner selection with Chainlink VRF mock

**Integration test examples:**

- Create and fund subscriptions
- Add consumer contracts to VRF
- Validate network configs for Sepolia & local Anvil

Run all tests:
forge test -vvvv

---

## Configuration

Raffle parameters are configured in **HelperConfig.s.sol**:

- `entranceFee`: ETH required to join
- `interval`: time between raffles (seconds)
- `vrfCoordinator`: Chainlink VRF coordinator address
- `keyLane`: gas lane key hash
- `subscriptionId`: Chainlink subscription ID
- `callbackGasLimit`: gas limit for VRF callback

---

## Contracts Overview

### `Raffle.sol`

- `enterRaffle()` → join the lottery
- `checkUpkeep()` → determines if upkeep is needed
- `performUpkeep()` → requests random winner
- `fulfillRandomWords()` → picks and pays the winner

### `DeployRaffle.s.sol`

Automates:

1. Creating subscription (if none exists)
2. Funding subscription
3. Deploying raffle contract
4. Adding raffle as a VRF consumer

### `Interactions.s.sol`

Utility scripts for:

- Creating subscriptions
- Funding subscriptions
- Adding consumer contracts

---

## Security Considerations

- Uses Chainlink VRF v2.5 for verifiable randomness
- Funds are transferred using `.call{value: ...}()` with revert checks
- Tests include edge cases for upkeep and raffle states

---

## Tech Stack

- [Solidity ^0.8.19](https://soliditylang.org/)
- [Foundry](https://book.getfoundry.sh/) (Forge, Anvil, Cast)
- [Chainlink VRF v2.5](https://docs.chain.link/vrf/v2-5)
- [Makefile](https://www.gnu.org/software/make/) for scripts

---

## Author

**Gaurav Poudel**
📧 Reach out for feedback, improvements, or collaboration!
