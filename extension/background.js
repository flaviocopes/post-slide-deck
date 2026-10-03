// Sends posts to the Postdeck app. The content script can't reach 127.0.0.1 from x.com, the service worker can.

const APP_URL = 'http://127.0.0.1:7678'

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message?.type !== 'postdeck:add') return false
  addPost(message.post).then(sendResponse)
  return true
})

async function addPost(post) {
  let response
  try {
    response = await fetch(`${APP_URL}/cards`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(post),
    })
  } catch {
    return { ok: false, error: 'offline' }
  }
  const body = await response.json().catch(() => ({}))
  if (!response.ok) return { ok: false, error: body.error ?? `The app answered ${response.status}.` }
  return { ok: true, ...body }
}
