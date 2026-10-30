# Pour Log for iPhone

A SwiftUI app for logging drinks: take a photo, record where you had it, rate it, and see where you rank on a shared leaderboard.

- **GPS:** asks for "While Using" location, suggests bars and restaurants within about 150 m, and fills in the city.
- **Photo location:** if you pick an older photo from your library, the app uses the GPS stored in that photo, so you get the bar where you took it.
- **Shared leaderboard:** uses the CloudKit public database. There's no server, and you can only delete your own entries.
- Requires iOS 17 or later.

## How it gets built: GitHub → Codemagic → TestFlight → your iPhone
You don't need a Mac. Every push to `main` makes Codemagic:
1. Generate `PourLog.xcodeproj` from `project.yml` with XcodeGen.
2. Sign the app with your Apple Developer account.
3. Build it and upload it to TestFlight.

Then you install it from the TestFlight app on your phone. Your friends can get it the same way.

Bundle ID: `com.rickjanik.PourLog` · iCloud container: `iCloud.com.rickjanik.PourLog`

## One-time setup

### A. Apple Developer portal (developer.apple.com → Certificates, IDs & Profiles)
1. Go to **Identifiers → + → iCloud Containers** and create `iCloud.com.rickjanik.PourLog`.
2. Go to **Identifiers → + → App IDs → App**:
   - Bundle ID (explicit): `com.rickjanik.PourLog`
   - Tick **iCloud** and choose "Include CloudKit support". Then click Edit/Configure and assign the container from step 1.
3. Do step 2 **before** Codemagic creates a provisioning profile. A profile made without iCloud will fail to sign the build.

### B. App Store Connect (appstoreconnect.apple.com)
1. Go to **Apps → + → New App**: iOS, name "Pour Log" (pick another name if that's taken), bundle ID `com.rickjanik.PourLog`, and any SKU.
2. Copy the **Apple ID** number from App Information into `APP_STORE_APPLE_ID` in `codemagic.yaml`.
3. Go to **Users and Access → Integrations → App Store Connect API → +**. Create a key with **App Manager** access, download the `.p8` file (you can only download it once), and note the Issuer ID and Key ID.

### C. Codemagic (codemagic.io)
1. Sign in with GitHub and add the `pour-log` repository.
2. Go to **Team settings → Team integrations → Developer Portal → Connect** and add the API key from B3. Name it exactly `PourLog ASC Key`, because `codemagic.yaml` refers to it by that name.
3. Go to **Team settings → codemagic.yaml settings → Code signing identities**:
   - iOS certificates: **Generate certificate** (Apple Distribution).
   - iOS provisioning profiles: **Fetch profiles** and choose the App Store profile for `com.rickjanik.PourLog`. If none exists, create one in the Apple portal under Profiles → + → App Store Connect first.
4. Start the **Pour Log to TestFlight** workflow, or push to `main`. The first build takes about 10 minutes.
5. In App Store Connect → TestFlight, add yourself as an internal tester. Then install the build with the TestFlight app on your iPhone.

### D. CloudKit schema (after the first install)
1. Open the TestFlight build and log one drink. **Note:** TestFlight builds use CloudKit's **Production** environment, which can't create record types on its own. So first create them in **Development**:
   - In CloudKit Console (icloud.developer.apple.com) → `iCloud.com.rickjanik.PourLog` → **Development → Schema → Record Types**, add:
     - `Pour`: `drink` String, `venue` String, `city` String, `notes` String, `rating` Int(64), `createdAt` Date/Time, `location` Location, `photo` Asset
     - `Drinker`: `name` String
   - Under **Indexes → Pour**, add `recordName` Queryable, `createdAt` Queryable, and `createdAt` Sortable.
   - Click **Deploy Schema Changes…** to push it to Production.
2. Pull to refresh in the app. Your drink should show up, and you'll be at the top of the leaderboard.

The default security roles are already correct: everyone can read, any iCloud user can create entries, and only the person who created an entry can edit or delete it.

## Making changes
Edit the Swift files, commit, and push to `main`. Codemagic builds the new version and TestFlight updates it on your phone.

## Notes
- You can't use the iOS Simulator with this setup, so all testing happens on your phone through TestFlight. That's fine for location and the camera, which the Simulator can't really do anyway.
- `project.yml` controls the Info.plist privacy prompts (`INFOPLIST_KEY_…`), the version and the deployment target. Change those settings there, not in an Xcode project.
- The app icon (`Assets.xcassets/AppIcon.appiconset/AppIcon.png`) is a placeholder. Replace it with any 1024×1024 PNG that has no transparency.
- The feed loads the latest 400 drinks, and the leaderboard is calculated on the phone. That's plenty for a group of friends.
- If the build fails with strict-concurrency errors, `SWIFT_VERSION` is already pinned to 5.0 in `project.yml`. Send me the log from Codemagic's build page and I'll fix it.
