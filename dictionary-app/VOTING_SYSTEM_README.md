# Voting & Comment System Implementation

## Overview

This implements a complete voting and comment system for the True Motu Dictionary that allows:
- Community validation through upvoting translations
- Context/discussion via comments (replaces individual notes)
- Trust score system that rewards quality contributions
- Democratic consensus while maintaining quality

## Key Features

### ✅ For Translations (Contributions)
- **Either/Or Rule**: Submit your own translation OR upvote existing ones (not both)
- Can't downvote translations (must provide alternative)
- Auto-collapse translations with net votes < -5
- Weighted by speaker type + trust_score

### ✅ For Comments
- **One comment per user per word**
- 20-500 character limit
- No threading/replies (prevents discussion forum)
- **Edit = lose all votes** (prevents bait-and-switch)
- Upvote/downvote others' comments
- Flag as irrelevant (3 flags = auto-hidden)
- Net -5 votes = auto-collapsed

### ✅ Trust Score System
- Upvotes → +0.1 to author's trust_score (weighted by voter quality)
- Downvotes → -0.2 to author's trust_score
- Low trust (< 0.5) → 0.75x vote weight
- Very low (< 0.2) → 0.1x weight, flagged for review

## Files Created

```
supabase/
  migration-voting-system.sql        # Complete database migration

app/contribute/
  comment-actions.ts                 # Server actions for comments & voting

components/
  CommentSection.tsx                 # UI for displaying/managing comments

lib/
  types.ts                           # Updated with Comment, CommentVote, ContributionVote types
```

## Installation Steps

### Step 1: Run Database Migration

1. Open Supabase SQL Editor
2. Copy the entire contents of `supabase/migration-voting-system.sql`
3. Execute it
4. Verify success:
   ```sql
   SELECT 'Comments created:' as status, COUNT(*) as count FROM comments
   UNION ALL
   SELECT 'Comment votes created:', COUNT(*) FROM comment_votes
   UNION ALL
   SELECT 'Contribution votes created:', COUNT(*) FROM contribution_votes;
   ```

### Step 2: Test the Migration

Check that existing notes were migrated:
```sql
SELECT
  c.comment_text,
  w.motu_word,
  p.name as author
FROM comments c
JOIN words w ON c.word_id = w.id
JOIN profiles p ON c.user_id = p.id
LIMIT 10;
```

### Step 3: Update Word Detail Page

Add the CommentSection component to your word detail page:

```tsx
import CommentSection from '@/components/CommentSection'

// In your page component, fetch comments:
const { data: comments } = await supabase
  .from('comments')
  .select(`
    *,
    profile:profiles(name, connection_type, trust_score)
  `)
  .eq('word_id', wordId)
  .order('net_votes', { ascending: false })

// Find user's comment
const userComment = comments?.find(c => c.user_id === currentUserId)

// Render in JSX:
<CommentSection
  wordId={word.id}
  comments={comments || []}
  userComment={userComment}
  currentUserId={currentUser?.id}
/>
```

### Step 4: Add Voting to Contributions

Update your contribution display to include upvote buttons:

```tsx
import { voteOnContribution } from '@/app/contribute/comment-actions'

// Check if user can vote (no own contribution for this word)
const { data: userContribution } = await supabase
  .from('contributions')
  .select('id')
  .eq('word_id', wordId)
  .eq('user_id', currentUserId)
  .single()

const canVote = !userContribution

// In JSX for each contribution:
{canVote && (
  <button onClick={() => voteOnContribution(contribution.id)}>
    ↑ {contribution.upvote_count}
  </button>
)}
```

## Database Schema

### New Tables

**comments**
- `id` UUID PRIMARY KEY
- `word_id` UUID → words(id)
- `user_id` UUID → profiles(id)
- `comment_text` TEXT (20-500 chars)
- `is_flagged` BOOLEAN
- `flag_count` INT
- `upvote_count` INT
- `downvote_count` INT
- `net_votes` INT
- `created_at` TIMESTAMPTZ
- `updated_at` TIMESTAMPTZ
- UNIQUE(word_id, user_id)

**comment_votes**
- `id` UUID PRIMARY KEY
- `comment_id` UUID → comments(id)
- `user_id` UUID → profiles(id)
- `vote_type` INT (-1 or 1)
- `created_at` TIMESTAMPTZ
- UNIQUE(comment_id, user_id)

**contribution_votes**
- `id` UUID PRIMARY KEY
- `contribution_id` UUID → contributions(id)
- `user_id` UUID → profiles(id)
- `created_at` TIMESTAMPTZ
- UNIQUE(contribution_id, user_id)

### Modified Tables

**contributions**
- Added: `upvote_count` INT
- Added: `net_votes` INT
- Deprecated (not removed yet): `notes`, `confidence`

**comments**
- Added: `upvote_count`, `downvote_count`, `net_votes`

## Automatic Features (via Triggers)

✅ Vote counts auto-update when votes added/removed
✅ Trust scores auto-update when content gets voted
✅ Comment votes reset to 0 when comment edited
✅ Comments auto-hidden when flag_count >= 3
✅ Contributions auto-collapsed when net_votes < -5

## Row Level Security

All tables have RLS enabled with policies:
- ✅ Anyone can read comments/votes
- ✅ Users can only insert/update/delete their own content
- ✅ Users cannot vote on their own comments
- ✅ Users cannot vote on contributions if they have their own

## Testing Checklist

After deployment, test:

- [ ] Add a comment (20-500 chars)
- [ ] Edit your comment (votes should reset)
- [ ] Upvote someone else's comment
- [ ] Downvote someone else's comment
- [ ] Flag a comment (3 flags should hide it)
- [ ] Upvote a translation (should work if no own translation)
- [ ] Try to upvote when you have own translation (should fail)
- [ ] Check trust scores update in database
- [ ] Verify low-scored comments auto-collapse
- [ ] Verify edited comments show "(edited)" tag

## Migration Safety

The migration is **non-destructive**:
- ✅ Existing notes migrated to comments
- ✅ Original `notes` and `confidence` columns NOT dropped (deprecated only)
- ✅ Can rollback if needed

To rollback:
```sql
DROP TABLE IF EXISTS comment_votes CASCADE;
DROP TABLE IF EXISTS contribution_votes CASCADE;
DROP TABLE IF EXISTS comments CASCADE;

ALTER TABLE contributions DROP COLUMN IF EXISTS upvote_count;
ALTER TABLE contributions DROP COLUMN IF EXISTS net_votes;
```

## Future Enhancements

Potential additions:
- [ ] Admin moderation dashboard for flagged content
- [ ] Auto-delete comments with net -10 votes
- [ ] User reputation badges (e.g., "Trusted Contributor")
- [ ] Email notifications for votes/flags
- [ ] Comment history/version tracking
- [ ] Export flagged content for review

## Performance

- All queries use indexed columns
- Denormalized vote counts for fast display
- Triggers handle updates asynchronously
- Estimated query time: < 50ms for word page

## Support

If you encounter issues:
1. Check Supabase logs for errors
2. Verify RLS policies are active
3. Check trigger execution in database
4. Review server action error messages

---

**Happy coding! The community will decide what's most useful and correct.** 🎉
