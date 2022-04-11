const { ethers } = require("ethers");
require('dotenv').config()

async function main() {

    const provider = new ethers.providers.JsonRpcProvider("https://api.avax-test.network/ext/bc/C/rpc");

    const owner = new ethers.Wallet(process.env.privateKey, provider);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })
