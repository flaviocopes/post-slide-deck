// Reads a post from X's page into the JSON the Postdeck app takes.
// It works with X's current markup (data-engagement-action and data-icon attributes)
// and with the older one (data-testid attributes), because X serves both.

const STATUS_PATH = /^\/([A-Za-z0-9_]{1,50})\/status\/(\d+)$/
const TWITTER_EPOCH = 1288834974657n

function readPost(article) {
  const quote = quoteOf(article)
  const own = (element) => !quote?.contains(element)
  const status = statusOf(article)
  if (!status) return null

  const textElement = textOf(article, own)
  return {
    id: status.id,
    author: {
      name: nameOf(article, status.handle, own),
      handle: status.handle,
      avatarURL: avatarOf(article, own),
      verified: isVerified(article, own),
    },
    text: textElement ? readText(textElement).trim() : '',
    links: textElement ? [...textElement.querySelectorAll('a')].map((a) => readText(a).trim()).filter(Boolean) : [],
    postedAt: postedAt(article, status.id, own),
    replyingTo: replyingTo(article, status, own),
    media: mediaOf(article, own),
    truncated: isTruncated(article, own),
  }
}

// The quoted post's card, so everything inside it can be skipped. The new markup nests an
// <article> in a role="link" card, the old one has a second User-Name in a role="link" card.
function quoteOf(article) {
  const nested = article.querySelector('article')
  if (nested) {
    const card = nested.parentElement?.closest('[role="link"]')
    return card && article.contains(card) ? card : nested
  }
  const names = article.querySelectorAll('[data-testid="User-Name"]')
  if (names.length < 2) return null
  const card = names[1].closest('[role="link"]')
  return card && article.contains(card) ? card : names[1].parentElement
}

// The post's handle and ID, from the first link to it that isn't in a quoted post.
function statusOf(article) {
  const quote = quoteOf(article)
  for (const link of article.querySelectorAll('a[href*="/status/"]')) {
    if (quote?.contains(link)) continue
    const match = new URL(link.href, location.origin).pathname.match(STATUS_PATH)
    if (match) return { handle: match[1], id: match[2] }
  }
  return null
}

function textOf(article, own) {
  const candidates = [
    ...article.querySelectorAll('[data-testid="tweetText"]'),
    ...article.querySelectorAll('div[dir="auto"]'),
  ]
  return candidates.find((element) => own(element) && !/^Replying to\b/.test(element.textContent.trim()))
}

// The text as X shows it: emoji images become their character, and hidden parts of links are left out.
function readText(element) {
  let text = ''
  for (const node of element.childNodes) {
    if (node.nodeType === Node.TEXT_NODE) {
      text += node.data
    } else if (node.nodeType !== Node.ELEMENT_NODE || ['SCRIPT', 'STYLE', 'TEMPLATE'].includes(node.tagName)) {
      continue
    } else if (node.tagName === 'IMG') {
      text += node.alt
    } else if (node.tagName === 'BR') {
      text += '\n'
    } else if (getComputedStyle(node).display !== 'none') {
      text += readText(node)
    }
  }
  return text
}

// The first link to the author's profile with some text that isn't the @handle.
function nameOf(article, handle, own) {
  for (const link of article.querySelectorAll('a[href]')) {
    if (!own(link) || new URL(link.href).pathname.toLowerCase() !== `/${handle.toLowerCase()}`) continue
    const name = readText(link).trim()
    if (name && !name.startsWith('@')) return name
  }
  return handle
}

// The first profile image. Later ones can be badges, like the X logo next to an affiliate's name.
function avatarOf(article, own) {
  const image = [...article.querySelectorAll('img[src*="profile_images/"]')].find(own)
  return image?.src ?? null
}

function isVerified(article, own) {
  return [...article.querySelectorAll('[data-icon^="icon-verified"], [data-testid="icon-verified"]')].some(own)
}

// Post IDs are snowflakes, which start with the time the post was made.
function postedAt(article, id, own) {
  const snowflake = BigInt(id)
  if (snowflake > 1000000000000000n) return Number((snowflake >> 22n) + TWITTER_EPOCH)
  const time = [...article.querySelectorAll('time[datetime]')].find(own)
  return time ? Date.parse(time.dateTime) : null
}

function mediaOf(article, own) {
  const media = []
  for (const element of article.querySelectorAll('img[src*="pbs.twimg.com/media/"], video[poster]')) {
    if (!own(element)) continue
    const isVideo = element.tagName === 'VIDEO'
    const url = isVideo ? element.poster : element.src
    if (url && !media.some((item) => item.url === url)) {
      media.push({ kind: isVideo ? 'video' : 'photo', url })
    }
  }
  return media.slice(0, 4)
}

// From a "Replying to @flaviocopes" line when the post has one. Otherwise, on a post's page,
// from the conversation: the posts above the open one are its parents, and the ones below reply to it.
function replyingTo(article, status, own) {
  const walker = document.createTreeWalker(article, NodeFilter.SHOW_TEXT)
  while (walker.nextNode()) {
    const node = walker.currentNode
    if (!/^\s*Replying to\b/.test(node.data) || !own(node.parentElement)) continue
    let container = node.parentElement
    while (container !== article && !/@\w/.test(container.textContent)) {
      container = container.parentElement
    }
    if (container === article) return []
    return [...container.textContent.matchAll(/@(\w{1,50})/g)].map((match) => match[1])
  }

  const page = location.pathname.match(/^\/[^/]+\/status\/(\d+)/)
  if (!page) return []
  const articles = [...document.querySelectorAll('article')].filter((a) => !a.parentElement?.closest('article'))
  const open = articles.findIndex((a) => statusOf(a)?.id === page[1])
  const index = articles.indexOf(article)
  if (open < 0 || index <= 0) return []
  const parent = statusOf(index <= open ? articles[index - 1] : articles[open])
  if (!parent || parent.handle.toLowerCase() === status.handle.toLowerCase()) return []
  return [parent.handle]
}

// Long posts in the timeline end with "Show more". The post's own page has the full text.
function isTruncated(article, own) {
  const links = article.querySelectorAll('[data-testid="tweet-text-show-more-link"], a, button, [role="button"], [role="link"]')
  return [...links].some((element) => own(element) && element.textContent.trim() === 'Show more')
}
