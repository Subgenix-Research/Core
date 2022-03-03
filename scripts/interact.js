const hre = require("hardhat");

async function main() {

    const [owner] = await ethers.getSigners();

    const VaultFactory = await ethers.getContractFactory("VaultFactory");
    const vault = await VaultFactory.attach("0x8950cD25aD566C366A854A6B4FF9C3B3D15C6DA8");


}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })
