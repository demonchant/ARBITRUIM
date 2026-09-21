const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("FlowGuardSettlement", function () {
  const amount = 2_400_000_000n;
  const proof = ethers.keccak256(ethers.toUtf8Bytes("encrypted-evidence-bundle-v1"));

  async function deployFixture() {
    const [buyer, supplier, courier, receiver, sensor, arbitrator, guardian, stranger] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("MockUSDG");
    const token = await Token.deploy();
    const FlowGuard = await ethers.getContractFactory("FlowGuardSettlement");
    const flowGuard = await FlowGuard.deploy(await token.getAddress(), guardian.address);
    await token.mint(buyer.address, amount);
    await token.connect(buyer).approve(await flowGuard.getAddress(), amount);
    const now = (await ethers.provider.getBlock("latest")).timestamp;
    await flowGuard.connect(buyer).createDeal(supplier.address, arbitrator.address, amount, now + 3600, 600, [courier.address, receiver.address, sensor.address], 2);
    return { buyer, supplier, courier, receiver, arbitrator, stranger, token, flowGuard };
  }

  it("releases only after the selected evidence threshold is met", async function () {
    const { buyer, supplier, courier, receiver, token, flowGuard } = await deployFixture();
    await flowGuard.connect(supplier).submitEvidence(1, proof);
    await flowGuard.connect(courier).attestEvidence(1, proof);
    await expect(flowGuard.connect(buyer).releasePayment(1)).to.be.reverted;
    await flowGuard.connect(receiver).attestEvidence(1, proof);
    await expect(flowGuard.connect(buyer).releasePayment(1)).to.emit(flowGuard, "PaymentReleased").withArgs(1, supplier.address, amount);
    expect(await token.balanceOf(supplier.address)).to.equal(amount);
  });

  it("refunds a buyer after a missed delivery deadline", async function () {
    const { buyer, token, flowGuard } = await deployFixture();
    await ethers.provider.send("evm_increaseTime", [3601]);
    await ethers.provider.send("evm_mine");
    await flowGuard.connect(buyer).refundExpired(1);
    expect(await token.balanceOf(buyer.address)).to.equal(amount);
  });

  it("limits dispute resolution to the deal-specific arbitrator", async function () {
    const { buyer, supplier, courier, stranger, arbitrator, token, flowGuard } = await deployFixture();
    await flowGuard.connect(supplier).submitEvidence(1, proof);
    await flowGuard.connect(courier).attestEvidence(1, proof);
    await flowGuard.connect(buyer).dispute(1, ethers.keccak256(ethers.toUtf8Bytes("temperature-exceeded")));
    await expect(flowGuard.connect(stranger).resolveDispute(1, true)).to.be.reverted;
    await flowGuard.connect(arbitrator).resolveDispute(1, false);
    expect(await token.balanceOf(buyer.address)).to.equal(amount);
  });
});
