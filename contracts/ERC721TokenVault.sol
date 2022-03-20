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

  //all addresses
  address[] public usersarr;

  bool public poolActivate = true;

   mapping(address => uint256) public claimableBalance;
   mapping(string => uint256) public userToToken;

  // Referral system related variables
  mapping(address => uint256) public _referrals;
  mapping(uint256 => address) public _referrers;
  uint256 public _referrersCount = 0;

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
      0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff
    );
    initialSupply = _supply;
    availableBalance = _supply;
  }

  function changeAqarFee(uint256 _fee) external onlyOwner {
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
  IERC20 private WETH = IERC20(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);
  IERC20 private WBTC = IERC20(0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6);
  IERC20 private WMATIC = IERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
  IERC20 public AQR =  IERC20(0xaE204EE82E60829A5850FE291C10bF657AF1CF02);

  function tokenPrice() public view returns (uint256) {
    return (ListPrice.mul(1e18)).div(totalSupply());
  }
  function setendtime(uint256 time) external onlyOwner{
    require(time > block.timestamp,"time be greater than now time");
    endtime = time;
  }
  function activate(bool act) external onlyOwner{
    poolActivate = act;
  }
 function addressAqr(address add) external onlyOwner{
    AQR = IERC20(add);
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
  function buyTokenWithStableCoin(address _token, uint256 _amount,string memory userid, address referrer) external {
    require(poolActivate,"pool not activated");
    require(availableBalance >= _amount.mul(1e18),"available balance is less than your entered amount");
    require(
      _token == address(usdt) ||
        _token == address(usdc)
    );
    require(_getNow() < endtime, "Crowdsale is ended");
    require(_amount % 1 == 0,"not a one multiple");
    require(IERC20(_token).transferFrom(msg.sender, address(this),_amount.mul(tokenPrice()).mul(1e6)) ,"not enough balance");

    addBalance(_amount,userid,referrer);
  }
    
  function buyFromwhiteListCrypto(address _token, uint256 _amount,string memory userid,address referrer) external {
    uint256 cryptoPrice = getQuoteToTokenAmount(
      1e18,
      address(_token),
      address(usdt)
    );
    require(poolActivate,"pool not activated");
    require(availableBalance >= _amount.mul(1e18),"available balance is less than your entered amount");
    require(_token == address(WETH) || _token == address(AQR));
    require(_getNow() < endtime, "Crowdsale is ended");
    require(_amount % 1 == 0,"not a one multiple");
   
    if(_token == address(AQR)){
    uint256 discount = userDiscount.div(1000).mul(_amount).mul(1e18);
    uint256 amount = _amount.mul(1e18).mul(tokenPrice());
    require(IERC20(_token).transferFrom(msg.sender, address(this),amount.mul(1e6).div(cryptoPrice).sub(discount)) ,"not enough balance");
    }
    else{
    require(IERC20(_token).transferFrom(msg.sender, address(this),_amount.mul(1e18).mul(tokenPrice()).mul(1e6).div(cryptoPrice)) ,"not enough balance");
    }
    addBalance(_amount,userid,referrer);
  }
  
  function buyFromBtc(uint256 _amount,string memory userid,address referrer) external {
    uint256 cryptoPrice = getQuoteToTokenAmount(
      1e8,
      address(WBTC),
      address(usdt)
    );
    require(poolActivate,"pool not activated");
    require(availableBalance >= _amount.mul(1e18),"available balance is less than your entered amount");
    require(_getNow() < endtime, "Crowdsale is ended");
    require(IERC20(address(WBTC)).transferFrom(msg.sender, address(this),_amount.mul(1e8).mul(tokenPrice()).mul(1e6).div(cryptoPrice)) ,"not enough balance");
    require(_amount % 1 == 0,"not a one multiple");

    addBalance(_amount,userid,referrer);
  }



  function buyFromMatic(uint256 _amount,string memory userid,address referrer) external payable {
     uint256 cryptoPrice = getQuoteToTokenAmount(
      1e18,
      address(WMATIC),
      address(usdt)
    );
    require(poolActivate,"pool not activated");
    require(availableBalance >= _amount.mul(1e18),"available balance is less than your entered amount");
    require(_getNow() < endtime, "Crowdsale is ended");
    require(_amount % 1 == 0,"not a one multiple");
    require(msg.value == _amount.mul(1e18).mul(tokenPrice()).mul(1e6).div(cryptoPrice), "not enough balance");
   
   addBalance(_amount,userid,referrer);
  }

  function addBalance(uint256 _amount,string memory userid,address referrer) internal {

    userToToken[userid] = userToToken[userid].add(_amount).mul(1e18);
    claimableBalance[msg.sender] =  claimableBalance[msg.sender].add(_amount.mul(1e18));
    availableBalance = availableBalance.sub(_amount.mul(1e18));
    usersarr.push(msg.sender);
    addReferral(referrer, _amount);

  }

  function withdrawFunds(IERC20 _token,uint256 _amt,address admin) external nonReentrant onlyOwner {

    require(_amt <= balanceOf(address(this)));

    _token.transfer(msg.sender, _amt.mul(fee).div(1000));
    _token.transfer(admin, _amt.sub(_amt.mul(fee).div(1000)));
    
  }
    function withdrawNft(IERC721 _token,uint256 tokenid) external nonReentrant onlyOwner {

    _token.transferFrom(address(this),msg.sender, tokenid);
    
  }

  function allocating(uint256 _amount,address _beneficiery) external onlyOwner{

    claimableBalance[_beneficiery] =  claimableBalance[_beneficiery].add(_amount.mul(1e18));
    availableBalance = availableBalance.sub(_amount.mul(1e18));
    usersarr.push(_beneficiery);

  }
  
  function claimToken() external nonReentrant {
    require(claimableBalance[msg.sender] > 0,"Nothing to claim");
    require(endtime < _getNow(),"Time not finished yet");
    IERC20(address(this)).transfer(msg.sender, claimableBalance[msg.sender]);
    claimableBalance[msg.sender] = 0;
  }

   function claimRef() external nonReentrant {
    require(_referrals[msg.sender] > 0,"Nothing to claim");

    if(_referrals[msg.sender] < 50000){
      IERC20(usdt).transfer(msg.sender, (_referrals[msg.sender]).div(100));
      IERC20(AQR).transfer(msg.sender, (_referrals[msg.sender]).mul(5).div(1000));
    }
    else if(_referrals[msg.sender] > 50000 && _referrals[msg.sender] <= 100000){
      IERC20(usdt).transfer(msg.sender, (_referrals[msg.sender]).mul(2).div(100));
      IERC20(AQR).transfer(msg.sender, (_referrals[msg.sender]).div(100));
    }
    else if(_referrals[msg.sender] >= 100001 && _referrals[msg.sender] < 250000){
      IERC20(usdt).transfer(msg.sender, (_referrals[msg.sender]).mul(25).div(1000));
      IERC20(AQR).transfer(msg.sender, (_referrals[msg.sender]).mul(15).div(1000));
    }
    else if(_referrals[msg.sender] >= 250000 ){
      IERC20(usdt).transfer(msg.sender, (_referrals[msg.sender]).mul(3).div(100));
      IERC20(AQR).transfer(msg.sender, (_referrals[msg.sender]).mul(2).div(100));
    }

    _referrals[msg.sender] = 0;
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

    // Referral points calculation
   function addReferral(address _referrer, uint256 _tokensCount) private {
    if (_referrals[_referrer] == 0) {
      _referrers[_referrersCount] = _referrer;
      _referrersCount += 1;
      // if referrer has never invited referrals, default bonus value is 0 in _referrals
      // then adding referrer to referrers list to find them after and increment _referrersCount index by 1
    }
    _referrals[_referrer] += _tokensCount;
  }

}
