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

To run the following security tools you need to first create a python environment:

1. Install [Python](https://www.python.org/downloads/).
2. In this directory, create a python environment: `python3 -m venv env`.
3. Start the environment: `source env/bin/activate`.
4. Install all requirements: `pip install -r requirements.txt`.

You are ready to go!

We used [Slither](https://github.com/crytic/slither) as a static analyzer to
search for vulnerabilities in the contract. If you want to run it on your local
machine use the command `slither .`.
