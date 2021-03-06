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
        "0x3d97964506800d433fb5DbEBDd0c202EC9B62557", // SwapperChanFactory
        "0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000" // WETH
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
