// SPDX-License-Identifier: Unlicense

pragma solidity 0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {IUniswapV3MintCallback} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract UniV3SingleTick is Test, IUniswapV3MintCallback {
    using TickMath for int24;

    address alice = vm.addr(1);

    // WETH-USDC.e
    IUniswapV3Pool constant pool = IUniswapV3Pool(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443);
    int24 currentTick = -200491;
    uint160 currentSqrtPriceX96 = 3511601962954168469131920;
    address token0 = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH
    address token1 = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // USDC.e

    function setUp() public {
        vm.createSelectFork("arb", 151299689);
    }

    function testSingleTickMint() public {
        // emit log_named_address("token0", pool.token0());
        // emit log_named_address("token1", pool.token1());
        // emit log_named_int("spacing", pool.tickSpacing());

        int24 _lt = -200690;
        int24 _ut = -200290;
        int24 _spacing = 10;

        uint256 _a0Max = 1 ether;
        uint256 _a1Max = 1000e6; // 1000 USDC.e

        uint128 _l = LiquidityAmounts.getLiquidityForAmounts(
            currentSqrtPriceX96,
            _lt.getSqrtRatioAtTick(),
            _ut.getSqrtRatioAtTick(),
            _a0Max,
            _a1Max
        );

        emit log_named_uint("computed liquidity", _l);

        address _recipient = address(this);

        deal(token0, _recipient, _a0Max);
        deal(token1, _recipient, _a1Max);

        for (int24 _t = _lt; _t <= _ut; _t += _spacing) {
            // ? if includes current tick, we are slightly in short of liquidity
            if (uint24((_t + _spacing) - currentTick) <= uint24(_spacing)) continue;

            emit log_string("=== uniswapV3MintCallback ===");
            emit log_named_int("tick", _t);

            pool.mint(_recipient, _t, _t + _spacing, _l, "");
        }

        for (int24 _t = _lt; _t <= _ut; _t += _spacing) {
            bytes32 _positionKey = keccak256(abi.encodePacked(address(this), _t, _t + _spacing));
            (uint128 _liquidity, , , , ) = pool.positions(_positionKey);

            emit log_string("=== position ===");
            emit log_named_int("tickLower", _t);
            emit log_named_int("tickUpper", _t + _spacing);
            emit log_named_uint("liquidity", _liquidity);
        }
    }

    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata) external override {
        address _pool = msg.sender;

        emit log_named_uint("amount0Owed", amount0Owed);
        emit log_named_uint("amount1Owed", amount1Owed);
        emit log_named_uint("balance0", IERC20(token0).balanceOf(address(this)));
        emit log_named_uint("balance1", IERC20(token1).balanceOf(address(this)));

        IERC20(token0).transfer(_pool, amount0Owed);
        IERC20(token1).transfer(_pool, amount1Owed);
    }
}
