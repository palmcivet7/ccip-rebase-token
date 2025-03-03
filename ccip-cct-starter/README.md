# CCIP Self-Serve Tokens

This repository has been modified and simplified from the [Chainlink examples repository](https://github.com/smartcontractkit/smart-contract-examples).
This repository contains a collection of Foundry scripts designed to simplify interactions with CCIP 1.5 contracts.

Find a list of available tutorials on the Chainlink documentation: [Cross-Chain Token (CCT) Tutorials](http://docs.chain.link/ccip/tutorials/cross-chain-tokens#overview).

---

## Tutorial

### Config File Overview

The `config.json` file within the `script` directory defines the key parameters used by all scripts. You can customize the token name, symbol, maximum supply, and cross-chain settings, among other fields.

Example `config.json` file:

```json
{
  "BnMToken": {
    "name": "BnM KH",
    "symbol": "BnMkh",
    "decimals": 18,
    "maxSupply": 0,
    "withGetCCIPAdmin": false,
    "ccipAdminAddress": "0x0000000000000000000000000000000000000000"
  },
  "tokenAmountToMint": 1000000000000000000000,
  "tokenAmountToTransfer": 10000,
  "feeType": "link",
  "remoteChains": {
    "11155111": 421614,
    "421614": 11155111
  }
}
```

The `config.json` file contains the following parameters:

| Field                   | Description                                                                                                                                                                                                                                                                                                                                              |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`                  | The name of the token you are going to deploy. Replace `"BnM KH"` with your desired token name.                                                                                                                                                                                                                                                          |
| `symbol`                | The symbol of the token. Replace `"BnMkh"` with your desired token symbol.                                                                                                                                                                                                                                                                               |
| `decimals`              | The number of decimals for the token (usually `18` for standard ERC tokens).                                                                                                                                                                                                                                                                             |
| `maxSupply`             | The maximum supply of tokens (in the smallest unit, according to `decimals`). When maxSupply is 0, the supply is unlimited.                                                                                                                                                                                                                              |
| `withGetCCIPAdmin`      | A boolean to determine whether the token contract has a `getCCIPAdmin()` function. If set to `true`, a CCIP admin is required. When `false`, token admin registration will use the token `owner()` function.                                                                                                                                             |
| `ccipAdminAddress`      | The address of the CCIP admin, only applicable if `withgetccipadmin` is set to `true`.                                                                                                                                                                                                                                                                   |
| ---                     | -----                                                                                                                                                                                                                                                                                                                                                    |
| `tokenAmountToMint`     | The amount of tokens to mint when running the minting script. This value should be specified in wei (1 token with 18 decimals = `1000000000000000000` wei).                                                                                                                                                                                              |
| ---                     | -----                                                                                                                                                                                                                                                                                                                                                    |
| `tokenAmountToTransfer` | The amount of tokens to transfer when running the token transfer script. Specify the number of tokens you want to transfer across chains.                                                                                                                                                                                                                |
| ---                     | -----                                                                                                                                                                                                                                                                                                                                                    |
| `feeType`               | Defines the fee type for transferring tokens across chains. Options are `"link"` (for paying fees in LINK tokens) or `"native"` (for paying fees in native tokens).                                                                                                                                                                                      |
| ---                     | -----                                                                                                                                                                                                                                                                                                                                                    |
| `remoteChains`          | Defines the relationship between source and remote (destination) chain IDs. The keys in this object are the current chain IDs, and the values represent the corresponding remote chain. Example: `"43113": 421614` means that if you're running a script on Avalanche Fuji (chain ID `43113`), the remote chain is Arbitrum Sepolia (chain ID `421614`). |

### Environment Variables

Example `.env` file to interact with the Fuji testnet and Arbitrum Sepolia testnet:

```bash
SEPOLIA_RPC_URL=<your_rpc_url>
ARBITRUM_SEPOLIA_RPC_URL=<your_rpc_url>
ETHERSCAN_API_KEY=<your_etherscan_api_key>
ARBISCAN_API_KEY=<your_arbiscan_api_key>
```

Variables to configure:

- `SEPOLIA_RPC_URL`: The RPC URL for the Sepolia testnet. You can get this from the [Alchemy](https://www.alchemy.com/) or [Infura](https://infura.io/) website.
- `ARBITRUM_SEPOLIA_RPC_URL`: The RPC URL for the Arbitrum Sepolia testnet. You can get this from the [Alchemy](https://www.alchemy.com/) or [Infura](https://infura.io/) website.
- `ETHERSCAN_API_KEY`: An API key from Etherscan to verify your contracts. You can obtain one from [Etherscan](https://docs.etherscan.io/getting-started/viewing-api-usage-statistics).
- `ARBISCAN_API_KEY`: An API key from Arbiscan to verify your contracts on Arbitrum. See [this guide](https://docs.arbiscan.io/getting-started/viewing-api-usage-statistics) to get one from Arbiscan.

**Load the environment variables** into the terminal session where you will run the commands:

```bash
source .env
```

### 1. Deploy the token contracts

On Sepolia:

```bash
forge script script/DeployToken.s.sol --rpc-url $SEPOLIA_RPC_URL --account <your-keystore-name> --broadcast --sender <your-address>
```

On Arbirtrum Sepolia:

```bash
forge script script/DeployToken.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --account <your-keystore-name> --broadcast --sender <your-address>
```

### 2. Deploy the token pools

On Sepolia:

```bash
forge script script/DeployBurnMintTokenPool.s.sol --rpc-url $SEPOLIA_RPC_URL --account <your-keystore-name> --broadcast --sender <your-address>
```

On Arbitrum Spolia:

```bash
forge script script/DeployBurnMintTokenPool.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --account <your-keystore-name> --broadcast --sender <your-address>
```

### 3. Claim the CCIP admin role

On Sepolia:

```bash
forge script script/ClaimAdmin.s.sol --rpc-url $SEPOLIA_RPC_URL --account <your-keystore-name> --broadcast --sender <your-address>
```

On Arbitrum Spolia:

```bash
forge script script/ClaimAdmin.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --account <your-keystore-name> --broadcast --sender <your-address>
```

### 4. Accept the CCIP admin role

On Sepolia:

```bash
forge script script/AcceptAdminRole.s.sol --rpc-url $SEPOLIA_RPC_URL --account <your-keystore-name> --broadcast --sender <your-address>
```

On Arbitrum Spolia:

```bash
forge script script/AcceptAdminRole.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --account <your-keystore-name> --broadcast --sender <your-address>
```

### 5. Set the pools associated with the tokens

On Sepolia:

```bash
forge script script/SetPool.s.sol --rpc-url $SEPOLIA_RPC_URL --account <your-keystore-name> --broadcast --sender <your-address>
```

On Arbitrum Spolia:

```bash
forge script script/SetPool.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --account <your-keystore-name> --broadcast --sender <your-address>
```

### 6. Add the remote chain to the token pool

On Sepolia:

```bash
forge script script/ApplyChainUpdates.s.sol --rpc-url $SEPOLIA_RPC_URL --account <your-keystore-name> --broadcast --sender <your-address>
```

On Aribtrum Sepolia:

```bash
forge script script/ApplyChainUpdates.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --account <your-keystore-name> --broadcast --sender <your-address>
```

### 7. Mint tokens

```bash
forge script script/MintTokens.s.sol --rpc-url $SEPOLIA_RPC_URL --account <your-keystore-name> --broadcast --sender <your-address>
```

### 8. Transfer tokens cross-chain from Sepolia to Arbitrum Sepolia

```bash
forge script script/TransferTokens.s.sol --rpc-url $SEPOLIA_RPC_URL --account <your-keystore-name> --broadcast <your-address>
```
