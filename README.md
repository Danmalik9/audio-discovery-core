# Audio Discovery Core

A comprehensive blockchain-native platform for decentralized audio content discovery and monetization built on Clarity smart contracts for the Stacks ecosystem.

## What is Audio Discovery Core?

Audio Discovery Core provides a robust infrastructure for creators to publish audio content, engage with audiences, and monetize their work through flexible payment models. The platform combines content cataloging, creator economics, and social discovery capabilities into an integrated suite of smart contracts.

## Core Capabilities

- **Content Indexing**: Store and organize audio content with rich metadata and geographic information
- **Flexible Monetization**: Support for free content, one-time purchases, and subscription models
- **Creator Economics**: Transparent fee structures with configurable platform margins
- **Social Graph**: Follow relationships, ratings, and community engagement features
- **Collection Curation**: Create and manage thematic audio collections and playlists
- **Access Control**: Granular permission management for private and restricted content

## Platform Architecture

The Audio Discovery Core consists of three specialized smart contracts:

### discovery-engine
The foundational content registry system managing:
- Audio entry creation and updates with geolocation metadata
- Access control lists for private content sharing
- Owner-based permission management
- Sequential entry indexing with owner attribution

### monetization-layer
Premium content distribution infrastructure supporting:
- Multiple pricing models (free, purchase, subscription)
- Recurring billing with auto-renewal capabilities
- Refund windows for eligible purchases
- Transparent fee calculation and settlement
- Admin-level fee management

### recommendation-engine
Community and discovery features including:
- User profiles with optional location information
- Follower relationships and social connections
- Content rating aggregation (1-5 scale)
- Playlist/collection management
- Playback tracking and engagement metrics

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks blockchain testnet access
- TypeScript/Node.js for test suite execution

### Installation & Deployment

```bash
# Clone and setup
git clone <repository>
cd audio-discovery-core
npm install

# Test the contracts
npm run test

# Deploy to testnet
clarinet deploy
```

### Basic Usage

#### Create an Audio Entry

```clarity
(contract-call? .discovery-engine store-new-entry
  "My Podcast Episode"
  "An interesting discussion about audio technology"
  "https://cdn.example.com/episode-001.mp3"
  40689247  ;; latitude (scaled by 10^6)
  -74012927 ;; longitude (scaled by 10^6)
  true      ;; publicly accessible
)
```

#### Register Paid Content

```clarity
(contract-call? .monetization-layer register-media
  1
  "Premium Audio Course"
  2              ;; purchase model
  5000000        ;; price in microSTX
  0              ;; N/A for purchase model
  24             ;; 24-hour refund window
)
```

#### Establish Creator Profile

```clarity
(contract-call? .recommendation-engine upsert-profile
  (some "username")
  (some "Creator bio and information")
  (some {latitude: 40689247, longitude: -74012927})
)
```

#### Subscribe to Content

```clarity
(contract-call? .monetization-layer begin-subscription
  3           ;; media-id
  true        ;; enable auto-renewal
)
```

## Key Functions Reference

### Discovery Engine

- `store-new-entry`: Create new indexed audio content
- `modify-entry`: Update entry metadata (owner only)
- `permit-access`: Grant access to specific principals
- `revoke-permission`: Remove access authorization
- `verify-access`: Check if principal can access entry
- `fetch-entry-details`: Retrieve complete entry information
- `list-creator-entries`: Query all entries by creator

### Monetization Layer

- `register-media`: Create monetized content entry
- `reconfigure-media`: Update pricing and terms
- `acquire-media`: Purchase one-time access
- `begin-subscription`: Start recurring subscription
- `extend-subscription`: Renew subscription period
- `halt-auto-renewal`: Cancel automatic renewal
- `refund-purchase`: Request refund (within window)
- `modify-fee-rate`: Adjust platform fee (admin)

### Recommendation Engine

- `upsert-profile`: Create/update user profile
- `initiate-follow`: Begin following a creator
- `terminate-follow`: Unfollow a creator
- `submit-rating`: Rate content (1-5 scale)
- `register-listen`: Log playback event
- `assemble-collection`: Create new playlist
- `append-to-collection`: Add content to playlist
- `excise-from-collection`: Remove content from playlist
- `adjust-collection-access`: Change playlist visibility

## Security Considerations

- Access control enforced at contract level for private entries
- Monetary operations validated against available balances
- Authorization checks on all mutation operations
- Fee calculations using integer arithmetic for precision
- One-time operations (purchases, ratings) prevent double-spending
- Admin functions protected by principal verification

## Technical Specifications

### Data Types & Encoding

- **Geographic Coordinates**: Stored as 32-bit integers with 6 decimal precision
  - Example: 40.689247° stored as 40689247
- **Time Values**: Block heights used for temporal operations
- **Currency**: All STX amounts in microSTX (1 STX = 1,000,000 microSTX)
- **Fee Basis Points**: Platform fees expressed in basis points (10,000 = 100%)
- **Ratings**: 1-5 point scale with aggregation

### Constraints & Limits

- Maximum 100 entries per creator
- Maximum 50 principals per entry access list
- Maximum 100 items per playlist
- Refund windows up to 255 hours post-purchase
- Subscription periods measured in days (1-255)
- Platform fee capped at 10% (1000 basis points)

## Testing

The test suite provides comprehensive coverage:

```bash
# Run all tests
npm run test

# Watch mode for development
npm run test:watch

# Generate coverage report
npm run test:report
```

Tests are organized by contract concern:
- `discovery-engine_test.ts`: Entry management and access control
- `monetization-layer_test.ts`: Purchase, subscription, and refund flows
- `recommendation-engine_test.ts`: Social features and curation

## Future Enhancements

- Advanced geographic search using optimized spatial indexing
- Content recommendation algorithms based on listening patterns
- Creator dashboard and analytics
- Integration with external IPFS/Arweave for audio hosting
- Governance token for protocol evolution
- Tiered creator benefits and loyalty programs

## License

Audio Discovery Core is distributed under the ISC license.

## Contributing

Community contributions are welcome. Please submit pull requests with:
- Clear description of proposed changes
- Comprehensive test coverage
- Updated documentation
- Adherence to existing code style conventions