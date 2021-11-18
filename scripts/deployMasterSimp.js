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

    // Deploy Dev & Investor TokenLock
    const TokenLockContract = await hre.ethers.getContractFactory("TokenLock");
    const DevTimeLock = await TokenLockContract.deploy();
    await DevTimeLock.deployed();
    console.log("DevTimeLock deployed to:", DevTimeLock.address);

    const InvestorTimeLock = await TokenLockContract.deploy();
    await InvestorTimeLock.deployed();
    console.log("InvestorTimeLock deployed to:", InvestorTimeLock.address);

    // Deploy MasterSimp
    const MasterSimpContract = await hre.ethers.getContractFactory("MasterSimp");
    const MasterSimp = await MasterSimpContract.deploy(
        deployer.address, // Treasury address
        DevTimeLock.address, // Dev address
        InvestorTimeLock.address // Investor address
    );

    await MasterSimp.deployed();

    console.log("MasterSimp deployed to:", MasterSimp.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
