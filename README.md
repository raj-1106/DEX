# DEX (hardened rewrite)

## Setup
```
forge install foundry-rs/forge-std --no-git
forge install OpenZeppelin/openzeppelin-contracts --no-git
forge test -vv
```

Requires solc 0.8.24 and `via_ir = true` (already set in foundry.toml) because
the functions have enough local variables to hit "stack too deep" without it.

## What changed from the original and why
See DEX.sol comments and the accompanying review for the full rationale:
reentrancy guard, canonical (sorted) pool keys, MINIMUM_LIQUIDITY lock,
slippage + deadline params on every state-changing function, SafeERC20,
and fee-on-transfer-safe accounting via measured balance deltas.

## Known limitations (not bugs, scope decisions)
- LP positions are an internal mapping, not a transferable ERC20. A real
  Uniswap V2-style deployment would give each pool its own LP token via a
  factory + clone pattern.
- Only two-token constant-product pools; no multi-hop routing.

## Uniswap V4 hook (CounterHook)

`src/hooks/CounterHook.sol` registers a real pool on the actual V4
`PoolManager` (same contract as testnet/mainnet, imported from
`Uniswap/v4-core`). It's deliberately low-privilege: it requests no
return-delta permissions, so it can count `beforeAddLiquidity`/`beforeSwap`/
`afterSwap` events but cannot move value in or out of a pool even if it has
a bug. Verified against v4-core's own `Deployers`/`PoolSwapTest`/`HookMiner`
test harness (5 tests, `test/V4Hook.t.sol`), not a mock of V4 behavior.

```
forge install Uniswap/v4-core --no-git
forge install Uniswap/v4-periphery --no-git
forge test --match-path test/V4Hook.t.sol -vv
```

Requires solc 0.8.26 exactly (PoolManager.sol pins it with a non-caret
pragma) plus `via_ir = true`; both are already set in foundry.toml.

To actually deploy to a testnet: `script/DeployV4Hook.s.sol`, set
`POOL_MANAGER`/`TOKEN0`/`TOKEN1` env vars and run with
`forge script script/DeployV4Hook.s.sol --rpc-url <testnet> --broadcast`.
Read the comment in that file about CREATE2_DEPLOYER before running it —
mining the hook address against the wrong deployer address is a real, easy
mistake that only shows up as a revert at broadcast time, not at compile time.
This script has NOT been run against a live chain in this environment
(no RPC egress available here) — only compiled.
