-- Database Migration to Add User Authentication
-- Run these commands in your Supabase Dashboard > SQL Editor

-- 1. Add user_id column to workout_sets table
ALTER TABLE workout_sets 
ADD COLUMN user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- 2. Create index for better performance on user_id lookups
CREATE INDEX idx_workout_sets_user_id ON workout_sets(user_id);

-- 3. Update Row Level Security policies for workout_sets

-- Drop existing policies
DROP POLICY IF EXISTS "Allow full access to workout_sets" ON workout_sets;

-- Create new policies that ensure users can only access their own data
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

-- 4. Optional: Backfill existing workout_sets with a default user_id
-- IMPORTANT: Only run this if you have existing data and want to assign it to a specific user
-- Replace 'YOUR_USER_ID_HERE' with an actual user ID from auth.users table
-- UPDATE workout_sets SET user_id = 'YOUR_USER_ID_HERE' WHERE user_id IS NULL;

-- 5. Make user_id NOT NULL after backfilling (optional, recommended for data integrity)
-- ALTER TABLE workout_sets ALTER COLUMN user_id SET NOT NULL; 