// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract Loans is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 public immutable collateralPrice;
    address public oracle;

    constructor(uint256 collateralPrice_) {
        collateralPrice = collateralPrice_;
        
        _disableInitializers();
    }

    function initialize(address _oracle) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();

        oracle = _oracle;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
