// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 < 0.9.9;

interface ERC20Interface {
    function totalSupply() external view returns (uint);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function transfer(address to, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);
    function approve(address spender, uint tokens) external returns (bool success);
    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    
    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract Crypto is ERC20Interface {
    string public name = "Musabs Coin";
    string public symbol = "MsCo";
    uint public decimals = 0; // Fixed typo: was "decimal"
    uint public override totalSupply;
    address public founder;

    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint)) public allowed;

    constructor() {
        totalSupply = 1000;
        founder = msg.sender;
        balances[founder] = totalSupply;
    }

    function transfer(address to, uint tokens) public override returns(bool success) {
        require(balances[msg.sender] >= tokens, "Insufficient balance");
        require(to != address(0), "Cannot transfer to zero address");
        
        balances[msg.sender] -= tokens; 
        balances[to] += tokens;
        emit Transfer(msg.sender, to, tokens);
        return true;
    }

    function transferFrom(address from, address to, uint tokens) public override returns(bool success) {
        require(balances[from] >= tokens, "Insufficient balance");
        require(allowed[from][msg.sender] >= tokens, "Insufficient allowance");
        require(to != address(0), "Cannot transfer to zero address");
        
        balances[from] -= tokens;
        balances[to] += tokens;
        allowed[from][msg.sender] -= tokens;
        
        emit Transfer(from, to, tokens);
        return true;
    }

    function approve(address spender, uint tokens) public override returns(bool success) {
        require(spender != address(0), "Cannot approve zero address");
        
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }

    function allowance(address tokenOwner, address spender) public override view returns(uint remaining) {
        return allowed[tokenOwner][spender];
    }

    function balanceOf(address tokenOwner) public override view returns (uint balance) {
        return balances[tokenOwner];
    }
}