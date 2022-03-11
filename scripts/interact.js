async function main() {

    const [owner] = await ethers.getSigners();

    const VaultFactory = await ethers.getContractFactory("VaultFactory");
    const vault = await VaultFactory.attach("0xf2984227CCa59b54f93cAd5E0e0b96b35BfD48DC");

    const [pendingRewards, shortLockup, longLockup] = await vault.viewPendingRewards(owner.address);
    console.log(pendingRewards);

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })

    //const Subgenix = await ethers.getContractFactory("Subgenix");
    //const sgx = await Subgenix.attach("0xafaa376eD83A82Df35c85f7Ff991F212AdAF9929");
//
    //const VaultFactory = await ethers.getContractFactory("VaultFactory");
    //const vault = await VaultFactory.attach("0xf2984227CCa59b54f93cAd5E0e0b96b35BfD48DC");
//
    //const LockupHell = await ethers.getContractFactory("LockUpHell");
    //const lockup = await LockupHell.attach("0xa24Bce2f4dfC1BC4F15F315DD638F33B30CD65b9");


    // Create vault
    //await (await sgx.approve(vault.address, ethers.utils.parseEther("10"))).wait();
    //await (await vault.createVault(ethers.utils.parseEther("2"))).wait();

    // Claim rewards
    //await (await sgx.approve(lockup.address, ethers.utils.parseEther("10"))).wait();
    //await (await vault.claimRewards(owner.address)).wait(); 