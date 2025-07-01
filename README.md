# SkillMarket

A merit-based professional network built on the Stacks blockchain that creates on-chain credibility for service providers with community arbitration.

## Overview

SkillMarket addresses the trust problem in professional service marketplaces by creating immutable, portable credibility records that follow service providers across platforms. Past work quality is permanently recorded on-chain, and disputes are resolved by community arbitrators who stake tokens to participate.

## Key Features

- **On-Chain Credibility**: Immutable credibility ratings built from completed assignment history
- **Escrow System**: Automatic payment escrow with smart contract release
- **Community Arbitration**: Decentralized dispute resolution with staked participation
- **Portable Profiles**: Credibility follows providers across any platform using SkillMarket
- **Transparent Feedback**: Public feedback system for both buyers and providers

## Smart Contract Functions

### Registration
- `enroll-as-provider()` - Create a service provider profile
- `enroll-as-buyer()` - Create a service buyer profile

### Assignment Management
- `establish-assignment(provider, payment-amount, work-description)` - Post new assignment with escrow
- `confirm-assignment(assignment-reference)` - Provider confirms posted assignment
- `finalize-assignment(assignment-reference)` - Buyer finalizes assignment and releases payment
- `record-feedback(assignment-reference, performance-score, written-feedback)` - Submit ratings and feedback

### Arbitration Resolution
- `open-arbitration-case(assignment-reference, dispute-explanation)` - Start arbitration process
- `become-arbitrator(case-reference)` - Join arbitrator panel (requires deposit)
- `submit-arbitration-decision(case-reference, support-buyer)` - Cast arbitrator decision

### Query Functions
- `get-provider-profile(principal)` - Get service provider credibility data
- `get-buyer-profile(principal)` - Get service buyer profile data
- `get-assignment-details(assignment-reference)` - Get assignment details
- `get-arbitration-case(case-reference)` - Get arbitration case information

## Credibility System

Service provider credibility is calculated based on:
- Finished assignments (+5 points per completion)
- Won arbitrations (+10 points)
- Lost arbitrations (-15 points)
- Buyer performance scores (integrated into overall rating)

Starting credibility: 100 points

## Arbitration Resolution Process

1. **Case Opening**: Either party can open arbitration case during active assignment
2. **Arbitrator Panel Formation**: Up to 5 community members stake STX to join panel
3. **Deliberation Period**: 7-day window for arbitrators to review and decide
4. **Case Resolution**: Majority decision determines outcome and fund distribution
5. **Compensation**: Winning voters receive proportional rewards from losing side deposits

## Technical Details

- **Blockchain**: Stacks (Bitcoin-secured)
- **Language**: Clarity smart contracts
- **Minimum Arbitrator Deposit**: 1 STX
- **Arbitration Window**: ~7 days (1008 blocks)
- **Arbitrator Panel Size**: 5 members maximum

## Getting Started

### Prerequisites
- Stacks wallet (Hiro, Xverse, etc.)
- STX tokens for transactions and arbitrator participation

### Deployment
```bash
# Install Clarinet
npm install -g @hirosystems/clarinet-cli

# Initialize project
clarinet new skillmarket
cd skillmarket

# Add contract
cp skillmarket.clar contracts/

# Test contracts
clarinet test

# Deploy to testnet
clarinet deploy --testnet
```

### Usage Example

```clarity
;; Register as service provider
(contract-call? .skillmarket enroll-as-provider)

;; Buyer creates assignment
(contract-call? .skillmarket establish-assignment 'SP1PROVIDER-ADDRESS u1000000 "Develop mobile app interface")

;; Provider confirms
(contract-call? .skillmarket confirm-assignment u1)

;; Buyer finalizes and releases payment
(contract-call? .skillmarket finalize-assignment u1)

;; Both parties record feedback
(contract-call? .skillmarket record-feedback u1 u5 "Outstanding work quality!")
```

## Roadmap

- **Phase 1**: Core contract deployment and testing
- **Phase 2**: Web interface development
- **Phase 3**: API integration for existing platforms
- **Phase 4**: Advanced credibility algorithms
- **Phase 5**: Cross-chain credibility bridging

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/enhancement`)
3. Commit changes (`git commit -m 'Add enhancement'`)
4. Push to branch (`git push origin feature/enhancement`)
5. Open Pull Request

## Security Considerations

- All funds are held in contract escrow until assignment completion
- Arbitrator panel members must stake tokens, creating economic incentive for honest decisions
- Arbitration resolution has time limits to prevent indefinite locks
- Credibility changes are permanent and cannot be manipulated

---

*Built with ❤️ on Stacks*