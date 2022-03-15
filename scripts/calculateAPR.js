async function main() {

    const [owner] = await ethers.getSigners();

    const VaultFactory = await ethers.getContractFactory("VaultFactory");
    const vault = await VaultFactory.attach("0x09446bF71D5465b27069807f68D871dD15010aaa");

    // 1. Get Interest Rate
    const interestRaw = await vault.InterestRate();

    // 2. Formats interestRaw from bigNumber to integer.
    const interestFormated = (((interestRaw.mul(100)).div(ethers.utils.parseEther("1"))).toNumber());

    console.log("finalAPR: ", interestFormated);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })




