# Tangible

### Description
Tangible is an RWA DeFi Mortgages protocol. It allows anyone

### Components
- NFTs
- Lending Pool
- On-Chain Mortgages
- Auctions
- etc

### Features
- Gas-Efficient Amortization Schedule
- Legally Compliant NFTs (capable of representing Real-Estate and property disputed can be solved on-chain by multisig)
- 

### Links
- MVP: https://tangible-frontend.vercel.app/
- MVP Demo: https://drive.google.com/file/d/1wTIdks_wdpMdmPu6DnEVThOgOw6iFtRA/view?usp=sharing
- On-Chain Gas-Efficient Amortization Schedule Mathematics:

### TODOs/Fixes
- Main
    - Add safety mechanism to protect against clashing function selectors
    - Improve state initialization
    - Finish test suite (to reach full coverage)
    - Replace PRB with my own Fixed Point Math
    - Foundry supports stateful fuzzing. Use it to replace GeneralFuzz.t.sol
    - TargetManager upgrades should be behind a dao with a timelock
    - Improve usage of environment variables
    - Improve Gas-Expensive Functions:
        - highestActionableBid() (max heap?)
        - _defaultTime() (should be able to have the user pass in the defaultTime as a param, and only have the smart contract sanity check the preceding and subsequent month)
- Other
    - Expected vars in tests aren't being used
    - Implement foundry scripts/tasks with vm.broadcast
    - NatSpec comments
    - Improve contract and variable naming
    - Figure out how to simplify and shorten selector setting scripts
    - Slippage Protection
    - Tokenized Vault Inflation Vulnerabilities (maybe implement ERC4626)
    - Replace error strings with custom errors for gas efficiency


### Future Features
- Mortgage Refinancing
- Fractionalization
    - Fractional Real Estate Ownership (ERC 1155 with nested mappings)
    - Ability to take out mortgage to purchase a fraction of a property
    - Build an exchange allowing users to buy in/out of real estate fractions

### Frameworks
- Foundry
- Hardhat
