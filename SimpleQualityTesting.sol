// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Simplified version without FHE for testing
contract SimpleQualityTesting {

    struct QualityTest {
        string category;
        string testType;
        string description;
        address submitter;
        uint256 timestamp;
        uint256 yesVotes;
        uint256 noVotes;
        bool isFinalized;
        bool result;
        bool resultRevealed;
    }

    mapping(uint256 => QualityTest) public qualityTests;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public totalTests;

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
            yesVotes: 0,
            noVotes: 0,
            isFinalized: false,
            result: false,
            resultRevealed: false
        });

        totalTests++;

        emit QualityTestSubmitted(testId, _category, _testType, msg.sender);
        return testId;
    }

    function voteOnTest(uint256 _testId, bool _passed) external {
        require(_testId < totalTests, "Test does not exist");
        require(!qualityTests[_testId].isFinalized, "Test already finalized");
        require(!hasVoted[_testId][msg.sender], "Already voted on this test");

        QualityTest storage test = qualityTests[_testId];

        // Simple voting without FHE
        if (_passed) {
            test.yesVotes += 1;
        } else {
            test.noVotes += 1;
        }

        hasVoted[_testId][msg.sender] = true;

        emit VoteSubmitted(_testId, msg.sender);
    }

    function finalizeTest(uint256 _testId) external {
        require(_testId < totalTests, "Test does not exist");
        require(!qualityTests[_testId].isFinalized, "Test already finalized");

        QualityTest storage test = qualityTests[_testId];

        // Simple comparison
        bool yesWins = test.yesVotes > test.noVotes;
        test.result = yesWins;
        test.isFinalized = true;
        test.resultRevealed = true;

        emit TestFinalized(_testId, yesWins);
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

        return (
            test.category,
            test.testType,
            test.description,
            test.yesVotes,
            test.noVotes,
            test.isFinalized
        );
    }

    function getTestResult(uint256 _testId) external view returns (bool hasPassed, bool isRevealed) {
        require(_testId < totalTests, "Test does not exist");

        QualityTest storage test = qualityTests[_testId];

        if (test.isFinalized) {
            return (test.result, true);
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

    function forceFinalize(uint256 _testId) external {
        require(_testId < totalTests, "Test does not exist");
        require(qualityTests[_testId].submitter == msg.sender, "Only submitter can force finalize");

        QualityTest storage test = qualityTests[_testId];
        require(!test.isFinalized, "Test already finalized");

        // Determine result based on current votes
        bool yesWins = test.yesVotes > test.noVotes;
        test.result = yesWins;
        test.isFinalized = true;
        test.resultRevealed = true;

        emit TestFinalized(_testId, yesWins);
    }

    // Function to get vote counts (simplified version)
    function getEncryptedVotes(uint256 _testId) external view returns (uint256, uint256) {
        require(_testId < totalTests, "Test does not exist");
        QualityTest storage test = qualityTests[_testId];

        return (test.yesVotes, test.noVotes);
    }
}