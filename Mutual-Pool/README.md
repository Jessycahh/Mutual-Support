# Decentralized Mutual Insurance Protocol

A blockchain-based mutual insurance platform built on the Stacks blockchain where community members stake STX tokens to build a collective insurance fund, earn proportional rewards on their stakes, and receive coverage through transparent claim processing.

## Overview

This smart contract implements a decentralized insurance protocol that operates on the principles of mutual aid and community-driven governance. Members contribute to a shared insurance pool by staking STX tokens, earn rewards based on their contributions, and can submit claims for coverage when needed.

## Key Features

### Mutual Insurance Pool
- Community-funded insurance pool built through member stakes
- Transparent fund management with real-time balance tracking
- Collective risk sharing among all participants

### Staking & Rewards System
- **Minimum Stake**: 1 STX (1,000,000 µSTX)
- **Lockup Period**: ~24 hours (144 blocks)
- **Yield Rate**: Configurable annual yield (default 1%, max 10%)
- **Reward Distribution**: Proportional to stake amount and time

### Claim Processing
- **Maximum Claim**: 100 STX per claim
- **Status Tracking**: Pending → Approved/Denied
- **Minimum Description**: 5 characters required
- **Admin Review**: Claims processed by contract administrator

### Governance & Security
- **Admin Controls**: Yield rate and threshold management
- **Emergency Functions**: Administrative withdrawal capabilities
- **Consensus Threshold**: Configurable approval requirements (default 51%)

## Contract Architecture

### Core Components

#### Data Structures
- **Member Stakes**: Tracks individual member contributions and rewards
- **Claim Records**: Manages insurance claim submissions and processing
- **Protocol State**: Maintains pool balance, payouts, and configuration

#### Key Functions

**Staking Operations**
- `stake-tokens`: Join the insurance pool by staking STX
- `unstake-tokens`: Withdraw staked tokens after lockup period
- `claim-rewards`: Collect accumulated staking rewards

**Claim System**
- `submit-claim`: File an insurance claim for review
- `process-claim`: Admin function to approve/deny claims

**Governance**
- `set-yield-rate`: Update annual reward rate
- `set-approval-threshold`: Modify consensus requirements
- `emergency-withdraw`: Emergency fund access

## Usage Guide

### For Members

#### 1. Joining the Pool
```clarity
;; Stake 5 STX to join the insurance pool
(contract-call? .insurance-protocol stake-tokens u5000000)
```

#### 2. Submitting a Claim
```clarity
;; Submit a claim for 2 STX with description
(contract-call? .insurance-protocol submit-claim u2000000 u"Medical expense claim")
```

#### 3. Claiming Rewards
```clarity
;; Claim accumulated staking rewards
(contract-call? .insurance-protocol claim-rewards)
```

#### 4. Withdrawing Stake
```clarity
;; Unstake 1 STX after lockup period
(contract-call? .insurance-protocol unstake-tokens u1000000)
```

### For Administrators

#### Processing Claims
```clarity
;; Approve claim ID 5
(contract-call? .insurance-protocol process-claim u5 true)

;; Deny claim ID 6
(contract-call? .insurance-protocol process-claim u6 false)
```

#### Updating Protocol Parameters
```clarity
;; Set yield rate to 2% (200 basis points)
(contract-call? .insurance-protocol set-yield-rate u200)

;; Set approval threshold to 60%
(contract-call? .insurance-protocol set-approval-threshold u6000)
```

### Query Functions

#### Check Member Information
```clarity
;; Get member stake details
(contract-call? .insurance-protocol get-member-stake-info 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Calculate pending rewards
(contract-call? .insurance-protocol calculate-pending-rewards 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

#### Pool and Claim Information
```clarity
;; Get total pool balance
(contract-call? .insurance-protocol get-total-pool-balance)

;; Get claim details
(contract-call? .insurance-protocol get-claim-details u1)
```

## Protocol Parameters

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| Minimum Stake | 1 STX | Minimum tokens required to join |
| Lockup Period | 144 blocks (~24 hours) | Time before unstaking allowed |
| Maximum Claim | 100 STX | Maximum claimable amount |
| Annual Yield Rate | 1% (100 basis points) | Default reward rate |
| Approval Threshold | 51% (5100 basis points) | Consensus requirement |

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | ERR-UNAUTHORIZED-ACCESS | Admin-only function access |
| u101 | ERR-INSUFFICIENT-BALANCE | Insufficient funds for operation |
| u102 | ERR-MEMBER-NOT-FOUND | Member not found in system |
| u103 | ERR-CLAIM-ALREADY-PROCESSED | Claim already approved/denied |
| u104 | ERR-CLAIM-REJECTED | Claim was rejected |
| u105 | ERR-STAKE-BELOW-MINIMUM | Stake amount below minimum |
| u106 | ERR-STAKE-LOCKED | Stake still in lockup period |
| u107 | ERR-THRESHOLD-EXCEEDED | Parameter exceeds maximum |
| u108 | ERR-CLAIM-AMOUNT-INVALID | Invalid claim amount |
| u109 | ERR-YIELD-RATE-TOO-HIGH | Yield rate exceeds maximum |
| u110 | ERR-INVALID-PARAMETER | Invalid parameter value |
| u111 | ERR-DESCRIPTION-TOO-SHORT | Claim description too short |

## Security Considerations

### Access Control
- Admin functions restricted to contract deployer
- Member functions require active stake participation
- Claim processing requires admin approval

### Economic Security
- Minimum stake requirements prevent spam
- Lockup periods ensure commitment
- Maximum claim limits prevent pool drainage

### Operational Security
- Emergency withdrawal functions for crisis management
- Configurable parameters for protocol adaptation
- Transparent claim processing with status tracking

## Development & Deployment

### Prerequisites
- Stacks blockchain testnet/mainnet access
- Clarity smart contract development environment
- STX tokens for testing and deployment