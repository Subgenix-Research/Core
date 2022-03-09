async function main() {

    const [owner] = await ethers.getSigners();

    const VaultFactory = await ethers.getContractFactory("VaultFactory");
    const vault = await VaultFactory.attach("0x34ac46B89044FD0b0112F39256609Af3e86Fd309");

    // 1. Call function.
    const [
        immediateRewards, 
        burnAmount, 
        shortLockup, 
        longLockup, 
        gSGXPercent, 
        gSGXToContract
    ] = await vault.viewPendingRewards(owner.address);
    
    // 2. Pending Rewards
    const pendingRewards = immediateRewards.toNumber() + shortLockup.toNumber() + longLockup.toNumber();

    // --------- REWARDS OVERVIEW ----------
    // |-----------------|-----------------|
    // | immediateRewards| gSGXPercent     |
    // |-----------------|-----------------|
    // | shortLockup     | longLockup      |
    // |-----------------|-----------------|
    // | burnAmount      | gSGXToContract  |
    // |-----------------|-----------------|
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })
