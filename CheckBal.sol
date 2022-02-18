// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import './IERC20.sol';

contract Checker {

  function checkBal(address _token, address _holder, uint256 _floorVal) public view returns(bool) {
    IERC20 token = IERC20(_token);
    return token.balanceOf(_holder) > _floorVal;
  }
}