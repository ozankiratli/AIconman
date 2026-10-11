# The interface

**Written 2026-10-11, against the tree at `e1866f4`.** Nothing had been built.

This is the second part of the design: the screens, how they are laid out, and what holds across all of them. The agent proposed it, and this note records the proposal as the agent's and Z's answers in Z's words. Z accepted the five defaults, added high-contrast themes, and then changed the scope with accounts (`product-brief.md`), which changes three things in the proposal.

## The proposal

**Screens**

1. **Login.** One button that lets the user in, with a line under it saying AIconman is meant only for a local network or a VPN.
2. **First run.** With no connections yet, the page says so and leads to adding one.
3. **Connections.** Each has a name, a base URL, a key that shows as saved and can be replaced but not read, and a protocol: Detect, OpenAI-compatible or Ollama. A Check button runs the detection and shows what answered and which models were found. Each model shows what it can do and its context window: reported values are filled in, missing ones are entered, and any can be overridden.
4. **Chat.**
   - The conversation list: new, rename, delete, newest first.
   - The messages: each reply labeled with the model that wrote it, streaming with a Stop button, Copy on code blocks, thumbnails of attached images, and errors shown in the conversation with Retry.
   - The composer: Enter sends and Shift+Enter starts a new line, with a Send button on a phone. An image button appears only when the model reads images. A microphone button appears only when a speech model exists, and is disabled, with the reason, when the page is not on HTTPS.
   - The top bar: a model picker grouped by connection, listing only models that chat, and the context meter, marked as an estimate where the count is not exact.
5. **Transcribe.** An audio file, a speech model and an optional language give the text, which can be copied, downloaded, or used to start a chat.
6. **Settings.** The theme, the connections, and clearing all local history.

**Layout**

```
Wide                                          Narrow (phone)
+--------------+-----------------------------+ +---------------------------+
| AIconman  [+]| [qwen3-4b (pi) v] ~1.2k/4k * | | [=] [qwen3-4b v] ~1.2k/4k |
|              |-----------------------------| |---------------------------|
| Today        | You: ...                    | | You: ...                  |
|  Trip plan   | qwen3-4b: ...               | | qwen3-4b: ...             |
|  Recipe      |   > Reasoning (collapsed)   | |                           |
| Yesterday    |                             | |                           |
|  ...         |-----------------------------| |---------------------------|
| Transcribe   | [img][mic] Message... [Send]| | [img][mic] Message [Send] |
| Connections  |                             | +---------------------------+
+--------------+-----------------------------+   [=] opens the list as a drawer
```

**Across every screen**

- Everything from a server or a model is untrusted text. It reaches the page as text, never as markup, and the formatter escapes everything first.
- The page loads nothing from outside the user's network: no fonts or scripts from a CDN.
- Chat history lives in the browser, and the backend never stores conversations.
- Everything is reachable from the keyboard, with a visible focus ring; contrast is settled with the palette.

**Defaults, for Z to accept or change**

1. Replies are formatted from a subset of markdown (paragraphs, headings, lists, bold and italic, inline code, code blocks, tables) by a short renderer of AIconman's own, rather than a library.
2. The first version has new, rename, delete, stop, copy, regenerate the last reply, edit and resend the last message, and export and import of history as a file.
3. Each conversation has a system prompt and an output limit.
4. The model can be switched mid-conversation, and each reply is labeled with its model.
5. A model's reasoning is shown as a collapsed block above its answer.

## Z's answers

Z: *"OK. Your solutions are mostly true see below. From your ideas, let's add a high contrast palette for both dark and light modes. I like the idea. Defaults accepted."*

- **The five defaults stand.**
- **Four themes:** dark, which is the default, light, and a high-contrast version of each. They are the third part of the design.

## What the accounts change

Z then added accounts, with chats kept per person in PostgreSQL (`product-brief.md`). Against the proposal:

- **History moves to the server.** Chats are stored by the backend, per account, not in the browser. The bullet under *Across every screen* that says otherwise no longer holds, and neither does clearing local history in Settings.
- **The login screen is a stand-in.** Signing up and signing in, with a password or through Nextcloud, replace the one-button screen once accounts are wired, which Z put after the interface is confirmed.
- **Export and import** were proposed so that history would not be stuck in one browser. With history on the server, that reason is gone, though the default was accepted.
- **Open:** whether connections and their keys belong to the household or to each account.

## Added later on 2026-10-11, against `e1866f4`: connections, an admin, and export

**Connections belong to the household.** Z: *"Connections to LLMs belong to the household. Needs to be established at the initial setup or by the admin user. The first human user in the system. (We might need an admin interface)."* So the first account created is the admin. The connections are set up during the first run or later by the admin, and the Connections screen is the admin's. An admin interface may follow. Z points to the same project of Z's own as for accounts.

**Export and import stay**, at three sizes. Z: *"I like export and imports should stay, full chat, one message or multiple."* So a whole conversation, one message, or several chosen messages can be exported, and imported.

**The colors** of the screens are in `the-palette.md`. One choice there belongs to the layout: the model name is shown in coral in the chat, and not in the top bar.

## Added later on 2026-10-11, against `e1866f4`: the remaining design topics

The agent listed eight topics it took to be still open, and Z answered each.

1. **Accounts and first run.** The sign-in and sign-up screens use the template of the same project of Z's own that accounts come from, with a few changes, in AIconman's colors. Z liked the first-run flow: the first account is the admin, who then adds the connections. The admin interface covers *"users and connections only for now. We might add later."*
2. **Typography.** Z: *"We need to choose a font for the brand. But I say we keep it simple and let the system serve? What do you think otherwise a sans font is fine ubuntu or dejavu works."* Open: the agent's answer is below Z's question in the conversation, and the choice is Z's.
3. **Depth.** Z: *"I'd like the neumorphic shadows."*, the style of Z's website.
4. **Icons.** Z: *"We can use a well known library."* Which library is open; a library is approved by name under *Other people's code* in `CLAUDE.md`.
5. **Export and import.** Asked whether the file format is JSON, Markdown or both, Z: *"Both."*
6. **The context meter** is text with a thin bar.
7. **Themes.** AIconman follows the device's dark or light setting until the user picks a theme, and high contrast is chosen in Settings. Z: *"That works"*.
8. **Empty and first-run states** get wording of their own: no conversations, no connections, and a connection that fails its check. Z: *"That works."*

## Added later on 2026-10-11, against `e1866f4`: fonts, icons and import

- **Fonts.** The agent proposed letting the system serve the interface text and bundling one font for the brand, so that the brand looks the same on every device. Asked whether that font is DejaVu Sans Bold, Z: *"Dejavu Sans Bold is Fine."* Then Z asked a design question: *"Should we use a serif font for the title, more handwritten kind of feeling"*. The agent rendered the title in the serif fonts on this machine and in one handwritten font (`the-palette.md`); the choice is Z's.
- **Icons.** Z: *"Propose a few. Having difficulty on this."* The agent proposed four libraries, and wrote reading-log entries, R-009 to R-012, to fetch the icons AIconman needs from each and render them side by side, for Z to clear.
- **Import reads JSON only.** Export writes JSON and Markdown; Markdown is for reading, and only JSON comes back in. Z: *"I'd say JSOn for import, you're right."*

## Added later on 2026-10-11, against `e1866f4`: Tabler

Z: *"Tabler lookss fine. I cleared only R-010 for now. Rejected 12. Left 2 not cleared unless we have a reason not to use Tabler."* R-010 was read. Tabler has every icon on AIconman's list in outline, and filled versions of all but six (refresh, upload, log out, server, plug and the waveform); its license is MIT (`dev/READING-LOG.md`, R-010). Drawn in the four themes, the outlines read cleanly at their 2 pixel stroke, and an outline icon on a raised button with its filled version, in the accent color, on the pressed button pairs with the neumorphic depth. Lucide and Phosphor (R-009, R-011) stay unread unless a reason not to use Tabler appears; Material Symbols (R-012) was rejected.

## Added later on 2026-10-11, against `e1866f4`: the title, the brand and the icons, approved

Z: *"Source Serif Pro Bold Italic, b 2 tone, Tabler."*

- **The title** is set in Source Serif Pro Bold Italic, and the rest of the interface uses the system's fonts.
- **The brand** is the name in two tones, "AI" in blue and "conman" in green, without a glow (`the-palette.md`).
- **Tabler Icons is approved by name**, and so is Source Serif Pro; both are listed in `CLAUDE.md` with FastAPI.
