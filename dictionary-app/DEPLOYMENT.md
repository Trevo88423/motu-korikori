# True Motu Dictionary - Deployment Guide

This guide walks you through deploying the True Motu Dictionary application to production.

## Prerequisites

Before deploying, ensure you have:
- [ ] GitHub account
- [ ] Vercel account (free tier works)
- [ ] Supabase account (free tier works)
- [ ] Cloudflare account (for R2 audio storage)
- [ ] Domain name (optional, but recommended)

## Step 1: Set Up Supabase

### 1.1 Create a New Project

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Click "New Project"
3. Fill in project details:
   - Name: `true-motu-dictionary`
   - Database Password: (generate a strong password)
   - Region: Choose closest to your target audience
4. Wait for project creation (~2 minutes)

### 1.2 Run Database Schema

1. Go to SQL Editor in Supabase dashboard
2. Open the file `supabase/schema.sql` from your project
3. Copy the entire contents
4. Paste into SQL Editor
5. Click "Run" to execute
6. Verify tables were created:
   - profiles
   - words
   - contributions
   - moderation_log

### 1.3 Seed Word Data

1. Generate seed file:
   ```bash
   cd dictionary-app
   npm run seed:generate
   ```
2. Open `supabase/seed.sql`
3. Copy contents to Supabase SQL Editor
4. Click "Run" (this may take 1-2 minutes)
5. Verify: `SELECT COUNT(*) FROM words;` should return 15,610

### 1.4 Get API Keys

1. Go to Settings > API in Supabase dashboard
2. Copy these values:
   - Project URL (`NEXT_PUBLIC_SUPABASE_URL`)
   - anon/public key (`NEXT_PUBLIC_SUPABASE_ANON_KEY`)
   - service_role key (`SUPABASE_SERVICE_ROLE_KEY`) - **Keep this secret!**

## Step 2: Set Up Cloudflare R2 for Audio Storage

### 2.1 Create R2 Bucket

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Go to R2 Object Storage
3. Click "Create bucket"
4. Name: `motu-dictionary-audio`
5. Location: Automatic
6. Click "Create bucket"

### 2.2 Configure Public Access

**Option A: R2.dev subdomain (easiest)**

1. Go to your bucket settings
2. Click "Public Access" tab
3. Enable "Allow Access"
4. Copy the R2.dev URL (e.g., `https://pub-xxx.r2.dev`)
5. This is your `R2_PUBLIC_URL`

**Option B: Custom domain (recommended for production)**

1. Go to bucket > Settings > Custom Domains
2. Click "Connect Domain"
3. Enter domain: `audio.yourdomain.com`
4. Follow DNS setup instructions
5. Wait for SSL certificate (~15 minutes)
6. Use `https://audio.yourdomain.com` as `R2_PUBLIC_URL`

### 2.3 Deploy Cloudflare Worker

1. Install Wrangler CLI:
   ```bash
   npm install -g wrangler
   ```

2. Authenticate:
   ```bash
   wrangler login
   ```

