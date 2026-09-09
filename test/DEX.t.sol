// test/DEX.t.sol
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/DEX.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor(string memory name, string memory symbol, uint256 supply) ERC20(name, symbol) {
        _mint(msg.sender, supply);
    }
}

/// Takes a 2% cut on every transfer, simulating a real fee-on-transfer token.
contract FeeToken is ERC20 {
    constructor(uint256 supply) ERC20("Fee Token", "FEE") {
        _mint(msg.sender, supply);
    }
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) {
            uint256 fee = value * 2 / 100;
            super._update(from, address(0xdead), fee);
            super._update(from, to, value - fee);
        } else {
            super._update(from, to, value);
        }
    }
}

contract ReentrantToken is ERC20 {
    DEX public target;
    address public otherToken;
    bool public attacking;

    constructor(DEX _target) ERC20("Evil", "EVIL") {
        target = _target;
        _mint(msg.sender, 1_000_000 ether);
    }
    function setOtherToken(address _other) external { otherToken = _other; }
    function startAttack() external { attacking = true; }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        bool ok = super.transferFrom(from, to, amount);
        if (attacking) {
            attacking = false;
            target.swap(address(this), otherToken, amount, 0, block.timestamp + 1);
        }
        return ok;
    }
}

contract DEXTest is Test {
    DEX dex;
    TestToken tokenA;
    TestToken tokenB;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        dex = new DEX();
        tokenA = new TestToken("Token A", "TKA", 1_000_000 ether);
        tokenB = new TestToken("Token B", "TKB", 1_000_000 ether);
        tokenA.transfer(alice, 10_000 ether);
        tokenB.transfer(alice, 10_000 ether);
        tokenA.transfer(bob, 10_000 ether);
        tokenB.transfer(bob, 10_000 ether);
    }

    // --- Main case ---
    function test_AddLiquidity_And_Swap_HappyPath() public {
        vm.startPrank(alice);
        tokenA.approve(address(dex), 1_000 ether);
        tokenB.approve(address(dex), 1_000 ether);
        dex.addLiquidity(address(tokenA), address(tokenB), 1_000 ether, 1_000 ether, 0, 0, block.timestamp + 1);
        vm.stopPrank();

        vm.startPrank(bob);
        tokenA.approve(address(dex), 100 ether);
        uint256 before = tokenB.balanceOf(bob);
        dex.swap(address(tokenA), address(tokenB), 100 ether, 0, block.timestamp + 1);
        assertGt(tokenB.balanceOf(bob), before);
        vm.stopPrank();
    }

    // --- Edge case: this is the actual regression test for issue #2 ---
    // Confirms addLiquidity(A,B) and a later swap(B,A) hit the SAME pool,
    // which was impossible before the _sortTokens fix.
    function test_PoolIdentity_IsOrderIndependent() public {
        vm.startPrank(alice);
        tokenA.approve(address(dex), 1_000 ether);
        tokenB.approve(address(dex), 1_000 ether);
        // Seed using (tokenA, tokenB) order.
        dex.addLiquidity(address(tokenA), address(tokenB), 1_000 ether, 1_000 ether, 0, 0, block.timestamp + 1);
        vm.stopPrank();

        vm.startPrank(bob);
        tokenB.approve(address(dex), 100 ether);
        // Swap using the REVERSED order — must succeed against the same pool.
        uint256 out = dex.swap(address(tokenB), address(tokenA), 100 ether, 0, block.timestamp + 1);
        assertGt(out, 0, "reversed-order swap must resolve to the same pool");
        vm.stopPrank();
    }

    // --- Edge case: fee-on-transfer accounting uses actual received amount ---
    function test_FeeOnTransferToken_PricesOffActualReceivedAmount() public {
        FeeToken feeToken = new FeeToken(1_000_000 ether);
        feeToken.transfer(alice, 10_000 ether);
        feeToken.transfer(bob, 10_000 ether);

        vm.startPrank(alice);
        feeToken.approve(address(dex), 1_000 ether);
        tokenB.approve(address(dex), 1_000 ether);
        // Request 1000, but ~2% fee means ~980 actually arrives.
        dex.addLiquidity(address(feeToken), address(tokenB), 1_000 ether, 1_000 ether, 0, 0, block.timestamp + 1);
        vm.stopPrank();

        (uint256 reserveFee,) = dex.getReserves(address(feeToken), address(tokenB));
        assertLt(reserveFee, 1_000 ether, "reserve should reflect actual received amount, not requested amount");
        assertApproxEqRel(reserveFee, 980 ether, 0.01e18);
    }

    // --- Edge case: slippage protection ---
    function test_Swap_RevertsOnSlippageViolation() public {
        vm.startPrank(alice);
        tokenA.approve(address(dex), 1_000 ether);
        tokenB.approve(address(dex), 1_000 ether);
        dex.addLiquidity(address(tokenA), address(tokenB), 1_000 ether, 1_000 ether, 0, 0, block.timestamp + 1);
        vm.stopPrank();

        vm.startPrank(bob);
        tokenA.approve(address(dex), 100 ether);
        vm.expectRevert("DEX: SLIPPAGE");
        dex.swap(address(tokenA), address(tokenB), 100 ether, 1_000 ether, block.timestamp + 1);
        vm.stopPrank();
    }

    // --- Failure case: expired deadline ---
    function test_Swap_RevertsOnExpiredDeadline() public {
        vm.startPrank(alice);
        tokenA.approve(address(dex), 1_000 ether);
        tokenB.approve(address(dex), 1_000 ether);
        dex.addLiquidity(address(tokenA), address(tokenB), 1_000 ether, 1_000 ether, 0, 0, block.timestamp + 1);
        vm.stopPrank();

        vm.startPrank(bob);
        tokenA.approve(address(dex), 100 ether);
        vm.expectRevert("DEX: EXPIRED");
        dex.swap(address(tokenA), address(tokenB), 100 ether, 0, block.timestamp - 1);
        vm.stopPrank();
    }

    // --- Failure case: the actual reentrancy attack, must now revert ---
    function test_Swap_BlocksReentrancy() public {
        ReentrantToken evil = new ReentrantToken(dex);
        evil.setOtherToken(address(tokenB));

        evil.approve(address(dex), 1_000 ether);
        tokenB.approve(address(dex), 1_000 ether);
        dex.addLiquidity(address(evil), address(tokenB), 1_000 ether, 1_000 ether, 0, 0, block.timestamp + 1);

        evil.approve(address(dex), 100 ether);
        evil.startAttack();
        vm.expectRevert();
        dex.swap(address(evil), address(tokenB), 100 ether, 0, block.timestamp + 1);
    }

    // --- Failure case: first deposit below MINIMUM_LIQUIDITY reverts ---
    function test_AddLiquidity_RevertsIfBelowMinimumLiquidity() public {
        vm.startPrank(alice);
        tokenA.approve(address(dex), 100);
        tokenB.approve(address(dex), 100);
        vm.expectRevert("DEX: INSUFFICIENT_INITIAL_LIQUIDITY");
        dex.addLiquidity(address(tokenA), address(tokenB), 100, 100, 0, 0, block.timestamp + 1);
        vm.stopPrank();
    }
}
