// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IInfo.sol";
import "../borrowing/status/Status.sol";

contract Info is IInfo, Status {

    using EnumerableSet for EnumerableSet.UintSet;

    function userLoans(address account) external view returns (uint[] memory userLoansTokenIds) {

        userLoansTokenIds = new uint[](10);
        uint realLength;

        for (uint i = 0; i < loansTokenIds.length(); i++) {

            // Get tokenId
            uint tokenId = loansTokenIds.at(i);

            if (_loans[tokenId].owner == account) {
                userLoansTokenIds[realLength] = tokenId;
                realLength += 1;
            }
        }

        for (uint i = realLength; i < userLoansTokenIds.length; i++) {
            userLoansTokenIds[i] = 999_999;
        }
    }

    function accruedInterest(uint tokenId) external view returns(uint) {
        return _accruedInterest(_loans[tokenId]);
    }

    function baseSaleFeeSpread() external view returns (UD60x18) {
        return _baseSaleFeeSpread;
    }

    function interestFeeSpread() external view returns (UD60x18) {
        return _interestFeeSpread;
    }

    function redemptionFeeSpread() external view returns (UD60x18) {
        return _redemptionFeeSpread;
    }

    function defaultFeeSpread() external view returns (UD60x18) {
        return _defaultFeeSpread;
    }

    function loansTokenIdsLength() external view returns (uint) {
        return loansTokenIds.length();
    }

    function loansTokenIdsAt(uint idx) external view returns (uint tokenId) {
        tokenId = loansTokenIds.at(idx);
    }

    function loans(uint tokenId) external view returns (Loan memory) {
        return _loans[tokenId];
    }

    function availableLiquidity() external view returns(uint) {
        return _availableLiquidity();
    }

    function lenderApy() public view returns(UD60x18) {
    //     if (totalDeposits == 0) {
    //         assert(maxTotalUnpaidInterest == 0);
    //         return convert(0);
    //     }
    //     return convert(maxTotalUnpaidInterest).div(convert(totalDeposits)); // Question: is this missing auto-compounding?
    }

    function utilization() public view returns(UD60x18) {
        if (totalDeposits == 0) {
            assert(totalPrincipal == 0);
            return convert(uint(0));
        }
        return convert(totalPrincipal).div(convert(totalDeposits));
    }

    function tUsdcToUsdc(uint tUsdcAmount) external view returns(uint usdcAmount) {
        
        // Get tUsdcSupply
        uint tUsdcSupply = tUSDC.totalSupply();

        // If tUsdcSupply or totalDeposits = 0, 1:1
        if (tUsdcSupply == 0 || totalDeposits == 0) {
            return usdcAmount = tUsdcAmount;
        }

        // Calculate usdcAmount
        return usdcAmount = tUsdcAmount * totalDeposits / tUsdcSupply;
    }

    function status(uint tokenId) external view returns (Status) {
        return _status(tokenId);
    }
}