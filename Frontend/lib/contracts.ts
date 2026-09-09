import DEX_ABI from "../abi/DEX.json";
import COUNTER_HOOK_ABI from "../abi/CounterHook.json";
import SIMPLE_V4_ROUTER_ABI from "../abi/SimpleV4Router.json";

// Fill these in AFTER running the forge scripts (DeployDEX.s.sol,
// DeployV4Hook.s.sol, DeployRouter.s.sol) against Sepolia. None of these
// addresses are guesses; they only exist once you've actually broadcast
// the deployments and copied the "deployed at:" console output.
export const CONTRACTS = {
  dex: {
    address: (process.env.NEXT_PUBLIC_DEX_ADDRESS ?? "0x0000000000000000000000000000000000000000") as `0x${string}`,
    abi: DEX_ABI,
  },
  counterHook: {
    address: (process.env.NEXT_PUBLIC_HOOK_ADDRESS ?? "0x0000000000000000000000000000000000000000") as `0x${string}`,
    abi: COUNTER_HOOK_ABI,
  },
  v4Router: {
    address: (process.env.NEXT_PUBLIC_ROUTER_ADDRESS ?? "0x0000000000000000000000000000000000000000") as `0x${string}`,
    abi: SIMPLE_V4_ROUTER_ABI,
  },
  // Sourced from Uniswap/sdks (sdk-core/src/addresses.ts) in this session.
  // That file carries its own "TODO: update once v4 on sepolia redeployed"
  // comment, meaning even Uniswap's team flags these as possibly stale.
  // Run `cast code <address> --rpc-url $SEPOLIA_RPC_URL` before trusting
  // this in anything beyond a quick smoke test.
  v4PoolManager: "0xE03A1074c86CFeDd5C142C4F04F1a1536e203543" as `0x${string}`,
  v4Quoter: "0x61b3f2011a92d183c7dbadbda940a7555ccf9227" as `0x${string}`,
} as const;

export const ERC20_ABI = [
  {
    type: "function",
    name: "approve",
    stateMutability: "nonpayable",
    inputs: [
      { name: "spender", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bool" }],
  },
  {
    type: "function",
    name: "allowance",
    stateMutability: "view",
    inputs: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
    ],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "balanceOf",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "decimals",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint8" }],
  },
] as const;
