// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

// forge install openzeppelin/openzeppelin-contracts --no-commit

import { ERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract BagelToken is ERC20, Ownable {
    constructor() ERC20("Bagel", "BAGEL") Ownable(msg.sender) { } // whoever deployes contract is the owner of the
        // contract

    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }
}
