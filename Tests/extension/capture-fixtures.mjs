// Saves real posts from x.com, logged out, as the fixtures for test.mjs.
// X changes its markup now and then: run this again, then npm test.
// It needs Google Chrome installed, because X refuses Playwright's Chromium.
import { writeFile } from 'node:fs/promises'
import { chromium } from 'playwright'

const pages = [
  { file: 'profile.html', url: 'https://x.com/flaviocopes' },
  { file: 'post.html', url: 'https://x.com/flaviocopes/status/2106174390564159515' },
  { file: 'quote.html', url: 'https://x.com/elonmusk', onlyQuotes: true },
]

const browser = await chromium.launch({ channel: 'chrome' })
// X shows no posts to a user agent that says HeadlessChrome.
const userAgent = (await browser.newPage().then((page) => page.evaluate(() => navigator.userAgent))).replace('HeadlessChrome', 'Chrome')
const page = await browser.newPage({ locale: 'en-US', userAgent, viewport: { width: 1280, height: 2000 } })

for (const { file, url, onlyQuotes } of pages) {
  await page.goto(url)
  await page.waitForSelector('article')
  await page.waitForTimeout(2000)
  const articles = await page.evaluate((onlyQuotes) => {
    const posts = [...document.querySelectorAll('article')].filter((article) => !article.parentElement.closest('article'))
    return posts
      .filter((article) => !onlyQuotes || article.querySelector('article'))
      .slice(0, onlyQuotes ? 1 : 5)
      .map((article) => {
        const copy = article.cloneNode(true)
        copy.querySelectorAll('script, style').forEach((node) => node.remove())
        copy.querySelectorAll('path').forEach((path) => path.removeAttribute('d'))
        copy.querySelectorAll('video').forEach((video) => video.removeAttribute('src'))
        return copy.outerHTML
      })
  }, onlyQuotes)
  if (articles.length === 0) {
    console.log(`${file}: no posts found on ${url}, kept the old fixture`)
    continue
  }
  const html = `<!doctype html>\n<html lang="en">\n<meta charset="utf-8">\n<body>\n<main>\n${articles.join('\n')}\n</main>\n</body>\n</html>\n`
  await writeFile(new URL(`fixtures/${file}`, import.meta.url), html)
  console.log(`${file}: ${articles.length} posts from ${url}`)
}

await browser.close()
