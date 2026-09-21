const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  const guardian = process.env.GUARDIAN_ADDRESS || deployer.address;
  let tokenAddress = process.env.USDG_ADDRESS;

  if (!tokenAddress) {
    console.log("USDG_ADDRESS not set: deploying MockUSDG for the Arbitrum Sepolia demo only.");
    const MockUSDG = await ethers.getContractFactory("MockUSDG");
    const mockUSDG = await MockUSDG.deploy();
    await mockUSDG.waitForDeployment();
    tokenAddress = await mockUSDG.getAddress();
    console.log("MockUSDG:", tokenAddress);
  }

  const FlowGuard = await ethers.getContractFactory("FlowGuardSettlement");
  const flowGuard = await FlowGuard.deploy(tokenAddress, guardian);
  await flowGuard.waitForDeployment();
  console.log("FlowGuardSettlement:", await flowGuard.getAddress());
  console.log("Guardian:", guardian);
}

main().catch((error) => { console.error(error); process.exitCode = 1; });
