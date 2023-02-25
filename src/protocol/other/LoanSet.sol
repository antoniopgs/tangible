// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

library LoanSet {

    struct Set {
        mapping(string => bool) contains;
        mapping(string => uint) indexes;
        Loan[] loans;
    }

    function get(Set storage set, string calldata propertyCid) internal view returns(IMortgageBase.Loan memory) {
        return set.loans[set.indexes[propertyCid]];
    }

    function at(Set storage set, uint idx) internal view returns(IMortgageBase.Loan memory) {
        return set.loans[idx];
    }

    function add(Set storage set, string calldata propertyCid, IMortgageBase.Loan calldata loan) internal {
        require(!set.contains[propertyCid], "set already contains loan");

        // Push loan into loans
        set.loans.push(loan);

        // Store loan index
        set.indexes[propertyCid] = set.loans.length - 1;

        // Update contains
        set.contains[propertyCid] = true;
    }

    function remove(Set storage set, string calldata propertyCid) internal {
        require(set.contains[propertyCid], "set doesn't contain loan");

        // Get index of element to remove
        uint idxToRemove = set.indexes[propertyCid];

        // Get lastLoan
        IMortgageBase.Loan memory lastLoan = set.loans[set.loans.length - 1];

        // Write lastLoan over item to remove
        set.loans[idxToRemove] = lastLoan;

        // Change lastLoan's propertyCid to index of item to remove
        set.indexes[lastLoan.propertyCid] = idxToRemove;

        // Remove lastLoan
        set.loans.pop();

        // Remove removed loan from contains mapping
        set.contains[propertyCid] = false;
    }

    function length(Set storage set) internal view returns(uint) {
        return set.loans.length;
    }
}