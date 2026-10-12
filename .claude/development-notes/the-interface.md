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

## Added later on 2026-10-11, against `440ca41`: the sign-in and sign-up screens of Z's other project

Z: *"Next is login and sign-up screens and [Z's other project] has some. You can engage. Keep your engagement scoped that project has 100k+ line codebase."* The project is Z's own, the one accounts come from, so the rule on other people's code does not reach it; the read was kept to the screens. The agent listed its tracked files by name, and read two: its sign-in page, whole, and from its authentication module the outline of its functions and the part that draws and handles the sign-up page. It did not open the project's environment file, its database setup, or anything else.

**What Z's project has:**

- **A sign-in page:** one centered card, about 380 pixels wide with rounded corners, holding the logo, the name, one line of text, a single full-width button, *Sign in with Nextcloud*, with Nextcloud's mark, and a footer line saying access is limited to linked accounts. The page uses the system's fonts. There is no password field: that project signs in through Nextcloud only.
- **A sign-up page**, reached after Nextcloud has verified someone who has no account yet. The same card says who is signing in and asks for a username, 1 to 50 characters, with a *Create account* button. A username that is too long or already taken is reported on the card, in red, and the page stays open for ten minutes.
- **Two refusals,** sent as bare text rather than pages: self sign-up is switched off and an admin has to link the account; or the account is deactivated and an admin has to reactivate it.
- **A switch for self sign-up** that the admin sets, kept in the database so that it takes effect without a restart, and checked again at the moment an account is created.

**What the agent proposed for AIconman,** keeping that template, in AIconman's palette and depth:

- **Sign in:** the same card, raised; the brand as the title; a username and password form with *Sign in* as the main button; then *Sign in with Nextcloud*; and a footer saying AIconman is for a local network or a VPN. Each way in appears only when it is set up.
- **Sign up:** for a password account, a username, a password and its repetition; for Nextcloud, Z's project's flow, where Nextcloud verifies and the person chooses a username.
- **First run:** while no account exists, the sign-in card asks for the admin account instead, by password or Nextcloud, and leads on to the connections.
- **Refusals and errors** on the card, as red bands, rather than as bare text.
- **The admin interface** has the switch for self sign-up, with the users and the connections.

**Raised for Z:** the mark on the Nextcloud button in Z's project is Nextcloud's own logo, drawn inline. That is someone else's artwork and a trademark, so whether and how AIconman may show it is a question for a source of its own, Nextcloud's terms for its brand; until then the button can carry a Tabler icon and the words.

## Added later on 2026-10-11, against `440ca41`: Z's answers on accounts

1. **Self sign-up is open by default, and the admin can limit it.** Z: *"Self signup open by default, admin can limit it."*
2. **A password has at least 16 characters, with at least 2 uppercase letters, 2 lowercase letters, 2 digits and 2 symbols.** Z: *"16 char min 2 uppercase 2 lowercase 2 number 2 symbol minimum"*.
3. **The Nextcloud button gets a design of its own.** Z: *"Nextcloud's mark is used on that project because only login is via nextcloud on that project. There is no password path. We need a different button."*
4. **Errors and refusals are red bands on the card.** Z: *"red band is good"*.
5. **The admin can create an account for someone, but cannot link it to Nextcloud.** Z: *"Admin should be able to create an account but cannot link it to Nextcloud. (In [Z's other project] that message is there but the mechanism is not therer yet lol)"*. So an account the admin creates is a password account, and a Nextcloud account is created only by its owner, signing in with Nextcloud.
6. **The first account is created like any other.** Z: *"The account creation does not need to say create an admin account, we will assign the admin to the first human user. IT will be done by database."* So no screen says "admin": the database makes the first human user the admin, and the first-run card is the ordinary sign-up card.

**What follows for the screens,** as the agent drew them after these answers:

- **Sign in:** the raised card with the brand as its title; username and password with *Sign in* as the main button; *or*; a second, raised button, *Sign in with Nextcloud*, with an icon of AIconman's choosing rather than Nextcloud's mark; *Create an account* while self sign-up is open; and the footer line about a local network or a VPN.
- **Sign up with a password:** username, password and its repetition, with the five password rules shown as a checklist that ticks off as they are met, and *Create account*.
- **Sign up with Nextcloud:** Nextcloud verifies the person, who then chooses a username.
- **When the admin has limited sign-up:** *Create an account* is not shown, and a Nextcloud identity with no account gets a red band telling the person to ask the admin for an account.
- **First run:** while no account exists, the page opens on the sign-up card, and after it the new account is led to the connections.
- **The icons** for these screens are not in the set already fetched from Tabler; R-013 in `dev/READING-LOG.md` would fetch them, for Z to clear.

