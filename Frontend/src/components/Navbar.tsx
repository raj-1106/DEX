import { useAccount, useConnect, useDisconnect } from 'wagmi';
import { Button } from '@/components/ui/button';
import { Wallet } from 'lucide-react';

export const Navbar = () => {
  const { address, isConnected } = useAccount();
  const { connect, connectors } = useConnect();
  const { disconnect } = useDisconnect();

  const handleConnect = () => {
    const injectedConnector = connectors.find((c) => c.id === 'injected');
    if (injectedConnector) {
      connect({ connector: injectedConnector });
    }
  };

  const formatAddress = (addr: string) => {
    return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
  };

  return (
    <nav className="bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 border-b border-border sticky top-0 z-50">
      <div className="container mx-auto px-4 py-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="bg-primary w-10 h-10 rounded-lg flex items-center justify-center">
            <span className="text-xl font-bold text-primary-foreground">DEX</span>
          </div>
          <h1 className="text-2xl font-bold text-foreground">
            CryptoSwap DEX
          </h1>
        </div>
        
        <div className="flex items-center gap-4">
          {isConnected && address ? (
            <div className="flex items-center gap-3">
              <div className="bg-muted/50 px-4 py-2 rounded-lg border border-border">
                <p className="text-sm text-muted-foreground">Connected</p>
                <p className="font-mono font-semibold text-primary">{formatAddress(address)}</p>
              </div>
              <Button 
                onClick={() => disconnect()}
                variant="outline"
                className="border-destructive/50 hover:bg-destructive/20"
              >
                Disconnect
              </Button>
            </div>
          ) : (
            <Button 
              onClick={handleConnect}
              className="bg-primary text-primary-foreground hover:bg-primary/90 transition-all"
            >
              <Wallet className="mr-2 h-4 w-4" />
              Connect Wallet
            </Button>
          )}
        </div>
      </div>
    </nav>
  );
};
