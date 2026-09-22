const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  const guardian = process.env.GUARDIAN_ADDRESS || deployer.address;
  const tokenAddress = process.env.USDG_ADDRESS || "0xFFC95faa3d63Cde504a05B567C600B78C0b41892";
  console.log("Settlement token (Paxos test USDG):", tokenAddress);

  const FlowGuard = await ethers.getContractFactory("FlowGuardSettlement");
  const flowGuard = await FlowGuard.deploy(tokenAddress, guardian);
  await flowGuard.waitForDeployment();
  console.log("FlowGuardSettlement:", await flowGuard.getAddress());
  console.log("Guardian:", guardian);
}

main().catch((error) => { console.error(error); process.exitCode = 1; });
