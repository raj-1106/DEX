import { useState } from "react";
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseUnits, formatUnits } from "viem";
import { CONTRACTS, ERC20_ABI } from "../lib/contracts";

/// Minimal example: approve tokenIn, then swap. Error handling and decimals
/// fetching are simplified for readability; a real UI should read
/// `decimals()` from each token rather than assuming 18, and should surface
/// `writeContract`'s error state to the user instead of just console logging.
export function DexSwapPanel({ tokenIn, tokenOut }: { tokenIn: `0x${string}`; tokenOut: `0x${string}` }) {
  const { address } = useAccount();
  const [amountIn, setAmountIn] = useState("");

  const { data: reserves } = useReadContract({
    ...CONTRACTS.dex,
    functionName: "getReserves",
    args: [tokenIn, tokenOut],
  });

  const { data: allowance } = useReadContract({
    address: tokenIn,
    abi: ERC20_ABI,
    functionName: "allowance",
    args: address ? [address, CONTRACTS.dex.address] : undefined,
    query: { enabled: !!address },
  });

  const { writeContract: approve, data: approveHash } = useWriteContract();
  const { writeContract: swap, data: swapHash } = useWriteContract();
  const { isLoading: approving } = useWaitForTransactionReceipt({ hash: approveHash });
  const { isLoading: swapping, isSuccess: swapped } = useWaitForTransactionReceipt({ hash: swapHash });

  const amountInWei = amountIn ? parseUnits(amountIn, 18) : 0n;
  const needsApproval = allowance !== undefined && amountInWei > 0n && (allowance as bigint) < amountInWei;

  function handleApprove() {
    approve({
      address: tokenIn,
      abi: ERC20_ABI,
      functionName: "approve",
      args: [CONTRACTS.dex.address, amountInWei],
    });
  }

  function handleSwap() {
    // amountOutMin left at 0 here for brevity — a real UI must compute this
    // from a quote (e.g. reserves-based estimate minus a slippage tolerance)
    // rather than accepting any output amount.
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 60 * 20); // 20 min
    swap({
      ...CONTRACTS.dex,
      functionName: "swap",
      args: [tokenIn, tokenOut, amountInWei, 0n, deadline],
    });
  }

  return (
    <div>
      <p>
        Reserves: {reserves ? `${formatUnits((reserves as [bigint, bigint])[0], 18)} / ${formatUnits((reserves as [bigint, bigint])[1], 18)}` : "..."}
      </p>
      <input value={amountIn} onChange={(e) => setAmountIn(e.target.value)} placeholder="Amount in" />
      {needsApproval ? (
        <button onClick={handleApprove} disabled={approving}>
          {approving ? "Approving..." : "Approve"}
        </button>
      ) : (
        <button onClick={handleSwap} disabled={swapping || amountInWei === 0n}>
          {swapping ? "Swapping..." : "Swap"}
        </button>
      )}
      {swapped && <p>Swap confirmed.</p>}
    </div>
  );
}