**Open, raised with Z:** what "limit" covers, whether a switch that closes self sign-up or something finer; and how a person gets into an account the admin created, whether with a first password the admin sets and the person must change at first sign-in, or otherwise.

## Added later on 2026-10-11, against `440ca41`: Z corrects the screens

- **The Nextcloud button keeps Nextcloud's logo, and the two ways in are separate buttons.** Z: *"Nextcloud button here still can use the Nextcloud logo here. When I said different button I meant the password login button, and nextcloud buttons will have to be separate. I think it is a fair use of their logo, as we are utilizing their login."* The agent had read *"We need a different button"* as being about the Nextcloud button. Where the logo's file comes from is open, below.
- **The password rule and the admin's limit stand as proposed.** Z: *"Password rule sounds good. Admin limit sounds good."*
- **First run is just signing in.** Z: *"First run, does not need to be complicated. The person can just log in, the system might show disabled with a message "Add an LLM connection (only the administrator can add a connection, if you are seeing this message contact your administrator" or something."* So nothing leads the first account anywhere: with no connection, the chat is disabled and says so.
- **Every account can have both a password and Nextcloud**, and links the other one later from its profile settings. Z: *"All accounts will have password and Nextcloud options. People should be able to connect their accounts later, from their profile settings."* This widens answer 5 above: the admin cannot link an account to Nextcloud, but its owner can.
- **Limiting sign-up closes it completely**, and then only the admin creates accounts. Z: *"Closes sign-up completely, only admin can create an account."*
- **The admin sets a first password, and the person changes it at first sign-in.** Z: *"Admin sets a password and user changes it at first sign in."*

**The screens, rendered** in the four themes with the icons of R-010 and R-013, in the agent's scratchpad: sign in, with a red band for a wrong password; sign up, with the password checklist; choosing one's own password at first sign-in; and the chat with no connection, its input and *Send* disabled, saying *"Add an LLM connection to start. Only the administrator can add one. If you are seeing this, please contact your administrator."* The Nextcloud logo is drawn as a labeled placeholder there, since its source is open. All four screens read in all four themes, with one exception: the disabled *Send* is a faded orange, and in light HC its white text all but disappears into it. Disabled controls are exempt from contrast targets, but they still need a look of their own per theme rather than a faded main button.

**Open:**

- **Where the Nextcloud logo comes from.** Z's other project draws it inline, but the artwork is Nextcloud's, and Nextcloud's own brand resources are the source that would also say how the mark may be shown. Fetching them would be a reading-log entry.
- **The profile settings screen,** where the other way in is linked and the password is changed, is not designed yet.

## Added later on 2026-10-11, against `440ca41`: the Nextcloud logo's sources, and profile settings

Z, on where the logo comes from: *"Prepare reading log. We can use from fonts awesome too?"* The agent wrote R-014, Nextcloud's brand and trademark pages, and R-015, Font Awesome's Nextcloud icon, in `dev/READING-LOG.md`. To name them exactly it requested only the headers of the candidate addresses: both Nextcloud pages and Font Awesome's icon file exist, and GitHub does not name a single license for Font Awesome, so its license file is the source for it.

Z, on profile settings: *"Yes. we need this."* The agent drew one page of six sections, rendered in the dark and light themes in its scratchpad:

- **Account:** the username, the role, and the ways the account signs in.
- **Password:** the current password, the new one and its repetition, the password checklist, and *Change password*. An account created through Nextcloud has no password, and sees *Set a password* without the current one.
- **Nextcloud:** *Link Nextcloud* while it is not linked; once linked, the Nextcloud account it is linked to, and *Unlink*. Unlinking is refused while the account has no password, so that no one can lock themselves out.
- **Theme:** follow the device, dark, light, dark with high contrast, light with high contrast.
- **Your chats:** export everything as JSON or as Markdown, and import JSON.
- **Sessions:** sign out, and sign out everywhere else.

**Open, raised with Z:** whether a person can change their username; whether a person can delete their own account and chats, or only the admin can; and whether *Sign out everywhere else* belongs in the first version.

## Added later on 2026-10-11, against `440ca41`: profile answers, and the Nextcloud logo

**Profile settings.** Z answered yes to all three: a person can change their own username, a person can delete their own account and chats, and *Sign out everywhere else* is in the first version. Profile settings gains a username field and *Delete my account*.

**The Nextcloud logo.** R-014 and R-015 were read (`dev/READING-LOG.md`):

- **Nextcloud's terms:** the brand page acknowledges fair use without saying what qualifies, and the trademarks page allows identifying a project as compatible with Nextcloud *"only [...] for non-commercial purposes"*. The guide asks for blue `#0082C9` on white and white on blue or on images, a clear space of half the mark's height, a smallest web width of 50 pixels, and no alteration.
- **Font Awesome's icon** is under CC BY 4.0, which needs its embedded attribution kept, and its brand icons may be used only to represent what they refer to.
- **Z's ruling:** *"My read of this is we can because we connect to a nextcloud instance and this is not a commercial product."* So the *Sign in with Nextcloud* button shows Nextcloud's logo.
- **Rendered at the size of a button**, both available files show the full logo, the mark with the word "Nextcloud" beneath it, and the word shrinks past reading while repeating the button's own words. The button wants the mark alone, which the brand guide says Nextcloud provides, behind the press page's link. R-016 would read that section, for Z to clear. Drawn at the button's size, the mark alone would also sit below the guide's 50 pixel smallest width; Z's ruling stands on fair use.

## Added later on 2026-10-11, against `440ca41`: the mark alone, from Font Awesome's drawing

Z: *"Question: can't we use logo without nextcloud written under it? If font awesome is providing logo I think we can still use it. Nextcloud word is on the button."*

The agent's answer was yes, on two grounds. Font Awesome's icon is under CC BY 4.0, which allows adapting it as long as the attribution stays and the change is said. And Nextcloud's brand guide treats the logo without the word as a variant of its own, so the mark alone is a form Nextcloud uses rather than a new alteration; that is the agent's reading of the guide, under Z's ruling on fair use.

**The crop changes only the frame.** Rendering Font Awesome's icon showed the mark from y 46 to 337 of its 640 by 512 grid and the word from y 381 to 465, with nothing between. Setting the SVG's `viewBox` to the mark, with 4 units around it, leaves every path exactly as Font Awesome drew it and the attribution comment in place, which the agent checked by comparing the paths of the two files. Rendered on the *Sign in with Nextcloud* button in the four themes, in white on the dark backgrounds and `#0082C9` on the light ones, the mark alone reads as a clear icon beside the button's words, where the full logo's word shrank past reading.

If Z takes this, R-016, Nextcloud's own files of the mark alone, is not needed. When the file enters the repository, it says in a comment beside Font Awesome's that its frame was cropped to the mark, and `SOURCES.md` says so too, as CC BY asks.

**Z took it:** *"I think I'll go with this R-016 is not needed. We can move on to Admin interface."* The button shows Font Awesome's mark, cropped by its frame, and the icon is on the approved list in `CLAUDE.md`. R-016 was not read; its *Cleared* line is Z's to mark.

## Added later on 2026-10-11, against `440ca41`: the admin interface

The agent drew the admin interface as one page with two tabs, rendered in the dark and light themes in its scratchpad; the tab in use is drawn pressed.

- **Users:**
  - a *Sign-up* card with the switch *Anyone can create an account*, on by default, and the line *When off, only you can create accounts.*;
  - *Create account*, which asks for a username and a first password, and marks the account as having to change it;
  - the list of accounts, each with its role, the ways it signs in (a key for a password, Nextcloud's mark for Nextcloud), its status (active, must change password, deactivated), and four actions: edit, reset password, deactivate, delete.
- **Connections:**
  - the list, each with its name, base URL, protocol (detected or set), whether a key is saved, and the result of its last check: the number of models, or a red band such as *Unreachable*;
  - beside it, the selected connection's editor: name; protocol, showing *Detect* with what was found; base URL; the key, shown as saved with *Replace*; *Check*; *Save*;
  - and its models, each with what it can do (chat, images, speech, which the admin can switch) and its context window, marked as reported by the server or set by the admin.

**One correction while rendering:** the first render drew the delete icon in the error red, which as a thin icon on the dark background has the 2.2:1 contrast that made errors into bands. Icons keep the text color; the red belongs to the confirmation that follows a delete.

**Open, raised with Z:** whether the admin can make other accounts admins; whether resetting a password sets a new first password that must be changed; whether the admin can delete accounts, and their chats, as well as deactivate them; and the agent's proposal that the only admin cannot remove their own role, or deactivate or delete their own account.

## Added later on 2026-10-11, against `440ca41`: Z's answers on the admin's powers

1. **An admin can make other accounts admins.** Z: *"Yes."*
2. **Resetting a password:** Z: *"Reset password, for now only warns the admin, Admin sets a new pasword and the user needs to change it in the next login."* So the admin is warned before going on, sets a new password, and the person must change it at their next sign-in.
3. **An admin can delete accounts.** Z: *"They can delete"*.
4. **Only an admin can give up their own admin role**, and no other admin can take it from them; and when they are the only admin, the system refuses. Z: *"Only an admin can change their own status from admin to user, other admins cannot do this. But if the admin is the only admin the system rejects. This again exists in [Z's other project's] schema. We will ensure all these through database."*

Z: *"We will deal with all these when we are working on the database."* So these four are rules for the database to enforce, settled here and built with it.

## Added later on 2026-10-11, against `440ca41`: the last three before the design closes

The agent listed what it took to be left: disabled controls, the chat screen drawn whole, and the phone layout, worth settling before building; and choosing several messages to export, confirmation dialogs, and text sizes and spacing, which can be settled while building. Z: *"Let's do 1-3 and finish the design."* Disabled controls are in `the-palette.md`. The other two were rendered in the agent's scratchpad.

**The chat screen at a desktop width**, in the dark and light themes:

- **The sidebar:** the brand; *New chat*; the conversations by day, the open one on the message background with a bar in the accent color; and at the foot *Transcribe*, *Administration* for an admin, and the person's own name, which opens profile settings.
- **The top bar:** the model picker, showing the model and its connection; the context meter, its numbers above a thin bar in the brand blue; and the conversation settings.
- **The conversation:** the person's message in a bubble on the right, with an attached image as a thumbnail; the reply on the left, under its model's name in coral, with the reasoning collapsed in lilac and the count of its hidden lines; the reply formatted, with a list, inline code, a code block with *Copy*, and a link in the accent color; under the reply, copy, regenerate and export; and a failed request as a red band with *Retry*.
- **The composer:** buttons for an image and the microphone, the message field naming the model, and *Send*, which becomes *Stop* while a reply streams.

**A second sheet**, in the dark and light themes: the model picker open, its models grouped by connection, the selected one ticked, a chip where a model reads images, and a line saying speech models are under *Transcribe*; *Conversation settings*, with the system prompt and the output limit set against the model's window; and *Transcribe*, with a place to choose or drop an audio file, the speech model and the language, *Transcribe*, the transcript, and *Copy*, *Download* and *Start a chat*.

**The phone layout**, at 390 pixels wide, in dark, dark with the list open, light, and dark HC: a top bar with the list button, the model picker, the context numbers and the conversation settings, and the meter's bar along its bottom edge; the conversation at the phone's width; the composer's *Send* as an icon; and the list opening as a drawer over the dimmed conversation. The first render stacked the numbers above the settings icon in the corner; they now sit on the same line.

**Left for the building:** choosing several messages to export, confirmation dialogs, and text sizes and spacing.

The renders depend on the Tabler and Font Awesome files fetched into the agent's scratchpad, which the reading log keeps out of the repository, so the scripts that draw them stay there too; this note and `the-palette.md` are the design's record.

## Added later on 2026-10-11, against `440ca41`: confirmation dialogs, and two items for the polishing

Z: *"Let's build confirmation dialogs. We should defer last two for after everything is done when we are polishing the app."* The agent read *build* as designing them, since nothing is coded before the design is done, and Z confirmed it: *"Righr"*.

**Deferred to the polishing, after everything else is done:** choosing several messages to export, and text sizes and spacing.

**The confirmation dialogs** share one form: a raised card over the dimmed screen, its title beside an icon, a close button, and two buttons at the foot. *Cancel* is on the left and holds the focus, so that pressing Enter in a destructive dialog cancels rather than confirms. A destructive action is a button in the error band's red with white text; any other action is the main button's orange. Five were drawn, rendered in the four themes in the agent's scratchpad:

1. **Delete a conversation:** its name and number of messages, a red band saying it cannot be undone, and *Delete*.
2. **Delete your account:** the account and all its chats, the same band, and the username typed to confirm; *Delete my account* stays disabled until the typed name matches.
3. **Reset a password,** for the admin: the warning Z asked for, in the warning color beside a warning icon, saying the current password stops working now and must be changed at the next sign-in; the new password with its checklist; and *Reset password*.
4. **Remove a connection,** for the admin: its models disappear for everyone, while conversations keep their messages and can continue with another model; and *Remove*.
5. **Give up admin, as the only admin:** the refusal as a red band, and *Close*.

**What the render showed:** in dark HC the disabled *Delete my account* carries the strong border that high contrast gives disabled controls, and looks nearly the same as an enabled outlined button. The agent proposes a line under the field saying what enables the button, such as *Type alex to enable*, in every theme, so that the state does not rest on color alone.

## Added 2026-10-12, against `b2b18b1`: refreshing the models

The agent pointed out, while building the connections in the database, that only an admin's session could record a check, so the model lists could not be refreshed without an admin signed in. Z: *"Let's set up a cronjob (every 30 mins), and put a button on the admin panel for faster refresh."* So the models of every connection are refreshed every 30 minutes by a job that cron runs, and the *Connections* tab of the admin panel gets a button that refreshes every connection at once, beside each connection's *Check*. Neither is built yet: both need the backend's code that talks to the model servers. The database's side is in `the-database.md`.
