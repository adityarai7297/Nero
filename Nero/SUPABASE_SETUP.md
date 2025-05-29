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

## Todo Table Structure
Make sure you have created a "todos" table in your Supabase project with:
- id: int (primary key, auto-increment)
- title: text (not null)

You can create this table in the Supabase Dashboard > Table Editor. 