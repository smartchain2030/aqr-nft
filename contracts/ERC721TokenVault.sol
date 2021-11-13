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
import "./interface/INonStandardERC20.sol";
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

  /// @notice the fee paid to the curator for collecting property funds
  uint256 public fee = 200;

  uint256 public userDiscount;

  IUniswapV2Router01 public QuickSwapRouter;

  uint256 public ListPrice;

  address public factory;

  bool public initialized;

  uint256 public initialSupply;

  uint256 public endtime;

  string propid;

  uint256 public availableBalance;

   mapping(address => uint256) public claimableBalance;

  constructor(
    address _curator,
    address _token,
    uint256 _id,
    uint256 _supply,
    uint256 _listPrice,
    string memory _propid,
    string memory _name,
    string memory _symbol
  ) ERC20(_name, _symbol) {
    factory = msg.sender;
    // set storage variables
    token = _token;
    id = _id;
    curator = _curator;
    propid = _propid;
    ListPrice = _listPrice; // in dollars
    QuickSwapRouter = IUniswapV2Router01(
      0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
    );
    initialSupply = _supply;
    availableBalance = _supply;
  }

  function changeAqarFee(uint256 _fee) external nonReentrant onlyOwner {
   fee = _fee;
  }

  function init() external nonReentrant onlyOwner {
    require(!initialized, "its already initialized");
    require(msg.sender == factory);
    _mint(address(this), initialSupply);
    initialized = true;
  }

  IERC20 private usdt = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
  IERC20 private usdc = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
//   IERC20 private WXTZ = IERC20(0xc3159137DaC99f59D7Ce16523af1dc345C1B5884);
//   IERC20 private WBNB = IERC20(0x83EDF015E89fe41B59aD864fc00c772B64040CA5);
  IERC20 private WETH = IERC20(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);
  IERC20 private WBTC = IERC20(0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6);
  IERC20 private WMATIC = IERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
  IERC20 private AQR = IERC20(0x7467afa7C48132e8f8C90A919fC2ebA041207195);

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
    require(availableBalance >= _amount.mul(1e12).mul(1e18).div(tokenPrice()),"available balance is less than your entered amount");
    require(
      _token == address(usdt) ||
        _token == address(usdc)
    );
    require(_getNow() < endtime, "Crowdsale is ended");
    require((_amount).div(1e6) % 1 == 0,"not a one multiple");
  
      uint256 totalTokenReceived = _amount.mul(1e12).mul(1e18).div(tokenPrice());
     IERC20(_token).transferFrom(msg.sender, address(this), _amount);
     claimableBalance[msg.sender] =  claimableBalance[msg.sender].add(totalTokenReceived);
     availableBalance = availableBalance.sub(totalTokenReceived);

  }
    
  function buyFromwhiteListCrypto(address _token, uint256 _amount) external {
    uint256 cryptoPrice = getQuoteToTokenAmount(
      1e18,
      address(_token),
      address(usdt)
    );
    require(availableBalance >= cryptoPrice.mul(_amount).mul(1e18).div(1e6).div(tokenPrice()),"available balance is less than your entered amount");
    require(_token == address(WETH) || _token == address(AQR));
    require(_getNow() < endtime, "Crowdsale is ended");
    require(cryptoPrice.mul(_amount).div(1e18).div(1e6) % 1 == 0,"not a one multiple");

    if(_token == address(AQR)){
    uint256 discount = userDiscount.div(1000).mul(_amount).div(10e18);
    IERC20(_token).transferFrom(msg.sender, address(this), _amount.sub(discount));
   
    uint256 totalCrypto = (
      (cryptoPrice.mul(_amount).mul(1e18)).div(1e6).div(tokenPrice())
    );
    
       claimableBalance[msg.sender] =  claimableBalance[msg.sender].add(totalCrypto);
       availableBalance = availableBalance.sub(totalCrypto);
    }
    else{
    IERC20(_token).transferFrom(msg.sender, address(this), _amount);
    uint256 totalCrypto = (
      (cryptoPrice.mul(_amount).mul(1e18)).div(1e6).div(tokenPrice())
    );
       claimableBalance[msg.sender] =  claimableBalance[msg.sender].add(totalCrypto);
       availableBalance = availableBalance.sub(totalCrypto);
    }
  }
  
  function buyFromBtc(uint256 _amount) external {
    uint256 cryptoPrice = getQuoteToTokenAmount(
      1e8,
      address(WBTC),
      address(usdt)
    );
    require(availableBalance >= cryptoPrice.mul(_amount).mul(1e10).mul(1e18).div(1e6).div(tokenPrice()),"available balance is less than your entered amount");
    require(_getNow() < endtime, "Crowdsale is ended");
    require(cryptoPrice.mul(_amount).div(1e8).div(1e6) % 1 == 0,"not a one multiple");

    IERC20(address(WBTC)).transferFrom(msg.sender, address(this), _amount);
    uint256 totalCrypto = (
      (cryptoPrice.mul(_amount).mul(1e10).mul(1e18)).div(1e6).div(tokenPrice())
    );
     claimableBalance[msg.sender] =  claimableBalance[msg.sender].add(totalCrypto);
     availableBalance = availableBalance.sub(totalCrypto);
  }



  function buyFromMatic(uint256 _amount) external payable {
     uint256 cryptoPrice = getQuoteToTokenAmount(
      1e18,
      address(WMATIC),
      address(usdt)
    );
    require(availableBalance >= cryptoPrice.mul(msg.value).mul(1e18).div(1e6).div(tokenPrice()),"available balance is less than your entered amount");
    require(msg.value == _amount);
    require(_getNow() < endtime, "Crowdsale is ended");
    require(cryptoPrice.mul(msg.value).div(1e18).div(1e6) % 1 == 0,"not a one multiple");
   
    uint256 totalCrypto = (
      (cryptoPrice.mul(msg.value).mul(1e18)).div(1e6).div(tokenPrice())
    );
   claimableBalance[msg.sender] =  claimableBalance[msg.sender].add(totalCrypto);
   availableBalance = availableBalance.sub(totalCrypto);
  }


  function withdrawFunds(IERC20 _token,uint256 _amt,address admin) external nonReentrant onlyOwner {

    require(_amt <= balanceOf(address(this)));

    _token.transfer(msg.sender, _amt.mul(fee).div(1000));
    _token.transfer(admin, _amt.sub(_amt.mul(fee).div(1000)));
  }
  
  function claimToken(IERC20 _token) external nonReentrant {
    require(claimableBalance[msg.sender] > 0,"Nothing to claim");
    require(endtime < _getNow(),"Time not finished yet");
    _token.transfer(msg.sender, claimableBalance[msg.sender]);
    claimableBalance[msg.sender] = 0;
  }

 function updateListPrice(uint256 newlistprice)external onlyOwner {
    ListPrice=newlistprice;
  }
  
   function adminTransferMaticFund() external onlyOwner {
        msg.sender.transfer(address(this).balance);
    }

  function _getNow() public view returns (uint256) {
        return block.timestamp;
    }



}

