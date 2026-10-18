# Product: what Aash does

A small pixel character, the same one as on aarshj.me, lives in the macOS menu bar. It idles and
blinks, goes for a short walk now and then, sleeps at night, chats when clicked and waves when one
of your reminders is due. It must never slow the Mac down or get in the way.

Source: the research doc "Menu bar buddy: research" (17 Oct 2026), with the changes listed in
[decisions.md](decisions.md).

## v1 does

| Area | Behaviour |
|---|---|
| **Lives in the menu bar** | A status item shows the buddy. No Dock icon. Opens at login if you turn that on. |
| **Idles** | A still frame that blinks every 3–6 seconds. |
| **Walks** | Every 5–15 minutes it walks a short way left of its home, rests and walks back. By default it walks inside its own icon, which widens for the walk and shrinks after. With Accessibility allowed, it can walk the free part of the menu bar instead. With Reduce Motion on, it stays home. |
| **Sleeps** | From 23:00 to 07:00 it sits with its eyes closed and doesn't move. |
| **Pauses** | Screen asleep, Mac locked, Low Power Mode on, or menu bar hidden: everything stops. |
| **Chats** | Left-click opens a small popover. Ask a question, or use one-click actions on the clipboard: summarise, rewrite, explain. Replies stream in. Gemini answers; it needs your free API key. |
| **Reminders** | Type "remind me to submit the lab report at 6" in the chat. It becomes a real Apple Reminders item with an alert on the Mac. (The user's phone is Android, so there's no phone sync.) A few seconds before it's due, the buddy waves. Each morning the menu shows how many reminders are due today. |
| **Ask Claude** (Phase 5) | An optional button that sends a hard question to Claude through the Claude Code CLI you already have. |
| **Menu** | Right-click: Chat, Walk now, Walking on/off, Open at login, Settings…, Quit. |
| **Settings** | Gemini API key, model, walking on/off, free walk (Accessibility), open at login. |

## v1 doesn't

- No Apple on-device model. It would add memory pressure on an 8 GB Mac.
- No SwiftUI, no Electron, no third-party libraries.
- No private task database: Apple Reminders is the store.
- No notifications of its own: the Reminders alert is the notification.
- No App Store build or sandbox. It's a personal build, signed locally.
- No conversation history kept on disk. A chat lasts until the popover closes.

## Principles

1. **Tiny.** Idle under 0.5% CPU, at most 1 wake-up a second, at most 30 MB
   ([performance.md](performance.md)).
2. **Never in the way.** It never covers menus or other icons, never steals focus, and it's silent.
3. **Private by default.** Nothing leaves the Mac unless you send a chat. Keys live in the Keychain.
4. **Works offline.** Everything except chat works without a network.

## Later ideas (not v1)

- Share the website's live sky and music mood: sleep with the real sunset, dance when music plays.
- Seasonal outfits, matching the website's character ideas.
- A small mini-game on a hidden shortcut.
