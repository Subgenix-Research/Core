const hre = require("hardhat");
const { BigNumber } = require("@ethersproject/bignumber");

async function main() {

    const [owner] = await ethers.getSigners();

    const Subgenix = await ethers.getContractFactory("Subgenix");
    const sgx = await Subgenix.attach("0x0dD2aaDb8336566b474aa386D951446CFF886c61");
    
    const VaultFactory = await ethers.getContractFactory("VaultFactory");
    const vault = await VaultFactory.attach("0xe0300d24D1357084cbB5128A2ae02F10F70E902D");

    await sgx.mint(owner.address, ethers.utils.parseEther("1000000"));


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
