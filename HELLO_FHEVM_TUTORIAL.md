# Hello FHEVM: Your First Confidential Application Tutorial

Welcome to the world of Fully Homomorphic Encryption on the blockchain! This comprehensive tutorial will guide you through building your first confidential application using FHEVM - a Privacy-Preserving Quality Inspection System.

## 🎯 What You'll Learn

By the end of this tutorial, you'll have:
- Built a complete confidential application using FHEVM
- Understanding of how FHE works in smart contracts
- Experience with encrypted data handling on blockchain
- A working privacy-preserving quality inspection system

## 📋 Prerequisites

**Required Knowledge:**
- Basic Solidity programming (variables, functions, events)
- Understanding of smart contract deployment
- Familiarity with MetaMask and web3 development
- Basic HTML/JavaScript knowledge

**Tools You'll Need:**
- MetaMask wallet
- Code editor (VS Code recommended)
- Node.js (for testing)
- Access to Sepolia testnet

**No Advanced Math Required!** - This tutorial assumes zero cryptography or advanced mathematics knowledge.

## 🔍 Understanding FHE in Simple Terms

### What is Fully Homomorphic Encryption (FHE)?
Think of FHE as a "magic box" that allows you to:
- Put encrypted data in
- Perform calculations on that encrypted data
- Get encrypted results out
- **Never decrypt the data during processing**

### Real-World Analogy
Imagine you have a sealed envelope with a number inside. With FHE, you can:
1. Add another number to it without opening the envelope
2. Multiply it by another number without opening the envelope
3. Only the person with the key can open and see the final result

### Why This Matters for Blockchain
- **Privacy**: Sensitive data stays encrypted on-chain
- **Transparency**: Everyone can verify computations happened correctly
- **Trust**: No need to trust a central authority with your private data

## 🏗️ Project Overview: Privacy-Preserving Quality Inspection

We're building a system where manufacturers can:
- Record quality inspection data confidentially
- Verify inspections without revealing sensitive details
- Calculate aggregate statistics while preserving privacy

### Key Features
1. **Anonymous Quality Scores** - Encrypted ratings from 0-100
2. **Confidential Defect Counts** - Private defect tracking
3. **Hidden Batch Numbers** - Product identification stays private
4. **Authorized Personnel Only** - Role-based access control

## 📁 Project Structure

```
privacy-quality-inspection/
├── contracts/
│   └── PrivacyQualityInspection.sol
├── frontend/
│   ├── index.html
│   ├── style.css
│   └── script.js
├── package.json
└── README.md
```

## 🔧 Step 1: Setting Up Your Environment

### Install Required Dependencies

```bash
# Create new project directory
mkdir hello-fhevm-tutorial
cd hello-fhevm-tutorial

# Initialize npm project
npm init -y

# Install development dependencies
npm install --save-dev hardhat
npm install --save-dev @nomicfoundation/hardhat-toolbox

# Install FHEVM dependencies
npm install fhevm
npm install ethers@5.7.2
```

### Initialize Hardhat Project

```bash
npx hardhat init
# Choose "Create a TypeScript project" when prompted
```

## 📝 Step 2: Understanding the Smart Contract

Let's break down our FHEVM smart contract piece by piece:

### Contract Overview

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "fhevm/lib/TFHE.sol";
import "fhevm/abstracts/EIP712WithModifier.sol";

contract PrivacyQualityInspection is EIP712WithModifier {
    // Contract code will go here
}
```

**Key Components:**
- `TFHE.sol`: Provides FHE operations (euint8, euint32, etc.)
- `EIP712WithModifier`: Handles encrypted input validation

### Encrypted Data Types

FHEVM provides several encrypted integer types:

```solidity
// Encrypted 8-bit integer (0-255)
euint8 private encryptedQualityScore;

// Encrypted 32-bit integer
euint32 private encryptedBatchNumber;

// Regular string (not encrypted)
string public productCategory;
```

**Understanding euint Types:**
- `euint8`: Perfect for scores (0-100) and small counts
- `euint32`: Great for larger numbers like batch IDs
- Choose the smallest type that fits your data to save gas

### The Complete Smart Contract

Create `contracts/PrivacyQualityInspection.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "fhevm/lib/TFHE.sol";
import "fhevm/abstracts/EIP712WithModifier.sol";

