# Halborn's Solidity CTF report

- **Report**
    - [High Issues](#high-issues)
    - [Medium Issues](#medium-issues)
    - [Low Issues](#low-issues)

## High issues
| Issue | Description |
|-|:-|
| [H-1](#H-1) | Logic `nft.safeTransferFrom` at `src/HalbornLoans.sol`'s method `depositNFTCollateral` leads to guaranteed DOS. |
| [H-2](#H-2) | Logic `nft.safeTransferFrom` at `src/HalbornLoans.sol`'s method `withdrawCollateral` is vulnerable to reentrancy attack. |
| [H-3](#H-3) | Wrong validation at `src/HalbornLoans.sol`'s method `getLoan` allows for draining the protocol funds. |
| [H-4](#H-4) | Wrong collateral record update at `src/HalbornLoans.sol`'s method `returnLoan` leading to loss for the borrower. |
| [H-5](#H-5) | Method `setMerkleRoot` inside `src/HalbornNFT.sol` lacks of access control. |
| [H-6](#H-6) | Internal method `_authorizeUpgrade` lacks of access control for upgrading the UUPS implementation. |
| [H-7](#H-7) | Method `multicall` inside `src/MulticallUpgradeable.sol` allows for malicious batching of logic. |

## Medium issues
| Issue | Description |
|-|:-|
| [M-1](#M-1) | Method `mintAirdrops` inside `src/HalbornNFT.sol` includes wrong validation to check if NFT ID has been minted already. |
| [M-2](#M-2) | Method `mintBuyWithETH` inside `src/HalbornNFT.sol` includes NFT ID collision leading to DOS when minting NFTs. |

## Low issues
| Issue | Description |
|-|:-|
| [L-1](#L-1) | Missing `_disableInitializers()` inside constructor of UUPS implementation. |
| [L-2](#L-2) | Missing event emissions for crucial state changes in all contracts. |
| [L-3](#L-3) | Contract `src/MulticallUpgradeable.sol` is a local fork of the OpenZeppelin’s `MulticallUpgradeable.sol` which might become outdated in a future OZ library upgrade. |
| [L-4](#L-4) | Variables defined with the `immutable` keyword are incompatible with UUPS the concept. |

## High issues description
### <a id="H-1" name="H-1"></a>[H-1] Logic `nft.safeTransferFrom` at `src/HalbornLoans.sol`'s method `depositNFTCollateral` leads to guaranteed DOS.

Contract `src/HalbornLoans.sol` lacks of `onERC721Received` callback meaning that using `safeTransferFrom` in the context of transfering NFT from the user to the contract will fail. The solutions based on the business logic of the smart contract could be to change `safeTransferFrom` to `transferFrom` or implement the `onERC721Received` callback to be part of the smart contract.
<br>


### <a id="H-2" name="H-2"></a>[H-2] Logic `nft.safeTransferFrom` at `src/HalbornLoans.sol`'s method `withdrawCollateral` is vulnerable to reentrancy attack.

Inside method `withdrawCollateral` the actual withdraw of the NFT from the smart contract to the user through `nft.safeTransferFrom` is done before the state changes. This opens the possibility for malicious user smart contract to implement the `onERC721Received` and place inside of it a request to `getLoan`. The impact is that the user has successfully withdrawn the NFT and the same time received a loan. Apply the Checks-Effects-Interactions pattern where all state changes are done before the `nft.safeTransferFrom` request.
<br>


### <a id="H-3" name="H-3"></a>[H-3] Wrong validation at `src/HalbornLoans.sol`'s method `getLoan` allows for draining the protocol funds.

Method `getLoan` checks if the requested borrow amount is greater than the available "borrowing power" _( subtracting the already borrowed amounts from the total user collateral )_. This is fundamentally wrong as it allows for the user to request undercollateralized loans. 

Replace:
```solidity
totalCollateral[msg.sender] - usedCollateral[msg.sender] < amount
```
With:
```solidity
totalCollateral[msg.sender] - usedCollateral[msg.sender] >= amount
```
<br>


### <a id="H-4" name="H-4"></a>[H-4] Wrong collateral record update at `src/HalbornLoans.sol`'s method `returnLoan` leading to loss for the borrower.

Method `returnLoan` has a false records update of the `usedCollateral` mapping. Instead of decreasing the borrowing assets record of the user when he is repaying back a loan, it increases it the record as if he just took another loan.

Replace:
```solidity
usedCollateral[msg.sender] += amount
```
With:
```solidity
usedCollateral[msg.sender] -= amount`
```
<br>


### <a id="H-5" name="H-5"></a>[H-5] Method `setMerkleRoot` inside `src/HalbornNFT.sol` lacks of access control.

Method `setMerkleRoot` lacks of access control meaning that anyone is entirely free to request it. A malicious actor can upload his own forged merkle root and abuse NFT minting through method `mintAirdrops`.

Consider setting permissions only for the smart contract owner to be able to request `setMerkleRoot`:
```solidity
function setMerkleRoot(bytes32 merkleRoot_) public onlyOwner
```
<br>


### <a id="H-6" name="H-6"></a>[H-6] Internal method `_authorizeUpgrade` lacks of access control for upgrading the UUPS implementation.

The internal method `_authorizeUpgrade` doesn't have access control. According to OpenZeppelin’s documentation _( [here](https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable) )_, `_authorizeUpgrade` must be overridden to include access restriction, typically using the `onlyOwner` modifier. This must be done to prevent unauthorized users from upgrading the contract to a potentially malicious implementation.

Replace:
```solidity
function _authorizeUpgrade(address) internal override {}
```
With:
```solidity
function _authorizeUpgrade(address) internal override onlyOwner {}
```

The vulnerability exists at the contracts listed below:
- `src/HalbornNFT.sol`
- `src/HalbornToken.sol`
- `src/HalbornLoans.sol`
<br>


### <a id="H-7" name="H-7"></a>[H-7] Method `multicall` inside `src/MulticallUpgradeable.sol` allows for malicious batching of logic.


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
<br>


### <a id="M-2" name="M-2"></a>[M-2] Method `mintBuyWithETH` inside `src/HalbornNFT.sol` includes NFT ID collision leading to DOS when minting NFTs.

Two methods inside `src/HalbornNFT.sol` can be used to mint new NFTs - methods `mintAirdrops` and `mintBuyWithETH`. `mintAirdrops` mints NFT by a given NFT ID, `mintBuyWithETH` mints NFT by a state counter `idCounter`. The problem is that the counter starts from value 0 and it increases by 1 everytime `mintBuyWithETH` is called. Let's suppose Alice minted NFT ID 2 by requesting `mintAirdrops` and now Bob and Jake are requesting `mintBuyWithETH`. Bob will successfully mint his NFT with ID 1, but Jake will fail, because `mintBuyWithETH` will try to mint a NFT with ID 2, but this NFT ID has been already minted by Alice. The result is collision of the NFT IDs leading to a possible DOS of method `mintBuyWithETH`.
<br>


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
<br>


### <a id="L-2" name="L-2"></a>[L-2] Missing event emissions for crucial state changes in all contracts.

Missing events in significant scenarios, such as important configuration changes like a minting NFT price or deposit/ withdraws/ borrows/ repays. Consider implementing more events for all crucial state changes in the contracts listed below:
- `src/HalbornNFT.sol`
- `src/HalbornToken.sol`
- `src/HalbornLoans.sol`
<br>


### <a id="L-3" name="L-3"></a>[L-3] Contract `src/MulticallUpgradeable.sol` is a local fork of the OpenZeppelin’s `MulticallUpgradeable.sol` which might become outdated in a future OZ library upgrade.

The protocol made a local fork of OpenZeppelin’s `MulticallUpgradeable.sol` located at `src/MulticallUpgradeable.sol`, but inside of it the file is still importing libraries directly from the OpenZeppelin’s library package:
```solidity
import {AddressUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/AddressUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
```
This could lead to future issues if OZ decide to upgrade the imported libraries leading to incompatibility with local forked `src/MulticallUpgradeable.sol`. The solution is to include in the local fork all of the files used by the `src/MulticallUpgradeable.sol`.
<br>


### <a id="L-4" name="L-4"></a>[L-4] Variables defined with the `immutable` keyword are incompatible with UUPS the concept.

Technically it's possible to have `immutable` variables inside UUPS implementation and set them in the constructor, but this is more of a semantic issue and OpenZeppelin is forcing builders to not follow this approach by explicitly forbidding it in the `@openzeppelin/hardhat-upgrades` package to prevent confusion. 

However if a developer still decides to stay like this he should be extemely aware and not confuse him self that he could also define state variables in the constructor - the constructor of the implementation doesn't store variables in the state of the proxy, this is why there is `initialize` method for this purpose. The non-immutable state variables defined in the constructor of implementation will have their default values in the context of the proxy.