# Subgenix

Core contracts for the Subgneix Network, an open protocol with emphasis on Subnet investments.

## Contracts

```ml
GovernanceSGX — "Governance token of the Subgenix Network."
LockupHell — "LockupHell for user rewards."
Subgenix — "Oficial ERC20 + EIP-2612 implementation of the Subgenix Network token."
VaultFactory — "The vaultFactory where users vaults are created & managed."
```

## Development:

**Dependencies**:
- [Foundry](https://github.com/gakonst/foundry#installation) - As the Development framework.   
- [Hardhat](https://github.com/NomicFoundation/hardhat) - As the deployment tool.    
- [Solmate](https://github.com/Rari-Capital/solmate) - Library for gas optimized smart contract development.    
- [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts) - Library for secure smart contract development.   
      
To compile all our contracts with foundry & hardhat use the following command: `make build`  
To run all our tests use the following command: `make test`   

## Security:

To run the following security tools you need to first create a python environment:

1. Install [Python](https://www.python.org/downloads/).
2. clone and cd into this repo: `git clone https://github.com/Subgenix-Research/Core.git && cd Core/`
3. In this directory, create a python environment: `python3 -m venv env`.
4. Start the environment: `source env/bin/activate`.
5. Install all requirements: `pip install -r requirements.txt`.

You are ready to go!

We used [Slither](https://github.com/crytic/slither) as a static analyzer to
search for vulnerabilities in the contract. If you want to run it on your local
machine use the command `slither .`.


## Deployment: