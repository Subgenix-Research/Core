require("@nomiclabs/hardhat-waffle");
require('dotenv').config()

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

module.exports = {
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            gasPrice: 225000000000,
            chainId: 43113,
            forking: {
                url: "https://api.avax-test.network/ext/bc/C/rpc",
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
            accounts: []
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
        version: "0.8.0",
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
    }
};
