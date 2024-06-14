import { ethers } from "hardhat";
import { LeveragedAMM, LeveragedAMM__factory } from "../typechain-types";
import { expect, assert } from "chai";

describe("LeveargedAMM", function () {
  let leveragedAMMFactory: LeveragedAMM__factory;
  let leveragedAMM: LeveragedAMM;
  let reserves: { eth: bigint; usdc: bigint } = {
    eth: BigInt(1000 * 10 ** 18),
    usdc: BigInt(3500000 * 10 ** 18),
  };
  const k = reserves.eth * reserves.usdc;

  beforeEach(async function () {
    leveragedAMMFactory = (await ethers.getContractFactory(
      "LeveragedAMM"
    )) as LeveragedAMM__factory;
    leveragedAMM = await leveragedAMMFactory.deploy();
  });

  it("Should get expected ETH amount if user wants to long 1000 USDC worth of ETH", async function () {
    let usdcAmount = ethers.parseUnits("1000", 6);
    // actual
    const ethAmount = await leveragedAMM.getEthAmount(1, usdcAmount);
    // expected
    usdcAmount = usdcAmount * BigInt(10 ** 12);
    const expectedEthAmount = reserves.eth - k / (reserves.usdc + usdcAmount);

    assert.equal(ethAmount, expectedEthAmount);
  });

  it("Should get expected ETH amount if user wants to short 1000 USDC worth of ETH", async function () {
    let usdcAmount = ethers.parseUnits("1000", 6);
    // actual
    const ethAmount = await leveragedAMM.getEthAmount(-1, usdcAmount);
    // expected
    usdcAmount = usdcAmount * BigInt(10 ** 12);
    const expectedEthAmount = reserves.eth - k / (reserves.usdc - usdcAmount);
    assert.equal(ethAmount, expectedEthAmount); // expect negative eth
  });

  it("Should get expected USDC amount if user wants to long 1 ETH", async function () {
    const ethAmount = ethers.parseUnits("1", 18);
    const usdcAmount = await leveragedAMM.getUsdcAmount(1, ethAmount);
    const expectedUsdcAmount = k / (reserves.eth - ethAmount) - reserves.usdc;
    assert.equal(usdcAmount, expectedUsdcAmount);
  });

  it("Should get expected USDC amount if user wants to short 1 ETH", async function () {
    const ethAmount = ethers.parseUnits("1", 18);
    const usdcAmount = await leveragedAMM.getUsdcAmount(-1, ethAmount);
    const expectedUsdcAmount = k / (reserves.eth + ethAmount) - reserves.usdc;
    assert.equal(usdcAmount, expectedUsdcAmount); // expect negative usdc
  });
});
