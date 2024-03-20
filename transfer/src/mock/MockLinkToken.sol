// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockLinkToken is ERC20 {
  uint256 private constant TOTAL_SUPPLY = 1_000_000_000 * 1e18;

  constructor() ERC20("Chainlink", "LINK") {
    _mint(msg.sender, TOTAL_SUPPLY);
  }
}
