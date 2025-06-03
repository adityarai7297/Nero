# Supabase Integration Setup

## Add Supabase Package
1. Open your project in Xcode
2. Go to File > Add Packages...
3. Enter the following URL in the search field:
   ```
   https://github.com/supabase-community/supabase-swift
   ```
4. Select the "supabase-swift" package
5. Click "Add Package" and select "Supabase" from the package products

## Supabase Configuration
The Supabase client is already configured in `SupabaseClient.swift` with:
- URL: https://zohjfuyehgzxscdtqsoo.supabase.co
- API Key: The anon/public key (already configured)

## Authentication Setup

### 1. Enable Email Authentication
In your Supabase Dashboard:
1. Go to Authentication > Settings
2. Ensure "Enable email confirmations" is enabled (recommended)
3. Configure email templates if desired
4. Set up any additional auth providers if needed

### 2. Configure App URLs (for email verification)
In Authentication > URL Configuration:
- Site URL: `your-app-scheme://` (for deep linking)
- Redirect URLs: Add your app's redirect URLs

## Database Schema

### Initial Setup
Run these SQL commands in your Supabase Dashboard > SQL Editor:

### 1. Create Exercises Table
```sql
CREATE TABLE exercises (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  default_weight DECIMAL(5,2) DEFAULT 0,
  default_reps INTEGER DEFAULT 0,
  default_rpe INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 2. Create Workout Sets Table (Updated with User Authentication)
```sql
CREATE TABLE workout_sets (
  id SERIAL PRIMARY KEY,
  exercise_name TEXT NOT NULL,
  weight DECIMAL(5,2) NOT NULL,
  reps INTEGER NOT NULL,
  rpe INTEGER NOT NULL,
  completed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL
);

-- Add index for better performance
CREATE INDEX idx_workout_sets_user_id ON workout_sets(user_id);
```

### 3. Insert Default Exercises
```sql
INSERT INTO exercises (name, default_weight, default_reps, default_rpe) VALUES
('Bench Press', 50, 8, 60),
('Squat', 80, 10, 70),
('Deadlift', 100, 6, 80),
('Overhead Press', 35, 8, 65),
('Pull-ups', 0, 12, 70),
('Barbell Row', 60, 10, 75),
('Incline Bench', 40, 8, 65),
('Dips', 0, 15, 70),
('Romanian Deadlift', 70, 12, 70),
('Leg Press', 120, 15, 75);
```

### 4. Enable Row Level Security with User Authentication
```sql
-- Enable RLS
ALTER TABLE exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_sets ENABLE ROW LEVEL SECURITY;

-- Exercises policies (public read access)
CREATE POLICY "Allow read access to exercises" ON exercises FOR SELECT USING (true);

-- Workout sets policies (user-specific access)
CREATE POLICY "Users can view their own workout sets" 
ON workout_sets FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own workout sets" 
ON workout_sets FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own workout sets" 
ON workout_sets FOR UPDATE 
USING (auth.uid() = user_id) 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own workout sets" 
ON workout_sets FOR DELETE 
USING (auth.uid() = user_id);
```

## Migration for Existing Installations

If you already have the app running and want to add user authentication, run the SQL commands in `DATABASE_MIGRATION.sql`:

1. Open Supabase Dashboard > SQL Editor
2. Copy and paste the contents of `DATABASE_MIGRATION.sql`
3. Execute the commands
4. If you have existing workout sets, uncomment and modify the backfill command with a valid user ID

## App Features

### Authentication
- ✅ User registration with email/password
- ✅ User login with email/password  
- ✅ Session management
- ✅ Logout functionality
- ✅ Beautiful authentication UI

### Data Security
- ✅ Row Level Security (RLS) enabled
- ✅ Users can only see their own workout data
- ✅ Automatic user_id assignment to new workout sets
- ✅ Secure authentication state management

### Workout Tracking
- ✅ Exercise management
- ✅ Set logging with user attribution
- ✅ Personal workout history
- ✅ Real-time data synchronization 