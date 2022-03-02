const hre = require("hardhat");

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

    console.log("1. SGX deployed to:", SGX.address);


    const LockUpHell = await ethers.getContractFactory("LockUpHell");
    const lockup = await LockUpHell.deploy(SGX.address);
    await lockup.deployed();
    
    console.log("2. lockupHell deployed to:", lockup.address);


    const GovernanceSGX = await ethers.getContractFactory("gSGX");
    const gSGX = await GovernanceSGX.deploy(SGX.address);
    await gSGX.deployed();
    
    console.log("3. gSGX deployed to:", gSGX.address);

    
    const VaultFactory = await ethers.getContractFactory("VaultFactory");
    const vault = await VaultFactory.deploy(
        SGX.address,
        gSGX.address,
        treasury,
        lockup.address
    );
    await vault.deployed();
    
    console.log("4. VaultFactory deployed to:", gSGX.address);


    const Zapper = await ethers.getContractFactory("Zapper");
    const zapper = await Zapper.deploy(SGX.address, vault.address);
    await zapper.deployed();
    
    console.log("5. Zapper deployed to:", zapper.address);

    // SETTING UP CONTRACTS

    console.log("All contracts deployed! Starting setup...");

    await lockup.setLongPercentage(1800);
    await lockup.setShortPercentage(1200);

    await lockup.setLongLockupTime(1555200);
    await lockup.setShortLockupTime(604800);

    await vault.setRewardPercent(ethers.utils.parseUnits("1", 16));
    await vault.setBurnPercent(200);
    await vault.setgSGXPercent(1300);
    await vault.setgSGXDistributed(500);
    await vault.setMinVaultDeposit(ethers.utils.parseEther("1"));

    await SGX.setManager(vault.address, true);
    
    console.log("Mint owner tokens...");
    
    await SGX.setManager(owner.address, true);
    await SGX.mint(owner.address, ethers.utils.parseEther("100"));

    console.log("All done!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })
