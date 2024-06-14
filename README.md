# Leveraged AMM (for Perpetual Protocol Pretest)

The leveraged AMM here follows the vAMM model.

All logic was verified on Excel, [which can be downloaded here](https://docs.google.com/spreadsheets/d/1oDHskyDESzW43ulrtyc6Yy2alLmBT5SX/edit?usp=sharing&ouid=105809551198347578878&rtpof=true&sd=true). The Excel simulates 2 users opening long/short positions. The model is verified because 1) vUSDC/vETH reserves returns to initial values afer everyone closes positions and 2) profits/losses are balanced.

A few definitions that differs from the testing prompt:<br />
accountValue = collateral + unrealizedPnl, where "collateral" is the amount of USDC deposited to the protocol<br />
buyingPower = accountValue _ 10 - ethPositionValue, where ethPositionValue = ethPosition _ ethPrice<br />
The leverage value is chosen on the frontent. The parameter passed to the contract is (leverage) x (amount usdc entered).
These changes were made for the Excel model to work out perfectly and to simplify the code.

The repository contains 1 contract and 1 testing file. To test, run **yarn install** and then **yarn hardhat test**.

A disclaimer is I haven't really focused on Solidity in the past year. I am more focused on Next.js/React, RWD styling via Tailwind, smooth connection to multiple chains (via wagmiV2, WalletConnect, etc.), database connections, and connections to various other APIs. I created (by myself) a crypto payments App that does use a simple smart contract, but 90% of the work was frontend. So, the Solidity code might not be very good, although I feel the general logic makes sense (verified on Excel).
