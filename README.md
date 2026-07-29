# DEX

A constant-product AMM (x*y=k) deployed on Polygon Amoy testnet, with a 0.3% swap fee.

## Deployment

- **Network:** Polygon Amoy Testnet (Polygon PoS testnet, Sepolia as L1 root)
- **DEX.sol:** `0xA1755560e8CAec3d69446F57B6D97B5aF6f2BD63`

## How it works

- `addLiquidity(token0, token1, amount0, amount1)` — deposits both tokens, mints LP shares (geometric mean `sqrt(amount0 * amount1)` on first deposit, ratio-matched afterward)
- `removeLiquidity(token0, token1, liquidityBurned)` — burns LP shares, returns proportional share of both reserves
- `swap(tokenIn, tokenOut, amountIn)` — constant-product swap with a 0.3% fee (997/1000)
- `getReserves(token0, token1)` — returns current reserves for a pair

## Known limitations (testnet-stage)

- Pools are keyed by `(token0, token1)` in argument order, calling with the pair reversed addresses a *different* pool, not the same one. Don't assume `swap(A, B)` and `swap(B, A)` share liquidity.
- No slippage protection (`minAmountOut`) or deadline on swaps
- Uses raw `IERC20` transfer calls, not `SafeERC20`
- `addLiquidity` calls external `transferFrom` before updating pool state
