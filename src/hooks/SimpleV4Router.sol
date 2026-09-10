// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

/// @notice Minimal single-hop, ERC20-only, exact-input swap router for V4
/// pools. Deliberately narrow scope: no native ETH handling, no multi-hop,
/// no caller-specified recipient. Written because pointing a frontend at
/// Uniswap's official router requires an address I could not verify as
/// currently live on Sepolia in this session (see deployment notes).
contract SimpleV4Router is IUnlockCallback, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IPoolManager public immutable poolManager;

    error NotPoolManager();
    error Expired();
    error TooLittleReceived(uint256 amountOut, uint256 amountOutMinimum);

    struct CallbackData {
        address swapper;
        PoolKey key;
        SwapParams params;
        bytes hookData;
    }

    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }

    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
    }

    /// @param tokenIn token the caller is paying
    /// @param tokenOut token the caller wants to receive
    /// @param fee pool fee tier (must match the pool's PoolKey exactly)
    /// @param tickSpacing pool tick spacing (must match the pool's PoolKey exactly)
    /// @param hooks the hook contract address the pool was initialized with (address(0) if none)
    function swapExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        int24 tickSpacing,
        address hooks,
        uint256 amountIn,
        uint256 amountOutMinimum,
        bytes calldata hookData,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOut) {
        if (block.timestamp > deadline) revert Expired();

        bool zeroForOne = tokenIn < tokenOut;
        (Currency currency0, Currency currency1) = zeroForOne
            ? (Currency.wrap(tokenIn), Currency.wrap(tokenOut))
            : (Currency.wrap(tokenOut), Currency.wrap(tokenIn));

        PoolKey memory key = PoolKey({
            currency0: currency0, currency1: currency1, fee: fee, tickSpacing: tickSpacing, hooks: IHooks(hooks)
        });

        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(amountIn), // negative = exact input
            sqrtPriceLimitX96: zeroForOne ? 4295128740 : 1461446703485210103287273052203988822378723970341 // MIN+1 / MAX-1
        });

        bytes memory result = poolManager.unlock(abi.encode(CallbackData(msg.sender, key, params, hookData)));
        BalanceDelta delta = abi.decode(result, (BalanceDelta));

        amountOut = zeroForOne ? uint256(uint128(delta.amount1())) : uint256(uint128(delta.amount0()));
        if (amountOut < amountOutMinimum) revert TooLittleReceived(amountOut, amountOutMinimum);
    }

    function unlockCallback(bytes calldata rawData) external onlyPoolManager returns (bytes memory) {
        CallbackData memory data = abi.decode(rawData, (CallbackData));

        BalanceDelta delta = poolManager.swap(data.key, data.params, data.hookData);

        int128 delta0 = delta.amount0();
        int128 delta1 = delta.amount1();

        // Pay what we owe the pool (negative deltas).
        if (delta0 < 0) _settle(data.key.currency0, data.swapper, uint256(uint128(-delta0)));
        if (delta1 < 0) _settle(data.key.currency1, data.swapper, uint256(uint128(-delta1)));

        // Collect what the pool owes us (positive deltas).
        if (delta0 > 0) poolManager.take(data.key.currency0, data.swapper, uint256(uint128(delta0)));
        if (delta1 > 0) poolManager.take(data.key.currency1, data.swapper, uint256(uint128(delta1)));

        return abi.encode(delta);
    }

    function _settle(Currency currency, address payer, uint256 amount) internal {
        poolManager.sync(currency);
        IERC20(Currency.unwrap(currency)).safeTransferFrom(payer, address(poolManager), amount);
        poolManager.settle();
    }
}
