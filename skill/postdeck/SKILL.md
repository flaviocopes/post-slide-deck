---
name: postdeck
description: Build slideshows in the Postdeck Mac app with the postdeck command. Create slideshows, add posts from X, text slides (a title with smaller text below) and images like screenshots, edit, reorder and remove slides, and pick a theme. Use when asked to make, prepare or change slides or a slideshow in Postdeck, add a post or tweet, a screenshot or an image to Postdeck, add title, intro, section or closing slides, or set up the slides for a video that talks over posts on X.
---

# Postdeck

Postdeck is a Mac app that turns posts on X into slides you talk over while recording a video. A slideshow mixes posts from X, text slides, which have a title and, if you want, smaller text below it, and images, shown as large as they fit on the theme's background. The `postdeck` command changes slideshows in the running app, and the app shows each change right away. When Postdeck isn't running, the command opens it in the background.

Run `postdeck help` for the commands, and `postdeck help <command>` for the options of one.

## Build a slideshow

```bash
postdeck create "Mac apps I shipped" --theme midnight
postdeck add-text "Mac apps I shipped" "Mac apps I shipped" --subtitle "Four apps in one week"
postdeck add-post "Mac apps I shipped" releases.json
postdeck add-image "Mac apps I shipped" ~/Desktop/noterepo.png
postdeck add-text "Mac apps I shipped" "Thanks for watching"
postdeck show "Mac apps I shipped"
postdeck open "Mac apps I shipped"
```

- Name a slideshow by its name or ID, and a slide by its number in `postdeck show` or its ID. Numbers change when you add, move or remove slides, IDs don't. Run `show` again before using numbers after a change.
- New slides go at the end. `--at <position>` puts one somewhere else, counted from 1.
- `add-image` takes a PNG, JPEG, HEIC, GIF or WebP file. Postdeck copies it, so the original can go away.
- `edit` changes the title or subtitle of a text slide. Posts and images can't be edited.
- Themes: dawn, mint and peach are light, midnight, ocean and graphite are dark. `postdeck theme <slideshow> <theme>` changes it.
- Every command takes `--json` and prints the slideshow as JSON, with each slide's ID.
- `create` leaves the app on the slideshow it was showing. `open` switches it, and then posts sent from X with the browser extension go to that slideshow too. Say so when you open one.
- Ask before you delete a slideshow or remove slides you didn't add.

## Add posts from X

`add-post` takes a post as JSON, from a file or stdin, the same JSON the Postdeck browser extension sends. `postdeck help add-post` shows the format. Postdeck downloads the avatar and images, which must be on `pbs.twimg.com`.

From the X API v2, ask for `created_at`, `entities`, `note_tweet`, `attachments` and the `author_id` and `attachments.media_keys` expansions, with `name`, `username`, `verified` and `profile_image_url` for users and `type`, `url` and `preview_image_url` for media. Then:

- `id` is the post ID, and `author` takes `name`, `handle` (the username), `verified` and `avatarURL` (the profile image URL).
- `text` is `note_tweet.text` for long posts, otherwise `text`. Replace each `t.co` link with its `display_url` from `entities.urls`, drop the `t.co` link at the end that points to the post's own photos or video, and put the display URLs and the @mentions in `links`, so they show in blue.
- `media`: a photo is `{"kind": "photo", "url": <url>}`, and a video or GIF is `{"kind": "video", "url": <preview_image_url>}`.
- `postedAt` is `created_at` in milliseconds since 1970. Without it, the date comes from the post ID.

## When the command is missing

If `postdeck` isn't on the PATH, use `/Applications/Postdeck.app/Contents/Helpers/postdeck`. Postdeck → Install Command Line Tool links it into `~/.local/bin`.
