# Personal Details Onboarding Setup

This guide explains how to set up and use the new personal details onboarding feature in the Nero app.

## Overview

The personal details onboarding allows users to provide their basic information including:
- Age
- Gender
- Height (feet & inches)
- Weight (lbs)
- Body fat percentage
- Activity level
- Primary fitness goal
- Injury history
- Sleep hours
- Stress level
- Workout history

## Database Setup

### Option 1: Fresh Database Setup
If you're starting fresh, run the existing `FRESH_DATABASE_SETUP.sql` which already includes basic user structure.

### Option 2: Existing Database Update
If you have an existing database, run the `UPDATED_DATABASE_SETUP.sql` script to add personal details columns:

```sql
-- This adds personal details columns to your existing users table
-- Run this in your Supabase Dashboard > SQL Editor
```

The script will:
- ✅ Add 12 new personal details columns to the existing `users` table
- ✅ Create indexes for better performance
- ✅ Update the user creation trigger to handle new columns
- ✅ Maintain all existing workout preferences functionality
- ✅ Ensure RLS policies cover new columns

## Features Added

### 1. PersonalDetailsView
- 12-step onboarding flow similar to workout questionnaire
- Interactive sliders for age, weight, and body fat percentage
- Picker wheels for height selection
- Multiple choice questions with button interface
- Progress indicator and navigation
- Summary screen before completion

### 2. PersonalDetailsService
- Save personal details to Supabase
- Load existing personal details
- Check if user has completed personal details
- Handles database errors gracefully

### 3. Updated ContentView
- New "Personal Details" menu option in side menu
- Sheet presentation for personal details onboarding
- Integrated with existing app flow

## How to Use

### For Users
1. Open the app and tap the hamburger menu (three lines) in the top left
2. Select "Personal Details" from the menu
3. Complete the 12-step onboarding process
4. Review your information on the summary screen
5. Tap "Finish" to save your details

### For Developers

#### Accessing Personal Details Data
```swift
@StateObject private var personalDetailsService = PersonalDetailsService()

// Check if user has personal details
let hasDetails = await personalDetailsService.hasPersonalDetails()

// Load user's personal details
if let details = await personalDetailsService.loadPersonalDetails() {
    print("User age: \(details.age)")
    print("User weight: \(details.weight) lbs")
    // ... use other fields
}
```

#### Database Schema
The personal details are stored in the existing `users` table with these new columns:
- `age` (INTEGER)
- `gender` (TEXT)
- `height_feet` (INTEGER)
- `height_inches` (INTEGER)
- `weight` (INTEGER)
- `body_fat_percentage` (INTEGER)
- `activity_level` (TEXT)
- `primary_fitness_goal` (TEXT)
- `injury_history` (TEXT)
- `sleep_hours` (TEXT)
- `stress_level` (TEXT)
- `workout_history` (TEXT)
- `personal_details_updated_at` (TIMESTAMP)

## Data Privacy & Security

- All personal details are stored securely in Supabase with Row Level Security (RLS)
- Users can only access their own data
- All fields are optional and can be NULL
- The service handles missing data gracefully with sensible defaults

## Future Enhancements

Potential improvements for the personal details system:
- Edit mode for updating existing details
- More granular fitness goals
- Integration with workout recommendations
- BMI and BMR calculations
- Progress tracking over time
- Data export functionality

## Troubleshooting

### Common Issues

1. **Database columns not found**: Make sure you've run the `UPDATED_DATABASE_SETUP.sql` script
2. **Permission errors**: Verify RLS policies are in place for the users table
3. **Service errors**: Check that the user is properly authenticated before accessing personal details

### Testing

To test the personal details flow:
1. Create a new user account
2. Complete the personal details onboarding
3. Check the database to verify data was saved
4. Log out and back in to verify data persistence

## Integration with Existing Features

The personal details onboarding works alongside:
- ✅ Existing workout preferences system
- ✅ User authentication flow
- ✅ Workout tracking functionality
- ✅ All existing RLS policies and security measures

Users can complete both workout preferences and personal details in any order, and the app will continue to function normally whether or not they've completed either onboarding flow. 