// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20Complete} from "./interfaces/IERC20Complete.sol";

contract LeveragedAMM {
    IERC20Complete usdc = IERC20Complete(address(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359)); // native USDC on Polygon

    // types
    struct Reserves {
        int256 eth;
        int256 usdc;
    }

    // state vars
    Reserves reserves = Reserves(1000 * 10 ** 18, 3500000 * 10 ** 18); // 1000 ETH and 3,500,000 USDC (18 decimals)
    mapping(address => int256) addressToCollateral; // "collateral" is the amount of USDC deposited into protocol
    mapping(address => int256) addressToPositionCost; // the cumulative cost of opening the long/short position, see Excel
    mapping(address => int256) addressToEthPosition; // the amount of eth longed/shorted (negative value is short), see Excel
    address[] addressesWithEthPosition; // convenient var used for iteration

    // constants
    int256 k = 1000 * 10 ** 18 * 3500000 * 10 ** 18;
    int256 priceMultiplier = 10 ** 18; // make price 18 decimals

    // events
    event UsdcDeposited(uint256 _depositAmount);
    event UsdcWithdrawn(uint256 _withdrawAmount);
    event PositionCreatedWithUsdcAmount(int8 _longOrShort, uint256 _amount, int256 _ethAmount);
    event PositionCreatedWithEthAmount(int8 _longOrShort, uint256 _amount, int256 _usdcAmount);

    // deposit USDC to protocol
    function deposit(uint256 _depositAmount) public {
        usdc.transferFrom(msg.sender, address(this), _depositAmount);
        addressToCollateral[msg.sender] += int256(_depositAmount);
        emit UsdcDeposited(_depositAmount);
    }

    // withdraw USDC from protocol
    function withdraw(uint256 _withdrawAmount) public {
        // revert if withdraw exceeds accountValue
        int256 accountValue = getAccountValue();
        if (int256(_withdrawAmount) > accountValue) {
            revert();
        }

        usdc.transferFrom(address(this), msg.sender, _withdrawAmount);

        addressToCollateral[msg.sender] -= int256(_withdrawAmount); // collateral can be negative if user has positive unrealizedPnl

        emit UsdcWithdrawn(_withdrawAmount);
    }

    // get accountValue
    function getAccountValue() public view returns (int256) {
        if (addressToCollateral[msg.sender] != 0) {
            int256 unrealizedPnl = reserves.usdc - addressToPositionCost[msg.sender] - k / (reserves.eth + addressToEthPosition[msg.sender]); // see email attachment for derivation
            int256 accountValue = addressToCollateral[msg.sender] + unrealizedPnl; // accountValue = collateral + unrealizedPnl
            return accountValue;
        } else {
            revert();
        }
    }

    // view function 1 (if user enters USDC into GUI, then this function will be used)
    // _usdcAmount = amount USDC entered in GUI * chosen leverage in GUI
    function getEthAmount(int8 _longOrShort, uint256 _usdcAmount) public view returns (int256) {
        _usdcAmount = _usdcAmount * 10 ** 12; // change to 18 decimals

        // 1 = long, while -1 = short
        if (_longOrShort == 1) {
            int256 ethAmount = reserves.eth - k / (reserves.usdc + int256(_usdcAmount)); // always positive
            return ethAmount;
        } else if (_longOrShort == -1) {
            int256 ethAmount = reserves.eth - k / (reserves.usdc - int256(_usdcAmount)); // always negative, but GUI will show positive and "short" tag
            return ethAmount;
        } else {
            revert();
        }
    }

    // view function 2 (if user enters ETH into GUI, then this function will be used)
    // GUI will show this function's returned value ÷ by chosen leverage in GUI
    function getUsdcAmount(int8 _longOrShort, uint256 _ethAmount) public view returns (int256) {
        // 1 = long, while -1 = short
        if (_longOrShort == 1) {
            int256 usdcAmount = k / (reserves.eth - int256(_ethAmount)) - reserves.usdc; // always positive
            return usdcAmount;
        } else if (_longOrShort == -1) {
            int256 usdcAmount = k / (reserves.eth + int256(_ethAmount)) - reserves.usdc; // always negative, but GUI will show positive and "short" tag
            return usdcAmount;
        } else {
            revert();
        }
    }

    // if user enters USDC in GUI, then this function will be used
    function createPositionWithUsdcAmount(int8 _longOrShort, uint256 _amount) public {
        int256 _usdcAmount = int256(_amount) * 10 ** 12; // change to int256 and 18 decimals

        // buyingPower = accountValue * 10 - positionValue, where positionValue = ethPosition * ethPrice
        int256 buyingPower = getAccountValue() * 10 - (addressToEthPosition[msg.sender] * ((reserves.usdc * priceMultiplier) / reserves.eth)) / priceMultiplier; // TODO: price does not consider price impact, which should be considered

        // revert if insufficient buyingPower
        if (_usdcAmount > buyingPower) {
            revert();
        }

        // create position
        if (_longOrShort == 1) {
            int256 _ethAmount = getEthAmount(1, _amount); // always positive
            addressToPositionCost[msg.sender] += _usdcAmount;
            addressToEthPosition[msg.sender] += _ethAmount;
            reserves.eth -= _ethAmount; // reserves always decrease
            reserves.usdc += _usdcAmount;

            emit PositionCreatedWithUsdcAmount(_longOrShort, _amount, _ethAmount);
        } else if (_longOrShort == -1) {
            int256 _ethAmount = getEthAmount(-1, _amount); // always negative
            addressToPositionCost[msg.sender] -= _usdcAmount;
            addressToEthPosition[msg.sender] += _ethAmount;
            reserves.eth -= _ethAmount; // reserves always increase
            reserves.usdc -= _usdcAmount;

            emit PositionCreatedWithUsdcAmount(_longOrShort, _amount, _ethAmount);
        } else {
            revert();
        }

        // Because price has change, we need to iterate over all positions to find underwater positions and liquidate it.
        // If marginRatio < 5% (maintenance margin), then liquidate.
        // marginRatio = buyingPower / ( ethPosition * ethPrice )
        // After liquidation, re-iterate over all positions again (and if another liquidation, then re-iterate)
        // This can be done off-chain using "view" functions to save gas.
    }

    // if user enters ETH in GUI, then this function will be used
    function createPositionWithEthAmount(int8 _longOrShort, uint256 _amount) public {
        int256 _ethAmount = int256(_amount) * _longOrShort; // make negative if shorting

        // create position
        if (_longOrShort == 1) {
            int256 _usdcAmount = getUsdcAmount(1, _amount); // always positive
            int256 buyingPower = getAccountValue() * 10 - (addressToEthPosition[msg.sender] * ((reserves.usdc * priceMultiplier) / reserves.eth)) / priceMultiplier;
            // revert if insufficient buyingPower
            if (_usdcAmount > buyingPower) {
                revert();
            }
            addressToPositionCost[msg.sender] += _usdcAmount;
            addressToEthPosition[msg.sender] += _ethAmount;
            reserves.eth -= _ethAmount; // reserves always decrease
            reserves.usdc += _usdcAmount;

            emit PositionCreatedWithEthAmount(_longOrShort, _amount, _usdcAmount);
        } else if (_longOrShort == -1) {
            int256 _usdcAmount = getUsdcAmount(-1, _amount); // always negative
            int256 buyingPower = getAccountValue() * 10 - (addressToEthPosition[msg.sender] * ((reserves.usdc * priceMultiplier) / reserves.eth)) / priceMultiplier;
            // revert if insufficient buyingPower
            if (_usdcAmount > buyingPower) {
                revert();
            }
            addressToPositionCost[msg.sender] += _usdcAmount; // _usdcAmount always negative
            addressToEthPosition[msg.sender] += _ethAmount;
            reserves.eth -= _ethAmount; // reserves always increase
            reserves.usdc += _usdcAmount;

            emit PositionCreatedWithEthAmount(_longOrShort, _amount, _usdcAmount);
        } else {
            revert();
        }

        // Because price has change, we need to iterate over all positions to liquidate (see ending note in createPositionFromUsdcAmount() function)
    }
}
