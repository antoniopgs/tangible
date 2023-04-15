// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// import "./targetManager/TargetManager.sol";
// import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
// import "../tokens/tUsdc.sol";
import { UD60x18 } from "@prb/math/UD60x18.sol";

interface IState {

    // Structs
    struct Loan {
        address borrower;
        UD60x18 ratePerSecond;
        UD60x18 paymentPerSecond;
        uint startTime;
        uint unpaidPrincipal;
        uint maxUnpaidInterest;
        uint maxDurationSeconds;
        uint lastPaymentTime;
    }

    // enum State { None, Mortgage, Default, Foreclosurable }
    enum Status { None, Mortgage, Default }
}