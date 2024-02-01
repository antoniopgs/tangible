# Tangible

### Description
Tangible is an RWA DeFi Mortgages protocol. It allows anyone

### Features
- NFTs: Legally Compliant NFTs, capable of representing RWA (property disputes can also be solved on-chain via arbitrator multisig)
- Lending Pool: Allows anyone to supply capital to the protocol and earn yeilds from mortgages. Includes tUSDC an SEC Compliant interest-bearing token (unavailable to US Citizens)
- On-Chain Mortgages: Gas-Efficient Amortization Schedule
- Auctions: Bidding mechanism to allow seamless real estate transactions. A user with an active mortgage can accept a bid, sell his house, pay off any mortgage debt, and keep the difference (all in one transaction).
- etc

### Architecture
- **protocol**
    - **state**
        - State.sol (holds all protocol state vars. the proxy and all logic contracts inherit from it, to avoid storage collisions)
        - TargetManager.sol (handles upgrade and delegatecall logic)
        - Roles.sol
    - **proxy**
        - ProtocolProxy.sol:  (the proxy responsible for mapping each function selector to the appropriate implementation)
    - **logic** (all non-abstract implementations inherit from State.sol)
        - Auctions.sol
        - Borrowing.sol
        - Info.sol (originally made to contain all external getters, and reduce size of other implementations. might get rid of it. under review)
        - Initializer.sol
        - Lending.sol
        - Residents.sol (Tracks who are the legitimate residents of the jurisdiction, which are the only eligible receivers of the NFT)
        - Setter.sol (originally made to contain all external setters, and reduce size of other implementations. might get rid of it. under review)
        - **interest**
            - InterestConstant.sol: Implementation of a Fixed/Constant Interest Rate Model
            - Interest2Slopes.sol: Implementation of a AAVE style 2 slope Interest Rate Model: https://www.desmos.com/calculator/cd10wksudo
            - InterestCurve.sol: Implementation of a smooth curve Interest Rate Model: https://www.desmos.com/calculator/nimb8tbzgb
        - **loanStatus**
            - Amortization.sol (holds implementation of a flexible & gas-efficient amortization schedule)
                - Mathematics Explanation: 
                - Desmos Implementation: https://www.desmos.com/calculator/cd10wksudo
            - LoanStatus.sol (inherits from Amortization.sol, to differentiate Active Mortgages from Defaults, and so on)
- **tokens**
    - TangibleNft.sol
    - tUSDC.sol

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
