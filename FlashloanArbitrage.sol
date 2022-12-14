// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

pragma solidity >=0.5.0;

interface IUniswapV2Factory {
  function getPair(address tokenA, address tokenB) external view returns (address pair);
}

pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

pragma solidity >=0.6.2;

interface IUniswapV2Router {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
    function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts);
}

pragma solidity >=0.6.6 <0.8.0;

contract FlashloanArbitrage {
    address private _owner;

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == _owner, "Caller not owner");
        _;
    }
    
    constructor() public {
        _owner = msg.sender;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Cannot be zero addr");
        _owner = newOwner;
    }

    /**
     * @notice Take a flashloan and execute arbitrage
     * @param amount0 amount of tokens to borrow
     * @param token0 address of token to be borrowed
     * @param token1 address of token to receive profits in
     * @param sourceRouter source router address
     * @param targetRouter target router address
     * @param sourceFactory source factory address
     */
    function initArbitrage(
        uint256 amount0,
        address token0, 
        address token1, 
        address sourceRouter,
        address targetRouter,
        address sourceFactory
    ) external onlyOwner {
        require(amount0 > 0, "Invalid borrow amount");
        address pairAddress = IUniswapV2Factory(sourceFactory).getPair(token0, token1);
        require(pairAddress != address(0), 'Pair not found');

        IUniswapV2Pair(pairAddress).swap(
            amount0,
            0,
            address(this),
            abi.encode(sourceRouter, targetRouter)
        );
    }

    function _executeOperation(
        address _sender, 
        uint256 _amount0, 
        uint256 _amount1, 
        bytes calldata _data
    ) internal {
        uint256 amountLoaned = _amount0 == 0 ? _amount1 : _amount0;

        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();

        address[] memory path0 = new address[](2);
        address[] memory path1 = new address[](2);
        
        // Sell token having non-zero amount
        path0[0] = path1[1] = _amount0 == 0 ? token1 : token0; 
        path0[1] = path1[0] = _amount0 == 0 ? token0 : token1; 

        (address sourceRouter, address targetRouter) = abi.decode(_data, (address, address));
        require(sourceRouter != address(0) && targetRouter != address(0), 'Router not set');

        IERC20 loanToken = IERC20(_amount0 == 0 ? token1 : token0); // token to be sold
        loanToken.approve(targetRouter, amountLoaned);

        uint256 amountRequired = IUniswapV2Router(sourceRouter).getAmountsIn(amountLoaned, path1)[0]; // amount to reimburse
        uint256 amountReceived = IUniswapV2Router(targetRouter).swapExactTokensForTokens(
            amountLoaned,
            amountRequired, 
            path0,
            address(this),
            block.timestamp + 60
        )[1];

        require(amountReceived > amountRequired, 'Insufficient tokens');

        IERC20 payoutToken = IERC20(_amount0 == 0 ? token0 : token1);

        payoutToken.transfer(msg.sender, amountRequired); // reimburse
        payoutToken.transfer(owner(), amountReceived - amountRequired); // transfer profit to owner
    }
    
    function pancakeCall(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        _executeOperation(_sender, _amount0, _amount1, _data);
    }

    function uniswapV2Call(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        _executeOperation(_sender, _amount0, _amount1, _data);
    }

    function BiswapCall(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        _executeOperation(_sender, _amount0, _amount1, _data);
    }
    
    function apeCall(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        _executeOperation(_sender, _amount0, _amount1, _data);
    }
    
}