3. Update `cloudflare-worker/wrangler.toml`:
   - Set `bucket_name` to your bucket name
   - Set `R2_PUBLIC_URL` to your R2 URL
   - Set `ALLOWED_ORIGIN` to your Vercel URL (you'll get this in next step)

4. Set secrets:
   ```bash
   cd cloudflare-worker

   wrangler secret put SUPABASE_URL
   # Paste your Supabase project URL

   wrangler secret put SUPABASE_ANON_KEY
   # Paste your Supabase anon key
   ```

5. Deploy worker:
   ```bash
   wrangler deploy
   ```

6. Copy the worker URL (e.g., `https://motu-dictionary-audio-upload.yourname.workers.dev`)
7. This is your `NEXT_PUBLIC_CLOUDFLARE_WORKER_URL`

## Step 3: Deploy to Vercel

### 3.1 Push to GitHub

1. Create a new GitHub repository
2. Initialize git in your project:
   ```bash
   cd dictionary-app
   git init
   git add .
   git commit -m "Initial commit"
   git branch -M main
   git remote add origin https://github.com/yourusername/motu-dictionary.git
   git push -u origin main
   ```

### 3.2 Deploy to Vercel

1. Go to [Vercel Dashboard](https://vercel.com)
2. Click "Add New" > "Project"
3. Import your GitHub repository
4. Configure:
   - Framework Preset: Next.js
   - Root Directory: ./
   - Build Command: `npm run build`
   - Output Directory: (leave default)

### 3.3 Set Environment Variables

In Vercel project settings > Environment Variables, add:

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Cloudflare Worker
NEXT_PUBLIC_CLOUDFLARE_WORKER_URL=https://your-worker.workers.dev
```

### 3.4 Deploy

1. Click "Deploy"
2. Wait for build to complete (~2-3 minutes)
3. Visit your deployment URL (e.g., `https://your-app.vercel.app`)

## Step 4: Post-Deployment Configuration

### 4.1 Update Cloudflare Worker CORS

1. Edit `cloudflare-worker/wrangler.toml`
2. Update `ALLOWED_ORIGIN` to your Vercel URL
3. Redeploy:
   ```bash
   wrangler deploy
   ```

### 4.2 Create First Admin User

1. Sign up on your deployed app
2. Go to Supabase dashboard > Table Editor > profiles
3. Find your user row
4. Set `is_admin = true`
5. Now you can access `/admin` on your app

### 4.3 Test the Application

See Verification Checklist below.

## Step 5: Custom Domain (Optional)

### 5.1 Configure in Vercel

1. Vercel Dashboard > Your Project > Settings > Domains
2. Add your domain (e.g., `motudictionary.com`)
3. Follow DNS configuration instructions
4. Wait for SSL certificate

### 5.2 Update Environment Variables

1. Update `ALLOWED_ORIGIN` in Cloudflare Worker
2. Redeploy worker

## Verification Checklist

### Database Setup
- [ ] Schema executed successfully
- [ ] 15,610 words seeded
- [ ] Query `SELECT COUNT(*) FROM words` returns 15,610
- [ ] RLS policies enabled on all tables

### Authentication
- [ ] Can access signup page
- [ ] Can create account with all steps
- [ ] Profile created in database
- [ ] Can log in
- [ ] Can log out
- [ ] Middleware redirects unauthorized users

### Contribute Flow
- [ ] Navigate to `/contribute` (must be logged in)
- [ ] See a word with example verse
- [ ] Can enter translation
- [ ] Can record audio (browser permission prompt)
- [ ] Can select confidence level
- [ ] Can add notes
- [ ] "Save & Next" works
- [ ] Contribution saved in database
- [ ] Next word loads
- [ ] Progress bar updates

### Dashboard
- [ ] Navigate to `/dashboard`
- [ ] See contribution count
- [ ] See progress percentage
- [ ] See recent contributions
- [ ] Stats calculate correctly

### Dictionary
- [ ] Navigate to `/dictionary`
- [ ] See list of words
- [ ] Search works
- [ ] Filter by status works
- [ ] Pagination works
- [ ] Click on word opens detail page
- [ ] Word detail shows all contributions
- [ ] Consensus bar displays correctly

### Admin Panel
- [ ] Set `is_admin = true` for test user
- [ ] Navigate to `/admin`
- [ ] Non-admin users blocked
- [ ] Can view flagged words
- [ ] Can view low trust users
- [ ] Can perform moderation actions
- [ ] Moderation log shows actions

### Audio Upload
- [ ] Record audio in contribute page
- [ ] Audio uploads to R2
- [ ] Audio playback works
- [ ] Audio URL stored in database

### Consensus Algorithm
- [ ] Multiple users contribute to same word
- [ ] Consensus calculated correctly
- [ ] Weights applied by connection type
- [ ] Consensus audio selected from highest-weighted contributor
- [ ] Flagged status set when contributions are close

## Monitoring & Maintenance

### Database Backups

Supabase automatically backs up your database. To manually export:

1. Supabase Dashboard > Database > Backups
2. Click "Download backup"

### Running Consensus Recalculation

Create a Vercel Cron Job or run manually:

```typescript
// Add to app/api/cron/consensus/route.ts
import { recalculateAllConsensus } from '@/lib/consensus'

export async function GET(request: Request) {
  // Verify cron secret
  const authHeader = request.headers.get('authorization')
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return new Response('Unauthorized', { status: 401 })
  }

  const result = await recalculateAllConsensus()
  return Response.json(result)
}
```

### Cost Estimates

**Free Tier Limits:**

- **Supabase Free**: 500MB database, 50,000 monthly active users
- **Vercel Free**: 100GB bandwidth/month, unlimited deployments
- **Cloudflare R2 Free**: 10GB storage, 1M read operations

**Estimated Monthly Costs (1,000 users, 10,000 contributions/month):**

- Supabase: $0 (within free tier)
- Vercel: $0 (within free tier)
- Cloudflare R2: ~$0.15 (storage) + $0.04 (operations) = **$0.19/month**

**Total: ~$0.20/month for small-scale deployment!**

## Troubleshooting

### Build Fails on Vercel

- Check that all environment variables are set
- Ensure Node version is compatible (18.x or later)
- Check build logs for specific errors

### Audio Upload Fails

- Verify Cloudflare Worker is deployed
- Check CORS settings in worker
- Verify R2 bucket permissions
- Check browser console for errors

### Consensus Not Calculating

- Verify service role key is set correctly
- Check Supabase logs for errors
- Manually trigger: call `calculateConsensus(wordId)`

### Slow Performance

- Enable Supabase connection pooling
- Add database indexes (already in schema.sql)
- Consider upgrading Supabase plan for more resources

## Support

For issues:
1. Check logs in Vercel Dashboard
2. Check Supabase logs
3. Open an issue on GitHub

## Next Steps

- [ ] Configure email notifications
- [ ] Add analytics (Vercel Analytics, Plausible, etc.)
- [ ] Set up error monitoring (Sentry)
- [ ] Create backup/restore procedures
- [ ] Set up staging environment
- [ ] Configure CI/CD pipeline
- [ ] Add rate limiting
- [ ] Implement caching (Redis)

Congratulations! Your True Motu Dictionary is now live! 🎉
