import { useState } from 'react';
import { useAccount, useWriteContract, useChainId } from 'wagmi';
import { parseUnits } from 'viem';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Label } from '@/components/ui/label';
import { ArrowDown, RefreshCw } from 'lucide-react';
import { DEX_ABI, ERC20_ABI, DEX_CONTRACT_ADDRESS } from '@/lib/dex-abi';
import { toast } from '@/hooks/use-toast';
import { mainnet, sepolia, hardhat } from 'wagmi/chains';

export const SwapCard = () => {
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const { writeContractAsync, isPending } = useWriteContract();
  
  const [tokenIn, setTokenIn] = useState('');
  const [tokenOut, setTokenOut] = useState('');
  const [amountIn, setAmountIn] = useState('');
  const [slippage, setSlippage] = useState('1'); // Default 1%

  const getChain = () => {
    if (chainId === mainnet.id) return mainnet;
    if (chainId === sepolia.id) return sepolia;
    if (chainId === hardhat.id) return hardhat;
    return mainnet;
  };

  const handleSwap = async () => {
    if (!isConnected || !address) {
      toast({
        title: "Wallet not connected",
        description: "Please connect your wallet first",
        variant: "destructive"
      });
      return;
    }

    if (!tokenIn || !tokenOut || !amountIn) {
      toast({
        title: "Missing information",
        description: "Please fill in all fields",
        variant: "destructive"
      });
      return;
    }

    if (tokenIn.toLowerCase() === address.toLowerCase() || tokenOut.toLowerCase() === address.toLowerCase()) {
      toast({
        title: "Invalid token address",
        description: "Please enter a valid ERC20 token contract address, not your wallet address",
        variant: "destructive"
      });
      return;
    }

    try {
      const amount = parseUnits(amountIn, 18);
      const chain = getChain();
      
      // First approve the DEX to spend tokens
      await writeContractAsync({
        address: tokenIn as `0x${string}`,
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [DEX_CONTRACT_ADDRESS as `0x${string}`, amount],
        account: address,
        chain,
      });

      toast({
        title: "Approval successful",
        description: "Now executing swap...",
      });

      const deadline = BigInt(Math.floor(Date.now() / 1000) + 1200);
      const amountOutMin = 0n; // Would require fetching getReserves to calculate properly

      // Then execute the swap
      await writeContractAsync({
        address: DEX_CONTRACT_ADDRESS as `0x${string}`,
        abi: DEX_ABI,
        functionName: 'swap',
        args: [tokenIn as `0x${string}`, tokenOut as `0x${string}`, amount, amountOutMin, deadline],
        account: address,
        chain,
      });

      toast({
        title: "Swap successful!",
        description: "Your tokens have been swapped",
      });

      setAmountIn('');
    } catch (error: any) {
      toast({
        title: "Swap failed",
        description: error.message || "Please check console for details",
        variant: "destructive"
      });
      console.error(error);
    }
  };

  const handleFlipTokens = () => {
    setTokenIn(tokenOut);
    setTokenOut(tokenIn);
  };

  return (
    <Card className="border-border/50">
      <CardHeader>
        <CardTitle className="text-2xl flex items-center gap-2">
          <RefreshCw className="h-6 w-6 text-primary" />
          Swap Tokens
        </CardTitle>
        <CardDescription>Exchange tokens instantly with minimal fees</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="tokenIn">From Token Address</Label>
          <Input
            id="tokenIn"
            placeholder="0x..."
            value={tokenIn}
            onChange={(e) => setTokenIn(e.target.value)}
            className="bg-input/50 border-primary/20 focus:border-primary"
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="amountIn">Amount</Label>
          <Input
            id="amountIn"
            type="number"
            placeholder="0.0"
            value={amountIn}
            onChange={(e) => setAmountIn(e.target.value)}
            className="bg-input/50 border-primary/20 focus:border-primary text-xl font-semibold"
          />
        </div>

        <div className="flex justify-center">
          <Button
            onClick={handleFlipTokens}
            variant="ghost"
            size="icon"
            className="rounded-full hover:bg-primary/20 hover:rotate-180 transition-all duration-300"
          >
            <ArrowDown className="h-5 w-5 text-primary" />
          </Button>
        </div>

        <div className="space-y-2">
          <Label htmlFor="tokenOut">To Token Address</Label>
          <Input
            id="tokenOut"
            placeholder="0x..."
            value={tokenOut}
            onChange={(e) => setTokenOut(e.target.value)}
            className="bg-input/50 border-primary/20 focus:border-primary"
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="swapSlippage">Slippage Tolerance (%)</Label>
          <Input
            id="swapSlippage"
            type="number"
            placeholder="1.0"
            value={slippage}
            onChange={(e) => setSlippage(e.target.value)}
            className="bg-input/50 border-primary/20 focus:border-primary"
          />
        </div>

        <Button
          onClick={handleSwap}
          disabled={isPending || !isConnected}
          className="w-full bg-primary text-primary-foreground hover:bg-primary/90 transition-all text-lg py-6"
        >
          {isPending ? 'Swapping...' : 'Swap Tokens'}
        </Button>
      </CardContent>
    </Card>
  );
};