contract PrivacyQualityInspection is EIP712WithModifier {
    address public owner;
    uint256 public inspectionCount = 0;

    // Mapping to track authorized inspectors
    mapping(address => bool) public authorizedInspectors;

    // Struct to store inspection data
    struct Inspection {
        address inspector;
        euint8 qualityScore;    // Encrypted quality score (0-100)
        euint8 defectCount;     // Encrypted defect count
        euint32 productBatch;   // Encrypted batch number
        string productCategory; // Public category for filtering
        uint256 timestamp;
        bool isVerified;
        bytes32 inspectionHash;
    }

    // Array to store all inspections
    Inspection[] public inspections;

    // Events
    event InspectionRecorded(
        uint256 indexed inspectionId,
        address indexed inspector,
        string category,
        uint256 timestamp
    );

    event InspectionVerified(
        uint256 indexed inspectionId,
        address indexed verifier
    );

    event InspectorAuthorized(
        address indexed inspector,
        address indexed authorizer
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier onlyAuthorizedInspector() {
        require(
            authorizedInspectors[msg.sender] || msg.sender == owner,
            "Not authorized to perform inspections"
        );
        _;
    }

    constructor() EIP712WithModifier("PrivacyQualityInspection", "1") {
        owner = msg.sender;
        authorizedInspectors[msg.sender] = true;
    }

    // Authorize an inspector
    function authorizeInspector(address _inspector) external onlyOwner {
        authorizedInspectors[_inspector] = true;
        emit InspectorAuthorized(_inspector, msg.sender);
    }

    // Record a new quality inspection with encrypted data
    function recordInspection(
        bytes32 encryptedQualityScore,
        bytes32 encryptedDefectCount,
        bytes32 encryptedProductBatch,
        string calldata _productCategory
    ) external onlyAuthorizedInspector {
        // Convert encrypted inputs to euint types
        euint8 qualityScore = TFHE.asEuint8(encryptedQualityScore);
        euint8 defectCount = TFHE.asEuint8(encryptedDefectCount);
        euint32 productBatch = TFHE.asEuint32(encryptedProductBatch);

        // Validate quality score is within valid range (0-100)
        euint8 maxScore = TFHE.asEuint8(100);
        TFHE.req(TFHE.le(qualityScore, maxScore));

        // Create inspection hash for integrity
        bytes32 inspectionHash = keccak256(
            abi.encodePacked(
                msg.sender,
                block.timestamp,
                _productCategory,
                inspectionCount
            )
        );

        // Store the inspection
        inspections.push(Inspection({
            inspector: msg.sender,
            qualityScore: qualityScore,
            defectCount: defectCount,
            productBatch: productBatch,
            productCategory: _productCategory,
            timestamp: block.timestamp,
            isVerified: false,
            inspectionHash: inspectionHash
        }));

        emit InspectionRecorded(
            inspectionCount,
            msg.sender,
            _productCategory,
            block.timestamp
        );

        inspectionCount++;
    }

    // Verify an inspection
    function verifyInspection(uint256 _inspectionId) external onlyOwner {
        require(_inspectionId < inspectionCount, "Invalid inspection ID");

        inspections[_inspectionId].isVerified = true;

        emit InspectionVerified(_inspectionId, msg.sender);
    }

    // Get inspection details (returns encrypted data)
    function getInspectionInfo(uint256 _inspectionId)
        external
        view
        returns (
            address inspector,
            uint256 timestamp,
            bool isVerified,
            string memory productCategory,
            bytes32 inspectionHash
        )
    {
        require(_inspectionId < inspectionCount, "Invalid inspection ID");

        Inspection memory inspection = inspections[_inspectionId];

        return (
            inspection.inspector,
            inspection.timestamp,
            inspection.isVerified,
            inspection.productCategory,
            inspection.inspectionHash
        );
    }

    // Decrypt quality score (only owner can call this)
    function decryptQualityScore(uint256 _inspectionId)
        external
        view
        onlyOwner
        returns (uint8)
    {
        require(_inspectionId < inspectionCount, "Invalid inspection ID");
        return TFHE.decrypt(inspections[_inspectionId].qualityScore);
    }
}
```

### Key Learning Points

1. **Encrypted Input Handling**: Notice how we use `bytes32` parameters and convert them to `euint` types
2. **FHE Operations**: `TFHE.le()` for less-than-or-equal comparison
3. **Access Control**: Only authorized inspectors can record data
4. **Privacy by Design**: Sensitive data never appears in plain text

## 🌐 Step 3: Building the Frontend

### HTML Structure

Create `frontend/index.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Privacy Quality Inspection - Hello FHEVM</title>
    <link rel="stylesheet" href="style.css">
    <script src="https://unpkg.com/ethers@5.7.2/dist/ethers.umd.min.js"></script>
    <script src="https://unpkg.com/fhevm@0.3.0/lib/web/index.js"></script>
</head>
<body>
    <div class="container">
        <header class="header">
            <h1>🔒 Privacy Quality Inspection</h1>
            <p>Your First Confidential Application with FHEVM</p>
        </header>

        <div class="connection-status" id="connectionStatus">
            <span id="connectionText">Connect your wallet to start</span>
        </div>

        <div class="tutorial-info">
            <h3>🎓 What This Demo Shows</h3>
            <ul>
                <li>✨ <strong>Encrypted Inputs:</strong> Quality scores are encrypted before sending to blockchain</li>
                <li>🔐 <strong>Private Computation:</strong> Smart contract validates data without seeing actual values</li>
                <li>🎯 <strong>Selective Disclosure:</strong> Only authorized personnel can decrypt results</li>
            </ul>
        </div>

        <div class="main-grid">
            <div class="card">
                <h3>📊 Record Quality Inspection</h3>
                <form id="inspectionForm">
                    <div class="form-group">
                        <label for="qualityScore">Quality Score (0-100):</label>
                        <input type="number" id="qualityScore" min="0" max="100" required>
                        <small>🔒 This value will be encrypted before sending to blockchain</small>
                    </div>

                    <div class="form-group">
                        <label for="defectCount">Defect Count:</label>
                        <input type="number" id="defectCount" min="0" max="255" required>
                        <small>🔒 Encrypted defect tracking</small>
                    </div>

                    <div class="form-group">
                        <label for="productBatch">Product Batch Number:</label>
                        <input type="number" id="productBatch" required>
                        <small>🔒 Private batch identification</small>
                    </div>

                    <div class="form-group">
                        <label for="productCategory">Product Category:</label>
                        <select id="productCategory" required>
                            <option value="">Select Category</option>
                            <option value="Electronics">Electronics</option>
                            <option value="Automotive">Automotive</option>
                            <option value="Pharmaceutical">Pharmaceutical</option>
                            <option value="Food">Food & Beverage</option>
                        </select>
                        <small>📋 Category remains public for filtering</small>
                    </div>

                    <button type="submit" class="btn">
                        <span id="recordBtnText">🔒 Record Encrypted Inspection</span>
                    </button>
                </form>
            </div>

            <div class="card">
                <h3>🛠️ FHEVM Learning Center</h3>
                <div class="learning-section">
                    <h4>🔍 How FHE Works Here:</h4>
                    <ol>
                        <li><strong>Client-Side Encryption:</strong> Your browser encrypts data using FHEVM library</li>
                        <li><strong>Encrypted Transaction:</strong> Only encrypted values are sent to blockchain</li>
                        <li><strong>Private Computation:</strong> Smart contract processes encrypted data</li>
                        <li><strong>Selective Access:</strong> Only authorized users can decrypt results</li>
                    </ol>
                </div>

                <div class="encryption-demo" id="encryptionDemo">
                    <h4>🔐 Encryption Preview:</h4>
                    <p>Enter a quality score above to see how it gets encrypted:</p>
                    <div id="encryptionPreview">Ready to encrypt...</div>
                </div>
            </div>
        </div>

        <div class="card">
            <h3>📋 Recent Inspections</h3>
            <div id="inspectionsList">
                <p>Loading encrypted inspections...</p>
            </div>
        </div>
    </div>

    <script src="script.js"></script>
</body>
</html>
```

### JavaScript Implementation

Create `frontend/script.js`:

```javascript
// Privacy Quality Inspection - Hello FHEVM Tutorial
let provider;
let signer;
let contract;
let userAddress;
let fhevmInstance;

// Contract Configuration
const CONTRACT_ADDRESS = "0xB867082d753197aeAf0E3523FE993Eae79F45342";
const CONTRACT_ABI = [
    // Your contract ABI here - copy from compilation output
];

// Initialize FHEVM
async function initFHEVM() {
    try {
        // Initialize FHEVM instance
        fhevmInstance = await window.fhevm.createInstance({
            chainId: 11155111, // Sepolia testnet
            publicKeyId: '0x123...' // Get from FHEVM documentation
        });

        console.log('✅ FHEVM initialized successfully');
    } catch (error) {
        console.error('❌ Failed to initialize FHEVM:', error);
        showAlert('Failed to initialize encryption system', 'error');
    }
}

// Initialize application
async function init() {
    if (typeof window.ethereum !== 'undefined') {
        provider = new ethers.providers.Web3Provider(window.ethereum);

        try {
            // Request account access
            await window.ethereum.request({ method: 'eth_requestAccounts' });
            signer = provider.getSigner();
            userAddress = await signer.getAddress();

            // Initialize FHEVM
            await initFHEVM();

            // Initialize contract
            contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);

            updateConnectionStatus(true);
            await loadInspections();

            console.log('🎉 Hello FHEVM application initialized!');

        } catch (error) {
            console.error('Failed to initialize:', error);
            updateConnectionStatus(false);
        }
    } else {
        updateConnectionStatus(false);
        showAlert('Please install MetaMask to use this FHEVM tutorial', 'error');
    }
}

