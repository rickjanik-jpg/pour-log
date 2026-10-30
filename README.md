# Pour Log for iPhone

A SwiftUI app for logging drinks: take a photo, record where you had it, rate it, and see where you rank on a shared leaderboard.

- **GPS:** asks for "While Using" location, suggests bars and restaurants within about 150 m, and fills in the city.
- **Photo location:** if you pick an older photo from your library, the app uses the GPS stored in that photo, so you get the bar where you took it, not where you are now.
- **Shared leaderboard:** uses the CloudKit public database, so there's no server and anyone with the app shares one log. You can only delete your own entries.
- Requires iOS 17 or later.

## 1. Create the project
1. In Xcode, choose File → New → Project → iOS → App.
   - Product Name: `PourLog`, Interface: SwiftUI, Storage: None.
2. Delete the `ContentView.swift` and `PourLogApp.swift` that Xcode made.
3. Drag every `.swift` file from `PourLog/` into the project (check "Copy items if needed").
4. Set the minimum deployment target to iOS 17.0 (General → Minimum Deployments).

## 2. Turn on iCloud
1. Select the target → Signing & Capabilities. Choose your team.
2. Click + Capability → **iCloud**, tick **CloudKit**, and add a container, for example `iCloud.com.rickjanik.PourLog`.
3. Open `CloudStore.swift` and set `containerID` to that exact container name.

## 3. Add the privacy prompts
Add these keys under the target's **Info** tab. iOS will crash the app if any of them is missing.

| Key | Example text |
|---|---|
| Privacy - Location When In Use Usage Description | Suggests the bar you're at and tags your drink with its location. |
| Privacy - Camera Usage Description | Take a photo of your drink. |
| Privacy - Photo Library Usage Description | Read where an older photo was taken. |

## 4. Set up the CloudKit schema (one time)
1. Run the app and log one drink. In the Development environment, saving that first drink creates the `Pour` and `Drinker` record types automatically.
2. Open [CloudKit Console](https://icloud.developer.apple.com) → your container → Development → Schema → **Indexes** → `Pour`, and add:
   - `recordName`: **Queryable**
   - `createdAt`: **Sortable** (also add Queryable)
3. Pull to refresh in the app. If you see "Field 'recordName' is not marked queryable" or a similar error, it means step 2 isn't finished.
4. Before giving the app to friends with TestFlight, click **Deploy Schema Changes…** to push the schema to Production.

The default security roles are already correct: everyone can read, any iCloud user can create entries, and only the person who created an entry can edit or delete it.

## Testing in the Simulator
- **iCloud:** open Settings in the Simulator and sign in with an Apple ID. CloudKit won't work otherwise.
- **Fake GPS:** in the Simulator menu, choose Features → Location → Custom Location… and enter a bar's latitude and longitude.
- **Photos:** the Simulator has no camera, so the Camera button is hidden. Drag an image onto the Simulator window to add it to Photos, then use Library.
- Testing the leaderboard needs a second Apple ID, for example the Simulator signed into one account and your phone signed into another.

## On your iPhone and friends' phones
- **Your phone:** plug it in, select it as the run destination, and press Run. Then trust the developer profile on the phone (Settings → General → VPN & Device Management).
- **Friends:** Product → Archive → Distribute → TestFlight. Then invite them by email in App Store Connect.

## Notes
- The feed loads the latest 400 drinks, and the leaderboard is calculated on the phone. That's plenty for a group of friends. If the log grows much bigger, use paging (CloudKit cursors) or store a count for each person.
- Photos are resized to 1600 px before upload, so each one is roughly 300–600 KB of iCloud public storage, which counts toward the app's free CloudKit quota.
- If Xcode shows strict-concurrency errors (Swift 6 language mode), set Build Settings → Swift Language Version to **Swift 5**.
