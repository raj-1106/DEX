import { useState } from 'react';
import { useAccount, useWriteContract, useChainId } from 'wagmi';
import { parseUnits } from 'viem';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Label } from '@/components/ui/label';
import { Minus } from 'lucide-react';
import { DEX_ABI, DEX_CONTRACT_ADDRESS } from '@/lib/dex-abi';
import { toast } from '@/hooks/use-toast';
import { mainnet, sepolia, hardhat } from 'wagmi/chains';

export const RemoveLiquidityCard = () => {
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const { writeContractAsync, isPending } = useWriteContract();
  
  const [token0, setToken0] = useState('');
  const [token1, setToken1] = useState('');
  const [liquidityAmount, setLiquidityAmount] = useState('');

  const getChain = () => {
    if (chainId === mainnet.id) return mainnet;
    if (chainId === sepolia.id) return sepolia;
    if (chainId === hardhat.id) return hardhat;
    return mainnet;
  };

  const handleRemoveLiquidity = async () => {
    if (!isConnected || !address) {
      toast({
        title: "Wallet not connected",
        description: "Please connect your wallet first",
        variant: "destructive"
      });
      return;
    }

    if (!token0 || !token1 || !liquidityAmount) {
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
      const amount = parseUnits(liquidityAmount, 18);
      const chain = getChain();

      await writeContractAsync({
        address: DEX_CONTRACT_ADDRESS as `0x${string}`,
        abi: DEX_ABI,
        functionName: 'removeLiquidity',
        args: [token0 as `0x${string}`, token1 as `0x${string}`, amount],
        account: address,
        chain,
      });

      toast({
        title: "Liquidity removed!",
        description: "Your liquidity has been successfully removed from the pool",
      });

      setLiquidityAmount('');
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
    <Card className="border-border/50 hover:border-destructive/30 transition-all">
      <CardHeader>
        <CardTitle className="text-2xl flex items-center gap-2">
          <Minus className="h-6 w-6 text-destructive" />
          Remove Liquidity
        </CardTitle>
        <CardDescription>Withdraw your liquidity from pools</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="removeToken0">Token 0 Address</Label>
          <Input
            id="removeToken0"
            placeholder="0x..."
            value={token0}
            onChange={(e) => setToken0(e.target.value)}
            className="bg-input/50 border-destructive/20 focus:border-destructive"
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="removeToken1">Token 1 Address</Label>
          <Input
            id="removeToken1"
            placeholder="0x..."
            value={token1}
            onChange={(e) => setToken1(e.target.value)}
            className="bg-input/50 border-destructive/20 focus:border-destructive"
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="liquidityAmount">Liquidity Amount</Label>
          <Input
            id="liquidityAmount"
            type="number"
            placeholder="0.0"
            value={liquidityAmount}
            onChange={(e) => setLiquidityAmount(e.target.value)}
            className="bg-input/50 border-destructive/20 focus:border-destructive"
          />
        </div>

        <Button
          onClick={handleRemoveLiquidity}
          disabled={isPending || !isConnected}
          variant="destructive"
          className="w-full text-lg py-6"
        >
          {isPending ? 'Removing Liquidity...' : 'Remove Liquidity'}
        </Button>
      </CardContent>
    </Card>
  );
};
