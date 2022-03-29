async function main() {

    const [owner] = await ethers.getSigners();

    const VaultFactory = await ethers.getContractFactory("VaultFactory");
    const vault = VaultFactory.attach("0xe686C61922e7F20dbD5aCCD2B4DaB9dC0e8Fd853");

    // Get All info.
    const [
        exists, 
        lastClaimTime, 
        uncollectedRewards,
        balance,
        interestLength,
        league
    ] = await vault.usersVault(owner.address);

    // Get User Balance.
    const [ , , , balance, , ] = await vault.usersVault(owner.address);


    // Get User League
    const [ , , , , , league] = await vault.usersVault(owner.address);


    // Check if vault exists.
    const [exists, , , , , ] = await vault.usersVault(owner.address);


}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })
