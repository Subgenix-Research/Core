async function main() {

    const [owner] = await ethers.getSigners();

    const Subgenix = await ethers.getContractFactory("Subgenix");
    const sgx = Subgenix.attach("0xFC4487f268a5f484FE4A8478c674cc3145621716");

    const GovernanceSGX = await ethers.getContractFactory("GovernanceSGX");
    const gSGX = GovernanceSGX.attach("0xD7382d3a4557cf1A00635da374534bF5a8898B1c");

    const Percent = (numerator, supply) => {
        if (numerator.lt(ethers.utils.parseUnits("1", 16))) {
            return 0;
        }
        const formula = (((numerator).mul(10000)).div(supply)).toNumber();

        return (formula * 100) / 10000;
    }

    const sgx_on_gSGX = await sgx.balanceOf(gSGX.address);

    const sgx_supply = await sgx.totalSupply();

    var gSGXDominance = Percent(sgx_on_gSGX, sgx_supply);

    console.log(gSGXDominance);

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })
