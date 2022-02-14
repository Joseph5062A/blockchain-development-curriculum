// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol';

contract BlackJackToken is ERC20 {
    address public dealer;
    // Structure of a game of blackjack being played
    struct game {
        uint player_hand;
        uint dealer_hand;
        uint bet;
    }
    // Creating a mapping between a user's address and a game of blackjack (similar to a hash map)
    mapping (address => game) games;
    address[] public total_games;

    constructor() ERC20('BlackJackToken', 'BJT') {
        // Inital supply of 10000 tokens, with 18 decimal points (ERC20 default)
        _mint(msg.sender, 10000 * 10 ** 18);
        dealer = msg.sender;
    }

    function mint(address to, uint amount) external {
        require(msg.sender == dealer, "Only the dealer can mint tokens.");
        _mint(to, amount);
    }

    // Returns random # between 1 and 10, with the same probablity as a standard deck of cards
    function draw_random(uint _seed) private view returns (uint){
        // Generating pseudorandom value between 0 and 12
        uint draw = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, _seed))) % 13;
        if (draw == 12 || draw == 11 || draw==10) {
            draw = 9;
        }
        return ++draw;
    }

    event return_game_state(uint player_value, uint dealer_value);

    function new_game(uint _bet) external {
        require(games[msg.sender].bet == 0, "A current game is already in play.");
        require(_bet > 0, "Bet must be greater than zero.");
        uint balance = balanceOf(msg.sender);
        require((balance > 0) && (_bet < balance), "Not enough tokens to play.");

        // Sending bet of player to smart contract owner
        transfer(dealer, _bet);

        // Player and user draw inital two cards each
        uint player_value = draw_random(1);
        uint dealer_value = draw_random(2);
        player_value += draw_random(3);
        dealer_value += draw_random(4);

        // Create game object for player
        games[msg.sender] = game(
            {
            player_hand: player_value,
            dealer_hand: dealer_value,
            bet: _bet
            }
        );
        total_games.push(msg.sender);
        emit return_game_state(player_value, dealer_value);
    }

    function end_game(address player) private {
        games[player].bet = 0;
        games[player].player_hand = 0;
        games[player].dealer_hand = 0;
    } 

    function hit() external {
        require(games[msg.sender].bet != 0, "Must start a new game to play.");
        games[msg.sender].player_hand += draw_random(0);
        uint player_value = games[msg.sender].player_hand;
        emit return_game_state(player_value, games[msg.sender].dealer_hand);
        if (player_value > 21) {
            // Player busts
            end_game(msg.sender);
        } else if (player_value == 21) {
            // Player hits blackjack, they're payed out 3:2
            uint win_amount = (games[msg.sender].bet * 5)/2;
            _approve(dealer, msg.sender, win_amount);
            transferFrom(dealer, msg.sender, win_amount);
            end_game(msg.sender);
        }
    }

    function stand() external {
        require(games[msg.sender].bet != 0, "Must start a new game to play.");
        uint player_value = games[msg.sender].player_hand;
        uint dealer_value = games[msg.sender].dealer_hand;

        // Dealer must draw until they reach 17 or bust
        bool playingGame = true;
        while (playingGame) {
            // Dealers must stand on or above 17 
            if (dealer_value >= 17 && dealer_value < 21) {
                if (player_value > dealer_value) {
                    // Player wins, double the orignal amount is returned to the player
                    uint win_amount = games[msg.sender].bet * 2;
                    _approve(dealer, msg.sender, win_amount);
                    transferFrom(dealer, msg.sender, win_amount);
                } else if (player_value == dealer_value) {
                    // A push, original amount is returned to player
                    uint win_amount = games[msg.sender].bet;
                    _approve(dealer, msg.sender, win_amount);
                    transferFrom(dealer, msg.sender, win_amount);
                }
                emit return_game_state(player_value, dealer_value);
                end_game(msg.sender);
                playingGame = false;
            } else if (dealer_value >= 21) {
                if (dealer_value != 21) {
                    // Dealer busts, double the orignal amount is returned to the player
                    uint win_amount = games[msg.sender].bet * 2;
                    _approve(dealer, msg.sender, win_amount);
                    transferFrom(dealer, msg.sender, win_amount);
                }
                emit return_game_state(player_value, dealer_value);
                end_game(msg.sender);
                playingGame = false;
            } else {
                // Dealer hasn't reached 17 or busted so they draw again
                dealer_value += draw_random(0);
                emit return_game_state(player_value, dealer_value);
            }
        }
    }
}