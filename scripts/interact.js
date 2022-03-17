const hre = require("hardhat");

async function main() {

    const [owner] = await ethers.getSigners();

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })
