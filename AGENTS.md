# Postdeck

A Mac app and a Chrome extension that turn posts on X into slides you talk over while recording a video. The extension adds a button next to Like on every post. A click sends the post to the app, which adds it to the selected slideshow. The app plays the slideshow in its main window, which you record with a screen recorder like Borumi.

A Swift package with no Xcode project and no Swift dependencies, plus the extension in plain JavaScript with no build step.

- `Sources/PostdeckCore`: all the logic. `Models.swift` has `Card` (a post), `TextSlide`, `Slide` (a post or a text slide), `Media`, `Deck` and `Library`. `LibraryEditing.swift` adds posts, inserts and edits text slides, reorders, moves and deletes. `PostPayload` is the JSON the extension sends, and `card()` checks it. `TwitterImage` turns X image URLs into their large version. `MediaDownloader` saves avatars and images next to the library. `LibraryStore` reads and writes it. `HTTP.swift`, `LocalServer` and `API` are the local server.
- `Sources/PostdeckApp`: the SwiftUI app. `AppModel` holds the state, runs the server and receives posts. `ContentView` lays out three columns under a hidden title bar, or the slideshow while it plays, and has the sidebar with the slideshows and the server status. `CardListView.swift` has the `Navigator`, the slides of the selected slideshow as thumbnails you drag to reorder. A drag carries the slide's ID as a string, and the sidebar's `DeckRow` takes the same drop to move a slide to another slideshow. `SlideView` draws one slide: a post on a card, or a text slide, which the stage draws with text fields so you type on the slide itself. `SlideTheme`, in the same file, has the six slide themes, three light and three dark. `SlideshowView.swift` has the `Stage` with the large slide and its controls, and `SlideshowView`, the slide alone that replaces the columns while the slideshow plays. `NextSlidePanel.swift` is the small floating window with the next slide, open while the slideshow plays. `Theme.swift` has the colors, type scale, sizes and shared pieces. `AppUpdater.swift` checks GitHub Releases for updates and installs them. It's a copy of a template shared by several apps, so don't edit it here.
- `extension/`: Manifest V3. `post.js` reads a post from the page, `content.js` adds the button and shows the toast, `background.js` posts to the app. The button is a copy of X's own Reply control with another icon, placed next to Like, so it takes X's size, alignment and hover color in every action bar. Don't give it fixed sizes.
- `Tests/PostdeckCoreTests`: Swift Testing tests for the core. `Tests/extension`: the Playwright test, the script that captures its fixtures from x.com, and the fixtures.
- `Scripts/`: `build-app.sh`, `build-release.sh`, `render-icon.swift`, `render-banner.swift`, and `screenshot.sh` with `screenshot.swift`.
- `docs/`: the README's banner, screenshots, slide and video poster, and `demo-library`, the library they're made from, with the author's own public posts from @flaviocopes. Screenshots and videos use it, never a real library.
- `.github/workflows/ci.yml`: `swift test` and `build-release.sh` on macOS, and `npm test` on Linux.

## Build and test

Requirements: macOS 14+, Swift 6.2 (Xcode 26), Node with npm, Google Chrome to capture fixtures.

```bash
swift build                                  # build everything (debug)
swift test                                   # the core tests, must pass before committing
swift run PostdeckApp                        # run the app from source
./Scripts/build-app.sh                       # universal release build, dist/Postdeck.app
./Scripts/build-release.sh                   # dist/Postdeck-<version>.zip with the app and "Postdeck Extension", notarized
npm install                                  # Playwright, for the extension test
npm test                                     # the extension in Chromium against real X markup (quit Postdeck first)
npm run capture-fixtures                     # save fresh posts from x.com into Tests/extension/fixtures
swift Scripts/render-icon.swift              # Assets/AppIcon.png and extension/icons/*.png
./Scripts/screenshot.sh <library> [folder]   # the main window and every slide of a library, as PNGs
swift Scripts/render-banner.swift            # docs/banner.png, from docs/screenshot-dark.png
```

To refresh the README images, run `./Scripts/screenshot.sh docs/demo-library /tmp/postdeck-shots`, copy `screenshot-light.png` and `screenshot-dark.png` into `docs/`, copy `slide-2-dawn.png` and `slide-2-midnight.png` as `docs/slide-light.png` and `docs/slide-dark.png`, then render the banner.

Set `POSTDECK_HOME=/tmp/postdeck-test` to use another library folder, and `POSTDECK_PORT=0` to listen on a free port. To try the extension in your own Chrome, open `chrome://extensions`, turn on Developer mode, click **Load unpacked** and pick the `extension` folder. After editing, click the reload arrow on the Postdeck card and reload the X tab.

## How it works

