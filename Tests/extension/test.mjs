// Loads the extension into Chromium, opens X pages saved by capture-fixtures.mjs at their real URLs,
// clicks the Post Slide Deck button, and checks the post that reaches a stand-in for the app on port 7678.
// Usage: npm test (quit Post Slide Deck first, it uses the same port)
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { createServer } from 'node:http'
import { fileURLToPath } from 'node:url'
import { chromium } from 'playwright'

const extension = fileURLToPath(new URL('../../extension', import.meta.url))
const fixture = (name) => readFile(new URL(`fixtures/${name}`, import.meta.url), 'utf8')
const snowflakeTime = (id) => Number((BigInt(id) >> 22n) + 1288834974657n)

const pages = {
  '/flaviocopes': await fixture('profile.html'),
  '/flaviocopes/status/2106174390564159515': await fixture('post.html'),
  '/maxfaber_Om/status/2106260000000000000': await fixture('post.html'),
  '/elonmusk': await fixture('quote.html'),
  '/maxfaber_Om': await fixture('old-markup.html'),
}

const requests = []
let nextError = null
const app = createServer((request, response) => {
  let body = ''
  request.on('data', (chunk) => (body += chunk))
  request.on('end', () => {
    requests.push({ method: request.method, path: request.url, headers: request.headers, post: JSON.parse(body) })
    response.writeHead(nextError ? 400 : 200, { 'Content-Type': 'application/json' })
    response.end(JSON.stringify(nextError ? { error: nextError } : { status: 'added', deck: 'Releases video', count: requests.length }))
    nextError = null
  })
})
await new Promise((resolve, reject) => {
  app.once('error', (error) =>
    reject(error.code === 'EADDRINUSE' ? new Error('Port 7678 is busy. Quit Post Slide Deck before running the test.') : error),
  )
  app.listen(7678, '127.0.0.1', resolve)
})

// Chrome ignores --load-extension since version 137, so the extension goes in through DevTools
const context = await chromium.launchPersistentContext('', {
  channel: 'chromium',
  args: ['--enable-unsafe-extension-debugging'],
  ignoreDefaultArgs: ['--disable-extensions'],
})

async function open(path) {
  const page = await context.newPage()
  await page.goto(`https://x.com${path}`)
  await page.waitForSelector('.postdeck-button')
  return page
}

async function click(page, index) {
  const count = requests.length
  await page.evaluate(() => document.getElementById('postdeck-toast')?.classList.remove('postdeck-visible'))
  await page.locator('.postdeck-button').nth(index).click()
  await page.waitForFunction(() => document.getElementById('postdeck-toast')?.classList.contains('postdeck-visible'))
  const toast = await page.locator('#postdeck-toast').textContent()
  return { post: requests.length > count ? requests.at(-1).post : null, toast }
}

