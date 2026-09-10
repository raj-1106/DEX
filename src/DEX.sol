// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @notice Constant-product AMM. Pools are keyed by the *sorted* token pair so
/// pools[A][B] and pools[B][A] can never diverge. A fixed MINIMUM_LIQUIDITY is
/// permanently unspendable (never credited to any user) to prevent the
/// first-depositor share-inflation attack. LP shares are tracked internally
/// and are NOT a transferable ERC20 (see review notes).
contract DEX is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 public constant FEE_NUMERATOR = 997;
    uint256 public constant FEE_DENOMINATOR = 1000;

    struct Pool {
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalSupply;
    }

    /// @dev Always accessed with token0 < token1 (see _sortTokens). Do not
    /// write to this mapping directly from a function that hasn't sorted.
    mapping(address token0 => mapping(address token1 => Pool)) public pools;
    mapping(address user => mapping(address token0 => mapping(address token1 => uint256))) public liquidity;

    event LiquidityAdded(
        address indexed user,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityMinted
    );
    event LiquidityRemoved(
        address indexed user,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityBurned
    );
    event Swap(
        address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    modifier ensure(uint256 deadline) {
        require(block.timestamp <= deadline, "DEX: EXPIRED");
        _;
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "DEX: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "DEX: ZERO_ADDRESS");
    }

    /// @notice Add liquidity to the tokenA/tokenB pool. Handles fee-on-transfer
    /// tokens by crediting reserves with the amount actually received, not
    /// the amount requested.
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        uint256 deadline
    ) external nonReentrant ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidityMinted) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        bool sameOrder = tokenA == token0;

        Pool storage pool = pools[token0][token1];
        bool isFirstMint = pool.totalSupply == 0;

        uint256 amount0Desired = sameOrder ? amountADesired : amountBDesired;
        uint256 amount1Desired = sameOrder ? amountBDesired : amountADesired;
        uint256 amount0Min = sameOrder ? amountAMin : amountBMin;
        uint256 amount1Min = sameOrder ? amountBMin : amountAMin;
        require(amount0Desired > 0 && amount1Desired > 0, "DEX: INVALID_AMOUNT");

        uint256 amount0;
        uint256 amount1;
        if (isFirstMint) {
            amount0 = amount0Desired;
            amount1 = amount1Desired;
        } else {
            uint256 amount1Optimal = Math.mulDiv(amount0Desired, pool.reserve1, pool.reserve0);
            if (amount1Optimal <= amount1Desired) {
                amount0 = amount0Desired;
                amount1 = amount1Optimal;
            } else {
                amount0 = Math.mulDiv(amount1Desired, pool.reserve0, pool.reserve1);
                amount1 = amount1Desired;
            }
        }
        require(amount0 >= amount0Min && amount1 >= amount1Min, "DEX: SLIPPAGE");

        IERC20 t0 = IERC20(token0);
        IERC20 t1 = IERC20(token1);

        uint256 bal0Before = t0.balanceOf(address(this));
        uint256 bal1Before = t1.balanceOf(address(this));
        t0.safeTransferFrom(msg.sender, address(this), amount0);
        t1.safeTransferFrom(msg.sender, address(this), amount1);
        uint256 received0 = t0.balanceOf(address(this)) - bal0Before;
        uint256 received1 = t1.balanceOf(address(this)) - bal1Before;
        require(received0 > 0 && received1 > 0, "DEX: NO_TOKENS_RECEIVED");

        if (isFirstMint) {
            uint256 rawLiquidity = Math.sqrt(received0 * received1);
            require(rawLiquidity > MINIMUM_LIQUIDITY, "DEX: INSUFFICIENT_INITIAL_LIQUIDITY");
            liquidityMinted = rawLiquidity - MINIMUM_LIQUIDITY;
            pool.totalSupply = rawLiquidity; // includes the locked, never-credited portion
        } else {
            uint256 liq0 = Math.mulDiv(received0, pool.totalSupply, pool.reserve0);
            uint256 liq1 = Math.mulDiv(received1, pool.totalSupply, pool.reserve1);
            liquidityMinted = liq0 < liq1 ? liq0 : liq1;
            require(liquidityMinted > 0, "DEX: INSUFFICIENT_LIQUIDITY_MINTED");
            pool.totalSupply += liquidityMinted;
        }

        pool.reserve0 += received0;
        pool.reserve1 += received1;
        liquidity[msg.sender][token0][token1] += liquidityMinted;

        (amountA, amountB) = sameOrder ? (received0, received1) : (received1, received0);
        emit LiquidityAdded(msg.sender, token0, token1, received0, received1, liquidityMinted);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidityBurned,
        uint256 amountAMin,
        uint256 amountBMin,
        uint256 deadline
    ) external nonReentrant ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        bool sameOrder = tokenA == token0;

        require(liquidityBurned > 0, "DEX: INVALID_LIQUIDITY");
        Pool storage pool = pools[token0][token1];
        require(pool.totalSupply > 0, "DEX: POOL_NOT_FOUND");
        require(liquidity[msg.sender][token0][token1] >= liquidityBurned, "DEX: INSUFFICIENT_BALANCE");

        uint256 amount0 = Math.mulDiv(liquidityBurned, pool.reserve0, pool.totalSupply);
        uint256 amount1 = Math.mulDiv(liquidityBurned, pool.reserve1, pool.totalSupply);
        require(amount0 > 0 && amount1 > 0, "DEX: INSUFFICIENT_LIQUIDITY_BURNED");

        (uint256 amount0Min, uint256 amount1Min) = sameOrder ? (amountAMin, amountBMin) : (amountBMin, amountAMin);
        require(amount0 >= amount0Min && amount1 >= amount1Min, "DEX: SLIPPAGE");

        // Effects before interactions: full CEI is achievable here because
        // outputs are derived from state, not measured after an external call.
        liquidity[msg.sender][token0][token1] -= liquidityBurned;
        pool.totalSupply -= liquidityBurned;
        pool.reserve0 -= amount0;
        pool.reserve1 -= amount1;

        IERC20(token0).safeTransfer(msg.sender, amount0);
        IERC20(token1).safeTransfer(msg.sender, amount1);

        (amountA, amountB) = sameOrder ? (amount0, amount1) : (amount1, amount0);
        emit LiquidityRemoved(msg.sender, token0, token1, amount0, amount1, liquidityBurned);
    }

    /// @notice Swap exact `amountIn` of tokenIn for tokenOut. Reverts if the
    /// output would be below `amountOutMin`. Handles fee-on-transfer tokenIn
    /// by pricing off the amount actually received.
    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOutMin, uint256 deadline)
        external
        nonReentrant
        ensure(deadline)
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "DEX: INVALID_AMOUNT_IN");
        (address token0, address token1) = _sortTokens(tokenIn, tokenOut);
        bool inIsToken0 = tokenIn == token0;

        Pool storage pool = pools[token0][token1];
        require(pool.totalSupply > 0, "DEX: POOL_NOT_FOUND");
        require(pool.reserve0 > 0 && pool.reserve1 > 0, "DEX: EMPTY_RESERVES");

        IERC20 tIn = IERC20(tokenIn);
        IERC20 tOut = IERC20(tokenOut);

        // NOTE: this is the one external call in this contract that happens
        // before state is finalized (needed to measure fee-on-transfer
        // amounts). `nonReentrant` above is the load-bearing defense against
        // reentrancy here, not call ordering.
        uint256 balInBefore = tIn.balanceOf(address(this));
        tIn.safeTransferFrom(msg.sender, address(this), amountIn);
        uint256 actualAmountIn = tIn.balanceOf(address(this)) - balInBefore;
        require(actualAmountIn > 0, "DEX: NO_TOKENS_RECEIVED");

        (uint256 reserveIn, uint256 reserveOut) =
            inIsToken0 ? (pool.reserve0, pool.reserve1) : (pool.reserve1, pool.reserve0);

        uint256 amountInWithFee = actualAmountIn * FEE_NUMERATOR;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountInWithFee;
        amountOut = numerator / denominator;

        require(amountOut > 0, "DEX: INSUFFICIENT_OUTPUT_AMOUNT");
        require(amountOut >= amountOutMin, "DEX: SLIPPAGE");
        require(amountOut < reserveOut, "DEX: INSUFFICIENT_LIQUIDITY");

        if (inIsToken0) {
            pool.reserve0 += actualAmountIn;
            pool.reserve1 -= amountOut;
        } else {
            pool.reserve1 += actualAmountIn;
            pool.reserve0 -= amountOut;
        }

        tOut.safeTransfer(msg.sender, amountOut);
        emit Swap(msg.sender, tokenIn, tokenOut, actualAmountIn, amountOut);
    }

    function getReserves(address tokenA, address tokenB) external view returns (uint256 reserveA, uint256 reserveB) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        Pool storage pool = pools[token0][token1];
        (reserveA, reserveB) = tokenA == token0 ? (pool.reserve0, pool.reserve1) : (pool.reserve1, pool.reserve0);
    }

    function getLiquidityBalance(address user, address tokenA, address tokenB) external view returns (uint256) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        return liquidity[user][token0][token1];
    }
}
