# Background Processing Implementation Guide

## Overview

This implementation ensures that all API calls in the Nero fitness app continue running even when the user minimizes the app, navigates away from views, or temporarily closes the app. The results are persisted and restored when the user returns to the app.

## Key Components

### 1. BackgroundTaskManager
- **File**: `BackgroundTaskManager.swift`
- **Purpose**: Coordinates background task execution and manages iOS background time
- **Features**:
  - Automatic background time management
  - Task persistence across app lifecycle
  - Progress tracking and status updates
  - Automatic cleanup of completed tasks

### 2. ResultPersistenceManager
- **File**: `BackgroundTaskManager.swift` (same file)
- **Purpose**: Saves and restores API results using UserDefaults
- **Features**:
  - Workout plan result persistence
  - Macro meal result persistence
  - Chat response persistence
  - Automatic cleanup of old results (7 days default)

### 3. AppLifecycleManager
- **File**: `AppLifecycleManager.swift`
- **Purpose**: Monitors app state changes and coordinates responses
- **Features**:
  - App active/background state tracking
  - Notification-based lifecycle events
  - View extension for easy lifecycle handling
  - Background task status UI components

## Implementation Details

### API Client Changes

#### DeepseekAPIClient
- Added `backgroundSession` with extended timeouts and connectivity waiting
- Created background-enabled wrapper methods:
  - `generateWorkoutPlanInBackground()`
  - `editWorkoutPlanInBackground()`
  - `getMealFromDescriptionInBackground()`
  - `getFitnessCoachResponseInBackground()`

#### Service Layer Changes

#### WorkoutPreferencesService
- Updated to use `BackgroundTaskManager` instead of manual background tasks
- Maintains UI status updates while running in background
- Persists workout plan results automatically

#### MacroService
- Added background-enabled methods:
  - `saveMealFromDescriptionInBackground()`
  - `editMealWithAIInBackground()`
- Integrates with result persistence system

#### AudioTranscriptionService
- Enhanced to support background audio processing
- Uses background task manager for extended recording sessions

### View Layer Changes

All major views now include:
- `@Environment(\.scenePhase)` monitoring
- `@StateObject` references to `BackgroundTaskManager`
- `checkForCompletedTasks()` methods for result restoration
- Lifecycle-aware state management

#### Updated Views:
- `AIChatView.swift`
- `MacroChatView.swift`
- `WorkoutEditChatView.swift`

## Usage Examples

### Starting a Background API Call

```swift
// Instead of this:
let result = try await DeepseekAPIClient.shared.generateWorkoutPlan(
    personalDetails: details,
    preferences: preferences
)

// Use this:
DeepseekAPIClient.shared.generateWorkoutPlanInBackground(
    personalDetails: details,
    preferences: preferences,
    taskId: "my_task_id"
) { result in
    switch result {
    case .success(let plan):
        // Handle success
    case .failure(let error):
        // Handle error
    }
}
```

### Checking for Completed Tasks

```swift
private func checkForCompletedTasks() {
    guard let taskId = currentTaskId else { return }
    
    if let taskInfo = backgroundTaskManager.getTaskInfo(taskId) {
        switch taskInfo.status {
        case .completed:
            // Load persisted result
            if let result = ResultPersistenceManager.shared.loadWorkoutPlanResult(taskId: taskId) {
                // Update UI with result
            }
        case .failed:
            // Handle failure
        case .running:
            // Keep loading state
        }
    }
}
```

### Adding Lifecycle Handling to Views

```swift
.onAppear {
    checkForCompletedTasks()
}
.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .active {
        checkForCompletedTasks()
    }
}
```

## Background Task Types

```swift
enum BackgroundTaskType {
    case workoutPlanGeneration
    case workoutPlanEdit
    case macroMealParsing
    case macroMealEdit
    case fitnessCoachChat
    case audioTranscription
}
```

## Task Status Tracking

```swift
enum BackgroundTaskStatus {
    case running
    case completed
    case failed
}
```

## Persistence Strategy

### UserDefaults Keys:
- **Active Tasks**: `BackgroundTasks_Active`
- **Workout Plans**: `WorkoutPlan_{taskId}`
- **Macro Meals**: `MacroMeal_{taskId}`
- **Chat Responses**: `ChatResponse_{taskId}`
- **Timestamps**: `{type}_{taskId}_timestamp`

### Cleanup Policy:
- Results older than 7 days are automatically removed
- Stale tasks (running for >5 minutes) are marked as failed on app startup
- Background task identifiers are properly cleaned up

## Benefits

### For Users:
1. **Uninterrupted Experience**: API calls continue even when switching apps
2. **Persistent Results**: Completed work is never lost
3. **Seamless Return**: Results appear immediately when returning to the app
4. **No Re-work**: Never need to retry failed operations due to app switching

### For Developers:
1. **Easy Integration**: Simple wrapper methods for existing API calls
2. **Automatic Management**: Background time and cleanup handled automatically
3. **Status Tracking**: Built-in progress monitoring and error handling
4. **Flexible**: Can be applied to any async operation

## Testing Scenarios

### Test Cases:
1. **Start API call → Minimize app → Return**: Result should appear
2. **Start API call → Navigate away → Return**: Process continues seamlessly
3. **Start API call → Force close app → Reopen**: Task recovery handles gracefully
4. **Multiple concurrent API calls**: All should be tracked independently
5. **Long-running tasks**: Should survive extended background time

### Testing Steps:
1. Start a workout plan generation
2. Immediately minimize the app or navigate away
3. Wait for the API call to complete (can check logs)
4. Return to the app
5. Verify the workout plan appears without user intervention

## iOS Background Execution Limits

### Important Considerations:
- **Background App Refresh**: Must be enabled for optimal experience
- **Time Limits**: iOS gives limited background time (typically 30 seconds to 10 minutes)
- **Battery Impact**: Background processing is optimized to minimize battery usage
- **Connectivity**: URLSession automatically waits for network connectivity

### Graceful Degradation:
- If background time expires, tasks are marked as failed
- Users can retry operations when returning to foreground
- No data corruption or inconsistent states occur

## Future Enhancements

### Potential Improvements:
1. **Network Queue**: Queue API calls when offline, execute when online
2. **Smart Retry**: Automatic retry logic for failed background tasks
3. **Progress Updates**: Real-time progress for long-running operations
4. **User Notifications**: Notify users when background tasks complete
5. **Analytics**: Track background task success rates and performance

## Troubleshooting

### Common Issues:
1. **Tasks not resuming**: Check Background App Refresh settings
2. **Persistence not working**: Verify UserDefaults access permissions
3. **UI not updating**: Ensure proper MainActor usage in completion handlers
4. **Memory issues**: Background task manager automatically cleans up

### Debugging:
- Check console logs for background task lifecycle events
- Monitor `BackgroundTaskManager.shared.activeTasks` for current status
- Use Xcode's background execution debugging tools
- Test with different background time scenarios

## Security Considerations

### Data Protection:
- API results are stored in UserDefaults (encrypted on device)
- Task identifiers are UUIDs (no sensitive information)
- Automatic cleanup prevents data accumulation
- No network credentials are persisted

### Privacy:
- Background processing respects user privacy settings
- No data is transmitted without user interaction
- Results are only accessible to the same app instance
