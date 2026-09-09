export const DEX_ABI = [
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "address", "name": "user", "type": "address" },
      { "indexed": true, "internalType": "address", "name": "token0", "type": "address" },
      { "indexed": true, "internalType": "address", "name": "token1", "type": "address" },
      { "indexed": false, "internalType": "uint256", "name": "amount0", "type": "uint256" },
      { "indexed": false, "internalType": "uint256", "name": "amount1", "type": "uint256" },
      { "indexed": false, "internalType": "uint256", "name": "liquidityMinted", "type": "uint256" }
    ],
    "name": "LiquidityAdded",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "address", "name": "user", "type": "address" },
      { "indexed": true, "internalType": "address", "name": "token0", "type": "address" },
      { "indexed": true, "internalType": "address", "name": "token1", "type": "address" },
      { "indexed": false, "internalType": "uint256", "name": "amount0", "type": "uint256" },
      { "indexed": false, "internalType": "uint256", "name": "amount1", "type": "uint256" },
      { "indexed": false, "internalType": "uint256", "name": "liquidityBurned", "type": "uint256" }
    ],
    "name": "LiquidityRemoved",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "address", "name": "user", "type": "address" },
      { "indexed": true, "internalType": "address", "name": "tokenIn", "type": "address" },
      { "indexed": true, "internalType": "address", "name": "tokenOut", "type": "address" },
      { "indexed": false, "internalType": "uint256", "name": "amountIn", "type": "uint256" },
      { "indexed": false, "internalType": "uint256", "name": "amountOut", "type": "uint256" }
    ],
    "name": "Swap",
    "type": "event"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "tokenA", "type": "address" },
      { "internalType": "address", "name": "tokenB", "type": "address" },
      { "internalType": "uint256", "name": "amountADesired", "type": "uint256" },
      { "internalType": "uint256", "name": "amountBDesired", "type": "uint256" },
      { "internalType": "uint256", "name": "amountAMin", "type": "uint256" },
      { "internalType": "uint256", "name": "amountBMin", "type": "uint256" },
      { "internalType": "uint256", "name": "deadline", "type": "uint256" }
    ],
    "name": "addLiquidity",
    "outputs": [
      { "internalType": "uint256", "name": "amountA", "type": "uint256" },
      { "internalType": "uint256", "name": "amountB", "type": "uint256" },
      { "internalType": "uint256", "name": "liquidityMinted", "type": "uint256" }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "tokenA", "type": "address" },
      { "internalType": "address", "name": "tokenB", "type": "address" },
      { "internalType": "uint256", "name": "liquidityBurned", "type": "uint256" },
      { "internalType": "uint256", "name": "amountAMin", "type": "uint256" },
      { "internalType": "uint256", "name": "amountBMin", "type": "uint256" },
      { "internalType": "uint256", "name": "deadline", "type": "uint256" }
    ],
    "name": "removeLiquidity",
    "outputs": [
      { "internalType": "uint256", "name": "amountA", "type": "uint256" },
      { "internalType": "uint256", "name": "amountB", "type": "uint256" }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "tokenIn", "type": "address" },
      { "internalType": "address", "name": "tokenOut", "type": "address" },
      { "internalType": "uint256", "name": "amountIn", "type": "uint256" },
      { "internalType": "uint256", "name": "amountOutMin", "type": "uint256" },
      { "internalType": "uint256", "name": "deadline", "type": "uint256" }
    ],
    "name": "swap",
    "outputs": [
      { "internalType": "uint256", "name": "amountOut", "type": "uint256" }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "_token0", "type": "address" },
      { "internalType": "address", "name": "_token1", "type": "address" }
    ],
    "name": "getReserves",
    "outputs": [
      { "internalType": "uint256", "name": "reserve0", "type": "uint256" },
      { "internalType": "uint256", "name": "reserve1", "type": "uint256" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "", "type": "address" },
      { "internalType": "address", "name": "", "type": "address" },
      { "internalType": "address", "name": "", "type": "address" }
    ],
    "name": "liquidity",
    "outputs": [
      { "internalType": "uint256", "name": "", "type": "uint256" }
    ],
    "stateMutability": "view",
    "type": "function"
  }
] as const;

export const ERC20_ABI = [
  {
    "inputs": [
      { "internalType": "address", "name": "spender", "type": "address" },
      { "internalType": "uint256", "name": "amount", "type": "uint256" }
    ],
    "name": "approve",
    "outputs": [{ "internalType": "bool", "name": "", "type": "bool" }],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "account", "type": "address" }
    ],
    "name": "balanceOf",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "decimals",
    "outputs": [{ "internalType": "uint8", "name": "", "type": "uint8" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "symbol",
    "outputs": [{ "internalType": "string", "name": "", "type": "string" }],
    "stateMutability": "view",
    "type": "function"
  }
] as const;

// Your deployed DEX contract address
export const DEX_CONTRACT_ADDRESS = "0x83Bc786acDEDF91cCA6Dd3af7aA6Bd9a36A8CFc8";
