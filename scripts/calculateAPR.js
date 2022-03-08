async function main() {

    const [owner] = await ethers.getSigners();

    const VaultFactory = await ethers.getContractFactory("VaultFactory");
    const vault = await VaultFactory.attach("0x5D582F9502ec43293C82aa982b5eAA836fa9335C");

    // Function to calcualte APR
    const APR = (interestRate) => {
        return ((((1 + interestRate) ** (1/31536000)) - 1) * 31536000) * 100
    }

    // 1. Get Interest Rate
    const interestRaw = await vault.InterestRate();

    // 2. Formats interestRaw from bigNumber to integer and divide it by 100.
    const interestFormated = (((interestRaw.mul(100)).div(ethers.utils.parseEther("1"))).toNumber())/100;

    // 3. Get the formated value and use the APR function to calculate the APR.
    const finalAPR = APR(interestFormated);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })




