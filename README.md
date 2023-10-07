## Understanding the Attack
- `create` address = hash(sender, nonce)
- `create2` address = hash(0xFF, sender, salt, bytecode)
- The addresses of contracts created with the `create` and `create2` methodology can be pre-computed.

0. A person from TornadoCash deploys their `TornadoCashDAO` contract. Responsible for approving and executing proposals. 
1. Attacker deploys contract `DeployerUsingCreate2`. A contract that will deploy another contact called `DeployerUsingCreate` using `create2`. The address of `DeployerUsingCreate` will always be fixed at `0xXYZ` because `create2` is based on the bytecode of the contract being deployed.
2. Attacker calls `DeployerUsingCreate` contract with normal `create` to deploy `Proposal` contract at address be `0xABC`. The contract address of a contract being deployed with `create` depends on the sender and nonce. It can also be pre-computed just like create2, except using sender and nonce rather than the bytecode.
3. The people at TornadoCash governance voted that the `Proposal` contract at address `0xABC` was not malicious. `selfdestruct` was somehow hidden in the code. The `TornadoCashDAO` then contract calls `approve` for `Proposal`. The contract address `0xABC` associated with `Proposal` can now call `execute` whenever they want, which is a delegate call to the DAO. However, `Proposal` doesn't actually contain any directly malicious code. The attacker needs to deploy a malicious contract at the same address of `Proposal` now.
4. Attacker selfdestructs `Proposal` and `DeployerUsingCreate` contracts. Self destructing `DeployerUsingCreate` allows for the nonce to be reset, if the attacker can manage to deploy `DeployerUsingCreate` to the same address.
5. Attacker redeploys `DeployerUsingCreate` contract with `DeployerUsingCreate2` using `create2`. `DeployerUsingCreate` will have the same address of `0xXYZ` because it's bytecode is the same. 
6. Attacker deploys `Attack` contract with `DeployerUsingCreate` using `create`, which also gives it the same address of `Proposal` of `0xABC`. This is because the sender is the same, `DeployerUsingCreate`, and the nonce is 0, the same as before. Effectively, the attacker had to find a clever way to reset the nonce to 0 in order to make another contract at the same address.
7. Attacker runs `executeProposal` inside `Attack`, which invokes a delegatecall inside `TornadoCash` contract from it's `execute` function, allowing the malicious code from `Attack` to be run in the context of `TornadoCash`. `TornadoCash` thought this contract was `Proposal`, since it's address is the same, and is already verified, but it's actually `Attack`.


## Recreating the Attack
- Deploy `TornadoCashDAO` with an Address 'A', representing an entity associated with TornadoCash DAO.
- Attacker deploys `DeployerUsingCreate2` contract with address 'B', representing the attackers address.
- Attacker calls `deploy` function from `DeployerUsingCreate2` to deploy `DeployerUsingCreate`, attacker retrieves address of `DeployerUsingCreate`.
- Attacker calls `deployProposal` function from `DeployerUsingCreate` to deploy the innocent `Proposal` contract, attacker retrieves address of `Proposal`.
- TornadoCash DAO votes to approve the `Proposal` contract, and then `TornadoCashDAO` contract calls `approve` for `Proposal`.
- Attacker calls `emergencyStop` and `kill` for `Proposal` and `Deployer`, self destructing both.
- Attacker calls `deploy` function from `DeployerUsingCreate2` to deploy `DeployerUsingCreate` again. The address is the same as before.
- Attacker calls `deployAttack` function from `DeployerUsingCreate` to deploy the malicious `Attack` contract. The address is the same as `Proposal`.
- `TornadoCashDAO` calls `execute` to bring in the proposal's update. It uses a delegatecall to call the `executeProposal` function in `Attack`. The `executeProposal` function is malicious in `Attack`, and changes the owner to the `Attack` contract.

## Lessons
- Assume `selfdestruct` is malicious even if coming from a trusted source. Carefully analyze the code and exactly why it was added.
- Be wary of delegatecalls as always.
- A contract can be re-created at the same address after having been destroyed. But it is possible for that newly created contract to have a different deployed bytecode even though the creation bytecode has been the same. Iif the constructor can query external state that might have changed between the two creations and incorporate that into the deployed bytecode before it is stored. 

## References:
- https://docs.soliditylang.org/en/latest/control-structures.html#salted-contract-creations-create2
- https://www.youtube.com/watch?v=whjRc4H-rAc
