// TODO Add Pragma

import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol';

contract KnockOutToken is ERC20 {

    // Declaring an address variable for the address who deployed the contract
    address public opponent;

    // Structure of a game of Knockout, only the bet data persists here for the game of Knockout, however more data could be stored here for more complex games
    struct game { uint bet; }

    // Creating a mapping between a user's address and a game of knockout (similar to a hash map)
    mapping (address => game) games;
    address[] public total_games; 

    // The constructor of the smart contract, only called once on deployment of the contract, notice how it also calls the ERC20 constructor
    constructor() ERC20('KnockoutToken', 'KOT') {
        // Assigning the account which deployed the smart contract to be the opponent for the game
        opponent = msg.sender; 
        // Inital supply of 1000 tokens minted for the account which deployed the smart contract, with 18 decimal points (ERC20 default)
        _mint(opponent, 1000 * 10 ** 18);
    }

    // Creating a wrapper function around the the mint functionality in the ERC20 contract. 
    // The external keyword means it can be called outside of the smart contract
    function mint(address to, uint amount) external {
        // The require function is used for validating conditions before executing the code in the rest of the function.
        // If the condition (first parameter) fails, the transaction will fail and the message (second parameter) will be returned
        require(msg.sender == opponent, "Only the opponent can mint tokens.");
        // Calling the _mint function from the ERC20 contract (https://docs.openzeppelin.com/contracts/2.x/api/token/erc20#ERC20-_mint-address-uint256-)
        _mint(to, amount);
    }

    // Creating a function which uses pseudo-randomness to simulate rolling a dice
    // The private key word means it can only be called by other functions within the contract
    // The view key word means it is view only and does not modify the contract's state
    // The seed parameter is used in case multiple random numbers need to be generated in one block (using multiple seeds)
    function roll_dice(uint _seed) private view returns (uint){
        // Generating pseudo-random value between 0 and 5 using the keccak256 hashing function
        uint roll = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, _seed))) % 6;
        // Adding one to the dice value so it's range is between 1 and 6, and then returning it
        return ++roll;
    }

    // An external function which a player can use to place a bet and start a new game
    function new_game(uint _bet) external {
        // Require functions which ensure that the address calling the contract to start a new
        // game isn't already playing a game and has placed a non-zero bet for this new game
        require(games[msg.sender].bet == 0, "A current game is already in play.");
        require(_bet > 0, "Bet must be greater than zero.");

        // Require function which ensures the address calling the contract has a balance can cover their bet
        uint balance = balanceOf(msg.sender);
        require((balance > 0) && (_bet < balance), "Not enough tokens to play.");

         // Using a function from the ERC20 contract to send the bet to the smart contract deployer, in this case, the opponent of the game
        transfer(opponent, _bet);

        // Create game object for player and appending it to the address-game mapping
        games[msg.sender] = game({ bet: _bet });
        total_games.push(msg.sender);
    }

    // A private function that resets the bet of a player in the address-game mapping once their game has ended
    function end_game(address player) private {
        games[player].bet = 0;
    } 

    // An event must be created and emited in order to return information to a user who calls an external function outside of the smart contract
    event return_game_state(uint player_value, uint opponent_value);

    // An external function which a player can use to play a round of a game once they've created one by calling the new_game function
    function play_round() external {
        // Require function which ensure that a game is in play for the player address which called the smart contract
        require(games[msg.sender].bet != 0, "Must start a new game to play.");

        // Using the roll_dice function described earlier to roll a dice for the player and the opponent
        uint player_roll = roll_dice(0);
        uint opponent_roll = roll_dice(1);

        // Emitting the previously created event to inform the player of their dice value and the dice value of the opponent
        emit return_game_state(player_roll, opponent_roll);

        // When the player wins, pay out double their taken bet using functions from the ERC20 contract and end the game
        if (player_roll > opponent_roll) { 
            uint win_amount = games[msg.sender].bet * 2;
            // Before a smart contract can transact tokens on behalf of another account, they must ask for approval from the other account
            _approve(opponent, msg.sender, win_amount);
            // Once approval is gained, they can transact the approved amount of tokens
            transferFrom(opponent, msg.sender, win_amount);
            end_game(msg.sender);
        } else if (opponent_roll > player_roll) { // When the oponent wins, don't pay out anything and end the game
            end_game(msg.sender);
        }
        // If player and opponent tie, another round can be played
    }
}