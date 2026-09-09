import { useState } from "react";
import { useAccount, useSimulateContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseUnits, formatUnits } from "viem";
import { CONTRACTS, ERC20_ABI } from "../lib/contracts";

const V4_QUOTER_ABI = [
  {
    type: "function",
    name: "quoteExactInputSingle",
    stateMutability: "nonpayable", // not `view`: V4Quoter computes via a revert-and-decode pattern internally
    inputs: [
      {
        name: "params",
        type: "tuple",
        components: [
          {
            name: "poolKey",
            type: "tuple",
            components: [
              { name: "currency0", type: "address" },
              { name: "currency1", type: "address" },
              { name: "fee", type: "uint24" },
              { name: "tickSpacing", type: "int24" },
              { name: "hooks", type: "address" },
            ],
          },
          { name: "zeroForOne", type: "bool" },
          { name: "exactAmount", type: "uint128" },
          { name: "hookData", type: "bytes" },
        ],
      },
    ],
    outputs: [
      { name: "amountOut", type: "uint256" },
      { name: "gasEstimate", type: "uint256" },
    ],
  },
] as const;

/// V4 has no direct swap() a frontend calls: this goes quote (view-style
/// call to the official V4Quoter) -> approve tokenIn to OUR router ->
/// router.swapExactInputSingle. fee/tickSpacing/hookAddress must exactly
/// match how the pool was initialized (see DeployV4Hook.s.sol), or the
/// PoolKey resolves to a different, non-existent pool.
export function V4SwapPanel({
  tokenIn,
  tokenOut,
  fee = 3000,
  tickSpacing = 60,
  hookAddress,
}: {
  tokenIn: `0x${string}`;
  tokenOut: `0x${string}`;
  fee?: number;
  tickSpacing?: number;
  hookAddress: `0x${string}`;
}) {
  const { address } = useAccount();
  const [amountIn, setAmountIn] = useState("");
  const amountInWei = amountIn ? parseUnits(amountIn, 18) : 0n;

  const zeroForOne = tokenIn.toLowerCase() < tokenOut.toLowerCase();
  const [currency0, currency1] = zeroForOne ? [tokenIn, tokenOut] : [tokenOut, tokenIn];

  const { data: quote } = useSimulateContract({
    address: CONTRACTS.v4Quoter,
    abi: V4_QUOTER_ABI,
    functionName: "quoteExactInputSingle",
    args: [
      {
        poolKey: { currency0, currency1, fee, tickSpacing, hooks: hookAddress },
        zeroForOne,
        exactAmount: amountInWei,
        hookData: "0x",
      },
    ],
    query: { enabled: amountInWei > 0n },
  });

  const amountOut = quote?.result?.[0] as bigint | undefined;

  const { writeContract: approve, data: approveHash } = useWriteContract();
  const { writeContract: swap, data: swapHash } = useWriteContract();
  const { isLoading: approving } = useWaitForTransactionReceipt({ hash: approveHash });
  const { isLoading: swapping, isSuccess: swapped } = useWaitForTransactionReceipt({ hash: swapHash });

  function handleApprove() {
    approve({
      address: tokenIn,
      abi: ERC20_ABI,
      functionName: "approve",
      args: [CONTRACTS.v4Router.address, amountInWei],
    });
  }

  function handleSwap() {
    if (!amountOut) return;
    const slippageBps = 50n; // 0.5%
    const amountOutMinimum = (amountOut * (10_000n - slippageBps)) / 10_000n;
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 60 * 20);

    swap({
      ...CONTRACTS.v4Router,
      functionName: "swapExactInputSingle",
      args: [tokenIn, tokenOut, fee, tickSpacing, hookAddress, amountInWei, amountOutMinimum, "0x", deadline],
    });
  }

  return (
    <div>
      <input value={amountIn} onChange={(e) => setAmountIn(e.target.value)} placeholder="Amount in" />
      <p>Quote: {amountOut !== undefined ? formatUnits(amountOut, 18) : "..."}</p>
      <button onClick={handleApprove} disabled={approving || amountInWei === 0n}>
        {approving ? "Approving..." : "Approve"}
      </button>
      <button onClick={handleSwap} disabled={swapping || !amountOut}>
        {swapping ? "Swapping..." : "Swap via V4"}
      </button>
      {swapped && <p>Swap confirmed. Check CounterHook.afterSwapCount to see the hook fire.</p>}
    </div>
  );
}
