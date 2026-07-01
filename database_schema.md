# Database Schema

Firestore collections structure based on our services:

*   **`users`**: Contains user profile data, balances (Wooden Coins, Lifebuoys), and user statistics.
*   **`friend_requests`**: Stores pending friend requests between users (fromUid, toUid, status).
*   **`friendships`**: Stores accepted friendship relationships.
*   **`challenge_invitations`**: Stores invitations sent from one user to another to start a challenge (status: pending, accepted, rejected).
*   **`cooperative_sessions`**: Stores data for active cooperative challenges between users.
*   **`competitive_sessions`**: Stores data for active competitive challenges between users.
