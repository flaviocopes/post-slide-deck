// Adds the Postdeck button next to Like on every post, and sends the post to the app on click.

const ICON_ADD =
  '<rect x="2.75" y="3.75" width="18.5" height="13" rx="2.5"/><path d="M12 7.25v6M9 10.25h6M8.5 20.25h7M12 16.75v3.5"/>'
const ICON_ADDED =
  '<rect x="2.75" y="3.75" width="18.5" height="13" rx="2.5"/><path d="M8.5 10.5l2.5 2.5 4.5-4.75M8.5 20.25h7M12 16.75v3.5"/>'

// The new markup puts data-engagement-action on the Like button's wrapper, the old one data-testid on the button.
function likeSlot(article) {
  const slot = article.querySelector('[data-engagement-action="like"], [data-engagement-action="unlike"]')
  if (slot) return slot
  return article.querySelector('[data-testid="like"], [data-testid="unlike"]')?.parentElement ?? null
}

function replyControl(article) {
  const reply = article.querySelector('[data-engagement-action="reply"], [data-testid="reply"]')
  return reply?.matches('a, button') ? reply : (reply?.querySelector('a, button') ?? null)
}

// A copy of X's Reply control with another icon, so the button gets X's own size, alignment and
// hover color in every kind of action bar. Reply never shows a pressed state, unlike Like.
function makeButton(reply) {
  const button = document.createElement('button')
  button.type = 'button'
  button.className = `${reply.className} postdeck-button`
  if (reply.hasAttribute('style')) button.setAttribute('style', reply.getAttribute('style'))
  for (const child of reply.childNodes) button.append(child.cloneNode(true))
  button.querySelectorAll('[data-animated-count], [data-testid="app-text-transition-container"]').forEach((count) => count.remove())
  for (const element of button.querySelectorAll('*')) {
    for (const { name } of [...element.attributes]) {
      if (name === 'id' || name.startsWith('data-')) element.removeAttribute(name)
    }
  }
  const icon = button.querySelector('svg')
  if (!icon) return null
  icon.setAttribute('viewBox', '0 0 24 24')
  icon.classList.add('postdeck-icon')
  icon.innerHTML = ICON_ADD
  button.title = 'Add to Postdeck'
  button.setAttribute('aria-label', 'Add to Postdeck')
  return button
}

function addButton(article) {
  if (article.querySelector('.postdeck-button')) return
  const slot = likeSlot(article)
  const reply = replyControl(article)
  const button = slot && reply && makeButton(reply)
  if (!button) return

  const wrapper = document.createElement('div')
  wrapper.className = `${slot.className} postdeck-slot`
  button.addEventListener('click', (event) => {
    event.preventDefault()
    event.stopPropagation()
    send(article, button)
  })
  wrapper.append(button)
  slot.after(wrapper)
}

async function send(article, button) {
  if (button.dataset.state === 'sending') return
  const post = readPost(article)
  if (!post) {
    showToast("Postdeck couldn't find this post's link, so it can't add it.")
    return
  }

  button.dataset.state = 'sending'
  let reply
  try {
    reply = await chrome.runtime.sendMessage({ type: 'postdeck:add', post })
  } catch {
    reply = { ok: false, error: 'reload' }
  }

  if (!reply.ok) {
    delete button.dataset.state
    if (reply.error === 'offline') showToast("Postdeck isn't running. Open the app and click again.")
    else if (reply.error === 'reload') showToast('Postdeck was updated. Reload the page and click again.')
    else showToast(`Postdeck couldn't add this post. ${reply.error}`)
    return
  }

  button.dataset.state = 'added'
  button.querySelector('.postdeck-icon').innerHTML = ICON_ADDED
  const messages = {
    added: `Added to “${reply.deck}”, slide ${reply.count}`,
    updated: `Updated the slide in “${reply.deck}”`,
    exists: `Already in “${reply.deck}”`,
  }
  const message = messages[reply.status] ?? messages.added
  showToast(post.truncated ? `${message}. X cut the text short, so open the post and click again to get all of it.` : message)
}

function showToast(message) {
  let toast = document.getElementById('postdeck-toast')
  if (!toast) {
    toast = document.createElement('div')
    toast.id = 'postdeck-toast'
    toast.setAttribute('role', 'status')
    document.body.append(toast)
  }
  toast.textContent = message
  toast.classList.add('postdeck-visible')
  clearTimeout(toast.hideTimer)
  toast.hideTimer = setTimeout(() => toast.classList.remove('postdeck-visible'), 4000)
}

let scheduled = false

// Quoted posts are articles too, but they have no Like button, so they get no Postdeck button.
function scan() {
  scheduled = false
  document.querySelectorAll('article').forEach(addButton)
}

new MutationObserver(() => {
  if (scheduled) return
  scheduled = true
  requestAnimationFrame(scan)
}).observe(document.body, { childList: true, subtree: true })

scan()
