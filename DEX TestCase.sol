// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./dex.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DEXTest {
    DEX public dex;
    TestToken public token0;
    TestToken public token1;
    uint256 constant INITIAL_SUPPLY = 1000000 * 10**18;

    event TestResult(string testName, bool passed);

    constructor() {
        dex = new DEX();
        token0 = new TestToken("Token0", "TKN0", INITIAL_SUPPLY);
        token1 = new TestToken("Token1", "TKN1", INITIAL_SUPPLY);
    }

    function testAddLiquidity() public {
        uint256 amount0 = 1000 * 10**18;
        uint256 amount1 = 2000 * 10**18;

        token0.approve(address(dex), amount0);
        token1.approve(address(dex), amount1);

        dex.addLiquidity(address(token0), address(token1), amount0, amount1);

        (uint256 reserve0, uint256 reserve1) = dex.getReserves(address(token0), address(token1));

        emit TestResult("AddLiquidity", reserve0 == amount0 && reserve1 == amount1);
    }

    function testSwap() public {
        uint256 swapAmount = 100 * 10**18;
        token0.approve(address(dex), swapAmount);

        uint256 initialBalance = token1.balanceOf(address(this));
        dex.swap(address(token0), address(token1), swapAmount);
        uint256 finalBalance = token1.balanceOf(address(this));

        emit TestResult("Swap", finalBalance > initialBalance);
    }

    function testRemoveLiquidity() public {
        uint256 amount0 = 1000 * 10**18;
        uint256 amount1 = 2000 * 10**18;

        token0.approve(address(dex), amount0);
        token1.approve(address(dex), amount1);

        dex.addLiquidity(address(token0), address(token1), amount0, amount1);

        uint256 liquidityToRemove = dex.liquidity(address(this), address(token0), address(token1));

        uint256 initialBalance0 = token0.balanceOf(address(this));
        uint256 initialBalance1 = token1.balanceOf(address(this));

        dex.removeLiquidity(address(token0), address(token1), liquidityToRemove);

        uint256 finalBalance0 = token0.balanceOf(address(this));
        uint256 finalBalance1 = token1.balanceOf(address(this));

        emit TestResult("RemoveLiquidity", finalBalance0 > initialBalance0 && finalBalance1 > initialBalance1);
    }

    function testGetReserves() public {
        uint256 amount0 = 1000 * 10**18;
        uint256 amount1 = 2000 * 10**18;

        token0.approve(address(dex), amount0);
        token1.approve(address(dex), amount1);

        dex.addLiquidity(address(token0), address(token1), amount0, amount1);

        (uint256 reserve0, uint256 reserve1) = dex.getReserves(address(token0), address(token1));

        emit TestResult("GetReserves", reserve0 == amount0 && reserve1 == amount1);
    }

    function runAllTests() public {
        testAddLiquidity();
        testSwap();
        testRemoveLiquidity();
        testGetReserves();
    }
}