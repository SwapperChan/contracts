// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');

    const [deployer] = await ethers.getSigners();
    console.log(
        "Deploying contracts with the account:",
        deployer.address
    );

    console.log("Account balance:", (await deployer.getBalance()).toString());
    console.log("");

    // Deploy SwapperChanRouter
    const SwapperChanRouterContract = await hre.ethers.getContractFactory("SwapperChanRouter");
    const SwapperChanRouter = await SwapperChanRouterContract.deploy(
        "0x643b35FF995799DC839f6728D66417A11510CC38", // SwapperChanFactory
        "0xc778417E063141139Fce010982780140Aa0cD5Ab" // WETH
    );

    await SwapperChanRouter.deployed();

    console.log("SwapperChanRouter deployed to:", SwapperChanRouter.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
