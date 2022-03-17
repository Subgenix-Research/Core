require("colors");

async function main() {

    const treasury = "0x59fcd31a5d1356844aD410e138D8a915E8AB20d0";
    const research = "0x59fcd31a5d1356844aD410e138D8a915E8AB20d0";

    const [owner] = await ethers.getSigners();

    console.log("Owner:", owner.address);

    console.log("Start contracts deployment...");

    const Subgenix = await ethers.getContractFactory("Subgenix");
    const SGX = await Subgenix.deploy(
        "Subgenix Token",
        "SGX",
        18
    );
    await SGX.deployed();

    console.log("✓".green + " SGX deployed to:", SGX.address);

    const LockUpHell = await ethers.getContractFactory("LockUpHell");
    const lockup = await LockUpHell.deploy(SGX.address);
    await lockup.deployed();
    
    console.log("✓".green + " lockupHell deployed to:", lockup.address);


    const GovernanceSGX = await ethers.getContractFactory("GovernanceSGX");
    const gSGX = await GovernanceSGX.deploy(SGX.address);
    await gSGX.deployed();
    
    console.log("✓".green + " GovernanceSGX deployed to:", gSGX.address);
    
    
    const VaultFactory = await ethers.getContractFactory("VaultFactory");
    const vault = await VaultFactory.deploy(
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
    await (await lockup.setLongLockupTime(1555200)).wait();
    await (await lockup.setShortLockupTime(604800)).wait();

    
    console.log("   set vaultFactory contract..");
    await (await lockup.setVaultFactory(vault.address)).wait();


    console.log("   set vault variables..");
    await (await vault.setInterestRate(ethers.utils.parseUnits("1", 17))).wait();    // 01e17 = 10%
    await (await vault.setBurnPercent(ethers.utils.parseUnits("2", 16))).wait();     // 02e16 = 02%
    await (await vault.setgSGXPercent(ethers.utils.parseUnits("13", 16))).wait();    // 13e16 = 13%
    await (await vault.setgSGXDistributed(ethers.utils.parseUnits("5", 16))).wait(); // 05e16 = 05%
    await (await vault.setMinVaultDeposit(ethers.utils.parseUnits("1", 18))).wait(); // 01e18
    await (await vault.setNetworkBoost(1)).wait();
    await (await vault.setRewardsWaitTime(0)).wait(); // No time so we can test. in seconds

    console.log("   set league amounts..");
    await (await vault.setLeagueAmount(0, ethers.utils.parseUnits("2000", 18))).wait();
    await (await vault.setLeagueAmount(1, ethers.utils.parseUnits("5000", 18))).wait();
    await (await vault.setLeagueAmount(2, ethers.utils.parseUnits("20000", 18))).wait();
    await (await vault.setLeagueAmount(3, ethers.utils.parseUnits("100000", 18))).wait();

    console.log("   set token manager..");
    await (await SGX.setManager(vault.address, true)).wait();
    await (await SGX.setManager(owner.address, true)).wait();
  
    console.log("   mint owner tokens...");
    await (await SGX.mint(owner.address, ethers.utils.parseEther("1000000"))).wait();

    console.log("All done!".green);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })
