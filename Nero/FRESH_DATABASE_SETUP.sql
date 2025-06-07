-- Complete Fresh Database Setup for Nero App
-- Run these commands in your Supabase Dashboard > SQL Editor
-- This script assumes you're starting fresh with no existing data

-- 1. Create the public.users table with all workout preferences
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Workout preferences (all 19 questions)
    primary_goal TEXT DEFAULT 'not_sure',
    training_experience TEXT DEFAULT 'not_sure', 
    session_frequency TEXT DEFAULT 'not_sure',
    session_length TEXT DEFAULT 'not_sure',
    equipment_access TEXT DEFAULT 'not_sure',
    movement_styles TEXT DEFAULT 'not_sure',
    weekly_split TEXT DEFAULT 'not_sure',
    volume_tolerance TEXT DEFAULT 'not_sure',
    rep_ranges TEXT DEFAULT 'not_sure',
    effort_level TEXT DEFAULT 'not_sure',
    eating_approach TEXT DEFAULT 'not_sure',
    injury_considerations TEXT DEFAULT 'not_sure',
    mobility_time TEXT DEFAULT 'not_sure',
    busy_equipment_preference TEXT DEFAULT 'not_sure',
    rest_periods TEXT DEFAULT 'not_sure',
    progression_style TEXT DEFAULT 'not_sure',
    exercise_menu_change TEXT DEFAULT 'not_sure',
    recovery_resources TEXT DEFAULT 'not_sure',
    programming_format TEXT DEFAULT 'not_sure',
    workout_preferences_updated_at TIMESTAMP WITH TIME ZONE
);

-- 2. Enable Row Level Security on users table
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 3. Create RLS policies for users table
CREATE POLICY "Users can view their own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile" ON public.users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- 4. Create workout_sets table (if it doesn't exist)
CREATE TABLE IF NOT EXISTS workout_sets (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    exercise_name TEXT NOT NULL,
    weight DECIMAL(6,2) NOT NULL,
    reps DECIMAL(4,1) NOT NULL,
    rpe DECIMAL(4,1) NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_id ON public.users(id);
CREATE INDEX IF NOT EXISTS idx_workout_sets_user_id ON workout_sets(user_id);
CREATE INDEX IF NOT EXISTS idx_workout_sets_created_at ON workout_sets(created_at);

-- 6. Enable Row Level Security on workout_sets
ALTER TABLE workout_sets ENABLE ROW LEVEL SECURITY;

-- 7. Create RLS policies for workout_sets
DROP POLICY IF EXISTS "Users can view their own workout sets" ON workout_sets;
DROP POLICY IF EXISTS "Users can insert their own workout sets" ON workout_sets;
DROP POLICY IF EXISTS "Users can update their own workout sets" ON workout_sets;
DROP POLICY IF EXISTS "Users can delete their own workout sets" ON workout_sets;

CREATE POLICY "Users can view their own workout sets" ON workout_sets
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own workout sets" ON workout_sets
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own workout sets" ON workout_sets
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own workout sets" ON workout_sets
    FOR DELETE USING (auth.uid() = user_id);

-- 8. Create function to automatically create user profiles
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, email, created_at, updated_at)
    VALUES (
        NEW.id,
        COALESCE(NEW.email, ''),
        NOW(),
        NOW()
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

-- 9. Create trigger to auto-create user profiles
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 10. Create exercises table (if it doesn't exist)
CREATE TABLE IF NOT EXISTS exercises (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    default_weight DECIMAL(5,2) DEFAULT 0,
    default_reps INTEGER DEFAULT 0,
    default_rpe INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 11. Insert default exercises
INSERT INTO exercises (name, default_weight, default_reps, default_rpe) VALUES
('Squat', 135.0, 8, 7),
('Bench Press', 135.0, 8, 7),
('Deadlift', 185.0, 5, 8),
('Overhead Press', 95.0, 8, 7),
('Barbell Row', 115.0, 8, 7),
('Pull-ups', 0.0, 8, 8),
('Dips', 0.0, 10, 7),
('Romanian Deadlift', 135.0, 10, 7),
('Front Squat', 115.0, 8, 8),
('Incline Bench Press', 115.0, 8, 7),
('Lat Pulldown', 100.0, 10, 7),
('Leg Press', 200.0, 12, 7),
('Leg Curl', 80.0, 12, 7),
('Leg Extension', 80.0, 12, 7),
('Calf Raise', 150.0, 15, 7),
('Bicep Curl', 25.0, 12, 7),
('Tricep Extension', 25.0, 12, 7),
('Lateral Raise', 15.0, 12, 7),
('Face Pull', 30.0, 15, 7),
('Plank', 0.0, 60, 7)
ON CONFLICT (name) DO NOTHING;

-- 12. Grant necessary permissions
GRANT USAGE ON SEQUENCE exercises_id_seq TO authenticated;
GRANT ALL ON exercises TO authenticated;
GRANT ALL ON public.users TO authenticated;
GRANT ALL ON workout_sets TO authenticated;

-- Setup complete! 
-- This script creates:
-- ✅ public.users table with all 19 workout preferences
-- ✅ Auto-creation trigger for new user profiles  
-- ✅ Row Level Security policies
-- ✅ workout_sets table with proper user attribution
-- ✅ Default exercises for the app
-- ✅ All necessary indexes for performance 