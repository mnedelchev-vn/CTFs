# Halborn's Solidity CTF report

- **Report**
    - [Low Issues](#low-issues)
    - [Medium Issues](#medium-issues)
    - [High Issues](#high-issues)

## Low issues
| Issue | Description |
|-|:-|
| [L-1](#L-1) | Missing `_disableInitializers()` inside constructor of UUPS implementation. |
| [L-2](#L-2) | Missing event emissions for crucial state changes in all contracts. |
| [L-3](#L-3) | Contract `src/MulticallUpgradeable.sol` is a local fork of the OZ's `MulticallUpgradeable.sol` which might become outdated in future OZ library upgrade. |

## Medium issues
| Issue | Description |
|-|:-|
| [M-1](#M-1) | Method `mintAirdrops` inside `src/HalbornNFT.sol` includes wrong validation to check if NFT ID has been minted already. |
| [M-2](#M-2) | Method `mintBuyWithETH` inside `src/HalbornNFT.sol` includes NFT ID collision leading to DOS when minting NFTs. |

## High issues
| Issue | Description |
|-|:-|
| [H-1](#H-1) | Logic `nft.safeTransferFrom` at `src/HalbornLoans.sol`'s method `depositNFTCollateral` leads to DOS as the `HalbornLoans` contract lacks of `onERC721Received` callback. |
| [H-2](#H-2) | Logic `nft.safeTransferFrom` at `src/HalbornLoans.sol`'s method `withdrawCollateral` is vulnerable to reentrancy attack. Checks-Effects-Interactions pattern is not applied. |
| [H-3](#H-3) | Wrong validation at `src/HalbornLoans.sol`'s method `getLoan` allows for draining the protocol. Replace `totalCollateral[msg.sender] - usedCollateral[msg.sender] < amount` with `totalCollateral[msg.sender] - usedCollateral[msg.sender] >= amount`. |
| [H-4](#H-4) | Wrong collateral record update at `src/HalbornLoans.sol`'s method `returnLoan` leading to loss for the borrower. Replace `usedCollateral[msg.sender] += amount` with `usedCollateral[msg.sender] -= amount`. |
| [H-5](#H-5) | Method `setMerkleRoot` inside `src/HalbornNFT.sol` lacks of access control. |
| [H-6](#H-6) | Internal method `_authorizeUpgrade` lacks of access control for upgrading the UUPS implementation. |
| [H-7](#H-7) | Method `multicall` inside `src/MulticallUpgradeable.sol` allows for batching of logic together with accepting `msg.value`. |

## Low issues description
### <a id="L-1" name="L-1"></a>[L-1] Missing `_disableInitializers()` inside constructor of UUPS implementation.

By putting `_disableInitializers()` in the constructor, this prevents initialization of the implementation contract itself, as extra protection to prevent an attacker from initializing it.

*Instances (3)*:

```solidity
File: src/HalbornLoans.sol

constructor(uint256 collateralPrice_) {
    collateralPrice = collateralPrice_;

    /// @audit missing _disableInitializers(); to prevent implementation from hijacking
}

```

```solidity
Files: src/HalbornToken.sol & src/HalbornNFT.sol

/// @audit missing constructor with _disableInitializers() to prevent implementation from hijacking
constructor() {
    _disableInitializers();
}

```

### <a id="L-2" name="L-2"></a>[L-2] Missing event emissions for crucial state changes in all contracts.

Missing events in significant scenarios, such as important configuration changes like a minting NFT price or deposit/ withdraws/ borrows/ repays. Consider implementing more events for all crucial state changes in the contracts listed below:
- `src/HalbornNFT.sol`
- `src/HalbornToken.sol`
- `src/HalbornLoans.sol`

### <a id="L-3" name="L-3"></a>[L-3] Contract `src/MulticallUpgradeable.sol` is a local fork of the OZ's `MulticallUpgradeable.sol` which might become outdated in future OZ library upgrade.

The protocol made a local fork of OZ's `MulticallUpgradeable.sol` located at `src/MulticallUpgradeable.sol`, but inside of it the file is still importing libraries directly from the OZ's library package:
```solidity
import {AddressUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/AddressUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
```
This could lead to future issues if OZ decide to upgrade the imported libraries leading to incompatibility with local forked `src/MulticallUpgradeable.sol`. The solution is to include in the local fork all of the files used by the `src/MulticallUpgradeable.sol`.


## Medium issues description
### <a id="M-1" name="M-1"></a>[M-1] Method `mintAirdrops` inside `src/HalbornNFT.sol` includes wrong validation to check if NFT ID has been minted already.

Method `mintAirdrops` currently checks if a NFT has been already minted, but it has to be the other way around - it has to check if NFT is not minted yet, because down in the method logic `_safeMint` will revert with error `ERC721InvalidSender()`, because the method will be trying to mint a NFT which is already minted. Reference: [https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/master/contracts/token/ERC721/ERC721Upgradeable.sol#L292C20-L292C39]

Replace:
```solidity
require(_exists(id), "Token already minted");
```
With:
```solidity
require(!_exists(id), "Token already minted");
```


### <a id="M-2" name="M-2"></a>[M-2] Method `mintBuyWithETH` inside `src/HalbornNFT.sol` includes NFT ID collision leading to DOS when minting NFTs.

Two methods inside `src/HalbornNFT.sol` can be used to mint new NFTs - methods `mintAirdrops` and `mintBuyWithETH`. `mintAirdrops` mints NFT by a given NFT ID, `mintBuyWithETH` mints NFT by a state counter `idCounter`. The problem is that the counter starts from value 0 and it increases by 1 everytime `mintBuyWithETH` is called. Let's suppose Alice minted NFT ID 2 by requesting `mintAirdrops` and now Bob and Jake are requesting `mintBuyWithETH`. Bob will successfully mint his NFT with ID 1, but Jake will fail, because `mintBuyWithETH` will try to mint a NFT with ID 2, but this NFT ID has been already minted by Alice. The result is collision of the NFT IDs leading to a possible DOS of method `mintBuyWithETH`.

## High issues description