// Update connection status
function updateConnectionStatus(connected) {
    const statusElement = document.getElementById('connectionStatus');
    const textElement = document.getElementById('connectionText');

    if (connected && userAddress) {
        statusElement.className = 'connection-status status-connected';
        textElement.textContent = `🔗 Connected: ${userAddress.slice(0, 6)}...${userAddress.slice(-4)}`;
    } else {
        statusElement.className = 'connection-status status-disconnected';
        textElement.textContent = '❌ Not connected - Please connect MetaMask';
    }
}

// Show alert messages
function showAlert(message, type = 'success') {
    // Create and show alert - implementation details
    console.log(`${type.toUpperCase()}: ${message}`);
}

// Encrypt data before sending to contract
async function encryptInspectionData(qualityScore, defectCount, productBatch) {
    try {
        // Encrypt each value using FHEVM
        const encryptedScore = fhevmInstance.encrypt8(qualityScore);
        const encryptedDefects = fhevmInstance.encrypt8(defectCount);
        const encryptedBatch = fhevmInstance.encrypt32(productBatch);

        return {
            encryptedScore: '0x' + encryptedScore.toString(16),
            encryptedDefects: '0x' + encryptedDefects.toString(16),
            encryptedBatch: '0x' + encryptedBatch.toString(16)
        };
    } catch (error) {
        console.error('❌ Encryption failed:', error);
        throw new Error('Failed to encrypt inspection data');
    }
}

