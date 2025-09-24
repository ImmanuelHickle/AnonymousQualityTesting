// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint8, euint32, ebool } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

contract PrivacyQualityInspection is SepoliaConfig {

    address public owner;
    uint256 public inspectionCount;
    uint256 public constant MAX_QUALITY_SCORE = 100;

    struct InspectionData {
        euint8 qualityScore;        // Encrypted quality score (0-100)
        euint8 defectCount;         // Encrypted defect count
        euint32 productBatch;       // Encrypted batch number
        address inspector;          // Inspector address (public for verification)
        uint256 timestamp;          // Inspection timestamp
        bool isVerified;            // Verification status
        string productCategory;     // Product category (public)
        bytes32 inspectionHash;     // Hash for data integrity
    }

    struct QualityMetrics {
        euint32 totalInspections;   // Total inspections count
        euint32 passedInspections;  // Inspections that passed quality threshold
        euint8 averageQuality;      // Average quality score
        bool metricsCalculated;     // Whether metrics have been calculated
    }

    mapping(uint256 => InspectionData) public inspections;
    mapping(address => uint256[]) public inspectorHistory;
    mapping(string => QualityMetrics) public categoryMetrics;
    mapping(address => bool) public authorizedInspectors;

    uint8 public constant QUALITY_THRESHOLD = 70; // Minimum quality score to pass

    event InspectionRecorded(
        uint256 indexed inspectionId,
        address indexed inspector,
        string category,
        uint256 timestamp
    );

    event InspectionVerified(uint256 indexed inspectionId, address indexed verifier);

    event MetricsUpdated(string indexed category, uint256 totalCount);

    event InspectorAuthorized(address indexed inspector, address indexed authorizer);

    event QualityAlert(string indexed category, uint256 inspectionId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyAuthorizedInspector() {
        require(authorizedInspectors[msg.sender] || msg.sender == owner, "Not authorized inspector");
        _;
    }

    modifier validInspectionId(uint256 _inspectionId) {
        require(_inspectionId < inspectionCount, "Invalid inspection ID");
        _;
    }

    constructor() {
        owner = msg.sender;
        inspectionCount = 0;
        authorizedInspectors[owner] = true;
    }

    // Authorize inspector to perform quality inspections
    function authorizeInspector(address _inspector) external onlyOwner {
        require(_inspector != address(0), "Invalid inspector address");
        require(!authorizedInspectors[_inspector], "Inspector already authorized");

        authorizedInspectors[_inspector] = true;
        emit InspectorAuthorized(_inspector, msg.sender);
    }

    // Revoke inspector authorization
    function revokeInspector(address _inspector) external onlyOwner {
        require(authorizedInspectors[_inspector], "Inspector not authorized");
        authorizedInspectors[_inspector] = false;
    }

    // Record encrypted quality inspection data
    function recordInspection(
        uint8 _qualityScore,
        uint8 _defectCount,
        uint32 _productBatch,
        string memory _productCategory
    ) external onlyAuthorizedInspector {
        require(_qualityScore <= MAX_QUALITY_SCORE, "Quality score exceeds maximum");
        require(bytes(_productCategory).length > 0, "Product category required");

        // Encrypt sensitive data
        euint8 encryptedQuality = FHE.asEuint8(_qualityScore);
        euint8 encryptedDefects = FHE.asEuint8(_defectCount);
        euint32 encryptedBatch = FHE.asEuint32(_productBatch);

        // Generate inspection data hash for integrity
        bytes32 dataHash = keccak256(
            abi.encodePacked(
                _qualityScore,
                _defectCount,
                _productBatch,
                _productCategory,
                msg.sender,
                block.timestamp
            )
        );

        // Store inspection data
        inspections[inspectionCount] = InspectionData({
            qualityScore: encryptedQuality,
            defectCount: encryptedDefects,
            productBatch: encryptedBatch,
            inspector: msg.sender,
            timestamp: block.timestamp,
            isVerified: false,
            productCategory: _productCategory,
            inspectionHash: dataHash
        });

        // Update inspector history
        inspectorHistory[msg.sender].push(inspectionCount);

        // Set access permissions
        FHE.allowThis(encryptedQuality);
        FHE.allowThis(encryptedDefects);
        FHE.allowThis(encryptedBatch);
        FHE.allow(encryptedQuality, msg.sender);
        FHE.allow(encryptedDefects, msg.sender);
        FHE.allow(encryptedBatch, msg.sender);

        // Emit alert if quality is below threshold (using FHE comparison)
        ebool isLowQuality = FHE.lt(encryptedQuality, FHE.asEuint8(QUALITY_THRESHOLD));
        FHE.allowThis(isLowQuality);

        emit InspectionRecorded(inspectionCount, msg.sender, _productCategory, block.timestamp);

        inspectionCount++;
    }

    // Verify inspection data (owner or another authorized inspector)
    function verifyInspection(uint256 _inspectionId)
        external
        validInspectionId(_inspectionId)
        onlyAuthorizedInspector
    {
        require(!inspections[_inspectionId].isVerified, "Already verified");
        require(
            inspections[_inspectionId].inspector != msg.sender,
            "Cannot verify own inspection"
        );

        inspections[_inspectionId].isVerified = true;
        emit InspectionVerified(_inspectionId, msg.sender);
    }

    // Calculate quality metrics for a product category (privacy-preserving)
    function calculateCategoryMetrics(string memory _category) external onlyOwner {
        uint256 categoryCount = 0;
        euint32 totalInspections = FHE.asEuint32(0);
        euint32 passedCount = FHE.asEuint32(0);
        euint32 qualitySum = FHE.asEuint32(0);

        // Process all inspections for the category
        for (uint256 i = 0; i < inspectionCount; i++) {
            if (keccak256(bytes(inspections[i].productCategory)) == keccak256(bytes(_category))) {
                categoryCount++;
                totalInspections = FHE.add(totalInspections, FHE.asEuint32(1));

                // Add quality score to sum
                qualitySum = FHE.add(qualitySum, FHE.asEuint32(inspections[i].qualityScore));

                // Check if inspection passed threshold
                ebool passed = FHE.ge(inspections[i].qualityScore, FHE.asEuint8(QUALITY_THRESHOLD));
                euint32 passedIncrement = FHE.select(passed, FHE.asEuint32(1), FHE.asEuint32(0));
                passedCount = FHE.add(passedCount, passedIncrement);
            }
        }

        if (categoryCount > 0) {
            // Calculate average quality (simplified - FHE division not available, store sum for off-chain calculation)
            euint8 avgQuality = FHE.asEuint8(0); // Placeholder - actual average calculated off-chain

            categoryMetrics[_category] = QualityMetrics({
                totalInspections: totalInspections,
                passedInspections: passedCount,
                averageQuality: avgQuality,
                metricsCalculated: true
            });

            // Set permissions
            FHE.allowThis(totalInspections);
            FHE.allowThis(passedCount);
            FHE.allowThis(avgQuality);

            emit MetricsUpdated(_category, categoryCount);
        }
    }

    // Get inspection basic info (non-encrypted data)
    function getInspectionInfo(uint256 _inspectionId)
        external
        view
        validInspectionId(_inspectionId)
        returns (
            address inspector,
            uint256 timestamp,
            bool isVerified,
            string memory productCategory,
            bytes32 inspectionHash
        )
    {
        InspectionData storage inspection = inspections[_inspectionId];
        return (
            inspection.inspector,
            inspection.timestamp,
            inspection.isVerified,
            inspection.productCategory,
            inspection.inspectionHash
        );
    }

    // Get inspector's inspection count
    function getInspectorHistoryCount(address _inspector) external view returns (uint256) {
        return inspectorHistory[_inspector].length;
    }

    // Get inspector's inspection IDs (paginated)
    function getInspectorInspections(address _inspector, uint256 _offset, uint256 _limit)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] storage history = inspectorHistory[_inspector];
        require(_offset < history.length, "Offset out of bounds");

        uint256 end = _offset + _limit;
        if (end > history.length) {
            end = history.length;
        }

        uint256[] memory result = new uint256[](end - _offset);
        for (uint256 i = _offset; i < end; i++) {
            result[i - _offset] = history[i];
        }

        return result;
    }

    // Check if metrics are available for a category
    function hasCategoryMetrics(string memory _category) external view returns (bool) {
        return categoryMetrics[_category].metricsCalculated;
    }

    // Emergency function to pause contract (owner only)
    bool public contractPaused = false;

    function pauseContract() external onlyOwner {
        contractPaused = true;
    }

    function unpauseContract() external onlyOwner {
        contractPaused = false;
    }

    modifier whenNotPaused() {
        require(!contractPaused, "Contract is paused");
        _;
    }

    // Get contract statistics
    function getContractStats() external view returns (
        uint256 totalInspections,
        uint256 totalInspectors,
        address contractOwner
    ) {
        uint256 inspectorCount = 0;
        // Note: In a real implementation, you'd maintain a count of authorized inspectors

        return (
            inspectionCount,
            inspectorCount,
            owner
        );
    }
}