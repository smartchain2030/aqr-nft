//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IUniswapRouter01.sol";
import "./interface/IUniswapFactory.sol";
import "./interface/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TokenVault is ERC20, ERC721Holder, Ownable, ReentrancyGuard {
  using Address for address;
  using SafeMath for uint256;

  /// -----------------------------------
  /// -------- TOKEN INFORMATION --------
  /// -----------------------------------

  /// @notice the ERC721 token address of the vault's token
  address public token;

  /// @notice the ERC721 token ID of the vault's token
  uint256 public id;

  /// @notice the address who initially deposited the NFT
  address public curator;

  /// @notice the AUM fee paid to the curator yearly. 3 decimals. ie. 100 = 10%
  uint256 public fee;

  IUniswapV2Router01 public QuickSwapRouter;

  uint256 public ListPrice;

  address public factory;

  bool public initialized;

  uint256 public initialSupply;

  uint256 public aqarFee;

  uint256 public endtime;

  constructor(
    address _curator,
    address _token,
    uint256 _id,
    uint256 _supply,
    uint256 _listPrice,
    uint256 _fee,
    string memory _name,
    string memory _symbol
  ) ERC20(_name, _symbol) {
    factory = msg.sender;
    // set storage variables
    token = _token;
    id = _id;
    curator = _curator;
    fee = _fee;
    ListPrice = _listPrice; // in dollars
    QuickSwapRouter = IUniswapV2Router01(
      0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
    );
    initialSupply = _supply;
    aqarFee = 200;
  }

  function changeAqarFee(uint256 _fee) external nonReentrant onlyOwner {
    aqarFee = _fee;
  }

  function init() external nonReentrant onlyOwner {
    require(!initialized, "its already initialized");
    require(msg.sender == factory);
    _mint(address(this), initialSupply);
    initialized = true;
  }

  IERC20 private usdt = IERC20(0x37906Bb496df5b3b7c741688b4EA6013870700B1);
  IERC20 private usdc = IERC20(0x37906Bb496df5b3b7c741688b4EA6013870700B1);
  IERC20 private WXTZ = IERC20(0x37906Bb496df5b3b7c741688b4EA6013870700B1);
  IERC20 private WETH = IERC20(0x37906Bb496df5b3b7c741688b4EA6013870700B1);
  IERC20 private WBTC = IERC20(0x37906Bb496df5b3b7c741688b4EA6013870700B1);
  IERC20 private WMATIC = IERC20(0x37906Bb496df5b3b7c741688b4EA6013870700B1);
  IERC20 private AQAR = IERC20(0x37906Bb496df5b3b7c741688b4EA6013870700B1);

  // IERC20 private aqar = IERC20();
  // IERC20 private wmatic = IERC20(0xc778417E063141139Fce010982780140Aa0cD5Ab);

  function tokenPrice() public view returns (uint256) {
    return (ListPrice.mul(1e18)).div(totalSupply());
  }
  function setendtime(uint256 time) external onlyOwner{
    require(time > block.timestamp,"time be greater than now time");
    endtime = time;
  }

  function getQuoteToTokenAmount(
    uint256 _fromTokenAmount,
    address _fromTokenAddress,
    address _toTokenAddress
  ) public view returns (uint256) {
    IUniswapV2Pair pair = IUniswapV2Pair(
      IUniswapV2Factory(QuickSwapRouter.factory()).getPair(
        _fromTokenAddress,
        _toTokenAddress
      )
    );
    (uint256 res0, uint256 res1, ) = pair.getReserves();
    address tokenA = pair.token0();
    (uint256 reserveA, uint256 reserveB) = _fromTokenAddress == tokenA
      ? (res0, res1)
      : (res1, res0);
    uint256 toTokenAmount = QuickSwapRouter.quote(
      _fromTokenAmount,
      reserveA,
      reserveB
    );
    return toTokenAmount;
  }

  // amount of usdt to buy
  function buyTokenWithStableCoin(address _token, uint256 _amount) external {
    require(
      _token == address(usdt) ||
        _token == address(usdc)
    );
    require(_getNow() >= endtime, "Crowdsale is ended");

    if (_token == address(usdt) || _token == address(usdc)) {
      uint256 totalTokenReceived = _amount.mul(1e12).mul(1e18).div(
        tokenPrice()
      );
      IERC20(_token).transferFrom(msg.sender, address(this), _amount);
      transfer(
        msg.sender,
        totalTokenReceived
      );
    } 
  }

  function buyFromwhiteListCrypto(address _token, uint256 _amount) external {
    require(_token == address(WETH) || _token == address(WXTZ) || _token == address(AQAR));
    require(_getNow() >= endtime, "Crowdsale is ended");
    uint256 cryptoPrice = getQuoteToTokenAmount(
      1e18,
      address(_token),
      address(usdt)
    );
    IERC20(_token).transferFrom(msg.sender, address(this), _amount);
    uint256 totalCrypto = (
      (cryptoPrice.mul(_amount).mul(1e18)).div(1e6).div(tokenPrice())
    );
    transfer(msg.sender, totalCrypto);
  }

  function buyFromBtc(uint256 _amount) external {
    uint256 cryptoPrice = getQuoteToTokenAmount(
      1e8,
      address(WBTC),
      address(usdt)
    );
    require(_getNow() >= endtime, "Crowdsale is ended");
    IERC20(address(WBTC)).transferFrom(msg.sender, address(this), _amount);
    uint256 totalCrypto = (
      (cryptoPrice.mul(_amount).mul(1e18)).div(1e6).div(tokenPrice())
    );
    transfer(msg.sender, totalCrypto);
  }

  function buyFromMatic(address _token, uint256 _amount) external payable {
    require(msg.value == _amount);
    require(_getNow() >= endtime, "Crowdsale is ended");
    uint256 cryptoPrice = getQuoteToTokenAmount(
      1e18,
      address(WMATIC),
      address(usdt)
    );
    require(_getNow() >= endtime, "Crowdsale is ended");
    uint256 totalCrypto = (
      (cryptoPrice.mul(_amount).mul(1e18)).div(1e6).div(tokenPrice())
    );

    transfer(msg.sender, totalCrypto);
  }

  function withdrawTokens(uint256 _amt,address admin) external nonReentrant onlyOwner {
    require(_amt <= balanceOf(address(this)));
    transfer(admin, _amt.mul(fee).div(1000));
    transfer(msg.sender, _amt.sub(_amt.mul(fee).div(1000)));
  }
  function updateEndTime(uint256 newtime) external onlyOwner {
    require(newtime > endtime);
    endtime = newtime;
  }
  function _getNow() internal view returns (uint256) {
        return block.timestamp;
    }
}
