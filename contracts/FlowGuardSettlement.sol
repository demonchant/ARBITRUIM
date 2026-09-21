// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title FlowGuardSettlement
/// @notice Evidence-driven, non-custodial ERC-20 milestone settlement.
/// @dev Evidence itself stays private offchain. Its immutable content hash is attested onchain.
interface IERC20Minimal {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract FlowGuardSettlement {
    error Unauthorized();
    error InvalidAddress();
    error InvalidAmount();
    error InvalidDeadline();
    error InvalidThreshold();
    error InvalidState();
    error EvidenceAlreadySubmitted();
    error EvidenceAlreadyAttested();
    error EvidenceMissing();
    error TooEarly();
    error TransferFailed();
    error Reentrancy();
    error Paused();

    enum Status { Funded, EvidenceSubmitted, Disputed, Released, Refunded }

    struct Deal {
        address buyer;
        address supplier;
        address arbitrator;
        uint128 amount;
        uint64 deliveryDeadline;
        uint64 disputeWindow;
        uint64 submittedAt;
        uint8 requiredAttestations;
        uint8 attestationCount;
        Status status;
        bytes32 evidenceBundleHash;
    }

    IERC20Minimal public immutable settlementToken;
    address public immutable guardian;
    bool public paused;
    uint256 public dealCount;
    uint256 private locked = 1;

    mapping(uint256 => Deal) private deals;
    mapping(uint256 => mapping(address => bool)) public isAttestor;
    mapping(uint256 => mapping(address => bool)) public hasAttested;

    event DealCreated(uint256 indexed dealId, address indexed buyer, address indexed supplier, uint256 amount, uint64 deliveryDeadline, uint8 requiredAttestations);
    event EvidenceSubmitted(uint256 indexed dealId, bytes32 indexed evidenceBundleHash, uint64 submittedAt);
    event EvidenceAttested(uint256 indexed dealId, address indexed attestor, uint8 attestationCount);
    event DealDisputed(uint256 indexed dealId, address indexed buyer, bytes32 indexed reasonHash);
    event PaymentReleased(uint256 indexed dealId, address indexed supplier, uint256 amount);
    event BuyerRefunded(uint256 indexed dealId, address indexed buyer, uint256 amount);
    event DisputeResolved(uint256 indexed dealId, bool paidSupplier);
    event PauseChanged(bool paused);

    modifier nonReentrant() {
        if (locked != 1) revert Reentrancy();
        locked = 2;
        _;
        locked = 1;
    }

    modifier onlyGuardian() {
        if (msg.sender != guardian) revert Unauthorized();
        _;
    }

    constructor(address token_, address guardian_) {
        if (token_ == address(0) || guardian_ == address(0)) revert InvalidAddress();
        settlementToken = IERC20Minimal(token_);
        guardian = guardian_;
    }

    /// @notice Funds a deal atomically. The buyer selects every trusted attestor and the arbitrator.
    function createDeal(
        address supplier,
        address arbitrator,
        uint128 amount,
        uint64 deliveryDeadline,
        uint64 disputeWindow,
        address[] calldata attestors,
        uint8 requiredAttestations
    ) external nonReentrant returns (uint256 dealId) {
        if (paused) revert Paused();
        if (supplier == address(0) || arbitrator == address(0) || supplier == msg.sender) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        if (deliveryDeadline <= block.timestamp || disputeWindow == 0) revert InvalidDeadline();
        if (requiredAttestations == 0 || requiredAttestations > attestors.length || attestors.length > 16) revert InvalidThreshold();

        dealId = ++dealCount;
        Deal storage deal = deals[dealId];
        deal.buyer = msg.sender;
        deal.supplier = supplier;
        deal.arbitrator = arbitrator;
        deal.amount = amount;
        deal.deliveryDeadline = deliveryDeadline;
        deal.disputeWindow = disputeWindow;
        deal.requiredAttestations = requiredAttestations;
        deal.status = Status.Funded;

        for (uint256 i; i < attestors.length; ++i) {
            address attestor = attestors[i];
            if (attestor == address(0) || isAttestor[dealId][attestor]) revert InvalidAddress();
            isAttestor[dealId][attestor] = true;
        }
        _safeTransferFrom(msg.sender, address(this), amount);
        emit DealCreated(dealId, msg.sender, supplier, amount, deliveryDeadline, requiredAttestations);
    }

    /// @notice Supplier anchors an encrypted evidence-bundle hash before the delivery deadline.
    function submitEvidence(uint256 dealId, bytes32 evidenceBundleHash) external {
        if (paused) revert Paused();
        Deal storage deal = deals[dealId];
        if (deal.status != Status.Funded || msg.sender != deal.supplier) revert Unauthorized();
        if (block.timestamp > deal.deliveryDeadline) revert InvalidDeadline();
        if (evidenceBundleHash == bytes32(0)) revert EvidenceMissing();
        deal.status = Status.EvidenceSubmitted;
        deal.evidenceBundleHash = evidenceBundleHash;
        deal.submittedAt = uint64(block.timestamp);
        emit EvidenceSubmitted(dealId, evidenceBundleHash, deal.submittedAt);
    }

    /// @notice A selected courier, receiver, or sensor oracle attests to the exact evidence hash.
    function attestEvidence(uint256 dealId, bytes32 evidenceBundleHash) external {
        Deal storage deal = deals[dealId];
        if (deal.status != Status.EvidenceSubmitted || !isAttestor[dealId][msg.sender]) revert Unauthorized();
        if (evidenceBundleHash != deal.evidenceBundleHash) revert EvidenceMissing();
        if (hasAttested[dealId][msg.sender]) revert EvidenceAlreadyAttested();
        hasAttested[dealId][msg.sender] = true;
        unchecked { ++deal.attestationCount; }
        emit EvidenceAttested(dealId, msg.sender, deal.attestationCount);
    }

    /// @notice Buyer can release after valid evidence. Anyone can settle after the buyer's dispute window expires.
    function releasePayment(uint256 dealId) external nonReentrant {
        Deal storage deal = deals[dealId];
        if (deal.status != Status.EvidenceSubmitted || deal.attestationCount < deal.requiredAttestations) revert InvalidState();
        bool buyerApproval = msg.sender == deal.buyer;
        bool timedApproval = block.timestamp >= uint256(deal.submittedAt) + deal.disputeWindow;
        if (!buyerApproval && !timedApproval) revert TooEarly();
        deal.status = Status.Released;
        _safeTransfer(deal.supplier, deal.amount);
        emit PaymentReleased(dealId, deal.supplier, deal.amount);
    }

    /// @notice Buyer disputes only during the agreed evidence review window.
    function dispute(uint256 dealId, bytes32 reasonHash) external {
        Deal storage deal = deals[dealId];
        if (msg.sender != deal.buyer || deal.status != Status.EvidenceSubmitted) revert Unauthorized();
        if (block.timestamp >= uint256(deal.submittedAt) + deal.disputeWindow || reasonHash == bytes32(0)) revert InvalidState();
        deal.status = Status.Disputed;
        emit DealDisputed(dealId, msg.sender, reasonHash);
    }

    /// @notice Refunds the buyer after a missed delivery deadline, without needing a privileged actor.
    function refundExpired(uint256 dealId) external nonReentrant {
        Deal storage deal = deals[dealId];
        if (msg.sender != deal.buyer || deal.status != Status.Funded || block.timestamp <= deal.deliveryDeadline) revert InvalidState();
        deal.status = Status.Refunded;
        _safeTransfer(deal.buyer, deal.amount);
        emit BuyerRefunded(dealId, deal.buyer, deal.amount);
    }

    /// @notice The deal-specific arbitrator resolves only a disputed deal; no admin can seize funds.
    function resolveDispute(uint256 dealId, bool paySupplier) external nonReentrant {
        Deal storage deal = deals[dealId];
        if (msg.sender != deal.arbitrator || deal.status != Status.Disputed) revert Unauthorized();
        deal.status = paySupplier ? Status.Released : Status.Refunded;
        _safeTransfer(paySupplier ? deal.supplier : deal.buyer, deal.amount);
        emit DisputeResolved(dealId, paySupplier);
        if (paySupplier) emit PaymentReleased(dealId, deal.supplier, deal.amount);
        else emit BuyerRefunded(dealId, deal.buyer, deal.amount);
    }

    /// @notice Emergency pause only blocks new deals and evidence; users can always exit settled paths.
    function setPaused(bool paused_) external onlyGuardian {
        paused = paused_;
        emit PauseChanged(paused_);
    }

    function getDeal(uint256 dealId) external view returns (Deal memory) {
        return deals[dealId];
    }

    function _safeTransferFrom(address from, address to, uint256 amount) private {
        (bool ok, bytes memory data) = address(settlementToken).call(abi.encodeCall(IERC20Minimal.transferFrom, (from, to, amount)));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransfer(address to, uint256 amount) private {
        (bool ok, bytes memory data) = address(settlementToken).call(abi.encodeCall(IERC20Minimal.transfer, (to, amount)));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
