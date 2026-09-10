// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DEX} from "../src/DEX.sol";
import {TestToken, FeeOnTransferToken, ReturnsFalseToken, ReentrantAttackerToken} from "../src/mocks/Mocks.sol";

contract DEXTest is Test {
    DEX dex;
    TestToken tokenA;
    TestToken tokenB;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint256 constant INITIAL_MINT = 1_000_000 ether;

    function setUp() public {
        dex = new DEX();
        tokenA = new TestToken("Token A", "TKA", 0);
        tokenB = new TestToken("Token B", "TKB", 0);

        tokenA.mint(alice, INITIAL_MINT);
        tokenB.mint(alice, INITIAL_MINT);
        tokenA.mint(bob, INITIAL_MINT);
        tokenB.mint(bob, INITIAL_MINT);

        vm.prank(alice);
        tokenA.approve(address(dex), type(uint256).max);
        vm.prank(alice);
        tokenB.approve(address(dex), type(uint256).max);
        vm.prank(bob);
        tokenA.approve(address(dex), type(uint256).max);
        vm.prank(bob);
        tokenB.approve(address(dex), type(uint256).max);
    }

    function _addInitialLiquidity(address user, uint256 amt0, uint256 amt1) internal {
        vm.prank(user);
        dex.addLiquidity(address(tokenA), address(tokenB), amt0, amt1, 0, 0, block.timestamp + 1 hours);
    }

    // ---------------------------------------------------------------------
    // addLiquidity: main case
    // ---------------------------------------------------------------------
    function test_AddLiquidity_InitialMint_MainCase() public {
        _addInitialLiquidity(alice, 10_000 ether, 10_000 ether);

        (uint256 rA, uint256 rB) = dex.getReserves(address(tokenA), address(tokenB));
        assertEq(rA, 10_000 ether);
        assertEq(rB, 10_000 ether);

        uint256 expectedLiquidity = 10_000 ether - dex.MINIMUM_LIQUIDITY();
        assertEq(dex.getLiquidityBalance(alice, address(tokenA), address(tokenB)), expectedLiquidity);
    }

    // ---------------------------------------------------------------------
    // addLiquidity: canonical ordering fix (was exploit #2)
    // ---------------------------------------------------------------------
    function test_AddLiquidity_OrderIndependence() public {
        _addInitialLiquidity(alice, 10_000 ether, 20_000 ether);

        // Bob adds liquidity with arguments in the OPPOSITE order.
        vm.prank(bob);
        (uint256 amtA, uint256 amtB, uint256 minted) = dex.addLiquidity(
            address(tokenB), address(tokenA), 2_000 ether, 1_000 ether, 0, 0, block.timestamp + 1 hours
        );

        // Must land in the SAME pool as alice's, proportionally.
        (uint256 rA, uint256 rB) = dex.getReserves(address(tokenA), address(tokenB));
        assertEq(rA, 11_000 ether);
        assertEq(rB, 22_000 ether);
        assertGt(minted, 0);
        assertEq(amtA, 2_000 ether); // amountA corresponds to tokenB here since bob passed tokenB first... see below
        // amtA/amtB are returned in the order the caller passed tokens: (tokenB, tokenA)
        assertEq(amtB, 1_000 ether);
    }

    // ---------------------------------------------------------------------
    // addLiquidity: edge case, minimum liquidity lock
    // ---------------------------------------------------------------------
    function test_AddLiquidity_MinimumLiquidityIsLockedForever() public {
        _addInitialLiquidity(alice, 10_000 ether, 10_000 ether);

        uint256 aliceBalance = dex.getLiquidityBalance(alice, address(tokenA), address(tokenB));
        (,, uint256 totalSupplyBefore) = _poolFields();
        assertEq(totalSupplyBefore, aliceBalance + dex.MINIMUM_LIQUIDITY());

        // Alice withdraws her ENTIRE tracked balance.
        vm.prank(alice);
        dex.removeLiquidity(address(tokenA), address(tokenB), aliceBalance, 0, 0, block.timestamp + 1 hours);

        (uint256 rA, uint256 rB, uint256 totalSupplyAfter) = _poolFields();
        // totalSupply never reaches zero: MINIMUM_LIQUIDITY is unspendable.
        assertEq(totalSupplyAfter, dex.MINIMUM_LIQUIDITY());
        // reserves are not fully drained either.
        assertGt(rA, 0);
        assertGt(rB, 0);
    }

    function _poolFields() internal view returns (uint256 r0, uint256 r1, uint256 ts) {
        (address t0,) =
            address(tokenA) < address(tokenB) ? (address(tokenA), address(tokenB)) : (address(tokenB), address(tokenA));
        (r0, r1, ts) = dex.pools(t0, t0 == address(tokenA) ? address(tokenB) : address(tokenA));
    }

    // ---------------------------------------------------------------------
    // addLiquidity: failure case, dust initial deposit
    // ---------------------------------------------------------------------
    function test_AddLiquidity_RevertsOnDustInitialDeposit() public {
        vm.prank(alice);
        vm.expectRevert(bytes("DEX: INSUFFICIENT_INITIAL_LIQUIDITY"));
        dex.addLiquidity(address(tokenA), address(tokenB), 10, 10, 0, 0, block.timestamp + 1 hours);
    }

    // ---------------------------------------------------------------------
    // addLiquidity: failure case, slippage
    // ---------------------------------------------------------------------
    function test_AddLiquidity_RevertsOnSlippage() public {
        _addInitialLiquidity(alice, 10_000 ether, 10_000 ether);

        vm.prank(bob);
        vm.expectRevert(bytes("DEX: SLIPPAGE"));
        // Pool is 1:1, bob demands unrealistic amountBMin given amountADesired.
        dex.addLiquidity(
            address(tokenA), address(tokenB), 1_000 ether, 1_000 ether, 0, 1_000 ether + 1, block.timestamp + 1 hours
        );
    }

    // ---------------------------------------------------------------------
    // removeLiquidity: main case
    // ---------------------------------------------------------------------
    function test_RemoveLiquidity_MainCase() public {
        _addInitialLiquidity(alice, 10_000 ether, 10_000 ether);
        uint256 bal = dex.getLiquidityBalance(alice, address(tokenA), address(tokenB));
        uint256 balBeforeA = tokenA.balanceOf(alice);

        vm.prank(alice);
        (uint256 amtA, uint256 amtB) =
            dex.removeLiquidity(address(tokenA), address(tokenB), bal / 2, 0, 0, block.timestamp + 1 hours);

        assertGt(amtA, 0);
        assertGt(amtB, 0);
        assertEq(tokenA.balanceOf(alice), balBeforeA + amtA);
    }

    // ---------------------------------------------------------------------
    // removeLiquidity: failure case, over-withdrawal
    // ---------------------------------------------------------------------
    function test_RemoveLiquidity_RevertsOnInsufficientBalance() public {
        _addInitialLiquidity(alice, 10_000 ether, 10_000 ether);
        uint256 bal = dex.getLiquidityBalance(alice, address(tokenA), address(tokenB));

        vm.prank(alice);
        vm.expectRevert(bytes("DEX: INSUFFICIENT_BALANCE"));
        dex.removeLiquidity(address(tokenA), address(tokenB), bal + 1, 0, 0, block.timestamp + 1 hours);
    }

    // ---------------------------------------------------------------------
    // removeLiquidity: failure case, expired deadline
    // ---------------------------------------------------------------------
    function test_RemoveLiquidity_RevertsOnExpiredDeadline() public {
        _addInitialLiquidity(alice, 10_000 ether, 10_000 ether);
        uint256 bal = dex.getLiquidityBalance(alice, address(tokenA), address(tokenB));

        vm.warp(block.timestamp + 2 hours);
        vm.prank(alice);
        vm.expectRevert(bytes("DEX: EXPIRED"));
        dex.removeLiquidity(address(tokenA), address(tokenB), bal, 0, 0, block.timestamp - 1 hours);
    }

    // ---------------------------------------------------------------------
    // swap: main case
    // ---------------------------------------------------------------------
    function test_Swap_MainCase() public {
        _addInitialLiquidity(alice, 100_000 ether, 100_000 ether);

        uint256 balBefore = tokenB.balanceOf(bob);
        vm.prank(bob);
        uint256 out = dex.swap(address(tokenA), address(tokenB), 1_000 ether, 0, block.timestamp + 1 hours);

        assertGt(out, 0);
        assertLt(out, 1_000 ether); // fee + slippage means less than 1:1
        assertEq(tokenB.balanceOf(bob), balBefore + out);
    }

    // ---------------------------------------------------------------------
    // swap: edge case, k invariant must not decrease across a swap (fee accrues)
    // ---------------------------------------------------------------------
    function test_Swap_KInvariantNonDecreasing() public {
        _addInitialLiquidity(alice, 100_000 ether, 100_000 ether);
        (uint256 r0Before, uint256 r1Before) = dex.getReserves(address(tokenA), address(tokenB));
        uint256 kBefore = r0Before * r1Before;

        vm.prank(bob);
        dex.swap(address(tokenA), address(tokenB), 5_000 ether, 0, block.timestamp + 1 hours);

        (uint256 r0After, uint256 r1After) = dex.getReserves(address(tokenA), address(tokenB));
        uint256 kAfter = r0After * r1After;
        assertGe(kAfter, kBefore);
    }

    // ---------------------------------------------------------------------
    // swap: failure case, slippage
    // ---------------------------------------------------------------------
    function test_Swap_RevertsOnSlippage() public {
        _addInitialLiquidity(alice, 100_000 ether, 100_000 ether);

        vm.prank(bob);
        vm.expectRevert(bytes("DEX: SLIPPAGE"));
        dex.swap(address(tokenA), address(tokenB), 1_000 ether, 1_000 ether, block.timestamp + 1 hours); // demanding 1:1, impossible with fee
    }

    // ---------------------------------------------------------------------
    // swap: failure case, expired deadline
    // ---------------------------------------------------------------------
    function test_Swap_RevertsOnExpiredDeadline() public {
        _addInitialLiquidity(alice, 100_000 ether, 100_000 ether);

        vm.warp(block.timestamp + 2 hours);
        vm.prank(bob);
        vm.expectRevert(bytes("DEX: EXPIRED"));
        dex.swap(address(tokenA), address(tokenB), 1_000 ether, 0, block.timestamp - 1 hours);
    }

    // ---------------------------------------------------------------------
    // swap: failure case, no pool exists
    // ---------------------------------------------------------------------
    function test_Swap_RevertsWhenPoolDoesNotExist() public {
        TestToken tokenC = new TestToken("C", "C", 0);
        vm.prank(bob);
        vm.expectRevert(bytes("DEX: POOL_NOT_FOUND"));
        dex.swap(address(tokenA), address(tokenC), 1 ether, 0, block.timestamp + 1 hours);
    }

    // ---------------------------------------------------------------------
    // fee-on-transfer token: prices off actual received amount (was exploit #5)
    // ---------------------------------------------------------------------
    function test_Swap_FeeOnTransferToken_PricesOffActualReceived() public {
        FeeOnTransferToken feeToken = new FeeOnTransferToken("Fee", "FEE", 1_000_000 ether, 200); // 2% fee
        feeToken.transfer(alice, 100_000 ether);
        feeToken.transfer(bob, 100_000 ether);

        vm.prank(alice);
        feeToken.approve(address(dex), type(uint256).max);
        vm.prank(bob);
        feeToken.approve(address(dex), type(uint256).max);

        vm.prank(alice);
        dex.addLiquidity(
            address(feeToken), address(tokenA), 10_000 ether, 10_000 ether, 0, 0, block.timestamp + 1 hours
        );

        // reserve for feeToken should reflect the post-fee amount actually received (9,800 not 10,000)
        (uint256 rFee,) = dex.getReserves(address(feeToken), address(tokenA));
        assertEq(rFee, 9_800 ether);

        // Now swap feeToken in; contract must not think it received more than it did.
        uint256 balBefore = tokenA.balanceOf(bob);
        vm.prank(bob);
        uint256 out = dex.swap(address(feeToken), address(tokenA), 1_000 ether, 0, block.timestamp + 1 hours);
        assertGt(out, 0);
        assertEq(tokenA.balanceOf(bob), balBefore + out);

        // sanity: reserve0 recorded for feeToken increased by the post-fee amount (980), not 1000
        (uint256 rFeeAfter,) = dex.getReserves(address(feeToken), address(tokenA));
        assertEq(rFeeAfter, 9_800 ether + 980 ether);
    }

    // ---------------------------------------------------------------------
    // non-compliant token (returns false instead of reverting): SafeERC20 catches it
    // ---------------------------------------------------------------------
    function test_AddLiquidity_RevertsOnNonCompliantTokenTransfer() public {
        // badToken.transfer/transferFrom always return false. DEX holds badToken
        // as the deployer minted it directly to address(this) (the test contract),
        // so we can call addLiquidity from here without needing alice to hold it.
        ReturnsFalseToken badToken = new ReturnsFalseToken("Bad", "BAD", 1_000_000 ether);
        badToken.approve(address(dex), type(uint256).max);
        tokenA.mint(address(this), INITIAL_MINT);
        tokenA.approve(address(dex), type(uint256).max);

        vm.expectRevert(); // SafeERC20: ERC20 operation did not succeed
        dex.addLiquidity(address(badToken), address(tokenA), 1_000 ether, 1_000 ether, 0, 0, block.timestamp + 1 hours);
    }

    // ---------------------------------------------------------------------
    // reentrancy: attacker token tries to re-enter swap()
    // ---------------------------------------------------------------------
    function test_Reentrancy_SwapBlocked() public {
        ReentrantAttackerToken evilToken = new ReentrantAttackerToken("Evil", "EVIL", 1_000_000 ether);
        evilToken.setTarget(dex, address(tokenA));

        // Seed a legit pool: evilToken/tokenA
        evilToken.approve(address(dex), type(uint256).max);
        tokenA.mint(address(this), INITIAL_MINT);
        tokenA.approve(address(dex), type(uint256).max);
        dex.addLiquidity(
            address(evilToken), address(tokenA), 10_000 ether, 10_000 ether, 0, 0, block.timestamp + 1 hours
        );

        evilToken.setAttackOnSwap(true);

        vm.expectRevert(); // ReentrancyGuard: reentrant call
        dex.swap(address(evilToken), address(tokenA), 1_000 ether, 0, block.timestamp + 1 hours);
    }

    // ---------------------------------------------------------------------
    // reentrancy: attacker token tries to re-enter addLiquidity()
    // ---------------------------------------------------------------------
    function test_Reentrancy_AddLiquidityBlocked() public {
        ReentrantAttackerToken evilToken = new ReentrantAttackerToken("Evil", "EVIL", 1_000_000 ether);
        evilToken.setTarget(dex, address(tokenA));
        evilToken.approve(address(dex), type(uint256).max);
        tokenA.mint(address(this), INITIAL_MINT);
        tokenA.approve(address(dex), type(uint256).max);

        evilToken.setAttackOnAddLiquidity(true);

        vm.expectRevert(); // ReentrancyGuard: reentrant call
        dex.addLiquidity(
            address(evilToken), address(tokenA), 10_000 ether, 10_000 ether, 0, 0, block.timestamp + 1 hours
        );
    }

    // ---------------------------------------------------------------------
    // fuzz: swap output should never exceed the constant-product bound
    // ---------------------------------------------------------------------
    function testFuzz_Swap_NeverExceedsReserveOut(uint256 amountIn) public {
        _addInitialLiquidity(alice, 50_000 ether, 50_000 ether);
        // Below ~1e6 wei against ether-scale reserves, amountOut rounds to 0
        // and the contract correctly reverts (DEX: INSUFFICIENT_OUTPUT_AMOUNT)
        // rather than paying out nothing. That's intended behavior, not the
        // property this fuzz test is checking, so keep amountIn above dust.
        amountIn = bound(amountIn, 1e6, 1_000_000 ether);

        tokenA.mint(bob, amountIn);
        vm.prank(bob);
        tokenA.approve(address(dex), amountIn);

        (, uint256 reserveOutBefore) = dex.getReserves(address(tokenA), address(tokenB));

        vm.prank(bob);
        uint256 out = dex.swap(address(tokenA), address(tokenB), amountIn, 0, block.timestamp + 1 hours);

        assertLt(out, reserveOutBefore);
    }
}
