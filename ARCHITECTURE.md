# Architecture Documentation

## Tech Stack Choices

### 1. State Management: Provider
**Why Provider?**
- **Simplicity**: Easy to understand and implement with minimal boilerplate
- **Performance**: Efficient widget rebuilds with `Consumer` and `Selector`
- **Maturity**: Stable and widely adopted in the Flutter community since 2018
- **Testing**: Easy to mock and test with `ChangeNotifier`
- **Lightweight**: Minimal overhead compared to BLoC/Riverpod for this use case

### 2. Local Storage: Shared Preferences
**Why Shared Preferences?**
- **Simplicity**: Perfect for storing simple key-value pairs and JSON-serialized objects
- **Transaction Data**: Our transaction objects are small (under 1KB each) and serialize well to JSON
- **Performance**: Fast read/write operations (native platform storage)
- **Persistence**: Data survives app restarts and process death
- **No Overhead**: Avoids complex database setup for this MVP

### 3. Connectivity: connectivity_plus
**Why connectivity_plus?**
- **Official Plugin**: Maintained by the Flutter team with regular updates
- **Platform Support**: Works consistently on iOS, Android, web, and desktop
- **Reliable**: Uses platform-specific APIs for accurate network state detection
- **Battery Efficient**: Listens to system events rather than polling

## Architecture Pattern: Clean Architecture

### Layers:
┌─────────────────────────────────────────┐
│ PRESENTATION LAYER │
│ • Widgets (UI Components) │
│ • Providers (State Management) │
│ • Themes (Styling) │
└─────────────────────────────────────────┘
│
┌─────────────────────────────────────────┐
│ DOMAIN LAYER │
│ • Business Logic │
│ • Models (Entities) │
│ • Exceptions │
└─────────────────────────────────────────┘
│
┌─────────────────────────────────────────┐
│ DATA LAYER │
│ • Repositories (Data Sources) │
│ • Services (External APIs) │
│ • Local Storage │
└─────────────────────────────────────────┘



### Separation of Concerns:
- **Widgets**: Handle UI rendering and user input only
- **Providers**: Manage application state and coordinate between UI and business logic
- **Repository**: Single source of truth, handles data persistence and API calls
- **Services**: Platform-specific implementations (storage, connectivity, mock APIs)

## Resilience Strategy

### 1. Transaction Queue (FIFO Buffer)
- All transactions are queued locally in memory before sending to server
- Queue persists through app restarts using SharedPreferences
- **Strict FIFO ordering** prevents race conditions and ensures consistency
- Each transaction has a **UUID v4 idempotency key** to prevent duplicate processing

### 2. Anti-Fraud Guard
**Formula**: 


**Implementation**:
- Immediate validation before adding transaction to queue
- UI always shows accurate available balance
- Prevents users from exploiting network lag to queue more money than they have

### 3. Optimistic UI Updates
- Balance updates immediately when user taps "Send"
- Transaction appears in history instantly (before server confirmation)
- If server rejects, automatic rollback with user notification
- Provides immediate feedback while maintaining data integrity

### 4. Retry Logic with Exponential Backoff
- **Max 5 retries** per transaction to prevent infinite loops
- **Exponential backoff**: `2^n * 1000ms` delay between retries
- **Retry triggers**:
    - Connectivity restoration (via `connectivity_plus` listener)
    - App launch/foreground
    - Manual retry for failed transactions
    - Periodic checks (every 10 seconds when pending transactions exist)

### 5. Error Handling Strategy
| Error Type | Action | User Feedback |
|------------|--------|---------------|
| **Network Errors** | Queue and retry | "Transaction queued - will complete when online" |
| **Server Errors (500)** | Retry with exponential backoff | "Temporary server issue - retrying..." |
| **Bank Decline (402)** | Fail permanently with rollback | "Transaction declined by bank" |
| **Insufficient Funds** | Fail permanently with rollback | "Insufficient funds on server" |
| **Max Retries Exceeded** | Fail permanently | "Failed after multiple attempts" |

## Data Consistency Strategy

