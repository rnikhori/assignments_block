// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/ECDSA.sol";

contract Escrow {
    using ECDSA for bytes32;

    struct Deposit {
        uint256 amount;
        address depositor;
        bytes32 beneficiaryHash;
        bool released;
    }

    mapping(uint256 => Deposit) public deposits;
    uint256 public depositCount;

    event DepositMade(uint256 depositId, address indexed depositor, uint256 amount);
    event FundsReleased(uint256 depositId, address indexed beneficiary, uint256 amount);

    function deposit(bytes32 beneficiaryHash) external payable {
        deposits[depositCount] = Deposit({
            amount: msg.value,
            depositor: msg.sender,
            beneficiaryHash: beneficiaryHash,
            released: false
        });

        emit DepositMade(depositCount, msg.sender, msg.value);

        depositCount++;
    }

    function release(uint256 depositId, address beneficiary, bytes memory signature) external {
        Deposit storage deposit = deposits[depositId];
        require(!deposit.released, "Funds already released");      
        bytes32 hash = keccak256(abi.encodePacked(beneficiary));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
        require(ECDSA.recover(ethSignedMessageHash, signature) == beneficiary, "Invalid signature");
        deposit.released = true;
        payable(beneficiary).transfer(deposit.amount);
        emit FundsReleased(depositId, beneficiary, deposit.amount);
    }
}

//escrow contract address 0xd8b934580fcE35a11B58C6D73aDeE468a2833fa8
//depositor account address 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
//benficiary account address 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db
