import { ethers } from "hardhat"; // this is hardhat's version of ethers

async function main() {
  const leveragedAMM = await ethers.deployContract("LeveragedAMM"); // knows about "contract" and "artifact" folders
  await leveragedAMM.waitForDeployment();
  console.log(leveragedAMM.target);
}

// run main() and handle errors
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
