// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RwatLending is Ownable, IERC721Receiver {
    struct LoanDetails {
        address borrower;
        uint256 amountLoaned;
        bool isApproved;
    }

    mapping(uint256 => LoanDetails) private activeLoans;

    uint256 private constant PROPERTY_VALUATION = 2800;
    uint256 private constant INITIAL_THRESHOLD = 60;

    event LoanRequested(uint256 indexed tokenId, uint256 indexed loanAmount);
    event LoanApproved(uint256 indexed tokenId, bool approved);
    event Borrow(uint256 indexed tokenId, uint256 indexed loanAmount);
    event LoanRepayed(uint256 indexed tokenId);
    event LoanAmountTransferred(address indexed borrower, uint256 amount);
    event TokenReturned(address indexed borrower, uint256 indexed tokenId);

    error SlippageToleranceExceeded();
    error OnlyBorrowerCanCall();

    IERC721 public immutable tokenContract;

    constructor(address _tokenContract, address _owner) Ownable(_owner) {
        tokenContract = IERC721(_tokenContract);
    }

    function requestLoan(uint256 tokenId, uint256 minLoanAmount) external {
        // Transfer the token to the smart contract
        tokenContract.safeTransferFrom(msg.sender, address(this), tokenId);

        activeLoans[tokenId] = LoanDetails({
            borrower: msg.sender,
            amountLoaned: minLoanAmount,
            isApproved: false
        });

        emit LoanRequested(tokenId, minLoanAmount);
    }

    function approveLoan(uint256 tokenId) external onlyOwner payable {
        LoanDetails storage loan = activeLoans[tokenId];
        uint256 eligibleLoanAmount = (PROPERTY_VALUATION * INITIAL_THRESHOLD) / 100;

        if (eligibleLoanAmount >= loan.amountLoaned) {
            loan.isApproved = true;
            emit LoanApproved(tokenId, true);
            // Transfer the loan amount to the borrower account
            payable(loan.borrower).transfer(loan.amountLoaned);
            emit LoanAmountTransferred(loan.borrower, loan.amountLoaned);
        } else {
            loan.isApproved = false;
            emit LoanApproved(tokenId, false);

            // Return the token to the borrower
            tokenContract.safeTransferFrom(address(this), loan.borrower, tokenId);
            emit TokenReturned(loan.borrower, tokenId);
        }
    }

    function repay(uint256 tokenId) external payable {
        LoanDetails memory loanDetails = activeLoans[tokenId];
        require(msg.sender == loanDetails.borrower, "Only borrower can call");

        // Transfer the repaid amount to the contract owner
        payable(owner()).transfer(loanDetails.amountLoaned);

        // Return the NFT to the borrower
        tokenContract.safeTransferFrom(address(this), loanDetails.borrower, tokenId);

        // Emit events
        emit LoanRepayed(tokenId);
        emit TokenReturned(loanDetails.borrower, tokenId);

        // Delete the loan details
        delete activeLoans[tokenId];
    }

    function getLoanDetails(uint256 tokenId) external view returns (address borrower, uint256 amountLoaned, bool isApproved) {
        LoanDetails memory loan = activeLoans[tokenId];
        return (loan.borrower, loan.amountLoaned, loan.isApproved);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

}
