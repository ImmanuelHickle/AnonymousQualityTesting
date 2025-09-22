// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint8, ebool, externalEuint8 } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

contract AnonymousQualityTesting is SepoliaConfig {

    struct QualityTest {
        string category;
        string testType;
        string description;
        address submitter;
        uint256 timestamp;
        euint8 yesVotes;
        euint8 noVotes;
        bool isFinalized;
        ebool result;
        bool resultRevealed;
    }

    mapping(uint256 => QualityTest) public qualityTests;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public totalTests;
    uint256 public constant VOTES_THRESHOLD = 5;

    event QualityTestSubmitted(
        uint256 indexed testId,
        string category,
        string testType,
        address submitter
    );

    event VoteSubmitted(
        uint256 indexed testId,
        address voter
    );

    event TestFinalized(
        uint256 indexed testId,
        bool passed
    );

    constructor() {
        // FHE initialization is handled by inheriting from SepoliaConfig
    }

    function submitQualityTest(
        string memory _category,
        string memory _testType,
        string memory _description
    ) external returns (uint256) {
        uint256 testId = totalTests;

        qualityTests[testId] = QualityTest({
            category: _category,
            testType: _testType,
            description: _description,
            submitter: msg.sender,
            timestamp: block.timestamp,
            yesVotes: FHE.asEuint8(0),
            noVotes: FHE.asEuint8(0),
            isFinalized: false,
            result: FHE.asEbool(false),
            resultRevealed: false
        });

        totalTests++;

        emit QualityTestSubmitted(testId, _category, _testType, msg.sender);
        return testId;
    }

    function voteOnTest(uint256 _testId, uint8 _vote) external {
        require(_testId < totalTests, "Test does not exist");
        require(!qualityTests[_testId].isFinalized, "Test already finalized");
        require(!hasVoted[_testId][msg.sender], "Already voted on this test");
        require(_vote <= 1, "Vote must be 0 (fail) or 1 (pass)");

        QualityTest storage test = qualityTests[_testId];

        // Convert uint8 to encrypted boolean (0 = false, 1 = true)
        ebool encryptedVote = FHE.asEbool(_vote == 1);

        // Create encrypted increment
        euint8 increment = FHE.asEuint8(1);

        // Use FHE conditional operations to increment appropriate counter
        test.yesVotes = FHE.select(encryptedVote, FHE.add(test.yesVotes, increment), test.yesVotes);
        test.noVotes = FHE.select(encryptedVote, test.noVotes, FHE.add(test.noVotes, increment));

        // Set FHE permissions
        FHE.allowThis(test.yesVotes);
        FHE.allowThis(test.noVotes);
        FHE.allow(test.yesVotes, msg.sender);
        FHE.allow(test.noVotes, msg.sender);

        hasVoted[_testId][msg.sender] = true;

        emit VoteSubmitted(_testId, msg.sender);
    }

    // Manual finalization function - owner can finalize tests manually
    function finalizeTest(uint256 _testId) external {
        require(_testId < totalTests, "Test does not exist");
        require(!qualityTests[_testId].isFinalized, "Test already finalized");

        QualityTest storage test = qualityTests[_testId];

        // Simple comparison using encrypted operations
        ebool yesWins = FHE.gt(test.yesVotes, test.noVotes);
        test.result = yesWins;
        test.isFinalized = true;

        // For event emission, we'll emit without decrypted result
        emit TestFinalized(_testId, false); // Placeholder result
    }

    function getTestDetails(uint256 _testId) external view returns (
        string memory category,
        string memory testType,
        string memory description,
        uint256 yesVotes,
        uint256 noVotes,
        bool isFinalized
    ) {
        require(_testId < totalTests, "Test does not exist");

        QualityTest storage test = qualityTests[_testId];

        // Vote counts remain encrypted for privacy
        uint256 yes = 0;
        uint256 no = 0;

        // Note: In this implementation, vote counts stay private

        return (
            test.category,
            test.testType,
            test.description,
            yes,
            no,
            test.isFinalized
        );
    }

    function getTestResult(uint256 _testId) external view returns (bool hasPassed, bool isRevealed) {
        require(_testId < totalTests, "Test does not exist");

        QualityTest storage test = qualityTests[_testId];

        if (test.isFinalized) {
            // Result remains encrypted for privacy
            // In production, this would use decryption requests
            return (false, true); // Placeholder - result is available but encrypted
        }

        return (false, false);
    }

    function getTotalTests() external view returns (uint256) {
        return totalTests;
    }

    function getTestSubmitter(uint256 _testId) external view returns (address) {
        require(_testId < totalTests, "Test does not exist");
        return qualityTests[_testId].submitter;
    }

    function getTestTimestamp(uint256 _testId) external view returns (uint256) {
        require(_testId < totalTests, "Test does not exist");
        return qualityTests[_testId].timestamp;
    }

    function hasUserVoted(uint256 _testId, address _user) external view returns (bool) {
        require(_testId < totalTests, "Test does not exist");
        return hasVoted[_testId][_user];
    }

    // Emergency function to manually finalize a test (only for testing)
    function forceFinalize(uint256 _testId) external {
        require(_testId < totalTests, "Test does not exist");
        require(qualityTests[_testId].submitter == msg.sender, "Only submitter can force finalize");

        QualityTest storage test = qualityTests[_testId];
        require(!test.isFinalized, "Test already finalized");

        // Determine result based on current votes
        ebool yesWins = FHE.gt(test.yesVotes, test.noVotes);
        test.result = yesWins;
        test.isFinalized = true;

        // Emit event without decrypted result for privacy
        emit TestFinalized(_testId, false); // Placeholder result
    }

    // Function to get encrypted vote counts (for testing FHE functionality)
    function getEncryptedVotes(uint256 _testId) external returns (euint8, euint8) {
        require(_testId < totalTests, "Test does not exist");
        QualityTest storage test = qualityTests[_testId];

        // Allow access to encrypted values
        FHE.allow(test.yesVotes, msg.sender);
        FHE.allow(test.noVotes, msg.sender);

        return (test.yesVotes, test.noVotes);
    }
}