### Single Source of Truth
- **PaymentRepository** maintains all application state
- All writes go through repository methods (never directly to UI)
- UI observes repository streams for updates
- Storage acts as persistence layer, not primary data source

### Transaction Lifecycle

Created → Pending → Processing → [Completed | Failed]
│ │ │ │
│ │ │ (Auto-Rollback)
│ │ └── Retry ────┘
│ └── Persisted ───────────┘
└── Idempotency Key Generated



### Rollback Mechanism
- Failed transactions are immediately removed from pending queue
- Effective balance automatically recalculates (no manual adjustment needed)
- User notified with clear error message and option to retry
- Failed transactions remain in history for audit purposes

## Testing Strategy

### Unit Tests (`test/` directory)
- Transaction queue logic (FIFO processing)
- Balance calculations (Anti-Fraud Guard)
- Error handling and retry logic
- Repository methods

### Widget Tests (`test/` directory)
- Send money form validation
- Balance display updates
- Transaction history rendering
- Connectivity status indicators

### Integration Tests (`integration_test/` directory)
- Complete user flows (send money, view history)
- Network simulation (online/offline transitions)
- App restart scenarios
- Queue persistence verification

## Trade-offs and Improvements

### Current Trade-offs (MVP):
1. **Shared Preferences Storage**:
    - ✅ Simple and fast for MVP
    - ❌ Not ideal for large datasets (>1000 transactions)
    - ✅ Sufficient for demonstration purposes

2. **In-Memory Queue**:
    - ✅ Fast processing and simple implementation
    - ❌ Could lose data if app killed during write
    - ✅ Mitigated by immediate persistence after each change

3. **Simple Retry Logic**:
    - ✅ Easy to understand and debug
    - ❌ Could be enhanced with circuit breaker pattern
    - ✅ Sufficient for demonstration scenarios

### Production Improvements:
1. **Database Migration**: Switch to SQLite/Drift for better querying and larger datasets
2. **Biometric Authentication**: Add Face ID/Touch ID for transaction authorization
3. **Push Notifications**: Notify users when transactions complete or fail
4. **Rate Limiting**: Implement daily/monthly transaction limits
5. **Analytics Integration**: Track transaction success rates and user behavior
6. **Background Processing**: Process queue when app is closed (using WorkManager/Background Fetch)
7. **Conflict Resolution**: Handle concurrent modifications with versioning
8. **Data Encryption**: Encrypt stored transaction data at rest
9. **Multi-Currency Support**: Extend beyond Euros with real-time exchange rates
10. **Transaction Limits**: Implement configurable daily/monthly limits

## Scalability Considerations

### Horizontal Scaling:
- Repository pattern allows easy swapping of data sources (Firebase, REST APIs, etc.)
- Could implement **Firebase/Firestore** for real-time sync across devices
- Could add **GraphQL** for flexible queries and reduced network payload
- Microservices-ready architecture

### Performance Optimizations:
- **Lazy loading** for transaction history (paginated API)
- **Pagination** for large datasets (load 50 transactions at a time)
- **Caching layer** for frequently accessed data (balance, recent transactions)
- **Debounced network requests** to prevent API spam

### Monitoring & Observability:
- **Error reporting**: Sentry/Crashlytics integration
- **Performance monitoring**: Firebase Performance Monitoring
- **User analytics**: Firebase Analytics/Mixpanel
- **Log aggregation**: Structured logging with log levels

### Security Enhancements:
- **Certificate Pinning** for API calls
- **Local data encryption** using Flutter Secure Storage
- **JWT token refresh** with secure storage
- **Input validation** and sanitization at all layers

## Deployment Considerations

### CI/CD Pipeline:
- Automated testing on each commit
- Code quality checks (linting, formatting)
- Build versioning and release automation
- Environment-specific configurations (dev, staging, prod)

### App Store Requirements:
- German market compliance (GDPR, PSD2)
- Accessibility support (VoiceOver, TalkBack)
- Localization 
- App store screenshots and descriptions

This architecture provides a solid foundation for a production-ready payment application while being simple enough for demonstration purposes. The clean separation of concerns makes it easy to extend, test, and maintain.