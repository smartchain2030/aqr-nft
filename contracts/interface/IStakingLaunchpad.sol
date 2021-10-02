pragma solidity >=0.6.0 <0.8.0;

interface IStakingLaunchpad {
  function usersUsdLimitData(address _user) external view returns (uint256);
}
