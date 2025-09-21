# TrialNet 🗂️ - Drug Trial Registry

A blockchain-based transparent system for recording and managing clinical trial data on the Stacks blockchain using Clarity smart contracts.

## Overview

TrialNet provides a decentralized, immutable platform for pharmaceutical companies, researchers, and regulatory bodies to register, track, and validate clinical drug trials. The system ensures transparency, data integrity, and regulatory compliance throughout the drug development process.

## Features

### Core Functionality
- **Trial Registration**: Register new clinical trials with comprehensive metadata
- **Participant Management**: Track participant enrollment and status
- **Data Recording**: Record trial results and adverse events
- **Status Tracking**: Monitor trial phases and completion status
- **Regulatory Compliance**: Maintain audit trails for regulatory submissions

### Smart Contract Architecture
- **trial-registry.clar**: Main contract for trial registration and management
- **participant-tracker.clar**: Contract for managing participant data and enrollment

## Smart Contract Features

### Trial Registry Contract
- Register new clinical trials with unique identifiers
- Store trial metadata (title, description, phase, sponsor)
- Track trial status and phase progression
- Record primary and secondary endpoints
- Manage trial approval and termination

### Participant Tracker Contract
- Enroll participants in specific trials
- Track participant demographics and eligibility
- Record consent status and withdrawal
- Monitor adverse events and safety data
- Generate participant statistics

## Data Structure

### Trial Information
- Trial ID (unique identifier)
- Trial title and description
- Sponsor organization
- Principal investigator
- Study phase (I, II, III, IV)
- Primary and secondary endpoints
- Start and end dates
- Participant enrollment targets

### Participant Data
- Participant ID (anonymized)
- Trial assignment
- Enrollment date
- Demographic data (age range, gender)
- Eligibility criteria met
- Consent status
- Adverse events reported

## Benefits

### For Pharmaceutical Companies
- Transparent trial registration
- Immutable data records
- Regulatory compliance tracking
- Public trust building

### For Researchers
- Standardized data collection
- Cross-trial data analysis
- Collaboration opportunities
- Research integrity verification

### For Regulatory Bodies
- Real-time trial monitoring
- Audit trail availability
- Compliance verification
- Public access to trial data

### For Patients
- Trial transparency
- Informed consent tracking
- Safety monitoring
- Treatment outcome visibility

## Technical Implementation

- **Blockchain**: Stacks blockchain
- **Language**: Clarity smart contracts
- **Framework**: Clarinet development environment
- **Testing**: Vitest testing framework
- **Deployment**: Mainnet, Testnet, and Devnet configurations

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm
- Stacks wallet for interactions

### Installation
```bash
git clone <repository-url>
cd TrialNet
npm install
```

### Testing
```bash
clarinet check
npm test
```

### Deployment
```bash
clarinet deploy --testnet
```

## Usage

### Register a New Trial
```clarity
(contract-call? .trial-registry register-trial
  "Phase II Alzheimer's Treatment Study"
  "Evaluating efficacy of novel compound XYZ-123"
  u2  ;; Phase II
  "PharmaCorp Inc"
  "Dr. Jane Smith"
)
```

### Enroll Participant
```clarity
(contract-call? .participant-tracker enroll-participant
  u1  ;; Trial ID
  "ANON-12345"  ;; Anonymized participant ID
  u45  ;; Age
  "F"  ;; Gender
)
```

## Security Considerations

- All participant data is anonymized
- Access controls for sensitive operations
- Immutable audit trails
- Compliance with data protection regulations

## License

MIT License - Open source for research and educational purposes

## Contributing

Contributions welcome! Please read our contributing guidelines and submit pull requests for review.

## Contact

For questions or support, please open an issue in this repository.

---

*TrialNet - Advancing medical research through blockchain transparency* 🧬
