//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC721TokenVault.sol";

contract ERC721VaultFactory is Ownable {
  /// @notice the number of ERC721 vaults
  uint256 public vaultCount;

  /// @notice the mapping of vault number to vault contract
  mapping(uint256 => address) public vaults;

  mapping(uint256 => address) public NftToToken;

  mapping(string => uint256) public propIdTopropTokenId;

  event Mint(
    address indexed token,
    uint256 id,
    uint256 price,
    address vault,
    uint256 vaultId
  );

  /// @notice the function to mint a new vault
  /// @param _name the desired name of the vault
  /// @param _symbol the desired sumbol of the vault
  /// @param _token the ERC721 token address fo the NFT
  /// @param _id the uint256 ID of the token
  /// @param _listPrice the initial price of the NFT
  /// @return the ID of the vault
  // whenNotPaused
  function mint(
    string memory _name,
    string memory _symbol,
    address _token,
    uint256 _id,
    uint256 _supply,
    uint256 _listPrice, // in 18 decimals
    string memory _propid
  ) external onlyOwner returns (uint256) {
    require(NftToToken[_id] == address(0));
 
    TokenVault vault = new TokenVault(
      msg.sender,
      _token,
      _id,
      _supply,
      _listPrice,
      _propid,
      _name,
      _symbol
    );

    vault.init();

    vault.transferOwnership(msg.sender);

    dividingFunction(address(vault), _id, _token,_propid);
    // return vaultCount - 1;
    emit Mint(_token, _id, _listPrice, address(vault), vaultCount);

  }


  function dividingFunction(address vault,uint256 _id, address _token,string memory propid) internal{

    NftToToken[_id] = vault;
    propIdTopropTokenId[propid] = _id;

    IERC721(_token).safeTransferFrom(msg.sender, vault, _id);

    vaults[vaultCount] = vault;
    vaultCount++;
  }

}
