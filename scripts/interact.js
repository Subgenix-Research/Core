const hre = require("hardhat");

async function main() {

    const [owner] = await ethers.getSigners();

    const Subgenix = await ethers.getContractFactory("Subgenix");
    const sgx = await Subgenix.attach("0x53Cb7eAe2d041160b2163F764CDd34a07DE1427B");

    

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })
