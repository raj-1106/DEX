import { createConfig, http } from "wagmi";
import { sepolia } from "wagmi/chains";
import { injected } from "wagmi/connectors";

// Verified against wagmi@3.7.7 / viem@2.56.3 in this session, not assumed
// from memory. If you're on a different wagmi major version, hook names
// (useReadContract/useWriteContract/useSimulateContract) may differ.
export const wagmiConfig = createConfig({
  chains: [sepolia],
  connectors: [injected()],
  transports: {
    [sepolia.id]: http(process.env.NEXT_PUBLIC_SEPOLIA_RPC_URL),
  },
});
