pragma solidity >=0.6.0 <0.8.0;

interface IUniswapV2Pair {
  function token0() external pure returns (address);

  function token1() external pure returns (address);

  function getReserves()
    external
    view
    returns (
      uint112 _reserve0,
      uint112 _reserve1,
      uint32 _blockTimestampLast
    );
}