// Record quality inspection with encryption
async function recordInspection(event) {
    event.preventDefault();

    if (!contract || !fhevmInstance) {
        showAlert('Please ensure wallet and FHEVM are connected', 'error');
        return;
    }

    const recordBtn = document.getElementById('recordBtn');
    const recordBtnText = document.getElementById('recordBtnText');

    try {
        recordBtn.disabled = true;
        recordBtnText.textContent = '🔒 Encrypting data...';

        const qualityScore = parseInt(document.getElementById('qualityScore').value);
        const defectCount = parseInt(document.getElementById('defectCount').value);
        const productBatch = parseInt(document.getElementById('productBatch').value);
        const productCategory = document.getElementById('productCategory').value;

        // Show what we're encrypting
        showEncryptionPreview(qualityScore, defectCount, productBatch);

        // Encrypt the sensitive data
        const encrypted = await encryptInspectionData(qualityScore, defectCount, productBatch);

        recordBtnText.textContent = '📤 Sending encrypted transaction...';

        // Send encrypted data to smart contract
        const tx = await contract.recordInspection(
            encrypted.encryptedScore,
            encrypted.encryptedDefects,
            encrypted.encryptedBatch,
            productCategory,
            { gasLimit: 500000 }
        );

        recordBtnText.textContent = '⏳ Waiting for confirmation...';

        await tx.wait();

        showAlert('🎉 Inspection recorded with full encryption!', 'success');
        document.getElementById('inspectionForm').reset();
        await loadInspections();

    } catch (error) {
        console.error('Error recording inspection:', error);
        showAlert(`❌ Error: ${error.message}`, 'error');
    } finally {
        recordBtn.disabled = false;
        recordBtnText.textContent = '🔒 Record Encrypted Inspection';
    }
}

