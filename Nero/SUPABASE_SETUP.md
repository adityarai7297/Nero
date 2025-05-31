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

## Database Schema

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

### 2. Create Workout Sets Table
```sql
CREATE TABLE workout_sets (
  id SERIAL PRIMARY KEY,
  exercise_name TEXT NOT NULL,
  weight DECIMAL(5,2) NOT NULL,
  reps INTEGER NOT NULL,
  rpe INTEGER NOT NULL,
  completed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
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

### 4. Enable Row Level Security (Optional but Recommended)
```sql
ALTER TABLE exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_sets ENABLE ROW LEVEL SECURITY;

-- Allow read access to exercises for everyone
CREATE POLICY "Allow read access to exercises" ON exercises FOR SELECT USING (true);

-- Allow full access to workout_sets for everyone (you can add user authentication later)
CREATE POLICY "Allow full access to workout_sets" ON workout_sets FOR ALL USING (true);
``` 