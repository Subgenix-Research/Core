async function main() {

    const [owner] = await ethers.getSigners();

    const GSGX = await ethers.getContractFactory("gSGX");
    const gsgx = await GSGX.attach("0x0dF10dbea580A5732F5D4481B6e15f061458F2af");

    const Subgenix = await ethers.getContractFactory("Subgenix");
    const sgx = await Subgenix.attach("0xafaa376eD83A82Df35c85f7Ff991F212AdAF9929");

    const numerator = (await sgx.balanceOf(gsgx.address)).div(ethers.utils.parseUnits("1", 18)).toNumber();

    console.log(numerator);

    const supply = (await sgx.totalSupply()).div(ethers.utils.parseUnits("1", 18)).toNumber();

    console.log(supply);

    const formula = numerator * 10000 / supply;
    
    const final = formula * 100 / 10000;

    console.log(final);

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
