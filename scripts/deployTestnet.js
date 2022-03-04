const hre = require("hardhat");

var colors = require("colors");


function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
 }



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

    sleep(5000);


    const LockUpHell = await ethers.getContractFactory("LockUpHell");
    const lockup = await LockUpHell.deploy(SGX.address);
    await lockup.deployed();
    
    console.log("✓".green + " lockupHell deployed to:", lockup.address);

    sleep(5000);

    const GovernanceSGX = await ethers.getContractFactory("gSGX");
    const gSGX = await GovernanceSGX.deploy(SGX.address);
    await gSGX.deployed();
    
    console.log("✓".green + " gSGX deployed to:", gSGX.address);

    sleep(5000);
    
    const VaultFactory = await ethers.getContractFactory("VaultFactory");
    const vault = await VaultFactory.deploy(
        SGX.address,
        gSGX.address,
        treasury,
        lockup.address
    );
    await vault.deployed();
    
    console.log("✓".green + " VaultFactory deployed to:", gSGX.address);

    sleep(5000);

    const Zapper = await ethers.getContractFactory("Zapper");
    const zapper = await Zapper.deploy(SGX.address, vault.address);
    await zapper.deployed();
    
    console.log("✓".green + " Zapper deployed to:", zapper.address);

    sleep(5000);

    // SETTING UP CONTRACTS

    console.log("All contracts deployed! Starting setup...");

    console.log("   set percentages..");
    await lockup.setLongPercentage(1800);
    await lockup.setShortPercentage(1200);

    sleep(5000);

    console.log("   set lockupTime..");
    await lockup.setLongLockupTime(1555200);
    await lockup.setShortLockupTime(604800);

    sleep(5000);

    console.log("   set vault variables..");
    await vault.setInterestRate(ethers.utils.parseUnits("1", 17)); // 10%
    await vault.setBurnPercent(200);
    sleep(5000);
    await vault.setgSGXPercent(1300);
    await vault.setgSGXDistributed(500);
    sleep(5000);
    await vault.setMinVaultDeposit(ethers.utils.parseEther("1"));

    console.log("   set token manager..");
    sleep(5000);
    await SGX.setManager(vault.address, true);
    await SGX.setManager(owner.address, true);
  
    sleep(5000);
    console.log("   mint owner tokens...");
    await SGX.mint(owner.address, ethers.utils.parseEther("1000000"));

    console.log("All done!".green);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })
