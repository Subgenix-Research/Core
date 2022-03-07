const colors = require("colors");

async function main() {

    const treasury = "0x11C0402CA8326a118A28abA79E8ddBCC69b3C910";

    const [owner] = await ethers.getSigners();

    console.log("Owner:", owner.address);

    console.log("Start contracts deployment...");

    const Subgenix = await ethers.getContractFactory("Subgenix");
    const SGX = await Subgenix.deploy(
        "Subgenix Currency",
        "SGX",
        18
    );
    await SGX.deployed();

    console.log("✓".green + " SGX deployed to:", SGX.address);

    const LockUpHell = await ethers.getContractFactory("LockUpHell");
    const lockup = await LockUpHell.deploy(SGX.address);
    await lockup.deployed();
    
    console.log("✓".green + " lockupHell deployed to:", lockup.address);


    const GovernanceSGX = await ethers.getContractFactory("gSGX");
    const gSGX = await GovernanceSGX.deploy(SGX.address);
    await gSGX.deployed();
    
    console.log("✓".green + " gSGX deployed to:", gSGX.address);

    
    const VaultFactory = await ethers.getContractFactory("VaultFactory");
    const vault = await VaultFactory.deploy(
        SGX.address,
        gSGX.address,
        treasury,
        lockup.address
    );
    await vault.deployed();
    
    console.log("✓".green + " VaultFactory deployed to:", vault.address);


    const Zapper = await ethers.getContractFactory("Zapper");
    const zapper = await Zapper.deploy(SGX.address, vault.address);
    await zapper.deployed();
    
    console.log("✓".green + " Zapper deployed to:", zapper.address);


    // SETTING UP CONTRACTS

    console.log("All contracts deployed! Starting setup...");

    console.log("   set percentages..");
    await (await lockup.setLongPercentage(1800)).wait();
    await (await lockup.setShortPercentage(1200)).wait();


    console.log("   set gSGX withdraw Ceil...");
    await (await gSGX.setWithdrawCeil(ethers.utils.parseEther("100000"))).wait();


    console.log("   set lockupTime..");
    await (await lockup.setLongLockupTime(1555200)).wait();
    await (await lockup.setShortLockupTime(604800)).wait();


    console.log("   set vault variables..");
    await (await vault.setInterestRate(ethers.utils.parseUnits("1", 16))).wait(); // 10%
    await (await vault.setBurnPercent(200)).wait();
    await (await vault.setgSGXPercent(1300)).wait();
    await (await vault.setgSGXDistributed(500)).wait();
    await (await vault.setMinVaultDeposit(ethers.utils.parseEther("1"))).wait();

    console.log("   set token manager..");
    await (await SGX.setManager(vault.address, true)).wait();
    await (await SGX.setManager(owner.address, true)).wait();
  
    console.log("   mint owner tokens...");
    await (await SGX.mint(owner.address, ethers.utils.parseEther("10000"))).wait();

    console.log("All done!".green);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })
