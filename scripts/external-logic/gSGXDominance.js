const { ethers } = require("ethers");
require("colors");
require('dotenv').config()
const SubgenixJson = require("../out/Subgenix.sol/Subgenix.json");
const GovernanceSGXJson = require("../out/GovernanceSGX.sol/GovernanceSGX.json");


async function main() {

    const provider = new ethers.providers.JsonRpcProvider("https://api.avax.network/ext/bc/C/rpc");

    const owner = new ethers.Wallet(process.env.privateKey, provider);

    const Subgenix = await ethers.ContractFactory(SubgenixJson.abi, SubgenixJson.bytecode, owner);
    const sgx = Subgenix.attach("0xFC4487f268a5f484FE4A8478c674cc3145621716");

    const GovernanceSGX = await ethers.ContractFactory(GovernanceSGXJson.abi, GovernanceSGXJson.bytecode, owner);
    const gSGX = GovernanceSGX.attach("0xD7382d3a4557cf1A00635da374534bF5a8898B1c");

    const Percent = (numerator, supply) => {
        if (numerator.lt(ethers.utils.parseUnits("1", 16))) {
            return 0;
        }
        const formula = (((numerator).mul(10000)).div(supply)).toNumber();

        return (formula * 100) / 10000;
    }

    const sgx_on_gSGX = await sgx.balanceOf(gSGX.address);

    const sgx_supply = await sgx.totalSupply();

    var gSGXDominance = Percent(sgx_on_gSGX, sgx_supply);

    console.log(gSGXDominance);

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })
