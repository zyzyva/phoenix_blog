# Blog Migration Checklist: contacts4us -> phoenix_blog

This checklist tracks all blog-related items that need to be migrated from contacts4us to phoenix_blog.

## Overview

**Goal**: Extract all blog functionality from contacts4us into the reusable phoenix_blog library. After migration, contacts4us will become a "dumb consumer" that just reads published blog posts from R2 storage.

**Key Principle**: All AI integration, blog editing, keyword research, and content generation should live in phoenix_blog. contacts4us should only display published content.

---

## 1. AI Modules

These modules handle AI content and image generation. They should be the authoritative versions in phoenix_blog.

- [x] **Claude Client** (`lib/contacts4us/ai/claude_client.ex`)
  - Purpose: Claude API integration for blog content generation
  - Status: Done - exists in phoenix_blog at `lib/phoenix_blog/ai/claude_client.ex`
  - Lines: ~249

- [x] **Imagen Client** (`lib/contacts4us/ai/imagen_client.ex`)
  - Purpose: Google Vertex AI Imagen for featured image generation
  - Status: Done - exists in phoenix_blog at `lib/phoenix_blog/ai/imagen_client.ex`
  - Lines: ~223

- [x] **Blog Templates** (`lib/contacts4us/ai/blog_templates.ex`)
  - Purpose: Prompts and templates for AI content generation
  - Status: Done - exists in phoenix_blog at `lib/phoenix_blog/ai/blog_templates.ex`
  - Lines: ~231

---

## 2. Keywords Module

Keyword research and management for SEO-optimized blog content.

- [x] **Keywords Context** (`lib/contacts4us/keywords.ex`)
  - Purpose: Main context for keyword CRUD, filtering, sorting, stats
  - Status: Done - exists in phoenix_blog at `lib/phoenix_blog/keywords.ex`

- [x] **Keyword Schema** (`lib/contacts4us/keywords/keyword.ex`)
  - Purpose: Schema with auto-categorization, audience detection, blog scoring
  - Status: Done - exists in phoenix_blog at `lib/phoenix_blog/keywords/keyword.ex`
  - Lines: ~320

- [x] **CSV Importer** (`lib/contacts4us/keywords/csv_importer.ex`)
  - Purpose: Import keywords from CSV files with categorization
  - Status: Done - exists in phoenix_blog at `lib/phoenix_blog/keywords/csv_importer.ex`
  - Lines: ~257

- [ ] **Import Keywords Task** (`lib/mix/tasks/keywords/import_keywords.ex`)
  - Purpose: Mix task for running keyword imports
  - Status: Needs to be created in phoenix_blog

---

## 3. Content/Features Modules

Feature documentation with screenshots for blog content.

- [x] **Features Context** (`lib/contacts4us/content/features.ex`)
  - Purpose: Manage product features with descriptions
  - Status: Done - exists in phoenix_blog at `lib/phoenix_blog/content/features.ex`
  - Lines: ~174

- [x] **Feature Screenshot Schema** (`lib/contacts4us/content/feature_screenshot.ex`)
  - Purpose: Schema for feature screenshots
  - Status: Done - exists in phoenix_blog at `lib/phoenix_blog/content/feature_screenshot.ex`
  - Lines: ~35

- [x] **Feature Screenshots Context** (`lib/contacts4us/content/feature_screenshots.ex`)
  - Purpose: CRUD for feature screenshots with ordering
  - Status: Done - exists in phoenix_blog at `lib/phoenix_blog/content/feature_screenshots.ex`
  - Lines: ~266

- [x] **Image Processor** (`lib/contacts4us/content/image_processor.ex`)
  - Purpose: ImageMagick integration for image resizing/processing
  - Status: Done - exists in phoenix_blog at `lib/phoenix_blog/content/image_processor.ex`
  - Lines: ~116

---

## 4. Blog Core Modules

Core blog functionality including posts and images.

- [x] **Blog Context** (`lib/contacts4us/blog.ex`)
  - Purpose: Main blog context with CRUD for posts, images
  - Status: Done - exists in phoenix_blog at `lib/phoenix_blog/blog.ex`

- [x] **Blog Post Schema** (`lib/contacts4us/blog/blog_post.ex`)
  - Purpose: Schema for blog posts with markdown support
  - Status: Done - phoenix_blog uses `Post` at `lib/phoenix_blog/blog/post.ex`
  - Lines: ~136

- [x] **Blog Image Schema** (`lib/contacts4us/blog/blog_image.ex`)
  - Purpose: Schema for blog images linked to posts
  - Status: Done - phoenix_blog uses `Image` at `lib/phoenix_blog/blog/image.ex`
  - Lines: ~58

- [x] **Image Uploader** (`lib/contacts4us/blog/image_uploader.ex`)
  - Purpose: Waffle uploader config for R2 storage
  - Status: Done - exists in phoenix_blog at `lib/phoenix_blog/blog/image_uploader.ex`
  - Lines: ~219

---

## 5. Admin LiveViews (MOVE TO PHOENIX_BLOG)

These are the admin interfaces for content management. All should move to phoenix_blog.

- [ ] **AI Blog Generator** (`lib/contacts4us_web/live/admin/ai_blog_live/generator.ex`)
  - Purpose: Complex LiveView for AI-powered blog content generation
  - Status: Only in contacts4us - must move
  - Lines: ~761
  - Features: Keyword selection, tone control, AI generation, preview

- [ ] **Blog Admin Index** (`lib/contacts4us_web/live/admin/blog_live/index.ex`)
  - Purpose: List all blog posts with management actions
  - Status: Only in contacts4us - must move
  - Lines: ~246

- [ ] **Blog Admin Form** (`lib/contacts4us_web/live/admin/blog_live/form.ex`)
  - Purpose: Create/edit blog posts with rich form
  - Status: Only in contacts4us - must move
  - Lines: ~612

- [ ] **Blog Admin Preview** (`lib/contacts4us_web/live/admin/blog_live/preview.ex`)
  - Purpose: Preview blog posts before publishing
  - Status: Only in contacts4us - must move
  - Lines: ~82

- [ ] **Keywords Admin** (`lib/contacts4us_web/live/admin/keywords_live/index.ex`)
  - Purpose: Keyword research and management interface
  - Status: Only in contacts4us - must move
  - Lines: ~685
  - Features: Sorting, filtering, stats, categorization

- [ ] **Feature Screenshots Admin** (`lib/contacts4us_web/live/admin/feature_screenshots_live/index.ex`)
  - Purpose: Feature screenshot management interface
  - Status: Only in contacts4us - must move
  - Lines: ~505

---

## 6. Public Blog LiveViews (DECISION NEEDED)

These display published blog content. Decision: Keep in contacts4us (reads from R2) or move to phoenix_blog?

- [ ] **Blog Index** (`lib/contacts4us_web/live/blog_live/index.ex`)
  - Purpose: Public listing of blog posts
  - Status: Only in contacts4us
  - Lines: ~115
  - Decision: [ ] Keep in contacts4us [ ] Move to phoenix_blog

- [ ] **Blog Show** (`lib/contacts4us_web/live/blog_live/show.ex`)
  - Purpose: Public view of individual blog post
  - Status: Only in contacts4us
  - Lines: ~146
  - Decision: [ ] Keep in contacts4us [ ] Move to phoenix_blog

---

## 7. Controllers

- [ ] **Blog Sitemap Controller** (`lib/contacts4us_web/controllers/blog_sitemap_controller.ex`)
  - Purpose: Generates XML sitemap for blog posts
  - Status: Only in contacts4us
  - Decision: Keep in contacts4us (needs published posts list) or move?

---

## 8. Tests (MOVE TO PHOENIX_BLOG)

All blog-related tests should move to phoenix_blog.

- [ ] **Blog Templates Test** (`test/contacts4us/ai/blog_templates_test.exs`)
  - Purpose: Tests for blog template generation

- [ ] **Claude Client Test** (`test/contacts4us/ai/claude_client_test.exs`)
  - Purpose: Tests for Claude API integration

- [ ] **Keywords Admin LiveView Test** (`test/contacts4us_web/live/admin/keywords_live_test.exs`)
  - Purpose: Tests for keywords admin interface

- [ ] **AI Blog Generator LiveView Test** (`test/contacts4us_web/live/admin/ai_blog_generator_live_test.exs`)
  - Purpose: Tests for AI generator interface

---

## 9. Migrations (RECONCILIATION NEEDED)

Different timestamps and table names between projects need reconciliation.

**contacts4us migrations:**
- [ ] `20251125192505_create_blog_posts.exs`
- [ ] `20251125192549_create_blog_images.exs`
- [ ] `20251129004427_create_keywords.exs`
- [ ] `20251129152817_add_audience_and_blog_score_to_keywords.exs`
- [ ] `20251129232720_create_feature_screenshots.exs`

**phoenix_blog migrations (already created):**
- `20251129200001_create_blog_authors.exs` (NEW - only in phoenix_blog)
- `20251129200002_create_blog_posts.exs`
- `20251129200003_create_blog_images.exs`
- `20251129200004_create_blog_keywords.exs`
- `20251129200005_create_blog_feature_screenshots.exs`

