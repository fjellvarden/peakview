# Publishing Peakview to the Mac App Store

A step-by-step guide for first-time App Store publishers.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Step-by-Step Publishing Process](#step-by-step-publishing-process)
- [Minimum Requirements](#minimum-requirements)
- [Recommended Preparations](#recommended-preparations)
- [Potential Limitations & Gotchas](#potential-limitations--gotchas)
- [Pricing Strategy](#pricing-strategy)
- [Quick Promotion Tips](#quick-promotion-tips)
- [Checklist](#checklist)

---

## Prerequisites

### 1. Apple Developer Account ($99/year)
- [ ] Enroll at [developer.apple.com](https://developer.apple.com/programs/enroll/)
- [ ] Use your personal Apple ID or create a new one
- [ ] Payment is required before you can submit apps
- [ ] Enrollment takes 24-48 hours to process

### 2. Required Hardware/Software
- [ ] Mac running latest macOS
- [ ] Xcode (latest stable version)
- [ ] Valid Apple ID with two-factor authentication enabled

### 3. Required Legal Documents
- [ ] Privacy Policy URL (required for all apps)
- [ ] Terms of Service URL (recommended)

---

## Step-by-Step Publishing Process

### Step 1: Prepare Your App for Distribution

**Configure Xcode Project:**
```
1. Open Peakview.xcodeproj
2. Select the project in the navigator
3. Under "Signing & Capabilities":
   - Team: Select your Apple Developer team
   - Signing Certificate: "Apple Distribution"
   - Provisioning Profile: Let Xcode manage automatically
4. Set Bundle Identifier: com.yourname.peakview (must be unique)
5. Set Version: 1.0.0
6. Set Build: 1
```

**App Sandbox (Already enabled):**
- Peakview uses security-scoped bookmarks which is App Store compliant
- Verify sandbox entitlements are correctly configured

### Step 2: Create App Store Connect Record

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click "My Apps" → "+" → "New App"
3. Fill in:
   - **Platform:** macOS
   - **Name:** Peakview (check availability)
   - **Primary Language:** English (US)
   - **Bundle ID:** Select from dropdown (must match Xcode)
   - **SKU:** PEAKVIEW001 (internal reference)

### Step 3: Prepare App Store Metadata

**Required Information:**
- [ ] App Name (30 characters max)
- [ ] Subtitle (30 characters max) - e.g., "Quick Project Launcher"
- [ ] Description (4000 characters max)
- [ ] Keywords (100 characters total, comma-separated)
- [ ] Support URL
- [ ] Privacy Policy URL
- [ ] Category: Developer Tools
- [ ] Secondary Category: Productivity (optional)

**Screenshots Required:**
- At least one screenshot for each supported screen size
- macOS requires: 1280x800 or 1440x900 or 2560x1600 or 2880x1800
- Recommended: 2-5 screenshots showing key features
- Can add text overlays to explain features

**App Icon:**
- 1024x1024 PNG for App Store listing
- Must not be a photo or contain transparency

### Step 4: Upload Build

**From Xcode:**
```
1. Product → Archive
2. Wait for archive to complete
3. In Organizer window, click "Distribute App"
4. Select "App Store Connect"
5. Select "Upload"
6. Follow prompts, let Xcode manage signing
7. Upload completes in 5-15 minutes
```

**Alternative: Using Transporter app**
- Download Transporter from Mac App Store
- Export .pkg from Xcode Archive
- Upload via Transporter

### Step 5: Submit for Review

1. In App Store Connect, go to your app
2. Select the uploaded build
3. Complete all required metadata fields
4. Answer export compliance questions (usually "No" for encryption)
5. Answer content rights questions
6. Set pricing (see Pricing section below)
7. Click "Submit for Review"

### Step 6: Wait for Review

- First review typically takes 24-48 hours
- Can take up to 7 days during busy periods
- You'll receive email notifications about status changes
- If rejected, you'll get specific feedback to address

---

## Minimum Requirements

### Technical Requirements
| Requirement | Status | Notes |
|------------|--------|-------|
| macOS 14+ support | ✅ | Already set in project |
| App Sandbox | ✅ | Already enabled |
| Hardened Runtime | Required | Enable in Xcode |
| Code Signing | Required | Automatic with Xcode |
| Privacy descriptions | Required | Info.plist usage descriptions |

### Info.plist Privacy Keys Needed
```xml
<!-- Already have these, verify they exist: -->
<key>NSDesktopFolderUsageDescription</key>
<string>Peakview needs access to scan your project folders.</string>
```

### Legal Requirements
- Privacy Policy (required)
- GDPR compliance if serving EU users
- No analytics/tracking without disclosure

---

## Recommended Preparations

### Before Submission

1. **Create a Simple Website**
   - One-page site is fine
   - Host privacy policy there
   - Use GitHub Pages (free) or Carrd ($19/year)

2. **Privacy Policy Generator**
   - Use [PrivacyPolicies.com](https://www.privacypolicies.com/) (free)
   - Or [Termly](https://termly.io/) (free tier available)
   - Key points: No data collection, local-only storage

3. **Prepare Support Channel**
   - Dedicated email: peakview@yourdomain.com
   - Or use GitHub Issues as support channel

4. **Create Demo Video**
   - 15-30 second screen recording
   - Show: Open menu bar → filter → click to open in editor
   - Can use for App Preview (optional but helpful)

5. **Test Thoroughly**
   - Test on clean macOS installation
   - Verify sandbox permissions work correctly
   - Test with various cloud storage states

### Marketing Assets
- [ ] App icon in multiple sizes
- [ ] 5 screenshots with feature callouts
- [ ] Short description (1-2 sentences)
- [ ] Feature list for description

---

## Potential Limitations & Gotchas

### Common Rejection Reasons for This Type of App

1. **Sandbox Violations**
   - ⚠️ Security-scoped bookmarks must be used correctly
   - App cannot access folders without user permission
   - Test the permission flow thoroughly

2. **Minimum Functionality**
   - Apple may reject if app seems "too simple"
   - Mitigation: Highlight unique features (cloud status, git integration)

3. **Guideline 4.2 - Minimum Functionality**
   - "Your app should include features, content, and UI that elevate it beyond a repackaged website"
   - Peakview should pass this as it provides native functionality

4. **Pricing Issues**
   - If priced too high relative to functionality, may face scrutiny
   - $10-20 is reasonable for developer tools

### Technical Limitations

1. **Sandboxed File Access**
   - Users must explicitly grant folder access
   - Cannot auto-scan common locations without permission
   - Current implementation handles this correctly

2. **Auto-Launch Limitations**
   - Login items require special entitlement
   - May need SMLoginItemSetEnabled for auto-start

3. **Updates**
   - Every update goes through review (usually faster)
   - Cannot push urgent fixes instantly

### What You CANNOT Do on App Store
- Use private/undocumented APIs
- Download/execute code at runtime
- Access system folders without permission
- Include trial/license checking (use App Store's built-in)

---

## Pricing Strategy

### Recommended: $14.99 (One-Time Purchase)

**Why This Price:**
- Sweet spot for developer tools
- Not too cheap (signals quality)
- Not too expensive (impulse buy territory)
- Apple takes 30% (you get ~$10.50)
- After first year at 15% (Small Business Program), you get ~$12.75

### Alternative Options

| Strategy | Price | Pros | Cons |
|----------|-------|------|------|
| One-time | $14.99 | Simple, users prefer | No recurring revenue |
| Subscription | $2.99/mo | Recurring revenue | Users hate subscriptions for simple tools |
| Free + IAP | Free/$9.99 | More downloads | Complex to implement |
| Free | $0 | Maximum reach | No revenue |

### Apple Small Business Program
- If earning < $1M/year, Apple only takes 15% cut
- Enroll at App Store Connect → Agreements, Tax, Banking
- Automatically applied once enrolled

---

## Quick Promotion Tips

### Low-Effort, High-Impact (Do These First)

1. **Product Hunt Launch**
   - Free to post
   - Schedule for Tuesday-Thursday, 12:01 AM PST
   - Prepare: tagline, description, 3-5 images, maker comment
   - Can generate 100+ visits in one day
   - [producthunt.com](https://www.producthunt.com)

2. **Hacker News "Show HN"**
   - Post title: "Show HN: Peakview – Menu bar app to quickly open projects in your editor"
   - Best time: weekday mornings (US time)
   - Be ready to answer questions
   - Can go viral if it resonates

3. **Reddit Posts**
   - r/macapps (45k+ members)
   - r/macOS
   - r/programming (if you share interesting technical details)
   - r/SideProject
   - Follow each subreddit's self-promotion rules

4. **Twitter/X Developer Community**
   - Post with hashtags: #macOS #DevTools #IndieDev
   - Share a GIF showing the app in action
   - Tag relevant accounts (@viaboringcode, @IndieDevLife, etc.)

### Medium-Effort Tactics

5. **Dev.to / Hashnode Article**
   - Write: "I built a menu bar app to solve my project-switching problem"
   - Include story, screenshots, technical details
   - Link to App Store

6. **GitHub Repository**
   - Consider open-sourcing (builds trust, community)
   - Or create a landing page repo with detailed README
   - Add "Available on Mac App Store" badge

7. **Email Signature**
   - Add: "Check out Peakview - [link]"
   - Zero ongoing effort

### Things to Prepare

- [ ] 15-second GIF demo
- [ ] One-liner description
- [ ] 3-5 bullet points of key features
- [ ] App Store link (after approval)
- [ ] Maker story (why you built it)

### Timing Strategy

1. **Week 1:** Submit to App Store, prepare marketing materials
2. **Week 2:** App approved → Product Hunt launch
3. **Week 3:** Reddit posts (space them out)
4. **Week 4:** Hacker News Show HN
5. **Ongoing:** Tweet updates, respond to feedback

---

## Checklist

### Pre-Submission
- [ ] Apple Developer Program enrolled ($99 paid)
- [ ] Bundle ID registered in Apple Developer portal
- [ ] App icon 1024x1024 ready
- [ ] Screenshots captured (at least 3)
- [ ] Privacy policy URL live
- [ ] Support URL/email ready
- [ ] Test app on clean Mac installation
- [ ] Version set to 1.0.0

### Xcode Configuration
- [ ] Team selected for signing
- [ ] Hardened Runtime enabled
- [ ] App Sandbox enabled (already done)
- [ ] Info.plist has all required privacy descriptions
- [ ] Archive builds successfully

### App Store Connect
- [ ] App record created
- [ ] All metadata fields completed
- [ ] Screenshots uploaded
- [ ] Pricing set
- [ ] Build uploaded and processed
- [ ] Export compliance answered
- [ ] Content rights answered

### Post-Approval
- [ ] Verify app appears in App Store search
- [ ] Test purchase/download flow
- [ ] Announce on social media
- [ ] Submit to Product Hunt

---

## Useful Links

- [Apple Developer Program](https://developer.apple.com/programs/)
- [App Store Connect](https://appstoreconnect.apple.com)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Human Interface Guidelines - macOS](https://developer.apple.com/design/human-interface-guidelines/macos)
- [Small Business Program](https://developer.apple.com/app-store/small-business-program/)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)

---

## Quick Reference: Timeline

| Phase | Duration | Tasks |
|-------|----------|-------|
| Setup | 1-3 days | Developer account, legal docs |
| Prepare | 2-4 days | Screenshots, metadata, testing |
| Submit | 1 day | Upload, fill forms, submit |
| Review | 1-7 days | Wait (usually 24-48h) |
| Launch | 1 day | Announce, promote |

**Realistic Total: 1-2 weeks from start to App Store listing**

---

*Last updated: January 2026*