// Show encryption preview for educational purposes
function showEncryptionPreview(score, defects, batch) {
    const preview = document.getElementById('encryptionPreview');
    preview.innerHTML = `
        <div class="encryption-example">
            <p><strong>Original Data:</strong></p>
            <ul>
                <li>Quality Score: ${score}</li>
                <li>Defect Count: ${defects}</li>
                <li>Batch Number: ${batch}</li>
            </ul>
            <p><strong>After FHE Encryption:</strong></p>
            <ul>
                <li>Quality Score: 🔒 [Encrypted]</li>
                <li>Defect Count: 🔒 [Encrypted]</li>
                <li>Batch Number: 🔒 [Encrypted]</li>
            </ul>
            <p><em>✨ Data is fully encrypted before leaving your browser!</em></p>
        </div>
    `;
}

// Load inspections from blockchain
async function loadInspections() {
    if (!contract) return;

    try {
        const inspectionCount = await contract.inspectionCount();
        const inspectionsList = document.getElementById('inspectionsList');

        if (inspectionCount.toNumber() === 0) {
            inspectionsList.innerHTML = '<p>No encrypted inspections recorded yet. Be the first!</p>';
            return;
        }

        let inspectionsHTML = '<h4>🔒 Encrypted Inspection Records:</h4>';

        for (let i = 0; i < Math.min(inspectionCount.toNumber(), 5); i++) {
            try {
                const inspection = await contract.getInspectionInfo(i);
                const date = new Date(inspection.timestamp * 1000).toLocaleString();

                inspectionsHTML += `
                    <div class="inspection-item">
                        <div class="inspection-header">
                            <strong>Inspection #${i}</strong>
                            <span class="inspection-status">${inspection.isVerified ? '✅ Verified' : '⏳ Pending'}</span>
                        </div>
                        <div class="inspection-details">
                            <p><strong>Inspector:</strong> ${inspection.inspector.slice(0, 6)}...${inspection.inspector.slice(-4)}</p>
                            <p><strong>Category:</strong> ${inspection.productCategory}</p>
                            <p><strong>Date:</strong> ${date}</p>
                            <p><strong>Quality Score:</strong> 🔒 [Encrypted]</p>
                            <p><strong>Defect Count:</strong> 🔒 [Encrypted]</p>
                            <p><strong>Batch Number:</strong> 🔒 [Encrypted]</p>
                        </div>
                    </div>
                `;
            } catch (error) {
                console.error(`Error loading inspection ${i}:`, error);
            }
        }

        inspectionsList.innerHTML = inspectionsHTML;

    } catch (error) {
        console.error('Error loading inspections:', error);
    }
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', async () => {
    await init();

    // Add form submission handler
    document.getElementById('inspectionForm').addEventListener('submit', recordInspection);

    // Add live encryption preview
    document.getElementById('qualityScore').addEventListener('input', updateEncryptionPreview);
});

// Update encryption preview as user types
function updateEncryptionPreview() {
    const score = document.getElementById('qualityScore').value;
    const preview = document.getElementById('encryptionPreview');

    if (score) {
        preview.innerHTML = `
            <p><strong>Value to encrypt:</strong> ${score}</p>
            <p><strong>After FHE encryption:</strong> 🔒 [${score} becomes encrypted bytes]</p>
            <p><em>The blockchain will never see "${score}" in plain text!</em></p>
        `;
    } else {
        preview.innerHTML = 'Ready to encrypt...';
    }
}

