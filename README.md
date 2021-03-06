# Subgenix

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

Core contracts for the Subgneix Network, an open protocol with emphasis on Subnet investments.

## Contracts

```ml
GovernanceSGX — "The governance token of the Subgenix Network."
LockupHell    — "LockupHell for user rewards."
Subgenix      — "Oficial ERC20 + EIP-2612 implementation of the Subgenix Network token."
VaultFactory  — "The vaultFactory where users vaults are created & managed."
```

## Development:

**Dependencies**:
- [Foundry](https://github.com/gakonst/foundry#installation) - As the Development framework.   
- [Solmate](https://github.com/Rari-Capital/solmate) - Library for gas optimized smart contract development.    
- [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts) - Library for secure smart contract development.    
      
To install all dependencies follow the next steps (you need to have foundry and hardhat installed):    
1. Clone and `cd` into this repo: `git clone https://github.com/Subgenix-Research/Core.git && cd Core/`   
2. Install all dependencies used with hardhat: `npm install`

To compile all our contracts with foundry use the following command: `make build`  
To run all our tests use the following command: `forge test`   

[Solhint](https://github.com/protofire/solhint) was used as a tool for Security 
and Style Guide validations. You can use it on your clone repo using the command 
`solhint 'src/*.sol'`.   
    
To run the linter: `npm run lint`.   


## Deployment:

Make sure that you have the private key from the deployer address in a `.env` file.
Follow the example from the [.env.example](.env.example) file.

To simulate deployment mocking the mainnet:
`npx hardhat run scripts/deployTestnet.js`.

To deploy the contracts in the testnet you can run the command:   
`npx hardhat run scripts/deployTestnet.js --network testnet`.

To deploy the contracts in the mainnet you can run the command:  
`npx hardhat run scripts/deployMainnet.js --network mainnet`.
