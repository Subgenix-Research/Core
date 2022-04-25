const { ethers } = require("ethers");
require("colors");
require('dotenv').config()
const SubgenixJson = require("../out/Subgenix.sol/Subgenix.json");
const GovernanceSGXJson = require("../out/GovernanceSGX.sol/GovernanceSGX.json");
const LockupHellJson = require("../out/LockupHell.sol/LockupHell.json");
const VaultFactoryJson = require("../out/VaultFactory.sol/VaultFactory.json");

async function main() {

    const provider = new ethers.providers.JsonRpcProvider("https://api.avax.network/ext/bc/C/rpc");

    const owner = new ethers.Wallet(process.env.privateKey, provider);

    const treasury = ""; 
    const research = "";
    const wavax = "";

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

    process.stdout.write("   set long percentages..  ");
    await (await lockup.setLongPercentage(ethers.utils.parseUnits("18", 16))).wait();  // 18e16 = 18%
    process.stdout.write("done!\n".green);
    process.stdout.write("   set short percentages..  ");
    await (await lockup.setShortPercentage(ethers.utils.parseUnits("12", 16))).wait(); // 12e16 = 12%
    process.stdout.write("done!\n".green);

    process.stdout.write("   set gSGX withdraw Ceil..  ");
    await (await gSGX.setWithdrawCeil(ethers.utils.parseEther("10000"))).wait(); // 10,000 SGX
    process.stdout.write("done!\n".green);

    process.stdout.write("   set vaultFactory contract..  ");
    await (await lockup.setVaultFactory(vault.address)).wait();
    process.stdout.write("done!\n".green);

    process.stdout.write("   set Interest rate..  ");
    await (await vault.setInterestRate(ethers.utils.parseUnits("7", 18))).wait();      // 07e18 = 700%
    process.stdout.write("done!\n".green);

    process.stdout.write("   set Burn Percent..  ");
    await (await vault.setBurnPercent(ethers.utils.parseUnits("2", 16))).wait();       // 02e16 = 02%
    process.stdout.write("done!\n".green);

    process.stdout.write("   set gSGX Percent..  ");
    await (await vault.setgSGXPercent(ethers.utils.parseUnits("13", 16))).wait();      // 13e16 = 13%
    process.stdout.write("done!\n".green);

    process.stdout.write("   set gSGX Distributed..  ");
    await (await vault.setgSGXDistributed(ethers.utils.parseUnits("5", 16))).wait();   // 05e16 = 05%
    process.stdout.write("done!\n".green);

    process.stdout.write("   set min vault deposit..  ");
    await (await vault.setMinVaultDeposit(ethers.utils.parseUnits("500", 18))).wait(); // 500e18 = 500 SGX
    process.stdout.write("done!\n".green);

    process.stdout.write("   set network boost..  ");
    await (await vault.setNetworkBoost(ethers.utils.parseUnits("16", 17))).wait();     // 1.6x
    process.stdout.write("done!\n".green);

    process.stdout.write("   set liquidate Vault Percent..  ");
    await (await vault.setLiquidateVaultPercent(ethers.utils.parseUnits("15", 16))).wait(); // 15%
    process.stdout.write("done!\n".green);

    process.stdout.write("   set rewards wait time..  ");
    await (await vault.setRewardsWaitTime(86400)).wait(); // 1 day in seconds
    process.stdout.write("done!\n".green);

    process.stdout.write("   set deposit swap Percentage..  ");
    await (await vault.setDepositSwapPercentage(ethers.utils.parseUnits("33", 16))); // 33e16 = 33%
    process.stdout.write("done!\n".green);

    process.stdout.write("   set create swap Percentage..  ");
    await (await vault.setCreateSwapPercentage(ethers.utils.parseUnits("66", 16)));  // 66e16 = 66%
    process.stdout.write("done!\n".green);

    process.stdout.write("   set league amounts..  ");
    await (await vault.setLeagueAmount(0, ethers.utils.parseUnits("2000", 18))).wait();
    await (await vault.setLeagueAmount(1, ethers.utils.parseUnits("5000", 18))).wait();
    await (await vault.setLeagueAmount(2, ethers.utils.parseUnits("20000", 18))).wait();
    await (await vault.setLeagueAmount(3, ethers.utils.parseUnits("100000", 18))).wait();
    process.stdout.write("done!\n".green);

    process.stdout.write("   set token manager..  ");
    await (await SGX.setManager(vault.address, true)).wait();
    process.stdout.write("done!\n".green);

    process.stdout.write("   add accepted tokens..");
    await (await vault.setAcceptedTokens(wavax, true)).wait();
    process.stdout.write("done!\n".green);

    console.log("All done!".green);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })
