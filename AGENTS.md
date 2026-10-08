# Post Slide Deck

A Mac app and a Chrome extension that turn posts on X into slides you talk over while recording a video. The extension adds a button next to Like on every post. A click sends the post to the app, which adds it to the selected slideshow. The app plays the slideshow in its main window, which you record with a screen recorder like Borumi. The `postdeck` command lets agents build slideshows in the running app.

A Swift package with no Xcode project and no Swift dependencies, plus the extension in plain JavaScript with no build step.

- `Sources/PostdeckCore`: all the logic. `Models.swift` has `Card` (a post), `TextSlide`, `ImageSlide`, `Slide` (one of the three), `Media`, `Deck` and `Library`. `LibraryEditing.swift` adds posts, inserts and edits slides, reorders, moves and deletes. `PostPayload` is the JSON the extension sends, and `card()` checks it. `TwitterImage` turns X image URLs into their large version. `MediaDownloader` saves avatars and images next to the library. `LibraryStore` reads and writes it, and copies images for image slides into the media folder. `HTTP.swift`, `LocalServer` and `API` are the local server. `Command.swift` has the commands of the `postdeck` tool and `Library.apply`, which runs them, and `AppClient` is the tool's side of the server. `SlideTheme` lists the six themes.
- `Sources/PostdeckCLI`: the `postdeck` command. `PostdeckCommand.swift` parses arguments, prints help and opens the app when it isn't running. `Commands.swift` has each command and its output.
- `Sources/PostdeckApp`: the SwiftUI app. `AppModel` holds the state, runs the server and receives posts. `ContentView` lays out three columns under a hidden title bar, or the slideshow while it plays, and has the sidebar with the slideshows and the server status. `CardListView.swift` has the `Navigator`, the slides of the selected slideshow as thumbnails you drag to reorder. A drag carries the slide's ID as a string, and the sidebar's `DeckRow` takes the same drop to move a slide to another slideshow. The list takes `SlideDrop`, a slide ID or an image (`ImageDrop`, a file or image data copied to a temporary file), so an image dropped between slides lands there. `SlideView` draws one slide: a post on a card, a text slide, which the stage draws with text fields so you type on the slide itself, or an image as large as it fits. An extension of `SlideTheme`, in the same file, has each theme's colors. `SlideshowView.swift` has the `Stage` with the large slide and its controls, and `SlideshowView`, the slide alone that replaces the columns while the slideshow plays. `NextSlidePanel.swift` is the small floating window with the next slide, open while the slideshow plays. `Theme.swift` has the colors, type scale, sizes and shared pieces. `CommandLineTool.swift` and `AgentSkill.swift` are the Post Slide Deck menu items that link the `postdeck` command into `~/.local/bin` and install the agent skill. `AppUpdater.swift` checks GitHub Releases for updates and installs them. It's a copy of a template shared by several apps, so don't edit it here.
- `extension/`: Manifest V3. `post.js` reads a post from the page, `content.js` adds the button and shows the toast, `background.js` posts to the app. The button is a copy of X's own Reply control with another icon, placed next to Like, so it takes X's size, alignment and hover color in every action bar. Don't give it fixed sizes.
- `skill/postdeck/SKILL.md`: the agent skill. `build-app.sh` puts it in the app at `Contents/Resources/SKILL.md`, and the app copies it to `~/.agents/skills/postdeck` from the menu, and again on launch when an update changed it.
- `Tests/PostdeckCoreTests`: Swift Testing tests for the core. `Tests/extension`: the Playwright test, the script that captures its fixtures from x.com, and the fixtures.
- `Scripts/`: `build-app.sh`, `build-release.sh`, `render-icon.swift`, `render-banner.swift`, and `screenshot.sh` with `screenshot.swift`.
- `docs/`: the README's banner, screenshots, slide and video poster, and `demo-library`, the library they're made from, with the author's own public posts from @flaviocopes. Screenshots and videos use it, never a real library.

## Build and test

Requirements: macOS 14+, Swift 6.2 (Xcode 26), Node with npm, Google Chrome to capture fixtures.

```bash
swift build                                  # build everything (debug)
swift test                                   # the core tests, must pass before committing
swift run PostdeckApp                        # run the app from source
swift run postdeck help                      # the command line tool, which talks to the running app
./Scripts/build-app.sh                       # universal release build, dist/Post Slide Deck.app, with postdeck in Contents/Helpers
./Scripts/build-release.sh                   # dist/Post Slide Deck-<version>.zip with the app and "Post Slide Deck Extension", notarized
npm install                                  # Playwright, for the extension test
npm test                                     # the extension in Chromium against real X markup (quit Post Slide Deck first)
npm run capture-fixtures                     # save fresh posts from x.com into Tests/extension/fixtures
swift Scripts/render-icon.swift              # Assets/AppIcon.png and extension/icons/*.png
./Scripts/screenshot.sh <library> [folder]   # the main window and every slide of a library, as PNGs
swift Scripts/render-banner.swift            # docs/banner.png, from docs/screenshot-dark.png
```

To refresh the README images, run `./Scripts/screenshot.sh docs/demo-library /tmp/postdeck-shots`, copy `screenshot-light.png` and `screenshot-dark.png` into `docs/`, copy `slide-2-dawn.png` and `slide-2-midnight.png` as `docs/slide-light.png` and `docs/slide-dark.png`, then render the banner.

Set `POSTDECK_HOME=/tmp/postdeck-test` to use another library folder, and `POSTDECK_PORT=0` to listen on a free port. To try the extension in your own Chrome, open `chrome://extensions`, turn on Developer mode, click **Load unpacked** and pick the `extension` folder. After editing, click the reload arrow on the Post Slide Deck card and reload the X tab.

## How it works

- The extension can't reach the app from the x.com page, so `content.js` hands the post to the service worker, which posts it to `http://127.0.0.1:7678/cards`. The port is `Postdeck.port` in `Version.swift` and `APP_URL` in `background.js`. Change both together.
- The server binds to 127.0.0.1 only. It refuses any request with an `Origin` that isn't `chrome-extension://`, and posts need `Content-Type: application/json`, which a web page can't send without a CORS preflight the server never allows. It also refuses a `Host` other than 127.0.0.1 or localhost, which is how a web page reaching it through DNS rebinding shows up. `GET /status` returns the app version and the current slideshow.
- The `postdeck` command talks to the same server, since the app holds the library in memory and is the only one that writes it. `GET /library` returns the library, and `POST /commands` takes a `Command` as JSON. The app runs it with `Library.apply`, passing `LibraryStore.importImage` for `add-image`, saves, keeps the selection on a slide that exists, and downloads a new post's images before it replies. When nothing answers, the command opens the app with `open -g -b com.flaviocopes.postdeck` and waits for the server. A slideshow made with `postdeck create` doesn't replace the one open in the app; `postdeck open` does.
- New posts go to the selected slideshow (`Library.currentDeckID`). With none, the newest one is used, and with no slideshows the first post creates "Untitled Slideshow". A slideshow holds each post once. Sending a post again with a longer text replaces its text (`AddResult.updated`), for timeline posts that X cut short.
- A slideshow's slides are posts and text slides, saved in order under `cards` in `library.json`, the name from when every slide was a post. A text slide has `"kind": "text"`, a UUID for its ID, a `title` and a `subtitle`. ⌘T or the button above the slides adds one after the selected slide and puts the cursor in its title. A click on the slide or the stage outside the text ends editing.
- An image slide has `"kind": "image"`, a UUID for its ID, and `file`, the image copied into `media/` as `<id>.<extension>`, so it keeps working when the original moves. Images dropped on the slide list, on the stage or on an empty slideshow, picked with ⇧⌘I or the button above the slides, or sent with `postdeck add-image` become image slides. `LibraryStore.importImage` checks the file with ImageIO before copying it.
- The theme is a slideshow setting: `Deck.theme` holds a `SlideTheme` ID, picked with the swatches next to Play. A slideshow without one uses the Light or Dark switch of Post Slide Deck 1.0, saved as `slideTheme` in the app's defaults: Midnight for dark, Dawn otherwise.
- The library is `~/Library/Application Support/Postdeck/library.json`, the images are in `media/` next to it, named `<post ID>-avatar.jpg` and `<post ID>-<n>.jpg`. The app downloads them when a post arrives, so slides work offline while you record. Deleting posts or slideshows deletes the images nothing points to.
- X serves two kinds of markup. The current one has no `data-testid` attributes: actions have `data-engagement-action`, icons have `data-icon`, the text is the first `div[dir="auto"]`, and a quoted post is a nested `<article>` inside a `role="link"` card. The older one has `data-testid` attributes. `post.js` handles both, so check `npm test` covers any new selector.
- `post.js` reads the handle and ID from the first `/handle/status/id` link outside the quote, the date from the ID (it's a snowflake), the avatar from the first `profile_images` image (later ones can be affiliate badges), and replies from a "Replying to" line, or on a post's page from the conversation order.
- A slide is laid out on a 1920×1080 canvas and every size is multiplied by `width / 1920`, so it's sharp at any window size. Shorter posts get bigger text. The app has one window. Play (`AppModel.isPresenting`) swaps the three columns for the slide alone and hides the traffic lights, so a recording of the app window shows only the slide, letterboxed in the slide's background color when the window isn't 16:9. S, Esc or ⌘↩ go back. The selected slide in the list is the slide on screen, so the list, the preview buttons and the keys while playing all move the same selection.
- While the slideshow plays, `NextSlidePanel` shows the next slide in a floating `NSPanel`. It's a window of its own, so a recording of the main window leaves it out. It's non-activating and never becomes key, so → ←, Space and clickers keep going to the slideshow.

## Working on the code

- Add logic to `PostdeckCore` with a test. Keep `AppModel` and the views thin.
- The app has its own look, not stock macOS controls. Use the tokens in `Theme.swift` (`Brand`, `Surface`, `Typography`, `Metrics`) and its button styles instead of new colors, font sizes or one-off styles. The brand gradient comes from the icon and only marks the selected slideshow, the Play button and the empty-state badges.
- New fields on `Card`, `TextSlide`, `ImageSlide`, `Deck` and `Library` must be optional, or have a default in a custom decoder, so old `library.json` files still decode.
- When X changes its markup, run `npm run capture-fixtures`, then `npm test`, then fix `post.js`. `capture-fixtures.mjs` needs Google Chrome: X refuses Playwright's Chromium and any user agent that says HeadlessChrome. `old-markup.html` is hand-written, the other fixtures are captured.
- When you add or change a `postdeck` command, update its help in `Commands.swift`, `skill/postdeck/SKILL.md` and the README together. Agents learn the command from the skill and the help, so they must match what it does.
- The agent-ready manifest lives in `Sources/PostdeckCLI/Capabilities.swift` as `Commands.manifest`. Every version bump adds a changelog entry there, newest first.
- The extension never needs more permissions than the host permission for 127.0.0.1:7678 and the content script on x.com and twitter.com.
- The icon is drawn by `Scripts/render-icon.swift`. Change a constant and run it again instead of editing the PNGs.
- The app has no UI tests. Check visual changes with `./Scripts/screenshot.sh`, pointed at `docs/demo-library` or a test library made with `POSTDECK_HOME`, and by opening `dist/Post Slide Deck.app`.
- The version is `Postdeck.version` in `Sources/PostdeckCore/Version.swift`, and `version` in `extension/manifest.json`. Keep them equal: `build-release.sh` refuses to build when they differ.

## Releases

- Releases are on GitHub, tagged `vX.Y.Z`, with `Post Slide Deck-X.Y.Z.zip` from `build-release.sh` attached. Use a minor version for a new feature or a change people notice, and a point version for bug fixes.
- The in-app updater installs a release only when the tag equals the app's version, the zip has `Post Slide Deck.app` at the top with the same bundle ID (`com.flaviocopes.postdeck`), and its signature is valid. It takes the first `.zip` in the release, so attach only that one zip.
- The release notes start with what's new. The update dialog shows them up to the `## Install` heading.
- The extension doesn't update itself. When a release changes `extension/`, say so in the notes, so people replace their `Post Slide Deck Extension` folder.
- The 30-second demo video is on flaviocopes.com, not in the repo. `docs/showreel-poster.jpg` in the README links to it.
- `build-release.sh` signs with the Developer ID and notarizes when the certificate and the `notary` notarytool profile are on the Mac. Everywhere else, like CI and forks, it signs ad hoc.
