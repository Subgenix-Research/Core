const hre = require("hardhat");
const { BigNumber } = require("@ethersproject/bignumber");
 
async function main() {

    const [owner] = await ethers.getSigners();
    
    const gSGX = await ethers.getContractFactory("gSGX");
    const gsgx = await gSGX.attach("0xDd1eA6ca171370556513e10ec3ee68Dc4020bB2e");


    const value = await gsgx.setWithdrawCeil(ethers.utils.parseEther("100000"));

    console.log("Done");

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })
