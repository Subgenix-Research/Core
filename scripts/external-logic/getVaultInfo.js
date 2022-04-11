const { ethers } = require("ethers");
require("colors");
require('dotenv').config()
const VaultFactoryJson = require("../out/VaultFactory.sol/VaultFactory.json");

async function main() {

    const provider = new ethers.providers.JsonRpcProvider("https://api.avax.network/ext/bc/C/rpc");

    const owner = new ethers.Wallet(process.env.privateKey, provider);

    const VaultFactory = await ethers.ContractFactory(VaultFactoryJson.abi, VaultFactoryJson.bytcode, owner);
    const vault = VaultFactory.attach("0x19EBe400929A04Fa3C978C9f5386862cB28142E5");

    // Get All info.
    const [
        exists, 
        lastClaimTime, 
        uncollectedRewards,
        balance,
        interestLength,
        league
    ] = await vault.usersVault(owner.address);

    // Example, Get User Balance.
    const [ , , , balance, , ] = await vault.usersVault(owner.address);


    // Example, Get User League
    const [ , , , , , league] = await vault.usersVault(owner.address);


    // Example, Check if vault exists.
    const [exists, , , , , ] = await vault.usersVault(owner.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })
