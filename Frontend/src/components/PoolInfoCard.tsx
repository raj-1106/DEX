import { useState } from 'react';
import { useReadContract } from 'wagmi';
import { formatUnits } from 'viem';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Label } from '@/components/ui/label';
import { BarChart3 } from 'lucide-react';
import { DEX_ABI, DEX_CONTRACT_ADDRESS } from '@/lib/dex-abi';

export const PoolInfoCard = () => {
  const [token0, setToken0] = useState('');
  const [token1, setToken1] = useState('');

  const { data: reserves, refetch } = useReadContract({
    address: DEX_CONTRACT_ADDRESS as `0x${string}`,
    abi: DEX_ABI,
    functionName: 'getReserves',
    args: token0 && token1 ? [token0 as `0x${string}`, token1 as `0x${string}`] : undefined,
  });

  const handleCheck = () => {
    refetch();
  };

  return (
    <Card className="border-border/50">
      <CardHeader>
        <CardTitle className="text-2xl flex items-center gap-2">
          <BarChart3 className="h-6 w-6 text-accent" />
          Pool Information
        </CardTitle>
        <CardDescription>Check reserves and pool statistics</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="poolToken0">Token 0 Address</Label>
          <Input
            id="poolToken0"
            placeholder="0x..."
            value={token0}
            onChange={(e) => setToken0(e.target.value)}
            className="bg-input/50 border-accent/20 focus:border-accent"
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="poolToken1">Token 1 Address</Label>
          <Input
            id="poolToken1"
            placeholder="0x..."
            value={token1}
            onChange={(e) => setToken1(e.target.value)}
            className="bg-input/50 border-accent/20 focus:border-accent"
          />
        </div>

        <Button
          onClick={handleCheck}
          className="w-full bg-accent hover:bg-accent/90 transition-all"
          disabled={!token0 || !token1}
        >
          Check Pool Reserves
        </Button>

        {reserves && (
          <div className="mt-6 p-4 rounded-lg bg-muted/50 border border-border">
            <h3 className="text-lg font-semibold mb-3 text-accent">Pool Reserves</h3>
            <div className="space-y-2">
              <div className="flex justify-between items-center">
                <span className="text-muted-foreground">Token 0 Reserve:</span>
                <span className="font-mono font-semibold text-primary">
                  {formatUnits(reserves[0], 18)}
                </span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-muted-foreground">Token 1 Reserve:</span>
                <span className="font-mono font-semibold text-primary">
                  {formatUnits(reserves[1], 18)}
                </span>
              </div>
              <div className="flex justify-between items-center pt-2 border-t border-border/50">
                <span className="text-muted-foreground">Exchange Rate:</span>
                <span className="font-mono font-semibold text-secondary">
                  {reserves[0] > 0n ? (Number(reserves[1]) / Number(reserves[0])).toFixed(6) : '0'}
                </span>
              </div>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
};
