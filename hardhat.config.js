require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");

require('dotenv').config()


module.exports = {
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            gasPrice: 225000000000,
            chainId: 43114,
            forking: {
                url: "https://api.avax.network/ext/bc/C/rpc",
                enabled: true,
                accounts: [
                    process.env.privateKey
                ]
            }
        },
        mainnet: {
            url: "https://api.avax.network/ext/bc/C/rpc",
            gasPrice: 225000000000,
            chainId: 43114,
            accounts: [
                process.env.privateKey
            ]
        },
        fuji: {
            url: "https://api.avax-test.network/ext/bc/C/rpc",
            gasPrice: 225000000000,
            chainId: 43113,
            accounts: [
                process.env.privateKey
            ]
        }
    },
    solidity: {
        version: "0.8.4",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200
            }
        }
    },
    paths: {
        sources: "contracts", 
        tests: "./tests",
        cache: "./cache",
        artifacts: "./artifacts"
    },
    etherscan: {
        apiKey: {
            avalanche: process.env.snowTraceAPI,
            avalancheFujiTestnet: process.env.snowTraceFujiAPI
        }
    }
};
