// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {HookMiner} from "@uniswap/v4-periphery/test/shared/HookMiner.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {CounterHook} from "../src/hooks/CounterHook.sol";
import {SimpleV4Router} from "../src/hooks/SimpleV4Router.sol";

/// @notice Registers CounterHook on a real V4 PoolManager (the same contract
/// deployed on testnets/mainnet), initializes a pool, adds liquidity, and
/// swaps through it. This is not a simulation of V4 mechanics; it runs
/// against the actual PoolManager/Hooks/PoolKey code from the v4-core repo.
contract V4HookTest is Test, Deployers {
    CounterHook hook;
    PoolKey poolKey;
    PoolId poolId;

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies(); // sets currency0 / currency1

        // The hook's callback bits must match its own deployed address bits
        // exactly (Hooks.validateHookPermissions enforces this in the
        // constructor; PoolManager enforces it again on initialize()).
        // The address can't be arbitrary, so we mine a salt that produces
        // one with the right bottom bits, then deploy via CREATE2 with it.
        uint160 flags = uint160(Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
        (address predictedAddress, bytes32 salt) =
            HookMiner.find(address(this), flags, type(CounterHook).creationCode, abi.encode(manager));

        hook = new CounterHook{salt: salt}(manager);
        assertEq(address(hook), predictedAddress, "hook did not deploy to the mined address");

        (poolKey, poolId) = initPoolAndAddLiquidity(currency0, currency1, IHooks(address(hook)), 3000, SQRT_PRICE_1_1);
    }

    // ---------------------------------------------------------------
    // SimpleV4Router: main case
    // ---------------------------------------------------------------
    function test_SimpleV4Router_SwapExactInputSingle_MainCase() public {
        SimpleV4Router router = new SimpleV4Router(manager);
        address tokenIn = Currency.unwrap(currency0);
        address tokenOut = Currency.unwrap(currency1);

        MockERC20(tokenIn).approve(address(router), type(uint256).max);
        uint256 balOutBefore = MockERC20(tokenOut).balanceOf(address(this));
        uint256 balInBefore = MockERC20(tokenIn).balanceOf(address(this));

        uint256 amountOut = router.swapExactInputSingle(
            tokenIn, tokenOut, poolKey.fee, poolKey.tickSpacing, address(hook), 1000, 0, ZERO_BYTES, block.timestamp + 1
        );

        assertGt(amountOut, 0);
        assertEq(MockERC20(tokenOut).balanceOf(address(this)), balOutBefore + amountOut);
        assertEq(MockERC20(tokenIn).balanceOf(address(this)), balInBefore - 1000);
        // hook fired for this swap too, proving the router goes through the real pool/hook, not around it
        assertEq(hook.beforeSwapCount(poolId), 1);
    }

    // ---------------------------------------------------------------
    // SimpleV4Router: failure case, slippage
    // ---------------------------------------------------------------
    function test_SimpleV4Router_RevertsOnSlippage() public {
        SimpleV4Router router = new SimpleV4Router(manager);
        address tokenIn = Currency.unwrap(currency0);
        address tokenOut = Currency.unwrap(currency1);
        MockERC20(tokenIn).approve(address(router), type(uint256).max);

        vm.expectRevert(); // TooLittleReceived
        router.swapExactInputSingle(
            tokenIn,
            tokenOut,
            poolKey.fee,
            poolKey.tickSpacing,
            address(hook),
            1000,
            1000, // demanding 1:1 output, impossible with the 0.30% fee
            ZERO_BYTES,
            block.timestamp + 1
        );
    }

    // ---------------------------------------------------------------
    // SimpleV4Router: failure case, expired deadline
    // ---------------------------------------------------------------
    function test_SimpleV4Router_RevertsOnExpiredDeadline() public {
        SimpleV4Router router = new SimpleV4Router(manager);
        address tokenIn = Currency.unwrap(currency0);
        address tokenOut = Currency.unwrap(currency1);
        MockERC20(tokenIn).approve(address(router), type(uint256).max);

        vm.warp(block.timestamp + 1 hours);
        vm.expectRevert(SimpleV4Router.Expired.selector);
        router.swapExactInputSingle(
            tokenIn,
            tokenOut,
            poolKey.fee,
            poolKey.tickSpacing,
            address(hook),
            1000,
            0,
            ZERO_BYTES,
            block.timestamp - 1 hours
        );
    }

    // ---------------------------------------------------------------
    // SimpleV4Router: failure case, direct unlockCallback call blocked
    // ---------------------------------------------------------------
    function test_SimpleV4Router_RevertsOnDirectCallbackCall() public {
        SimpleV4Router router = new SimpleV4Router(manager);
        vm.expectRevert(SimpleV4Router.NotPoolManager.selector);
        router.unlockCallback("");
    }

    // ---------------------------------------------------------------
    // main case: pool initializes and the hook actually gets invoked
    // ---------------------------------------------------------------
    function test_PoolInitialization_HookRegistered() public view {
        assertEq(address(poolKey.hooks), address(hook));
        // beforeAddLiquidity fired once, during setUp's initPoolAndAddLiquidity
        assertEq(hook.beforeAddLiquidityCount(poolId), 1);
    }

    function test_Swap_MainCase_HookCountsFire() public {
        assertEq(hook.beforeSwapCount(poolId), 0);
        assertEq(hook.afterSwapCount(poolId), 0);

        BalanceDelta delta = swap(poolKey, true, -1000, ZERO_BYTES); // zeroForOne exact-input

        assertEq(hook.beforeSwapCount(poolId), 1);
        assertEq(hook.afterSwapCount(poolId), 1);
        assertLt(delta.amount0(), 0); // swapper paid currency0
        assertGt(delta.amount1(), 0); // swapper received currency1
    }

    // ---------------------------------------------------------------
    // edge case: hook counters are per-pool, not global
    // ---------------------------------------------------------------
    function test_HookCounters_ArePerPool_NotGlobal() public {
        // Initialize a second, independent pool with the SAME hook instance
        // but a different fee tier (different PoolId).
        (PoolKey memory secondKey,) = initPool(currency0, currency1, IHooks(address(hook)), 500, SQRT_PRICE_1_1);
        PoolId secondId = secondKey.toId();

        swap(poolKey, true, -1000, ZERO_BYTES);

        assertEq(hook.beforeSwapCount(poolId), 1);
        assertEq(hook.beforeSwapCount(secondId), 0, "counters must not leak across pools");
    }

    // ---------------------------------------------------------------
    // failure case: only the PoolManager may call hook callbacks
    // ---------------------------------------------------------------
    function test_RevertsWhen_CalledDirectlyNotByPoolManager() public {
        vm.expectRevert(CounterHook.NotPoolManager.selector);
        hook.beforeAddLiquidity(address(this), poolKey, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    // ---------------------------------------------------------------
    // failure case: initializing a pool with a hook address whose bits
    // don't match its declared permissions must revert, not silently
    // downgrade permissions. Prove this with a hook that requests fewer
    // permissions than its address bits imply.
    // ---------------------------------------------------------------
    function test_RevertsWhen_HookAddressBitsDoNotMatchPermissions() public {
        // Mine an address with ONLY the beforeSwap bit set...
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);
        (, bytes32 salt) = HookMiner.find(address(this), flags, type(CounterHook).creationCode, abi.encode(manager));

        // ...but CounterHook's constructor demands beforeAddLiquidity + beforeSwap + afterSwap.
        // validateHookPermissions must revert during construction.
        vm.expectRevert();
        new CounterHook{salt: salt}(manager);
    }
}
