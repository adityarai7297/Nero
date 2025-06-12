-- Updated Database Setup for Nero App with Personal Details
-- Run these commands in your Supabase Dashboard > SQL Editor
-- This adds personal details columns to the existing users table

-- 1. Add personal details columns to the existing users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS age INTEGER,
ADD COLUMN IF NOT EXISTS gender TEXT,
ADD COLUMN IF NOT EXISTS height_feet INTEGER,
ADD COLUMN IF NOT EXISTS height_inches INTEGER,
ADD COLUMN IF NOT EXISTS weight INTEGER,
ADD COLUMN IF NOT EXISTS body_fat_percentage INTEGER,
ADD COLUMN IF NOT EXISTS activity_level TEXT,
ADD COLUMN IF NOT EXISTS primary_fitness_goal TEXT,
ADD COLUMN IF NOT EXISTS injury_history TEXT,
ADD COLUMN IF NOT EXISTS sleep_hours TEXT,
ADD COLUMN IF NOT EXISTS stress_level TEXT,
ADD COLUMN IF NOT EXISTS workout_history TEXT,
ADD COLUMN IF NOT EXISTS personal_details_updated_at TIMESTAMP WITH TIME ZONE;

-- 2. Create indexes for better performance on new columns
CREATE INDEX IF NOT EXISTS idx_users_personal_details_updated ON public.users(personal_details_updated_at);
CREATE INDEX IF NOT EXISTS idx_users_age ON public.users(age);
CREATE INDEX IF NOT EXISTS idx_users_gender ON public.users(gender);

-- 3. Update the handle_new_user function to include default personal details
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (
        id, 
        email, 
        created_at, 
        updated_at,
        -- Workout preferences defaults
        primary_goal,
        training_experience, 
        session_frequency,
        session_length,
        equipment_access,
        movement_styles,
        weekly_split,
        volume_tolerance,
        rep_ranges,
        effort_level,
        eating_approach,
        injury_considerations,
        mobility_time,
        busy_equipment_preference,
        rest_periods,
        progression_style,
        exercise_menu_change,
        recovery_resources,
        programming_format,
        -- Personal details defaults (optional)
        age,
        gender,
        height_feet,
        height_inches,
        weight,
        body_fat_percentage,
        activity_level,
        primary_fitness_goal,
        injury_history,
        sleep_hours,
        stress_level,
        workout_history
    )
    VALUES (
        NEW.id,
        COALESCE(NEW.email, ''),
        NOW(),
        NOW(),
        -- Workout preferences defaults
        'not_sure',
        'not_sure', 
        'not_sure',
        'not_sure',
        'not_sure',
        'not_sure',
        'not_sure',
        'not_sure',
        'not_sure',
        'not_sure',
        'not_sure',
        'not_sure',
        'not_sure',
        'not_sure',
        'not_sure',
        'not_sure',
        'not_sure',
        'not_sure',
        'not_sure',
        -- Personal details defaults (leave as NULL for new users)
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL
    );
    RETURN NEW;
EXCEPTION
    WHEN unique_violation THEN
        -- User already exists, do nothing
        RETURN NEW;
    WHEN OTHERS THEN
        -- Log error but don't fail the auth process
        RAISE WARNING 'Error creating user profile: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Ensure RLS policies still work with new columns
-- The existing policies should automatically cover the new columns since they operate on the users table

-- 5. Grant permissions on new columns (should be inherited from table permissions)
-- No additional grants needed as the table permissions cover all columns

-- 6. Create workout_plans table for storing generated plans
CREATE TABLE IF NOT EXISTS workout_plans (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    plan_json JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 7. Enable Row Level Security on workout_plans
ALTER TABLE workout_plans ENABLE ROW LEVEL SECURITY;

-- 8. Create RLS policies for workout_plans
CREATE POLICY "Users can view their own workout plans" ON workout_plans
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own workout plans" ON workout_plans
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own workout plans" ON workout_plans
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own workout plans" ON workout_plans
    FOR DELETE USING (auth.uid() = user_id);

-- Setup complete! 
-- This script adds:
-- ✅ Personal details columns to existing users table
-- ✅ Indexes for better performance on personal details
-- ✅ Updated trigger function with personal details support
-- ✅ Maintains all existing workout preferences functionality
-- ✅ All existing RLS policies automatically apply to new columns

-- Note: Users will have NULL values for personal details until they complete the onboarding
-- The PersonalDetailsService handles these NULL values gracefully with defaults 