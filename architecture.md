# Architecture

*   **State Management:** We use **Provider** for global state management and injecting dependencies across the app.
*   **Firebase Communication:** We use the **Service Pattern** (e.g., `ChallengeService`, `FriendsService`) to handle all external communication with Firebase Firestore. Services contain the pure data fetching, writing logic, and exception handling (`try-catch` blocks).
*   **Separation of Concerns:** Business logic and data mutation reside in Providers or Services. The UI layer (Screens/Widgets) focuses solely on rendering and reacting to state changes.
