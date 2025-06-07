# New User Testing Guide

## Prerequisites

### 1. Database Setup
1. **Delete all existing users** from your Supabase Dashboard:
   - Go to **Authentication > Users**
   - Delete all existing users
   - Go to **Table Editor > public.users** 
   - Delete all rows (if table exists)
   - Go to **Table Editor > workout_sets**
   - Delete all rows (if table exists)

2. **Run the fresh database setup**:
   - Go to **SQL Editor** in Supabase Dashboard
   - Copy and paste the entire contents of `FRESH_DATABASE_SETUP.sql`
   - Click "Run" to execute the script
   - Verify you see success messages for all operations

### 2. Expected Database Structure After Setup
✅ `public.users` table with 19 workout preference columns  
✅ `workout_sets` table with user_id foreign key  
✅ `exercises` table with 20 default exercises  
✅ Row Level Security policies on all tables  
✅ Auto-creation trigger function for new user profiles  

## Testing Steps

### Test 1: Email/Password Signup (Primary Test)

1. **Open the app** - you should see the AuthView
2. **Switch to "Sign Up" tab**
3. **Enter test credentials**:
   - Email: `test1@example.com`
   - Password: `password123`
   - Confirm Password: `password123`
4. **Tap "Create Account"**

**Expected Console Output:**
```
🔄 Creating new user account for: test1@example.com
✅ Profile verified - ID: [UUID], Email: test1@example.com
✅ New user signup completed for: test1@example.com
```

**Expected Behavior:**
- App should navigate to workout questionnaire
- No error messages should appear
- User should be authenticated

**Verify in Supabase Dashboard:**
- Go to **Authentication > Users** → should see 1 user
- Go to **Table Editor > public.users** → should see 1 row with the user's data
- User ID should match between auth.users and public.users

### Test 2: Complete Workout Questionnaire

1. **Answer all 19 questions** in the questionnaire
2. **Tap "Complete Setup"**

**Expected Behavior:**
- Loading overlay should appear
- Success popup should appear: "Workout preferences saved successfully!"
- App should navigate to main workout interface

**Verify in Database:**
- Go to **Table Editor > public.users**
- Check that all 19 preference columns have values (not 'not_sure')
- `workout_preferences_updated_at` should have a timestamp

### Test 3: Sign Out and Sign In

1. **Tap the menu button** (top-left)
2. **Tap "Sign Out"**
3. **Confirm sign out**
4. **Sign back in** with same credentials

**Expected Console Output:**
```
🔄 Signing in user: test1@example.com
✅ Profile verified for existing user: test1@example.com
✅ Sign in completed for: test1@example.com
```

**Expected Behavior:**
- Should go straight to main workout interface (skip questionnaire)
- All workout preferences should be preserved

### Test 4: Create Second User

1. **Sign out** current user
2. **Create another account**:
   - Email: `test2@example.com`
   - Password: `password123`

**Verify in Database:**
- **Authentication > Users** → should show 2 users
- **Table Editor > public.users** → should show 2 rows
- Each user should have their own separate data

### Test 5: Workout Set Logging

1. **Log some workout sets** for the current user
2. **Switch exercises** and log more sets

**Verify in Database:**
- **Table Editor > workout_sets** → should show workout data
- Each set should have the correct `user_id`
- Data should be isolated per user

## Troubleshooting

### If User Profile Creation Fails

**Check Console for:**
```
❌ Failed to create user profile: [error message]
⚠️ Trigger didn't create profile, creating manually...
```

**Manual Fix:**
1. Go to **SQL Editor** in Supabase
2. Run: 
```sql
SELECT * FROM public.users WHERE id = '[USER_ID_FROM_CONSOLE]';
```
3. If no results, manually insert:
```sql
INSERT INTO public.users (id, email, created_at, updated_at)
VALUES ('[USER_ID]', '[EMAIL]', NOW(), NOW());
```

### If Trigger Function Issues

**Check trigger exists:**
```sql
SELECT * FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';
```

**Recreate trigger if needed:**
```sql
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

### If Workout Preferences Don't Save

**Check permissions:**
```sql
SELECT * FROM information_schema.table_privileges 
WHERE table_name = 'users' AND grantee = 'authenticated';
```

**Check RLS policies:**
```sql
SELECT * FROM pg_policies WHERE tablename = 'users';
```

## Success Criteria

✅ New users can sign up without errors  
✅ User profiles are created automatically in public.users  
✅ Workout questionnaire saves all 19 preferences  
✅ Users can sign out and sign back in  
✅ Workout sets are properly attributed to users  
✅ Multiple users can exist with isolated data  
✅ No manual database intervention required  

## Console Logging

The app now provides detailed console logging. Watch for:
- ✅ Success messages (green checkmarks)
- 🔄 Process messages (blue arrows) 
- ⚠️ Warning messages (yellow warnings)
- ❌ Error messages (red X marks)
- 🔧 Manual intervention messages

This logging will help you identify exactly where any issues occur in the user creation flow. 