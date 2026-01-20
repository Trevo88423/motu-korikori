# Cloudflare Worker for Audio Uploads

This worker handles audio file uploads to Cloudflare R2 for the True Motu Dictionary app.

## Setup

### 1. Install Wrangler CLI

```bash
npm install -g wrangler
```

### 2. Authenticate with Cloudflare

```bash
wrangler login
```

### 3. Create R2 Bucket

```bash
wrangler r2 bucket create motu-dictionary-audio
```

### 4. Set Environment Variables

Set secrets (these won't be visible in code):

```bash
wrangler secret put SUPABASE_URL
# Enter your Supabase project URL

wrangler secret put SUPABASE_ANON_KEY
# Enter your Supabase anon key

wrangler secret put SUPABASE_JWT_SECRET
# Enter your Supabase JWT secret (from Settings > API > JWT Secret)
```

### 5. Update wrangler.toml

Edit `wrangler.toml` and update:
- `bucket_name`: Your R2 bucket name
- `R2_PUBLIC_URL`: Your R2 public URL (see below)
- `ALLOWED_ORIGIN`: Your Next.js app URL

### 6. Configure R2 Public Access

Option A: Use R2.dev subdomain (easiest)
- Go to Cloudflare Dashboard > R2
- Click on your bucket
- Settings > Public Access > Allow Access
- Copy the R2.dev URL

Option B: Custom domain (recommended for production)
- Go to Cloudflare Dashboard > R2
- Click on your bucket
- Settings > Custom Domains
- Add your domain (e.g., audio.yourdomain.com)
- Update DNS as instructed
- Use this domain as R2_PUBLIC_URL

### 7. Deploy Worker

```bash
wrangler deploy
```

This will give you a worker URL like:
`https://motu-dictionary-audio-upload.YOUR_SUBDOMAIN.workers.dev`

Copy this URL and add it to your Next.js `.env.local` as:
```
NEXT_PUBLIC_CLOUDFLARE_WORKER_URL=https://motu-dictionary-audio-upload.YOUR_SUBDOMAIN.workers.dev
```

## Development

Run locally:

```bash
wrangler dev
```

This starts the worker on `http://localhost:8787`

Update your Next.js `.env.local` for local development:
```
NEXT_PUBLIC_CLOUDFLARE_WORKER_URL=http://localhost:8787
```

## Testing

Test upload with curl:

```bash
curl -X POST https://your-worker.workers.dev \
  -H "Authorization: Bearer YOUR_SUPABASE_JWT" \
  -F "audio=@test.webm" \
  -F "wordId=123" \
  -F "userId=456"
```

## Monitoring

View logs:

```bash
wrangler tail
```

## Cost Estimate

R2 Pricing (as of 2024):
- Storage: $0.015/GB/month
- Class A operations (write): $4.50 per million
- Class B operations (read): $0.36 per million

Example for 10,000 audio files (~500MB total):
- Storage: $0.0075/month
- Uploads: ~$0.045 one-time
- Downloads: ~$0.0036 per million plays

Extremely affordable!
