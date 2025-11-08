# $wap

<img width="1411" height="625" alt="Screenshot 2025-11-08 at 1 12 02 AM" src="https://github.com/user-attachments/assets/78ca44bf-da91-40f6-87ad-34f9039469d5" />
<img width="1411" height="394" alt="Screenshot 2025-11-08 at 1 14 13 AM" src="https://github.com/user-attachments/assets/759a45b7-3e87-41f8-85ac-462b0f4aa8fa" />
<img width="1512" height="855" alt="Screenshot 2025-11-08 at 1 02 41 AM" src="https://github.com/user-attachments/assets/80a62cd2-2c5b-40ee-9871-e04365dee102" />
<img width="1195" height="761" alt="Screenshot 2025-11-08 at 1 05 32 AM" src="https://github.com/user-attachments/assets/251be873-25f8-4cdc-9bc7-f48cbf093c52" />
<img width="1507" height="863" alt="Screenshot 2025-11-08 at 1 06 08 AM" src="https://github.com/user-attachments/assets/47d7ac78-e97e-47f1-b782-7f0a9d0dce6b" />
<img width="1507" height="863" alt="Screenshot 2025-11-08 at 1 06 40 AM" src="https://github.com/user-attachments/assets/ddd18e3c-41d1-4bbe-b69e-5660e0367ccb" />
<img width="1507" height="863" alt="Screenshot 2025-11-08 at 1 06 47 AM" src="https://github.com/user-attachments/assets/fe64da47-431d-4636-94c0-6d2795b4b39f" />

## Challenge Statement(s) Addressed 🎯
We built Swap to help people share and monetize short, teachable skills in a trusted community marketplace. Primary challenge statements we targeted:

- How might we provide an accessible, discoverable marketplace for people to teach and trade short skills locally and remotely?
- How might we enable creators to package micro-services (skills) with clear deliverables and pricing so buyers can quickly find the right tutor or contributor?
- How might we reduce friction for onboarding, discovery, and secure transactions for peer-to-peer skill exchange?

## Project Description 🤯
$wap is a dark-themed, responsive web app where users can post short teachable skills, browse offerings, and request services from creators. The app includes an onboarding flow, a dashboard, a discover grid, and a post-skill form that captures title, description, logistics, tags, and deliverables.

How it works (high level):

- Creators sign up, describe a skill, and list deliverables, estimated hours, availability, and tags.
- Seekers browse the discover page or search, preview a listing, then request or book the service.
- The platform facilitates messaging/requests and (optionally) payment flow (placeholder for payment provider).

## Project Value 💰
Target users:

- Primary: independent creators, freelancers, and hobbyists who want to teach or sell short services.
- Secondary: people seeking fast, affordable, targeted instruction or delivery of small tasks.

Benefits:

- For Creators: quick listing flow, discoverability via tags, and built-in deliverable templates to reduce friction posting services.
- For Buyers: concise previews, clear deliverables, and simple request workflow to reduce time-to-purchase.
- For Communities: enables micro-entrepreneurship and skill-sharing in local and remote contexts.

## 💻 Tech Overview & Tech Stack

Website / Frontend: Flutter (web) — responsive UI, single codebase targeting web/desktop/mobile.

#### Frontend

- Built with Flutter & Dart

![Dart](https://img.shields.io/badge/dart-%23039BE5.svg?style=for-the-badge&logo=dart) ![Flutter](https://img.shields.io/badge/flutter-%23039BE5.svg?style=for-the-badge&logo=flutter)

#### Backend

- Placeholder: [Cloud Functions / Firebase / Other] — backend handles auth, listing persistence, requests, and optional payments.

![Firebase](https://img.shields.io/badge/firebase-%23039BE5.svg?style=for-the-badge&logo=firebase)

#### Authentication & Database

- Firebase Authentication and Firestore (placeholder — update if using different services).

#### CI / Hosting

- Frontend hosting: placeholder (e.g., Netlify / Firebase Hosting / Vercel)
- Backend hosting: placeholder (e.g., Firebase Cloud Functions / Heroku / Google Cloud)

## APIs USED

### Internal APIs

1) Listings API

* GET /listings — fetch discover listings
* POST /listings — create a listing
* GET /listings/:id — fetch listing details

2) Requests API

* POST /requests — send a request to a creator
* GET /requests/:userId — fetch requests for a user

### External APIs

* (Optional) Chat / AI services: placeholder (e.g., OpenAI Chat for recommendation or messaging enhancements)
* (Optional) Payment provider: placeholder (Stripe / PayPal / other)

## User Stories

- As a Creator, I want to post a skill with a clear title, description, tags, and deliverables so buyers can understand what I'll provide.
- As a Buyer, I want to search or browse listings and preview deliverables so I can quickly find a suitable service.
- As a User, I want to receive requests and manage them from a dashboard to track ongoing and completed work.

## Walkthrough: Using Swap

Basic flow (quick):

1. Sign up / Sign in (placeholder test credentials below if you want to demo quickly).
2. Creators: Click "Post Skill", fill the Basic Information and Details & Logistics sections, then Publish.
3. Buyers: Browse the Discover page or use tags to find skills, preview a skill, and send a Request.

### Test/demo credentials (placeholder)
- Creator: email: creator@example.com, password: password123
- Buyer: email: buyer@example.com, password: password123

### Link to Video Pitch
- placeholder: https://your-video-link

### Link to Demo Presentation
- placeholder: https://your-presentation-link

### Team Checklist ✅
- [x] Team photo
- [x] Team Slack channel
- [x] Communication established with mentor
- [x] Repo created from template
- [ ] Flight Deck / Hangar registration (placeholder)

### Project Checklist
- [ ] Presentation complete and linked (placeholder)
- [ ] Video pitch recorded and linked (placeholder)
- [x] Code merged to main branch

### School Name
Philander Smith University

### Team Name
Panthers

### ✨ Contributors ✨
* Immanuella Emem Umoren
* Kenna Agbugba
* Otito Udedibor
* Olaoluwa James-Owolabi
* Emmanuella Turkson
