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

### Low issues description
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