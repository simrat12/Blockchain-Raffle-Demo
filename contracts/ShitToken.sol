//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ShitToken2 is ERC20 {

    // Decimals are set to 18 by default in `ERC20`
    constructor() ERC20("ShitToken2", "ST") {
        _mint(msg.sender, 1000000000000000000000000000);
    }
}