// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol';

contract BlackJackToken is ERC20 {

    address public dealer;
    struct game {
        #TODO
    }
    mapping (address => game) games;
    address[] public total_games;

    constructor() ERC20('BlackJackToken', 'BJT') {
		#TODO
    }

    function mint(address to, uint amount) external {
        #TODO
    }

    // Returns random # between 1 and 10, with the same probablity as a standard deck of cards
    function draw_random(uint _seed) private view returns (uint){
		#TODO
		return 0;
    }

    event return_game_state(uint player_value, uint dealer_value);

    function new_game(uint _bet) external {
		#TODO
    }

    function end_game(address player) private {
		#TODO
    } 

    function hit() external {
		#TODO
    }

    function stand() external {
		#TODO
    }
}