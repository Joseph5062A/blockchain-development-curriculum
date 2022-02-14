// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol';

contract NFTAuction is ERC721URIStorage {
    // A counter is used and incremented to ensure that no two NFTs or auctions have the same ID
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIDs;
    Counters.Counter private _auctionIDs;

    address public owner;
    struct auction {
        uint token_ID;
        address token_owner;
        uint current_bid;
        address lead_bidder;
        uint end_time;
    }
    mapping (uint => auction) auctions;
    uint[] public total_auctions;

    constructor() ERC721("NFTAuction", "NFA") {}

    // Owner of this smart contract calls this function to mint an NFT of an URI (Uniform Resource Identifier) for a specified user
    // These URI's represent anything from HTTPS API calls, to something through IPFS, or some other type of unique identifier
    function mintNft(address receiver, string memory tokenURI) external returns (uint) {
        require(msg.sender == owner, "Only the owner can mint NFTs.");
        _tokenIDs.increment();
        uint newNftTokenID = _tokenIDs.current();

        _mint(receiver, newNftTokenID);
        _setTokenURI(newNftTokenID, tokenURI);

        return newNftTokenID;
    }

    event return_auction(uint token_ID, uint current_bid, address lead_bidder, uint end_time);

    function createAuction(uint tokenID, uint endTime, uint minBid) external {
        require(msg.sender == ownerOf(tokenID), "Must own token to auction it off.");
        require(minBid > 0, "Minimum bid must be greater than 0.");
        _auctionIDs.increment();
        auctions[_auctionIDs.current()] = auction(
            {
            token_ID: tokenID,
            token_owner: msg.sender,
            current_bid: minBid,
            lead_bidder: owner,
            end_time: endTime
            }
        );
        total_auctions.push(_auctionIDs.current());
        emit return_auction(tokenID, minBid, owner, endTime);
    }

    function bid(uint auctionID, uint amount) external {
        require(auctions[auctionID].token_ID != 0, "Auction must exist to bid.");
        require(msg.sender != auctions[auctionID].lead_bidder && msg.sender != auctions[auctionID].token_owner, "Already involved in auction.");
        require(amount > auctions[auctionID].current_bid, "Bid must be greater than current bid.");
        payable(auctions[auctionID].lead_bidder).transfer(auctions[auctionID].current_bid);
        payable(owner).transfer(amount - auctions[auctionID].current_bid);
        auctions[auctionID].lead_bidder = msg.sender;
        auctions[auctionID].current_bid = amount;
    }

    // In a real world use case, the dApp interacting with this contract would schedule an additional call to this function, a second past
    // the specified end time for the auction, in a queue when the createAuction() function was initially called
    function endAuction(uint auctionID) external {
        require(msg.sender == owner, "Only the owner can end auctions.");
        require(auctions[auctionID].end_time < block.timestamp, "Auction hasn't reached its expiration date yet.");
        address lead_bidder = auctions[auctionID].lead_bidder;
        if (lead_bidder != owner) {
            uint TID = auctions[auctionID].token_ID;
            address token_owner = auctions[auctionID].token_owner;
            approve(lead_bidder, TID);
            transferFrom(token_owner, lead_bidder, TID);
            payable(token_owner).transfer(auctions[auctionID].current_bid);
        }
        auctions[auctionID].token_ID = 0;
        auctions[auctionID].current_bid = 0;
        auctions[auctionID].end_time = 0;
        auctions[auctionID].token_owner = address(0);
        auctions[auctionID].lead_bidder = address(0);
    }
}