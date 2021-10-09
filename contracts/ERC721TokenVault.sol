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

  IUniswapV2Router01 public QuickSwapRouter;

  uint256 public ListPrice;

  address public factory;

  bool public initialized;

  uint256 public initialSupply;

  uint256 public endtime;

  string propid;

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

  IERC20 private usdt = IERC20(0x110a13FC3efE6A245B50102D2d79B3E76125Ae83);
  IERC20 private usdc = IERC20(0x07865c6E87B9F70255377e024ace6630C1Eaa37F);
  IERC20 private WXTZ = IERC20(0xA003362095Ef35B3FBa88C4854aD4548d3e90b85);
  IERC20 private WBNB = IERC20(0xA003362095Ef35B3FBa88C4854aD4548d3e90b85);
  IERC20 private WETH = IERC20(0xc778417E063141139Fce010982780140Aa0cD5Ab);
  IERC20 private WBTC = IERC20(0xc4f00272451B19eCEE5eDb36Eff527D632b23b5B);
  IERC20 private WMATIC = IERC20(0x1B48A5123F5d77dC89664B5f3b69218D3EA0A4ea);
  IERC20 private AQR = IERC20(0x677BbF70a052C221cEe74C8Ca68c20719B58A226);

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
    require(_getNow() < endtime, "Crowdsale is ended");
  
    if (_token == address(usdt) ) {
      uint256 totalTokenReceived = _amount.mul(1e12).mul(1e18).div(
        tokenPrice()
      );
      doTransferIn(address(token), msg.sender, amount);
     claimableBalance[msg.sender] =  claimableBalance[msg.sender].add(totalTokenReceived);
    }
       else{
          uint256 totalTokenReceived = _amount.mul(1e12).mul(1e18).div(
        tokenPrice()
      );
      IERC20(_token).transferFrom(msg.sender, address(this), _amount);
     claimableBalance[msg.sender] =  claimableBalance[msg.sender].add(totalTokenReceived);
       }
    
  }

  function buyFromwhiteListCrypto(address _token, uint256 _amount) external {
    require(_token == address(WETH) || _token == address(WXTZ) || _token == address(AQR));
    require(_getNow() < endtime, "Crowdsale is ended");
    uint256 cryptoPrice = getQuoteToTokenAmount(
      1e18,
      address(_token),
      address(usdt)
    );
    IERC20(_token).transferFrom(msg.sender, address(this), _amount);
    uint256 totalCrypto = (
      (cryptoPrice.mul(_amount).mul(1e18)).div(1e6).div(tokenPrice())
    );
       claimableBalance[msg.sender] =  claimableBalance[msg.sender].add(totalCrypto);
  }

  function buyFromBtc(uint256 _amount) external {
    uint256 cryptoPrice = getQuoteToTokenAmount(
      1e8,
      address(WBTC),
      address(usdt)
    );
    require(_getNow() < endtime, "Crowdsale is ended");
    IERC20(address(WBTC)).transferFrom(msg.sender, address(this), _amount);
    uint256 totalCrypto = (
      (cryptoPrice.mul(_amount).mul(1e18)).div(1e6).div(tokenPrice())
    );
     claimableBalance[msg.sender] =  claimableBalance[msg.sender].add(totalCrypto);
  }

  function buyFromMatic() external payable {
    require(msg.value == _amount);
    require(_getNow() < endtime, "Crowdsale is ended");
    uint256 cryptoPrice = getQuoteToTokenAmount(
      1e18,
      address(WMATIC),
      address(usdt)
    );
   
    uint256 totalCrypto = (
      (cryptoPrice.mul(msg.value).mul(1e18)).div(1e6).div(tokenPrice())
    );
   claimableBalance[msg.sender] =  claimableBalance[msg.sender].add(totalCrypto);
  }

  function withdrawFunds(address _token,uint256 _amt,address admin) external nonReentrant onlyOwner {

    require(_amt <= balanceOf(address(this)));

    if (_token == usdt) {
           doTransferOut(address(_token), msg.sender, _amt.mul(fee).div(1000));
           doTransferOut(address(_token), admin, _amt.sub(_amt.mul(fee).div(1000)));
        }

    _token.transfer(msg.sender, _amt.mul(fee).div(1000));
    _token.transfer(admin, _amt.sub(_amt.mul(fee).div(1000)));
  }
  
  function claimToken(uint256 _amt,address admin) external nonReentrant onlyOwner {
    require(claimableBalance[msg.sender] > 0,"Nothing to claim");
    require(endtime < _getNow(),"Time not finished yet");
    transfer(msg.sender,claimableBalance[msg.sender]);
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

        function doTransferIn(
        address tokenAddress,
        address from,
        uint256 amount
    ) internal returns (uint256) {
        INonStandardERC20 _token = INonStandardERC20(tokenAddress);
        uint256 balanceBefore = IERC20(tokenAddress).balanceOf(address(this));
        _token.transferFrom(from, address(this), amount);

        bool success;
        assembly {
            switch returndatasize()
                case 0 {
                    // This is a non-standard ERC-20
                    success := not(0) // set success to true
                }
                case 32 {
                    // This is a compliant ERC-20
                    returndatacopy(0, 0, 32)
                    success := mload(0) // Set `success = returndata` of external call
                }
                default {
                    // This is an excessively non-compliant ERC-20, revert.
                    revert(0, 0)
                }
        }
        require(success, "TOKEN_TRANSFER_IN_FAILED");

        // Calculate the amount that was actually transferred
        uint256 balanceAfter = IERC20(tokenAddress).balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "TOKEN_TRANSFER_IN_OVERFLOW");
        return balanceAfter.sub(balanceBefore); // underflow already checked above, just subtract
    }

    /**
     * @dev Similar to EIP20 transfer, except it handles a False success from `transfer` and returns an explanatory
     *      error code rather than reverting. If caller has not called checked protocol's balance, this may revert due to
     *      insufficient cash held in this contract. If caller has checked protocol's balance prior to this call, and verified
     *      it is >= amount, this should not revert in normal conditions.
     *
     *      Note: This wrapper safely handles non-standard ERC-20 tokens that do not return a value.
     *            See here: https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
     */
    function doTransferOut(
        address tokenAddress,
        address to,
        uint256 amount
    ) internal {
        INonStandardERC20 _token = INonStandardERC20(tokenAddress);
        _token.transfer(to, amount);

        bool success;
        assembly {
            switch returndatasize()
                case 0 {
                    // This is a non-standard ERC-20
                    success := not(0) // set success to true
                }
                case 32 {
                    // This is a complaint ERC-20
                    returndatacopy(0, 0, 32)
                    success := mload(0) // Set `success = returndata` of external call
                }
                default {
                    // This is an excessively non-compliant ERC-20, revert.
                    revert(0, 0)
                }
        }
        require(success, "TOKEN_TRANSFER_OUT_FAILED");
    }
}