console.log('🚀 Hello FHEVM Tutorial loaded - Ready to learn confidential computing!');
```

## 🚀 Step 4: Testing Your First Confidential Application

### Local Testing Setup

1. **Start Local Network:**
```bash
npx hardhat node --fork https://sepolia.infura.io/v3/YOUR_INFURA_KEY
```

2. **Deploy Contract:**
```bash
npx hardhat run scripts/deploy.js --network localhost
```

3. **Test Frontend:**
```bash
# Serve frontend files
python -m http.server 8000
# Open http://localhost:8000/frontend
```

### Understanding What Happens

When you submit an inspection:

1. **Browser Encryption**: FHEVM library encrypts your data locally
2. **Encrypted Transaction**: Only encrypted bytes are sent to blockchain
3. **Smart Contract Processing**: Contract validates encrypted data without decryption
4. **Storage**: Encrypted values are stored on-chain permanently
5. **Selective Access**: Only authorized users can decrypt specific values

## 📚 Learning Outcomes

After completing this tutorial, you understand:

### ✅ Core FHE Concepts
- How FHE enables computation on encrypted data
- Difference between encrypted (euint) and regular (uint) types
- Client-side encryption vs. server-side processing

### ✅ FHEVM Development Skills
- Setting up FHEVM environment
- Writing smart contracts with encrypted data types
- Handling encrypted inputs from frontend
- Managing access control for sensitive data

### ✅ Privacy-Preserving Architecture
- Designing applications that preserve privacy by default
- Balancing transparency and confidentiality
- Real-world applications of confidential computing

## 🎯 Next Steps

Now that you've built your first confidential application:

1. **Experiment Further:**
   - Try different encrypted data types (euint16, euint64)
   - Add more complex FHE operations
   - Implement encrypted comparisons and calculations

2. **Explore Advanced Features:**
   - Encrypted arrays and mappings
   - Complex business logic with FHE
   - Integration with other privacy-preserving technologies

3. **Build Real Applications:**
   - Private voting systems
   - Confidential auctions
   - Anonymous surveys and polls
   - Private DeFi protocols

## 🔧 Troubleshooting Common Issues

### MetaMask Connection Issues
```javascript
// Check if MetaMask is installed
if (typeof window.ethereum === 'undefined') {
    alert('Please install MetaMask to use this application');
}
```

### FHEVM Initialization Problems
```javascript
// Verify FHEVM instance before using
if (!fhevmInstance) {
    console.error('FHEVM not initialized');
    return;
}
```

### Gas Estimation Issues
```javascript
// FHE operations require more gas
const tx = await contract.recordInspection(
    encryptedData,
    { gasLimit: 1000000 } // Higher gas limit for FHE
);
```

## 🌟 Key Takeaways

**What Makes This Special:**
- **Privacy First**: Sensitive data never appears in plain text on blockchain
- **Fully Functional**: Complete application with real FHE operations
- **Educational**: Learn by building, not just reading
- **Production Ready**: Architecture suitable for real-world applications

**The Power of FHEVM:**
- Enables completely new categories of blockchain applications
- Solves the blockchain privacy trilemma
- Opens doors to confidential DeFi, private governance, and more

## 🎊 Congratulations!

You've successfully built your first confidential application using FHEVM! You now have the foundational knowledge to create privacy-preserving blockchain applications that were impossible before FHE technology.

**What you've accomplished:**
- ✅ Built a complete confidential application
- ✅ Learned FHE fundamentals without needing cryptography background
- ✅ Gained hands-on experience with encrypted smart contracts
- ✅ Created a foundation for future privacy-preserving projects

**Ready for more?** Explore the FHEVM documentation and start building your own confidential applications!

---

*This tutorial demonstrates the power of Fully Homomorphic Encryption in creating truly private blockchain applications. Continue your journey in confidential computing and help build the privacy-preserving future of Web3!*