-- Create notifications table
CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    image_icon TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add RLS (Row Level Security) policy
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Users can only see their own notifications
CREATE POLICY "Users can view own notifications" ON notifications 
FOR SELECT USING (auth.uid() = user_id);

-- Users can only insert their own notifications  
CREATE POLICY "Users can insert own notifications" ON notifications 
FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can only update their own notifications
CREATE POLICY "Users can update own notifications" ON notifications 
FOR UPDATE USING (auth.uid() = user_id);

-- Users can only delete their own notifications
CREATE POLICY "Users can delete own notifications" ON notifications 
FOR DELETE USING (auth.uid() = user_id);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_timestamp ON notifications(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);

-- Insert sample notification for testing (you can remove this later)
-- Note: Replace 'your-user-id-here' with an actual user UUID from your auth.users table
-- INSERT INTO notifications (user_id, title, message, type, timestamp, is_read, image_icon)
-- VALUES ('your-user-id-here', 'Welcome to Nero!', 'Start tracking your workouts and achieve your fitness goals.', 'system', NOW(), FALSE, 'info.circle.fill'); 