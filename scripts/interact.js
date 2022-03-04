const hre = require("hardhat");
const { BigNumber } = require("@ethersproject/bignumber");

async function main() {

    const [owner] = await ethers.getSigners();
    
    const VaultFactory = await ethers.getContractFactory("VaultFactory");
    const vault = await VaultFactory.attach("0xE41E9F1D23658925124ef2Ca73b945254A13EE81");


    const apy = await vault.getInterestRate();

    // Calculate interest rate in percentage.
    const interestRate = (apy.mul(100)).div(ethers.utils.parseEther("1"));

    console.log(interestRate.toString());

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })
