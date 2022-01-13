import time
import hashlib
import json
import copy

from flask import Flask, jsonify, request
import requests
from urllib.parse import urlparse

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

    def add_node(self, address):
        self.nodes.add(urlparse(address).netloc)
    
    def replace_chain(self):
        longest_chain = None
        max_length = len(self.chain)
        for node in self.nodes:
            response = requests.get(f'http://{node}/get_chain')
            if response.status_code == 200:
                length = response.json()['length']
                chain = response.json()['chain']
                if length > max_length and self.validate_chain():
                    max_length = length
                    longest_chain = chain
        if longest_chain:
            self.chain = longest_chain
            return True
        return False

# Creating a web app
app = Flask(__name__)

# Creating a Blockchain instance
blockchain = Blockchain()

# Getting the full Blockchain
@app.route('/get_chain', methods = ['GET'])
def get_chain():
    chain_data = []
    for block in blockchain.chain:
        chain_data.append(block if type(block) is dict else block.__dict__)
    response = {'chain': chain_data, 'length': len(blockchain.chain)}
    return jsonify(response), 200

# Checking if the Blockchain is valid
@app.route('/is_valid', methods = ['GET'])
def is_valid():
    if blockchain.validate_chain():
        response = {'message': 'The Blockchain is valid.'}
    else:
        response = {'message': 'The Blockchain is not valid.'}
    return jsonify(response), 200

# Mining a new block
@app.route('/mine_block', methods = ['GET'])
def mine_block():
    response = blockchain.mine()
    return jsonify(response), 200

# # Adding a new transaction to the Blockchain
@app.route('/add_transaction', methods = ['POST'])
def add_transaction():
    json = request.get_json()
    print(json)
    transaction_keys = ['sender', 'receiver', 'amount']
    if not all(key in json for key in transaction_keys):
        return jsonify({'message': 'Some elements of the transaction are missing'}), 400
    blockchain.add_new_transaction({'sender': json['sender'], 'receiver': json['receiver'], 'amount': json['amount']})
    response = {'message': 'This transaction will be added to the next mined block.'}
    return jsonify(response), 201

# # Connecting new nodes
@app.route('/connect_node', methods = ['POST'])
def connect_node():
    json = request.get_json()
    nodes = json.get('nodes')
    if nodes is None:
        return "No node", 400
    for node in nodes:
        blockchain.add_node(node)
    response = {'message': 'All the nodes are now connected. The Blockchain now contains the following nodes:',
                'total_nodes': list(blockchain.nodes)}
    return jsonify(response), 201

# Replacing the chain by the longest chain if needed
@app.route('/replace_chain', methods = ['GET'])
def replace_chain():
    is_chain_replaced = blockchain.replace_chain()
    chain_data = []
    for block in blockchain.chain:
        chain_data.append(block if type(block) is dict else block.__dict__)
    if is_chain_replaced:
        response = {'message': 'The nodes had different chains so the chain was replaced by the longest one.',
                    'new_chain': chain_data}
    else:
        response = {'message': 'The current chain is the largest one.',
                    'actual_chain': chain_data}
    return jsonify(response), 200

# Running the app
app.run(port=5002)
