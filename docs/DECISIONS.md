# Decisions

Decisions on record, and rejections, each with why and what would reopen it.
Newest first.

## 2026-10-24: New contributors aren't visible to the public until established (Trevor)

**Decided:** entries (translations, and later proposed words) by a contributor still at
the **New** level of the trust ladder (#51, #53) are **hidden from signed-out visitors**.
Signed-in members still see them, marked "new contributor", so the community can confirm
or flag them. They become publicly visible once the contributor is **established**: they
have reached the Member level, meaning enough of their entries were verified by
consensus, or their trust has reached the threshold in the settings table, with no upheld
flags.

**Why:** a fresh account's first entries are the most likely to be junk or abuse, and the
public, Google included, shouldn't see them before the community has. This serves
principle 6 (the community filters first) and costs genuine newcomers nothing, since
members still see and count their work.

**Implemented in:** #53 (defines "established"). Visitor-facing reads apply the rule
alongside #30 (showing contributions to visitors at all).

**Reopen if:** genuine new speakers' work sits unseen too long because confirmations are
slow. Then lower the threshold, don't remove the rule.

## 2026-10-24: Adding words and keeping it clean (approved by Trevor)

**Context:** Trevor wants members to be able to add words the Bible-derived list (15,610
words) is missing. His one real concern is abuse (bad language, deliberately wrong
translations), and he doesn't want to audit content himself.

**Decided:**
- **Any signed-in member can propose a word**, but new accounts start on probation (limits
  below). This casts the widest net for the living language (principle 3).
- **A proposed word goes live when speakers confirm it**: two trusted native or heritage
  speakers, or an admin. Until then it's visible only as "Proposed" (principle 1).
- **Proposing needs the word, an English meaning, and an example sentence in Motu.** Audio,
  region and notes are optional. The example is the best evidence a word is real Motu
  (principle 2).
- **Abuse is handled by an automatic community-moderation layer**, not by Trevor reviewing
  content (principle 6). See #51 for the design.

**Rejected:**
- *Admin approves every new word:* it makes Trevor the bottleneck and the auditor
  (crosses principle 6). Reopen if the community is too small to confirm words.
- *Words go live immediately:* the fastest way for Hiri Motu, English or junk to enter as
  Motu (crosses principle 2).
- *Restricting anyone who disagrees with the majority:* disagreement is often a real
  regional or generational variant (crosses principle 3). Restriction is triggered by
  flags, bad language and sustained low agreement across many words, never by a single
  disagreement.
