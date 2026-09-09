import { WagmiProvider } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { config } from '@/lib/web3-config';
import { Navbar } from '@/components/Navbar';
import { SwapCard } from '@/components/SwapCard';
import { AddLiquidityCard } from '@/components/AddLiquidityCard';
import { RemoveLiquidityCard } from '@/components/RemoveLiquidityCard';
import { PoolInfoCard } from '@/components/PoolInfoCard';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { ArrowRightLeft, Plus, Minus, BarChart3 } from 'lucide-react';

const queryClient = new QueryClient();

const Index = () => {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <div className="min-h-screen">
          <Navbar />
          
          <main className="container mx-auto px-4 py-8">
            <div className="max-w-7xl mx-auto">
              <div className="text-center mb-12 animate-in fade-in duration-700">
                <h2 className="text-4xl md:text-5xl font-bold mb-4 text-foreground tracking-tight">
                  Decentralized Exchange
                </h2>
                <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
                  Trade tokens, provide liquidity, and earn rewards on our secure and efficient DEX platform
                </p>
              </div>

              <Tabs defaultValue="swap" className="w-full">
                <TabsList className="grid w-full max-w-2xl mx-auto grid-cols-4 bg-muted/50 h-14 p-1 rounded-xl">
                  <TabsTrigger value="swap" className="rounded-lg">
                    <ArrowRightLeft className="h-4 w-4 mr-2" />
                    Swap
                  </TabsTrigger>
                  <TabsTrigger value="add" className="rounded-lg">
                    <Plus className="h-4 w-4 mr-2" />
                    Add
                  </TabsTrigger>
                  <TabsTrigger value="remove" className="rounded-lg">
                    <Minus className="h-4 w-4 mr-2" />
                    Remove
                  </TabsTrigger>
                  <TabsTrigger value="info" className="rounded-lg">
                    <BarChart3 className="h-4 w-4 mr-2" />
                    Info
                  </TabsTrigger>
                </TabsList>

                <div className="mt-8 max-w-2xl mx-auto">
                  <TabsContent value="swap" className="animate-in fade-in duration-500">
                    <SwapCard />
                  </TabsContent>

                  <TabsContent value="add" className="animate-in fade-in duration-500">
                    <AddLiquidityCard />
                  </TabsContent>

                  <TabsContent value="remove" className="animate-in fade-in duration-500">
                    <RemoveLiquidityCard />
                  </TabsContent>

                  <TabsContent value="info" className="animate-in fade-in duration-500">
                    <PoolInfoCard />
                  </TabsContent>
                </div>
              </Tabs>
            </div>
          </main>
        </div>
      </QueryClientProvider>
    </WagmiProvider>
  );
};

export default Index;