- The extension can't reach the app from the x.com page, so `content.js` hands the post to the service worker, which posts it to `http://127.0.0.1:7678/cards`. The port is `Postdeck.port` in `Version.swift` and `APP_URL` in `background.js`. Change both together.
- The server binds to 127.0.0.1 only. It refuses any request with an `Origin` that isn't `chrome-extension://`, and posts need `Content-Type: application/json`, which a web page can't send without a CORS preflight the server never allows. `GET /status` returns the app version and the current slideshow.
- New posts go to the selected slideshow (`Library.currentDeckID`). With none, the newest one is used, and with no slideshows the first post creates "Untitled Slideshow". A slideshow holds each post once. Sending a post again with a longer text replaces its text (`AddResult.updated`), for timeline posts that X cut short.
- A slideshow's slides are posts and text slides, saved in order under `cards` in `library.json`, the name from when every slide was a post. A text slide has `"kind": "text"`, a UUID for its ID, a `title` and a `subtitle`. ⌘T or the button above the slides adds one after the selected slide and puts the cursor in its title.
- The theme is a slideshow setting: `Deck.theme` holds a `SlideTheme` ID, picked with the swatches next to Play. A slideshow without one uses the Light or Dark switch of Postdeck 1.0, saved as `slideTheme` in the app's defaults: Midnight for dark, Dawn otherwise.
- The library is `~/Library/Application Support/Postdeck/library.json`, the images are in `media/` next to it, named `<post ID>-avatar.jpg` and `<post ID>-<n>.jpg`. The app downloads them when a post arrives, so slides work offline while you record. Deleting posts or slideshows deletes the images nothing points to.
- X serves two kinds of markup. The current one has no `data-testid` attributes: actions have `data-engagement-action`, icons have `data-icon`, the text is the first `div[dir="auto"]`, and a quoted post is a nested `<article>` inside a `role="link"` card. The older one has `data-testid` attributes. `post.js` handles both, so check `npm test` covers any new selector.
- `post.js` reads the handle and ID from the first `/handle/status/id` link outside the quote, the date from the ID (it's a snowflake), the avatar from the first `profile_images` image (later ones can be affiliate badges), and replies from a "Replying to" line, or on a post's page from the conversation order.
- A slide is laid out on a 1920×1080 canvas and every size is multiplied by `width / 1920`, so it's sharp at any window size. Shorter posts get bigger text. The app has one window. Play (`AppModel.isPresenting`) swaps the three columns for the slide alone and hides the traffic lights, so a recording of the app window shows only the slide, letterboxed in the slide's background color when the window isn't 16:9. S, Esc or ⌘↩ go back. The selected slide in the list is the slide on screen, so the list, the preview buttons and the keys while playing all move the same selection.
- While the slideshow plays, `NextSlidePanel` shows the next slide in a floating `NSPanel`. It's a window of its own, so a recording of the main window leaves it out. It's non-activating and never becomes key, so → ←, Space and clickers keep going to the slideshow.

## Working on the code

- Add logic to `PostdeckCore` with a test. Keep `AppModel` and the views thin.
- The app has its own look, not stock macOS controls. Use the tokens in `Theme.swift` (`Brand`, `Surface`, `Typography`, `Metrics`) and its button styles instead of new colors, font sizes or one-off styles. The brand gradient comes from the icon and only marks the selected slideshow, the Play button and the empty-state badges.
- New fields on `Card`, `TextSlide`, `Deck` and `Library` must be optional, or have a default in a custom decoder, so old `library.json` files still decode.
- When X changes its markup, run `npm run capture-fixtures`, then `npm test`, then fix `post.js`. `capture-fixtures.mjs` needs Google Chrome: X refuses Playwright's Chromium and any user agent that says HeadlessChrome. `old-markup.html` is hand-written, the other fixtures are captured.
- The extension never needs more permissions than the host permission for 127.0.0.1:7678 and the content script on x.com and twitter.com.
- The icon is drawn by `Scripts/render-icon.swift`. Change a constant and run it again instead of editing the PNGs.
- The app has no UI tests. Check visual changes with `./Scripts/screenshot.sh`, pointed at `docs/demo-library` or a test library made with `POSTDECK_HOME`, and by opening `dist/Postdeck.app`.
- The version is `Postdeck.version` in `Sources/PostdeckCore/Version.swift`, and `version` in `extension/manifest.json`. Keep them equal: `build-release.sh` refuses to build when they differ.

## Releases

- Releases are on GitHub, tagged `vX.Y.Z`, with `Postdeck-X.Y.Z.zip` from `build-release.sh` attached. Use a minor version for a new feature or a change people notice, and a point version for bug fixes.
- The in-app updater installs a release only when the tag equals the app's version, the zip has `Postdeck.app` at the top with the same bundle ID (`com.flaviocopes.postdeck`), and its signature is valid. It takes the first `.zip` in the release, so attach only that one zip.
- The release notes start with what's new. The update dialog shows them up to the `## Install` heading.
- The extension doesn't update itself. When a release changes `extension/`, say so in the notes, so people replace their `Postdeck Extension` folder.
- The 30-second demo video is on flaviocopes.com, not in the repo. `docs/showreel-poster.jpg` in the README links to it.
- `build-release.sh` signs with the Developer ID and notarizes when the certificate and the `notary` notarytool profile are on the Mac. Everywhere else, like CI and forks, it signs ad hoc.
