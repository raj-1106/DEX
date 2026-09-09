import { useState } from 'react';
import { useAccount, useWriteContract, useChainId } from 'wagmi';
import { parseUnits } from 'viem';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Label } from '@/components/ui/label';
import { Plus } from 'lucide-react';
import { DEX_ABI, ERC20_ABI, DEX_CONTRACT_ADDRESS } from '@/lib/dex-abi';
import { toast } from '@/hooks/use-toast';
import { mainnet, sepolia, hardhat } from 'wagmi/chains';

export const AddLiquidityCard = () => {
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const { writeContractAsync, isPending } = useWriteContract();
  
  const [token0, setToken0] = useState('');
  const [token1, setToken1] = useState('');
  const [amount0, setAmount0] = useState('');
  const [amount1, setAmount1] = useState('');
  const [slippage, setSlippage] = useState('1'); // Default 1%

  const getChain = () => {
    if (chainId === mainnet.id) return mainnet;
    if (chainId === sepolia.id) return sepolia;
    if (chainId === hardhat.id) return hardhat;
    return mainnet;
  };

  const handleAddLiquidity = async () => {
    if (!isConnected || !address) {
      toast({
        title: "Wallet not connected",
        description: "Please connect your wallet first",
        variant: "destructive"
      });
      return;
    }

    if (!token0 || !token1 || !amount0 || !amount1) {
      toast({
        title: "Missing information",
        description: "Please fill in all fields",
        variant: "destructive"
      });
      return;
    }

    if (token0.toLowerCase() === address.toLowerCase() || token1.toLowerCase() === address.toLowerCase()) {
      toast({
        title: "Invalid token address",
        description: "Please enter valid ERC20 token contract addresses, not your wallet address",
        variant: "destructive"
      });
      return;
    }

    try {
      const amt0 = parseUnits(amount0, 18);
      const amt1 = parseUnits(amount1, 18);
      const chain = getChain();
      
      // Approve first token
      await writeContractAsync({
        address: token0 as `0x${string}`,
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [DEX_CONTRACT_ADDRESS as `0x${string}`, amt0],
        account: address,
        chain,
      });

      toast({
        title: "Token 0 approved",
        description: "Approving token 1...",
      });

      // Approve second token
      await writeContractAsync({
        address: token1 as `0x${string}`,
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [DEX_CONTRACT_ADDRESS as `0x${string}`, amt1],
        account: address,
        chain,
      });

      toast({
        title: "Both tokens approved",
        description: "Adding liquidity...",
      });

      const deadline = BigInt(Math.floor(Date.now() / 1000) + 1200);
      const slippageBps = BigInt(Math.floor(parseFloat(slippage || '0') * 100));
      const amountAMin = (amt0 * (10000n - slippageBps)) / 10000n;
      const amountBMin = (amt1 * (10000n - slippageBps)) / 10000n;

      // Add liquidity
      await writeContractAsync({
        address: DEX_CONTRACT_ADDRESS as `0x${string}`,
        abi: DEX_ABI,
        functionName: 'addLiquidity',
        args: [token0 as `0x${string}`, token1 as `0x${string}`, amt0, amt1, amountAMin, amountBMin, deadline],
        account: address,
        chain,
      });

      toast({
        title: "Liquidity added!",
        description: "Your liquidity has been successfully added to the pool",
      });

      setAmount0('');
      setAmount1('');
    } catch (error: any) {
      toast({
        title: "Transaction failed",
        description: error.message || "Please check console for details",
        variant: "destructive"
      });
      console.error(error);
    }
  };

  return (
    <Card className="border-border/50">
      <CardHeader>
        <CardTitle className="text-2xl flex items-center gap-2">
          <Plus className="h-6 w-6 text-secondary" />
          Add Liquidity
        </CardTitle>
        <CardDescription>Provide liquidity to earn trading fees</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="token0">Token 0 Address</Label>
          <Input
            id="token0"
            placeholder="0x..."
            value={token0}
            onChange={(e) => setToken0(e.target.value)}
            className="bg-input/50 border-secondary/20 focus:border-secondary"
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="amount0">Token 0 Amount</Label>
          <Input
            id="amount0"
            type="number"
            placeholder="0.0"
            value={amount0}
            onChange={(e) => setAmount0(e.target.value)}
            className="bg-input/50 border-secondary/20 focus:border-secondary"
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="token1">Token 1 Address</Label>
          <Input
            id="token1"
            placeholder="0x..."
            value={token1}
            onChange={(e) => setToken1(e.target.value)}
            className="bg-input/50 border-secondary/20 focus:border-secondary"
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="amount1">Token 1 Amount</Label>
          <Input
            id="amount1"
            type="number"
            placeholder="0.0"
            value={amount1}
            onChange={(e) => setAmount1(e.target.value)}
            className="bg-input/50 border-secondary/20 focus:border-secondary"
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="slippage">Slippage Tolerance (%)</Label>
          <Input
            id="slippage"
            type="number"
            placeholder="1.0"
            value={slippage}
            onChange={(e) => setSlippage(e.target.value)}
            className="bg-input/50 border-secondary/20 focus:border-secondary"
          />
        </div>

        <Button
          onClick={handleAddLiquidity}
          disabled={isPending || !isConnected}
          className="w-full bg-secondary hover:bg-secondary/90 transition-all text-lg py-6 text-secondary-foreground"
        >
          {isPending ? 'Adding Liquidity...' : 'Add Liquidity'}
        </Button>
      </CardContent>
    </Card>
  );
};