try {
  const cdp = await context.browser().newBrowserCDPSession()
  await cdp.send('Extensions.loadUnpacked', { path: extension })
  await context.route('**/*', (route) => {
    const url = new URL(route.request().url())
    if (url.hostname === '127.0.0.1') return route.continue()
    if (url.hostname !== 'x.com') return route.abort()
    return route.fulfill({ contentType: 'text/html; charset=utf-8', body: pages[url.pathname] ?? '<title>Not a fixture</title>' })
  })

  // A profile in X's current markup
  const profile = await open('/flaviocopes')
  assert.equal(await profile.locator('.postdeck-button').count(), 5, 'every post gets a button')
  const neighbor = await profile.evaluate(() => document.querySelector('.postdeck-slot').previousElementSibling.dataset.engagementAction)
  assert.equal(neighbor, 'like', 'the button sits right after Like')
  const copy = await profile.evaluate(() => {
    const article = document.querySelector('article')
    const reply = article.querySelector('[data-engagement-action="reply"] a')
    const button = article.querySelector('.postdeck-button')
    return {
      classes: button.className === `${reply.className} postdeck-button`,
      iconSize: button.querySelector('svg').getAttribute('width') === reply.querySelector('svg').getAttribute('width'),
      leftovers: button.querySelectorAll('[id], [data-animated-count], [data-icon]').length,
      text: button.textContent.trim(),
      label: button.getAttribute('aria-label'),
    }
  })
  assert.deepEqual(copy, { classes: true, iconSize: true, leftovers: 0, text: '', label: 'Add to Post Slide Deck' }, "the button is a clean copy of X's Reply control")

  const first = await click(profile, 0)
  const request = requests.at(-1)
  assert.equal(request.method, 'POST')
  assert.equal(request.path, '/cards')
  assert.equal(request.headers['content-type'], 'application/json')
  assert.match(request.headers.origin, /^chrome-extension:\/\//)
  assert.deepEqual(first.post, {
    id: '2106174390564159515',
    author: {
      name: 'flavio',
      handle: 'flaviocopes',
      avatarURL: 'https://pbs.twimg.com/profile_images/1084880084090146819/uFLTp7C1_normal.jpg',
      verified: true,
    },
    text: 'Releases: my free, open source Mac app that tracks every app I ship flaviocopes.com/releases/',
    links: ['flaviocopes.com/releases/'],
    postedAt: snowflakeTime('2106174390564159515'),
    replyingTo: [],
    media: [
      {
        kind: 'video',
        url: 'https://pbs.twimg.com/amplify_video_thumb/2105992733001211905/img/Jkshc7k5o5kefoI4?format=webp&name=medium',
      },
    ],
    truncated: false,
  })
  assert.ok(new Date(first.post.postedAt).toISOString().startsWith('2026-10-03T00:08'), 'the date comes from the post ID')
  assert.equal(first.toast, 'Added to “Releases video”, slide 1')
  assert.equal(await profile.locator('.postdeck-button').first().getAttribute('data-state'), 'added')

  const long = await click(profile, 4)
  assert.match(long.post.text, /^Launched the Calculum macOS app/)
  assert.match(long.post.text, /\n▶︎ Works offline, results update as you type\n/, 'line breaks survive')
  assert.match(long.post.text, /flaviocopes\.com\/calculum-mac\/$/)

  // The post's own page
  const post = await open('/flaviocopes/status/2106174390564159515')
  const fromPost = await click(post, 0)
  assert.equal(fromPost.post.id, '2106174390564159515')
  assert.equal(fromPost.post.text, first.post.text)
  assert.deepEqual(fromPost.post.replyingTo, [])

  // A reply on its own page, under the post it replies to
  const conversation = await open('/maxfaber_Om/status/2106260000000000000')
  await conversation.evaluate(() => {
    const parent = document.querySelector('article')
    const reply = parent.cloneNode(true)
    reply.querySelector('.postdeck-slot').remove()
    for (const link of reply.querySelectorAll('a[href]')) {
      const href = link.getAttribute('href')
      link.setAttribute('href', href.replace('/flaviocopes/status/2106174390564159515', '/maxfaber_Om/status/2106260000000000000').replace(/^\/flaviocopes$/, '/maxfaber_Om'))
    }
    const walker = document.createTreeWalker(reply, NodeFilter.SHOW_TEXT)
    while (walker.nextNode()) {
      const node = walker.currentNode
      if (node.data === 'flavio') node.data = 'maxfaber'
      if (node.data === '@flaviocopes') node.data = '@maxfaber_Om'
    }
    reply.querySelector('img[src*="profile_images/"]').src = 'https://pbs.twimg.com/profile_images/1700000000000000000/abcdEFGH_normal.jpg'
    reply.querySelector('div[dir="auto"]').textContent = 'How on earth do you release new app every single day?'
    reply.querySelector('video').closest('[style*="aspect-ratio"]').remove()
    parent.after(reply)
  })
  await conversation.waitForFunction(() => document.querySelectorAll('.postdeck-button').length === 2)
  const reply = await click(conversation, 1)
  assert.equal(reply.post.author.handle, 'maxfaber_Om')
  assert.equal(reply.post.author.name, 'maxfaber')
  assert.equal(reply.post.text, 'How on earth do you release new app every single day?')
  assert.deepEqual(reply.post.replyingTo, ['flaviocopes'])
  assert.deepEqual(reply.post.media, [])
  assert.deepEqual((await click(conversation, 0)).post.replyingTo, [], 'the post on top replies to nobody')

  // A post that quotes another one: the quote is a nested article
  const quotePage = await open('/elonmusk')
  assert.equal(await quotePage.locator('.postdeck-button').count(), 1, 'the quoted post gets no button of its own')
  const quoted = await quotePage.evaluate(() => {
    const quote = document.querySelector('article article')
    return {
      text: quote.querySelector('div[dir="auto"]').textContent.trim(),
      media: [...quote.querySelectorAll('img[src*="/media/"], video[poster]')].map((m) => m.src || m.poster),
      avatar: document.querySelector('article img[src*="profile_images/"]').src,
    }
  })
  const quoting = await click(quotePage, 0)
  assert.equal(quoting.post.author.handle, 'elonmusk')
  assert.equal(quoting.post.author.avatarURL, quoted.avatar, 'the avatar, not the affiliate badge next to the name')
  assert.ok(quoting.post.text && !quoting.post.text.includes(quoted.text), 'the text is the post, not the quote')
  assert.ok(!quoting.post.media.some((m) => quoted.media.includes(m.url)), "the quote's media stays out")

  // X's older markup, with data-testid attributes
  const old = await open('/maxfaber_Om')
  const oldNeighbor = await old.evaluate(() => document.querySelector('.postdeck-slot').previousElementSibling.querySelector('[data-testid]').dataset.testid)
  assert.equal(oldNeighbor, 'like')
  assert.equal(await old.locator('.postdeck-button').textContent(), '', 'the copy of Reply leaves its count out')
  const oldPost = await click(old, 0)
  assert.deepEqual(oldPost.post, {
    id: '2106260000000000000',
    author: {
      name: 'maxfaber 🚀',
      handle: 'maxfaber_Om',
      avatarURL: 'https://pbs.twimg.com/profile_images/1700000000000000000/abcdEFGH_normal.jpg',
      verified: false,
    },
    text: 'How on earth do you release new app every single day? 🤯\nAsking for @kentcdodds and flaviocopes.com/releases/',
    links: ['@kentcdodds', 'flaviocopes.com/releases/'],
    postedAt: snowflakeTime('2106260000000000000'),
    replyingTo: ['flaviocopes'],
    media: [
      { kind: 'photo', url: 'https://pbs.twimg.com/media/GaBcDeF1?format=jpg&name=small' },
      { kind: 'photo', url: 'https://pbs.twimg.com/media/GaBcDeF2?format=jpg&name=small' },
    ],
    truncated: false,
  })

  // The app turns a post down, then isn't running
  nextError = 'The post has no text or media to show.'
  const refused = await click(profile, 1)
  assert.equal(refused.toast, "Post Slide Deck couldn't add this post. The post has no text or media to show.")
  assert.equal(await profile.locator('.postdeck-button').nth(1).getAttribute('data-state'), null)

  await new Promise((resolve) => app.close(resolve))
  const offline = await click(profile, 2)
  assert.equal(offline.post, null)
  assert.equal(offline.toast, "Post Slide Deck isn't running. Open the app and click again.")

  console.log(`ok: ${requests.length} posts sent from 5 pages, current and older markup, replies, quotes, errors`)
} finally {
  await context.close()
  app.close()
}