**Decision needed:** Use `blog_` prefix for all tables (phoenix_blog style) or original names?

---

## 10. Configuration (MOVE TO PHOENIX_BLOG)

Runtime and application configuration for AI services.

- [ ] **runtime.exs - Google Cloud Config**
  - `GOOGLE_CLOUD_PROJECT` (line ~47)
  - `GOOGLE_CLOUD_LOCATION` (line ~48)
  - `IMAGEN_MODEL` (line ~49)

- [ ] **runtime.exs - R2 Storage Config**
  - Blog images bucket configuration (lines ~158-177)
  - Note: phoenix_blog has `.r2.json` for provisioner

- [ ] **application.ex - Goth Startup**
  - Goth configuration for Google Cloud auth (lines ~59-70)

---

## 11. Router Configuration

Routes that need to exist in phoenix_blog.

**Admin routes (move to phoenix_blog):**
- [ ] `/admin/blog` - Blog index
- [ ] `/admin/blog/new` - New blog post
- [ ] `/admin/blog/:id/edit` - Edit blog post
- [ ] `/admin/blog/:id/preview` - Preview blog post
- [ ] `/admin/blog/ai-generator` - AI content generator
- [ ] `/admin/feature-screenshots` - Feature screenshots management
- [ ] `/admin/keywords` - Keyword research

**Public routes (keep in contacts4us or create simple versions):**
- [ ] `/blog` - Public blog index
- [ ] `/blog/:slug` - Public blog post view
- [ ] `/blog/sitemap.xml` - Blog sitemap

---

## 12. Data Files

- [ ] **features.json** (`priv/content/features.json`)
  - Purpose: Seed data for product features
  - Status: Exists in both - ensure they're in sync

---

## 13. Dependencies

Ensure phoenix_blog has all required dependencies:

- [x] `mdex` - Markdown rendering
- [x] `req` - HTTP client for AI APIs
- [x] `ex_aws` and `ex_aws_s3` - R2 storage (used directly, no Waffle needed)
- [x] `goth` - Google Cloud authentication

---

## Post-Migration Tasks

After moving all items:

- [ ] Remove blog-related modules from contacts4us
- [ ] Update contacts4us to consume blog posts from R2 (read-only)
- [ ] Remove AI dependencies from contacts4us
- [ ] Remove Google Cloud config from contacts4us
- [ ] Update contacts4us tests to remove blog-related tests
- [ ] Run full test suite in both projects
- [ ] Verify contacts4us still compiles without blog modules

---

## Notes

- **Schema naming decision needed**: contacts4us uses `BlogPost`/`BlogImage`, phoenix_blog uses `Post`/`Image`
- **phoenix_blog adds Author schema**: contacts4us doesn't have author support
- **All admin interfaces move to phoenix_blog**: contacts4us becomes read-only consumer
- **API keys stay in phoenix_blog**: No AI keys in contacts4us production

---

## 14. Research Pipeline (NEW)

New modules added for competitor research and content generation pipeline.

### AI Clients

- [x] **GeminiClient** (`lib/phoenix_blog/ai/gemini_client.ex`)
  - Purpose: Google Gemini API for image generation
- [x] **HuggingFaceClient** (`lib/phoenix_blog/ai/huggingface_client.ex`)
  - Purpose: Unified router to Fal AI, Replicate, Together, etc.
- [x] **ReplicateClient** (`lib/phoenix_blog/ai/replicate_client.ex`)
  - Purpose: Direct Replicate API access
- [x] **ImageGenerator** (`lib/phoenix_blog/ai/image_generator.ex`)
  - Purpose: Unified image generation interface
- [x] **VideoGenerator** (`lib/phoenix_blog/ai/video_generator.ex`)
  - Purpose: Unified video generation interface

### Research Clients

- [x] **ApifyClient** (`lib/phoenix_blog/research/apify_client.ex`)
  - Purpose: Social media scraping (Facebook, Instagram, TikTok)
- [x] **AdLibraryClient** (`lib/phoenix_blog/research/ad_library_client.ex`)
  - Purpose: Meta Ad Library API for competitor ads
- [x] **GraphClient** (`lib/phoenix_blog/research/graph_client.ex`)
  - Purpose: Facebook Graph API for page posts/comments

### Research Pipeline Schemas

- [x] **Competitor** (`lib/phoenix_blog/competitors/competitor.ex`)
  - Purpose: Track competitor profiles
- [x] **ResearchJob** (`lib/phoenix_blog/research/research_job.ex`)
  - Purpose: Async scraping job tracking
- [x] **ResearchData** (`lib/phoenix_blog/research/research_data.ex`)
  - Purpose: Scraped content with sentiment
- [x] **Insight** (`lib/phoenix_blog/insights/insight.ex`)
  - Purpose: AI-generated insights
- [x] **ContentGeneration** (`lib/phoenix_blog/generations/content_generation.ex`)
  - Purpose: Content generation queue
- [x] **Webhook** (`lib/phoenix_blog/delivery/webhook.ex`)
  - Purpose: Webhook configurations
- [x] **CostEntry** (`lib/phoenix_blog/costs/cost_entry.ex`)
  - Purpose: Usage cost tracking

### Contexts

- [x] **Competitors** (`lib/phoenix_blog/competitors.ex`)
  - Purpose: Competitor CRUD
- [x] **Costs** (`lib/phoenix_blog/costs.ex`)
  - Purpose: Cost recording and aggregation
- [x] **Insights** (`lib/phoenix_blog/insights.ex`)
  - Purpose: Insight CRUD with activation, archiving, usage tracking, search
- [x] **Generations** (`lib/phoenix_blog/generations.ex`)
  - Purpose: Generation queue management, status tracking, delivery, cost aggregation
- [x] **Delivery** (`lib/phoenix_blog/delivery.ex`)
  - Purpose: Webhook management with HMAC signing, failure tracking

### Database Migrations

- [x] `create_competitors` - Competitor profiles
- [x] `create_research_jobs` - Async job tracking
- [x] `create_research_data` - Scraped content
- [x] `create_insights` - AI insights
- [x] `create_content_generations` - Generation queue
- [x] `create_webhooks` - Webhook configs
- [x] `create_cost_tracking` - Usage costs
- [x] `add_user_id_to_research_tactics` - Multi-tenant support

### Oban Workers

**Research Pipeline Workers (Todo):**
- [ ] `CompetitorScrapeWorker` - Run Apify actors
- [ ] `AdLibraryWorker` - Search Meta Ad Library
- [ ] `InsightGenerationWorker` - Generate insights from data
- [ ] `ImageGenerationWorker` - AI images
- [ ] `VideoGenerationWorker` - AI videos
- [ ] `EmailDeliveryWorker` - Send via Swoosh
- [ ] `WebhookDeliveryWorker` - POST with HMAC

---

## 15. Social Media Module (NEW)

Social media scheduling and publishing functionality.

### Schemas

- [x] **Account** (`lib/phoenix_blog/social/account.ex`)
  - Purpose: Connected social media accounts with OAuth tokens
- [x] **Post** (`lib/phoenix_blog/social/post.ex`)
  - Purpose: Social media posts (scheduled/published)
- [x] **PostPlatform** (`lib/phoenix_blog/social/post_platform.ex`)
  - Purpose: Join table for posts to platform accounts
- [x] **AnalyticsRecord** (`lib/phoenix_blog/social/analytics_record.ex`)
  - Purpose: Platform analytics data

### Context

- [x] **Social** (`lib/phoenix_blog/social.ex`)
  - Purpose: Account/Post CRUD, scheduling, analytics

### Oban Workers

- [x] **PublishPostWorker** (`lib/phoenix_blog/social/workers/publish_post_worker.ex`)
  - Purpose: Publish posts to platforms
- [x] **ScheduledPublisherWorker** (`lib/phoenix_blog/social/workers/scheduled_publisher_worker.ex`)
  - Purpose: Process scheduled posts
- [x] **FetchAnalyticsWorker** (`lib/phoenix_blog/social/workers/fetch_analytics_worker.ex`)
  - Purpose: Fetch post analytics from platforms
- [x] **BatchAnalyticsWorker** (`lib/phoenix_blog/social/workers/batch_analytics_worker.ex`)
  - Purpose: Batch analytics fetching
- [x] **TokenRefreshWorker** (`lib/phoenix_blog/social/workers/token_refresh_worker.ex`)
  - Purpose: Refresh expiring OAuth tokens

### Utilities

- [x] **OAuth** (`lib/phoenix_blog/social/oauth.ex`)
  - Purpose: OAuth flow helpers
- [x] **ContentGenerator** (`lib/phoenix_blog/social/content_generator.ex`)
  - Purpose: AI content generation for social posts
- [x] **TwitterClient** (`lib/phoenix_blog/social/clients/twitter_client.ex`)
  - Purpose: Twitter/X API integration
