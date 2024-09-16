// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DEX {
    using SafeMath for uint256;

    struct Pool {
        IERC20 token0;
        IERC20 token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalSupply;
    }

    mapping(address => mapping(address => Pool)) public pools;
    mapping(address => mapping(address => mapping(address => uint256))) public liquidity;

    event LiquidityAdded(address indexed user, address indexed token0, address indexed token1, uint256 amount0, uint256 amount1, uint256 liquidityMinted);
    event LiquidityRemoved(address indexed user, address indexed token0, address indexed token1, uint256 amount0, uint256 amount1, uint256 liquidityBurned);
    event Swap(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function addLiquidity(address _token0, address _token1, uint256 _amount0, uint256 _amount1) external {
        require(_token0 != _token1, "Invalid token pair");
        require(_amount0 > 0 && _amount1 > 0, "Invalid amounts");

        IERC20 token0 = IERC20(_token0);
        IERC20 token1 = IERC20(_token1);

        token0.transferFrom(msg.sender, address(this), _amount0);
        token1.transferFrom(msg.sender, address(this), _amount1);

        Pool storage pool = pools[_token0][_token1];
        uint256 liquidityMinted;

        if (pool.totalSupply == 0) {
            liquidityMinted = sqrt(_amount0.mul(_amount1));
            pool.token0 = token0;
            pool.token1 = token1;
        } else {
            uint256 liquidity0 = _amount0.mul(pool.totalSupply) / pool.reserve0;
            uint256 liquidity1 = _amount1.mul(pool.totalSupply) / pool.reserve1;
            liquidityMinted = (liquidity0 < liquidity1) ? liquidity0 : liquidity1;
        }

        require(liquidityMinted > 0, "Insufficient liquidity minted");

        pool.reserve0 = pool.reserve0.add(_amount0);
        pool.reserve1 = pool.reserve1.add(_amount1);
        pool.totalSupply = pool.totalSupply.add(liquidityMinted);
        liquidity[msg.sender][_token0][_token1] = liquidity[msg.sender][_token0][_token1].add(liquidityMinted);

        emit LiquidityAdded(msg.sender, _token0, _token1, _amount0, _amount1, liquidityMinted);
    }

    function removeLiquidity(address _token0, address _token1, uint256 _liquidityBurned) external {
        require(_token0 != _token1, "Invalid token pair");
        require(_liquidityBurned > 0, "Invalid liquidity amount");

        Pool storage pool = pools[_token0][_token1];
        require(pool.totalSupply > 0, "Pool does not exist");
        require(liquidity[msg.sender][_token0][_token1] >= _liquidityBurned, "Insufficient liquidity");

        uint256 amount0 = _liquidityBurned.mul(pool.reserve0) / pool.totalSupply;
        uint256 amount1 = _liquidityBurned.mul(pool.reserve1) / pool.totalSupply;

        require(amount0 > 0 && amount1 > 0, "Insufficient liquidity burned");

        liquidity[msg.sender][_token0][_token1] = liquidity[msg.sender][_token0][_token1].sub(_liquidityBurned);
        pool.totalSupply = pool.totalSupply.sub(_liquidityBurned);
        pool.reserve0 = pool.reserve0.sub(amount0);
        pool.reserve1 = pool.reserve1.sub(amount1);

        pool.token0.transfer(msg.sender, amount0);
        pool.token1.transfer(msg.sender, amount1);

        emit LiquidityRemoved(msg.sender, _token0, _token1, amount0, amount1, _liquidityBurned);
    }

    function swap(address _tokenIn, address _tokenOut, uint256 _amountIn) external {
        require(_tokenIn != _tokenOut, "Invalid token pair");
        require(_amountIn > 0, "Invalid input amount");

        Pool storage pool = pools[_tokenIn][_tokenOut];
        require(pool.totalSupply > 0, "Pool does not exist");

        IERC20 tokenIn = IERC20(_tokenIn);
        IERC20 tokenOut = IERC20(_tokenOut);

        tokenIn.transferFrom(msg.sender, address(this), _amountIn);

        uint256 amountInWithFee = _amountIn.mul(997);
        uint256 numerator = amountInWithFee.mul(pool.reserve1);
        uint256 denominator = pool.reserve0.mul(1000).add(amountInWithFee);
        uint256 amountOut = numerator / denominator;

        require(amountOut > 0, "Insufficient output amount");

        pool.reserve0 = pool.reserve0.add(_amountIn);
        pool.reserve1 = pool.reserve1.sub(amountOut);

        tokenOut.transfer(msg.sender, amountOut);

        emit Swap(msg.sender, _tokenIn, _tokenOut, _amountIn, amountOut);
    }

    function getReserves(address _token0, address _token1) external view returns (uint256 reserve0, uint256 reserve1) {
        Pool storage pool = pools[_token0][_token1];
        return (pool.reserve0, pool.reserve1);
    }
}

contract TestToken is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}
