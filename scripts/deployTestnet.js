const { ethers } = require("ethers");
require("colors");
require('dotenv').config()
const SubgenixJson = require("../artifacts/contracts/Subgenix.sol/Subgenix.json");
const GovernanceSGXJson = require("../artifacts/contracts/GovernanceSGX.sol/GovernanceSGX.json");
const LockupHellJson = require("../artifacts/contracts/LockupHell.sol/LockupHell.json");
const VaultFactoryJson = require("../artifacts/contracts/VaultFactory.sol/VaultFactory.json");

async function main() {

    const provider = new ethers.providers.JsonRpcProvider("https://api.avax-test.network/ext/bc/C/rpc");

    const owner = new ethers.Wallet(process.env.privateKey, provider);

    const treasury = "0x0000000000000000000000000000000000000001"; 
    const research = "0x0000000000000000000000000000000000000001";
    const wavax = "0xfee34F9C22Bb731B187b6f09D21E4Fb07b2612f7"; // Testnet

    console.log("Owner:", owner.address);

    console.log("Start contracts deployment...");

    const Subgenix = new ethers.ContractFactory(SubgenixJson.abi, SubgenixJson.bytecode, owner);
    const SGX = await Subgenix.deploy(
        "Subgenix Token",
        "SGX",
        18
    );
    await SGX.deployed();

    console.log("✓".green + " SGX deployed to:", SGX.address);

    const LockupHell = new ethers.ContractFactory(LockupHellJson.abi, LockupHellJson.bytecode, owner);
    const lockup = await LockupHell.deploy(SGX.address);
    await lockup.deployed();
    
    console.log("✓".green + " lockupHell deployed to:", lockup.address);


    const GovernanceSGX = new ethers.ContractFactory(GovernanceSGXJson.abi, GovernanceSGXJson.bytecode, owner);
    const gSGX = await GovernanceSGX.deploy(SGX.address);
    await gSGX.deployed();
    
    console.log("✓".green + " GovernanceSGX deployed to:", gSGX.address);
    
    
    const VaultFactory = new ethers.ContractFactory(VaultFactoryJson.abi, VaultFactoryJson.bytecode, owner);
    const vault = await VaultFactory.deploy(
        wavax,
        SGX.address,
        gSGX.address,
        treasury,
        research,
        lockup.address
    );
    await vault.deployed();
    
    console.log("✓".green + " VaultFactory deployed to:", vault.address);


    // SETTING UP CONTRACTS

    console.log("All contracts deployed! Starting setup...");

    console.log("   set percentages..");
    await (await lockup.setLongPercentage(ethers.utils.parseUnits("18", 16))).wait();  // 18e16 = 18%
    await (await lockup.setShortPercentage(ethers.utils.parseUnits("12", 16))).wait(); // 12e16 = 12%


    console.log("   set gSGX withdraw Ceil...");
    await (await gSGX.setWithdrawCeil(ethers.utils.parseEther("100000"))).wait();


    console.log("   set lockupTime..");
    await (await lockup.setLongLockupTime(1296000)).wait(); // 15 days in seconds
    await (await lockup.setShortLockupTime(604800)).wait(); // 07 days in seconds

    
    console.log("   set vaultFactory contract..");
    await (await lockup.setVaultFactory(vault.address)).wait();


    console.log("   set vault variables..");
    await (await vault.setInterestRate(ethers.utils.parseUnits("1", 17))).wait();    // 01e17 = 10%
    await (await vault.setBurnPercent(ethers.utils.parseUnits("2", 16))).wait();     // 02e16 = 02%
    await (await vault.setgSGXPercent(ethers.utils.parseUnits("13", 16))).wait();    // 13e16 = 13%
    await (await vault.setgSGXDistributed(ethers.utils.parseUnits("5", 16))).wait(); // 05e16 = 05%
    await (await vault.setMinVaultDeposit(ethers.utils.parseUnits("1", 18))).wait(); // 01e18
    await (await vault.setNetworkBoost(ethers.utils.parseUnits("1", 18))).wait();    // 1x
    await (await vault.setLiquidateVaultPercent(ethers.utils.parseUnits("15", 16))).wait(); // 15%
    await (await vault.setRewardsWaitTime(0)).wait(); // No time so we can test. in seconds
    await (await vault.setAcceptedTokens(SGX.address, true)).wait(); // Add SGX to the list of accepted tokens

    console.log("   set league amounts..");
    await (await vault.setLeagueAmount(0, ethers.utils.parseUnits("2000", 18))).wait();
    await (await vault.setLeagueAmount(1, ethers.utils.parseUnits("5000", 18))).wait();
    await (await vault.setLeagueAmount(2, ethers.utils.parseUnits("20000", 18))).wait();
    await (await vault.setLeagueAmount(3, ethers.utils.parseUnits("100000", 18))).wait();

    console.log("   set token manager..");
    await (await SGX.setManager(vault.address, true)).wait();


    console.log("All done!".green);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })
