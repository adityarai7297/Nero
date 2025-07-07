-- Progressive Overload Analysis Database Setup
-- Run these queries in Supabase SQL Editor

-- 1. Create progressive_overload_analyses table
CREATE TABLE IF NOT EXISTS progressive_overload_analyses (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    analysis_date TIMESTAMP WITH TIME ZONE NOT NULL,
    suggestions JSONB NOT NULL,
    summary TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create index for efficient user queries
CREATE INDEX IF NOT EXISTS idx_progressive_overload_user_date 
ON progressive_overload_analyses(user_id, analysis_date DESC);

-- 3. Create updated_at trigger
CREATE OR REPLACE FUNCTION update_progressive_overload_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER progressive_overload_updated_at
    BEFORE UPDATE ON progressive_overload_analyses
    FOR EACH ROW
    EXECUTE FUNCTION update_progressive_overload_updated_at();

-- 4. Enable Row Level Security
ALTER TABLE progressive_overload_analyses ENABLE ROW LEVEL SECURITY;

-- 5. Create RLS policies for users to only access their own data
CREATE POLICY "Users can view their own progressive overload analyses"
ON progressive_overload_analyses
FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own progressive overload analyses"
ON progressive_overload_analyses
FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own progressive overload analyses"
ON progressive_overload_analyses
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own progressive overload analyses"
ON progressive_overload_analyses
FOR DELETE
USING (auth.uid() = user_id);

-- 6. Optional: Function to clean up old analyses (keep only last 5 per user)
CREATE OR REPLACE FUNCTION cleanup_old_progressive_overload_analyses()
RETURNS void AS $$
BEGIN
    DELETE FROM progressive_overload_analyses
    WHERE id NOT IN (
        SELECT id FROM (
            SELECT id, 
                   ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY analysis_date DESC) as rn
            FROM progressive_overload_analyses
        ) ranked
        WHERE rn <= 5
    );
END;
$$ LANGUAGE plpgsql;

-- 7. Test data structure (optional - for verification)
-- SELECT * FROM progressive_overload_analyses WHERE user_id = auth.uid() ORDER BY analysis_date DESC; 