import time
import hashlib
import json
import copy
from urllib.parse import urlparse
from flask import Flask, jsonify, request
import requests


class Block:
    def __init__(self, index, timestamp, previous_hash, transactions, nonce):
        self.index = index
        self.timestamp = timestamp
        self.previous_hash = previous_hash
        self.transactions = transactions
        self.nonce = nonce

    def compute_hash(self):
        attributes = copy.copy(self.__dict__)
        if 'hash' in attributes:
            attributes.pop('hash')
        block_string = json.dumps(attributes, sort_keys=True)
        return hashlib.sha256(block_string.encode()).hexdigest()

class Blockchain:
    def __init__(self, difficulty=4):
        self.unconfirmed_transactions = []
        self.chain = []
        genesis_block = Block(0, time.time(), "0", [], 0)
        genesis_block.hash = genesis_block.compute_hash()
        self.chain.append(genesis_block)
        self.difficulty = difficulty
        self.nodes = set()
    
    def consensus(self, block):
        computed_hash = block.compute_hash()
        while not computed_hash.startswith('0' * self.difficulty):
            block.nonce += 1
            computed_hash = block.compute_hash()
        return computed_hash

    def is_valid_hash(self, block, block_hash):
        return (block_hash.startswith('0' * self.difficulty) and block_hash == block.compute_hash())

    def add_new_transaction(self, transaction):
        self.unconfirmed_transactions.append(transaction)
    
    def add_block(self, block, block_hash):
        previous_hash = self.chain[-1].hash
        if previous_hash != block.previous_hash:
            return "Warning: The previous hash of the given block doesn't match the hash of the previous block."
        if not self.is_valid_hash(block, block_hash):
            return "Warning: The hash of the given block is not valid."
        block.hash = block_hash
        self.chain.append(block)
        if block.transactions:
            ret_str = ""
            for t in block.transactions:
                ret_str += json.dumps(t) + "\n"
            return f"A block with the following transactions has been succesfully added to the blockchain:\n{ret_str}"
        else:
            return "A block has been succesfully added to the blockchain."

    def mine(self):
        last_block = self.chain[-1]
        new_block = Block(index = last_block.index + 1,
                          timestamp = time.time(),
                          previous_hash = last_block.hash,
                          transactions = self.unconfirmed_transactions,
                          nonce = 0)
        block_hash = self.consensus(new_block)
        response = self.add_block(new_block, block_hash)
        self.unconfirmed_transactions = []
        return response

    def validate_chain(self):
        previous_block = self.chain[0]
        block_index = 1
        while block_index < len(self.chain):
            block = self.chain[block_index]
            if block.previous_hash != previous_block.compute_hash():
                return "Warning: Mismatching block hashes are detected."
            block_hash = block.compute_hash()
            if not self.is_valid_hash(block, block_hash):
                return "Warning: Current block hash is invalid."
            previous_block = block
            block_index += 1
        return "Blockchain is valid."
