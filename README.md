# 🏠 Tenant History NFT

A blockchain-based tenant verification and history tracking system built on the Stacks blockchain using Clarity smart contracts.

## 📋 Overview

Tenant History NFT creates immutable digital records of tenant rental history as Non-Fungible Tokens (NFTs). This system enables:

- 🔐 **Secure tenant verification** through blockchain technology  
- 📊 **Transparent rental history tracking** with payment scores and ratings
- 🏆 **Reputation scoring system** based on verified rental records
- 🏘️ **Property listing marketplace** for landlords and tenants
- ⚡ **Decentralized verification** without relying on traditional credit agencies

## ✨ Key Features

### 🎫 NFT-Based Records
- Each tenant record is minted as a unique NFT
- Immutable storage of rental history on the blockchain
- Transferable ownership of rental history records

### 📈 Reputation System  
- Payment history scoring (1-10 scale)
- Property condition scoring (1-10 scale) 
- Overall tenant rating system
- Automatic calculation of reputation scores

### 🏡 Property Management
- Create and manage property listings
- Set rental prices and deposit amounts
- Track listing availability status
- Application fee processing

### 🔑 Permission Management
- Tenants can grant/revoke landlord permissions
- Contract owner verification system
- Secure authorization checks

## 🚀 Usage Instructions

### For Tenants

#### Grant Permission to Landlord
```clarity
(contract-call? .tenant-history-nft grant-landlord-permission 'SP1A2B3C...)
```

#### View Your Stats
```clarity
(contract-call? .tenant-history-nft get-tenant-stats tx-sender)
```

#### Check Your Reputation Score
```clarity
(contract-call? .tenant-history-nft get-tenant-reputation-score tx-sender)
```

### For Landlords

#### Mint a New Tenant Record
```clarity
(contract-call? .tenant-history-nft mint-tenant-record
  'SP1TENANT...  ; tenant principal
  "123 Main St"  ; property address
  u1000         ; rent amount (micro-STX)
  u1000000      ; lease start block
  u2000000      ; lease end block  
  u8            ; payment score (1-10)
  u9            ; condition score (1-10)
  u8            ; overall rating (1-10)
)
```

#### Create Property Listing
```clarity
(contract-call? .tenant-history-nft create-property-listing 
  "456 Oak Ave"  ; property address
  u1200         ; monthly rent
  u2400         ; deposit amount
)
```

#### Update Listing Availability
```clarity
(contract-call? .tenant-history-nft update-listing-availability 
  u1     ; listing ID
  false  ; available status
)
```

### For Contract Owner

#### Verify Tenant Records
```clarity
(contract-call? .tenant-history-nft verify-record u1)
```

#### Bulk Verification
```clarity
(contract-call? .tenant-history-nft bulk-verify-records (list u1 u2 u3))
```

#### Set Contract Fee
```clarity
(contract-call? .tenant-history-nft set-contract-fee u50000)
```

## 📊 Data Structures

### Tenant Record
- `tenant`: Principal of the tenant
- `landlord`: Principal of the landlord
- `property-address`: String description of property
- `rent-amount`: Monthly rent in micro-STX
- `lease-start`/`lease-end`: Block height timestamps
- `payment-history-score`: Score from 1-10
- `property-condition-score`: Score from 1-10  
- `overall-rating`: Score from 1-10
- `verified`: Boolean verification status

### Tenant Statistics
- `total-records`: Number of rental records
- `average-rating`: Calculated average rating
- `total-rent-paid`: Cumulative rent payments
- `verified-records`: Count of verified records

## 🔒 Security Features

- ✅ Owner-only functions for verification and fee management
- ✅ Permission-based record creation
- ✅ Input validation for rating scores (1-10 scale)
- ✅ Secure STX transfer handling
- ✅ Authorization checks for all sensitive operations

## 🛠️ Development

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Setup
```bash
git clone https://github.com/your-repo/tenant-history-nft
cd tenant-history-nft
clarinet check
```

### Testing
```bash
npm install
npm test
```

## 📝 Contract Functions

### Read-Only Functions
- `get-last-token-id()`: Get the highest minted token ID
- `get-token-uri(uint)`: Get token metadata URI  
- `get-owner(uint)`: Get token owner
- `get-tenant-record(uint)`: Get tenant record data
- `get-tenant-stats(principal)`: Get tenant statistics
- `get-property-listing(uint)`: Get property listing details
- `get-tenant-reputation-score(principal)`: Calculate reputation score
- `get-contract-stats()`: Get overall contract statistics

### Public Functions
- `mint-tenant-record(...)`: Create new tenant NFT record
- `grant-landlord-permission(principal)`: Allow landlord to create records
- `revoke-landlord-permission(principal)`: Remove landlord permissions
- `verify-record(uint)`: Mark record as verified (owner only)
- `create-property-listing(...)`: Add new property listing
- `update-listing-availability(uint, bool)`: Update listing status
- `pay-application-fee(uint)`: Process application fee payment
- `transfer(uint, principal, principal)`: Transfer NFT ownership
- `set-contract-fee(uint)`: Update contract fee (owner only)
- `bulk-verify-records(list)`: Verify multiple records (owner only)

## 🌟 Benefits

- **For Tenants**: Build portable rental history and reputation
- **For Landlords**: Access verified tenant information and reduce risk
- **For Property Managers**: Streamline tenant screening process  
- **For the Market**: Create transparent, trustworthy rental ecosystem

## 📄 License

This project is licensed under the MIT License.

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests for any improvements.

---

*Built with ❤️ on the Stacks blockchain*
