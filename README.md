# Subgenix

[![Project Status: WIP – Initial development is in progress, but there has not yet been a stable, usable release suitable for the public.](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)

Subgenix smart contracts.


## Development:

tests: `make test`   
compile: `make build`  
clean: `make clean`   

**Dependencies**:
- [Foundry](https://github.com/gakonst/foundry#installation) As the development framework.    

**External libraries**:
- [Solmate](https://github.com/Rari-Capital/solmate): `forge install Rari-Capital/solmate`   
- [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts): `forge install openzeppelin/openzeppelin-contracts` 


## Security:

[Slither](https://github.com/crytic/slither) was used as a static analyzer to
search for vulnerabilities in the contract.


run: `slither --hardhat-ignore-compile .`   
