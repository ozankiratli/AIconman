# Reading log

Every read of another person's code, or of documentation published outside the project, is made the same way: named, recorded, cleared and done, in that order. The rule, and what it covers, are in `CLAUDE.md` under *Other people's code*.

This file is where the second and third steps happen:
- An entry is written **before** anything in it is opened.
- **Z writes the *Cleared* line.** The agent never writes it.
- After the read, the agent adds a *Done* line saying what was found and where it went.

Nothing in an entry is rewritten afterwards; an entry only gains lines. The entry ID is what a fact in `dev/facts/` cites.

```
## R-<number>: <source, in a few words>

- **Named:** <date>
- **Task:** <what the read is for>
- **Source:** <file or section>, at <commit, or URL and the date it was read>
- **Facts sought:** <which facts>
- **Not read:** <what stays closed>
- **Cleared:** <written by Z>
- **Done:** <date; what was found, and where it went>
```

## R-001: the OpenAI API reference, three endpoints

- **Named:** 2026-10-11
- **Task:** design, part 1, in `.claude/development-notes/the-backbone.md`: what the OpenAI-compatible protocol says about listing models, chatting and transcribing, so that the backend can relay it and the protocol detection knows what to test for.
- **Source:** the OpenAI API reference, https://platform.openai.com/docs/api-reference, as it reads on the day of the read: the sections on listing models, creating a chat completion, and creating a transcription. If the reference has moved, the new address is reported to Z before anything is read.
- **Facts sought:**
  - listing models: the path and method, and the fields of a model entry;
  - chat: the request fields a chat needs (the model, the messages and their roles, image parts, the output limit, streaming), the response fields, the token counts a response reports, and how a streamed response is framed and ended;
  - transcription: the path, the form fields (the file, the model, the language, the response format), and the response;
  - how a key is sent, and the shape of an error.
- **Not read:** every other section of the reference, the Responses API among them, and the guides.
- **Cleared:** 2026-10-11
- **Done:** 2026-10-11, not read: the source has moved. `https://platform.openai.com/docs/api-reference` answers with a permanent redirect (HTTP 301) to `https://developers.openai.com/api/reference/overview`. Only the response headers were requested. Reported to Z; the new address is named in R-006.

## R-002: Ollama's API documentation

- **Named:** 2026-10-11
- **Task:** design, part 1: what Ollama's own API reports about its models, so that the backend can take capabilities and context windows from it, and what the protocol detection can test for.
- **Source:** `docs/api.md` in github.com/ollama/ollama, on `main` on the day of the read, with the commit recorded under *Done*. That file only. If it has moved, the new place is reported to Z before anything is read.
- **Facts sought:**
  - listing models: the path, and the fields of a model entry;
  - a model's details: what it can do, its context length, and where each sits in the response;
  - chat: the request and response, the token counts it reports, and how a streamed response is framed and ended;
  - an endpoint that answers without a model being named, such as a version endpoint, as a signal for the detection;
  - whether the API counts tokens for a text;
  - whether any endpoint transcribes audio;
  - how an error is reported.
- **Not read:** every other file in the repository, the source code above all.
- **Cleared:** 2026-10-11
- **Done:** 2026-10-11.
  - **What was read:** `docs/api.md` at commit `eab97e9f92b9a25c2d52d2cc6c1b1c99bd9fae21` (committed 2026-10-09), fetched raw from GitHub. Its headings first, then the endpoint list, *Conventions*, *Generate a chat completion* (parameters, and the streaming, non-streaming and image examples), *List Local Models*, *Show Model Information* and *Version*, and a search of the whole file for errors, token counting and audio. The file opens with a note that Ollama's API docs *"are moving to https://docs.ollama.com/api"*; the file was still at its address, so it was read as cleared.
  - **What was found:** models are listed at `GET /api/tags`; what a model can do is `capabilities` in `POST /api/show`, which also gives the length the model was trained for in `model_info`; chat is `POST /api/chat`, streamed unless turned off; `GET /api/version` needs no model; no endpoint counts the tokens of a text or transcribes audio; the file describes neither its errors nor how a stream's objects are separated, and mentions no key. The detail is in `the-backbone.md`.
  - **Where it went:** `.claude/development-notes/the-backbone.md`, and `SOURCES.md`.

## R-003: the llama.cpp server's README

- **Named:** 2026-10-11
- **Task:** design, part 1: what an OpenAI-compatible llama.cpp server reports beyond the OpenAI protocol, about context size, token counting and images.
- **Source:** `tools/server/README.md` in github.com/ggml-org/llama.cpp, on `master` on the day of the read, with the commit recorded under *Done*. That file only. If it has moved, the new place is reported to Z before anything is read.
- **Facts sought:**
  - which OpenAI-compatible endpoints it serves;
  - what its model list returns beyond the OpenAI fields;
  - how a client learns the context size, and where it sits in the response;
  - whether it counts tokens for a text, and how;
  - whether it says if the loaded model accepts images;
  - whether it transcribes audio;
  - how a key is set on the server and sent by a client;
  - an endpoint that answers without a model being named, as a signal for the detection.
- **Not read:** every other file in the repository, the server's source above all.
- **Cleared:** 2026-10-11
- **Done:** 2026-10-11.
  - **What was read:** `tools/server/README.md` at commit `5c8854fd88319125125dc4b836c98b1b215b0f23` (committed 2026-10-11), fetched raw from GitHub. Its headings first, then *Multimodal support*, `GET /health`, `POST /tokenize`, `GET /props`, `GET /v1/models`, the opening of `POST /v1/chat/completions` through its multimodal input, the two token-counting endpoints, and the routing part of *Using multiple models* with its `GET /models`; and a search of the whole file for the key option and for audio. The multi-model part was read because the model list section says it has one element on a single-model server, which made the router's list part of what the model list returns.
  - **What was found:** the OpenAI-compatible endpoints it serves, with no transcription among them; a model list carrying `architecture.input_modalities` and `meta.n_ctx_train`; the context the server runs with, in `GET /props`; two ways to count tokens, one of them for a whole chat request; the key options, with examples that send `Authorization: Bearer`; and `GET /health`, which needs no key. The detail is in `the-backbone.md`.
  - **Where it went:** `.claude/development-notes/the-backbone.md`, and `SOURCES.md`.

## R-004: vLLM's OpenAI-compatible server documentation

- **Named:** 2026-10-11
- **Task:** design, part 1: what a vLLM server reports beyond the OpenAI protocol, about context length and token counting, and whether it transcribes.
- **Source:** the vLLM documentation page on its OpenAI-compatible server, https://docs.vllm.ai/en/stable/serving/openai_compatible_server.html, as it reads on the day of the read. That page only. If it has moved, the new address is reported to Z before anything is read.
- **Facts sought:**
  - which endpoints it serves: models, chat, transcription, token counting;
  - what its model list returns beyond the OpenAI fields, the context length in particular;
  - how a key is set on the server and sent by a client.
- **Not read:** every other page of the documentation, and the source.
- **Cleared:** 2026-10-11
- **Done:** 2026-10-11, not read: the page has moved. The address redirects to the same path ending in a slash, and that serves an 804-byte page holding nothing but a redirect to `../online_serving/`, which is `https://docs.vllm.ai/en/stable/serving/online_serving/`. Only the redirect page was fetched; the new address was not opened. Reported to Z; the new address is named in R-007.

## R-005: MDN on secure contexts and installable web apps

- **Named:** 2026-10-11
- **Task:** design, part 1, point 2: what a page served over plain HTTP on a local network cannot do, which the design gave from memory.
- **Source:** two pages of MDN Web Docs, as they read on the day of the read:
  - *Features restricted to secure contexts*, https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts/features_restricted_to_secure_contexts, with its parent page *Secure contexts* for what counts as one;
  - *Making PWAs installable*, https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Making_PWAs_installable.

  If either has moved, the new address is reported to Z before anything is read.
- **Facts sought:**
  - whether microphone access and service workers are restricted to secure contexts;
  - what counts as a secure context, `localhost` and a local network address over plain HTTP in particular;
  - what a browser needs before it offers to install a web app.
- **Not read:** every other MDN page.
- **Cleared:** 2026-10-11
- **Done:** 2026-10-11, not read: two of the three addresses have moved. Both *Secure contexts* pages answer with a permanent redirect (HTTP 301) from `Web/Security/Secure_Contexts/...` to `Web/Security/Defenses/Secure_Contexts/...`. *Making PWAs installable* answers at its address (HTTP 200), but was not read either, since the entry stops when either source has moved. Only the response headers were requested. Reported to Z; the new addresses are named in R-008.

## R-006: the OpenAI API reference at its new address

- **Named:** 2026-10-11
- **Task:** the same as R-001, whose source moved.
- **Source:** the OpenAI API reference, https://developers.openai.com/api/reference/overview, as it reads on the day of the read: the sections on listing models, creating a chat completion, and creating a transcription. `https://platform.openai.com/docs/api-reference` redirects there (R-001).
- **Facts sought:** the same as R-001.
- **Not read:** every other section of the reference, the Responses API among them, and the guides.
- **Cleared:** 2026-10-11
- **Done:** 2026-10-11.
  - **What was read:** pages fetched from developers.openai.com and read as text. From the overview, its *Authentication* and *Debugging requests* parts. Then *List models* (`/api/reference/resources/models/methods/list`); *Create chat completion* (`/api/reference/resources/chat/subresources/completions/methods/create`) with its *Streaming events* page (`/api/reference/resources/chat/subresources/completions/streaming-events`), read as part of the chat completion section for how a stream is framed; and *Create transcription* (`/api/reference/resources/audio/subresources/transcriptions/methods/create`). On each page, only the part on its endpoint.
  - **What was found:** a key is sent as `Authorization: Bearer`. `GET /models` returns entries with `id`, `created`, `object`, `owned_by` and an optional `shutdown_date`, and nothing about what a model can do or its window. Chat is `POST /chat/completions`; its stream is server-sent events of `chat.completion.chunk` objects ending with `data: [DONE]`; its counts are in `usage`. Transcription is `POST /audio/transcriptions`, with the form fields `file`, `model`, `language` and `response_format` among others, and returns `text`. The format of an error response is not in these sections: the overview points to an error-codes guide, which was not cleared. The detail is in `the-backbone.md`.
  - **Where it went:** `.claude/development-notes/the-backbone.md`, and `SOURCES.md`.

## R-007: vLLM's online serving documentation

- **Named:** 2026-10-11
- **Task:** the same as R-004, whose source moved.
- **Source:** the vLLM documentation page https://docs.vllm.ai/en/stable/serving/online_serving/, as it reads on the day of the read. That page only. The page R-004 named redirects there.
- **Facts sought:** the same as R-004.
- **Not read:** every other page of the documentation, and the source.
- **Cleared:** 2026-10-11
- **Done:** 2026-10-11, not read: the site refused. `https://docs.vllm.ai/en/stable/serving/online_serving/` answered HTTP 429 with a *"Just a moment..."* challenge page, to `curl` twice (the second time with a browser's user agent) and to the WebFetch tool once. No documentation reached the agent. Reported to Z.

## R-008: MDN on secure contexts and installable web apps, at the new addresses

- **Named:** 2026-10-11
- **Task:** the same as R-005, two of whose sources moved.
- **Source:** MDN Web Docs, as they read on the day of the read:
  - *Features restricted to secure contexts*, https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Secure_Contexts/features_restricted_to_secure_contexts, with its parent page *Secure contexts*, https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Secure_Contexts, for what counts as one;
  - *Making PWAs installable*, https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Making_PWAs_installable, unchanged from R-005.
- **Facts sought:** the same as R-005.
- **Not read:** every other MDN page.
- **Cleared:** 2026-10-11
- **Done:** 2026-10-11.
  - **What was read:** the three pages, fetched and read as text. On *Features restricted to secure contexts*, its list and the methods named after it; on *Secure contexts*, *When is a context considered secure?* and *Potentially trustworthy origins*; on *Making PWAs installable*, from *Installability* through *HTTPS, localhost, or loopback are required*, and *Installing sites as apps*.
  - **What was found:** service workers are available only in secure contexts, and `getUserMedia()`, which the microphone needs, requires one. A page is a secure context over HTTPS, from `localhost` or a loopback address, or from a file; `http://example.com` is listed as not secure. A browser promotes installing a web app only when the app has a manifest and is served over HTTPS or from `localhost` or `127.0.0.1`; a service worker is not required. The page also says that Chrome on desktop and Android, Safari on desktop and Edge on desktop let a user install any website as an app, regardless of the manifest criteria; it does not say whether that holds over plain HTTP. The detail is in `the-backbone.md`.
  - **Where it went:** `.claude/development-notes/the-backbone.md`, and `SOURCES.md`.

## R-009 to R-012: four icon libraries, for a comparison

These four entries share a task and a method, given once here; each entry names its source.

- **Task:** the design of the interface, `.claude/development-notes/the-interface.md`: Z asked for icon libraries to be proposed. The icons AIconman needs are drawn from each library side by side, in the four themes, so that Z can choose one to approve by name.
- **Method:** fetch the library's license file and the SVG files of the icons below, by name, from its repository at the commit current on the day of the read, recorded under *Done*. The SVG files are used only to draw a comparison image in the agent's scratchpad, and none is copied into the repository. If the repository's layout differs from the one named, the new place is reported to Z before anything is read.
- **Icons:** send, stop, microphone, image, plus, menu, settings, trash, pencil, copy, refresh, download, upload, sun, moon, contrast, user, log out, server or plug, chevron down, check, close, warning, and an audio file or waveform. Where a library has no icon for one of these, the comparison says so.
- **Facts sought:** the license; and for each icon, whether the library has it and how it is drawn: outline or filled, stroke width, grid size.
- **Not read:** any code, build script or documentation page of the libraries.

## R-009: Lucide

- **Named:** 2026-10-11
- **Source:** github.com/lucide-icons/lucide: `LICENSE`, and `icons/<name>.svg`.
- **Cleared:** Not cleared
- **Done:**

## R-010: Tabler Icons

- **Named:** 2026-10-11
- **Source:** github.com/tabler/tabler-icons: `LICENSE`, and `icons/outline/<name>.svg` with `icons/filled/<name>.svg` where a filled version exists.
- **Cleared:** 2026-10-11
- **Done:** 2026-10-11.
  - **What was read:** at commit `a4ce1404bc6d24d3c365afe7b258d6bf6f48d62d` (committed 2026-10-05) on `main`, fetched raw from GitHub: `LICENSE`, and for each icon on the list the outline SVG and, where one exists, the filled SVG, tried by name. The names used: `send`, `player-stop`, `microphone`, `photo`, `plus`, `menu-2`, `settings`, `trash`, `pencil`, `copy`, `refresh`, `download`, `upload`, `sun`, `moon`, `contrast`, `user`, `logout`, `server`, `plug`, `chevron-down`, `check`, `x`, `alert-triangle`, `file-music`, `wave-sine`.
  - **What was found:** the license is MIT, copyright Paweł Kuna, 2020 to 2026. Every icon on the list exists in outline. Six have no filled version: `refresh`, `upload`, `logout`, `server`, `plug` and `wave-sine`; and for the icons that are lines only, such as `plus`, `check` and `x`, the filled version is drawn the same as the outline. An outline icon is drawn on a 24 pixel grid with a 2 pixel stroke, rounded caps and joins, in `currentColor`, so it takes the color of the text around it.
  - **Where it went:** a comparison image of the icons in the four themes, outline and filled and on raised and pressed buttons, in the agent's scratchpad; `the-interface.md`; and `SOURCES.md`. No SVG file was copied into the repository.

## R-011: Phosphor

- **Named:** 2026-10-11
- **Source:** github.com/phosphor-icons/core: `LICENSE`, and `assets/regular/<name>.svg` with `assets/fill/<name>-fill.svg`.
- **Cleared:** Not cleared
- **Done:**

## R-012: Material Symbols

- **Named:** 2026-10-11
- **Source:** github.com/google/material-design-icons: `LICENSE`, and the Rounded style of each icon under `symbols/web/<name>/`, outlined and filled.
- **Cleared:** Rejected
- **Done:**

## R-013: more Tabler icons, for the account screens

- **Named:** 2026-10-11
- **Task:** the design of the sign-in, sign-up and admin screens, `.claude/development-notes/the-interface.md`: the icons those screens need, drawn on the cards in the four themes so that Z can see the screens whole. Tabler Icons is approved by name (`CLAUDE.md`), and R-010 fetched the icons of the chat screens.
- **Source:** github.com/tabler/tabler-icons, at the commit current on the day of the read, recorded under *Done*: `icons/outline/<name>.svg`, with `icons/filled/<name>.svg` where one exists, for these names: `cloud`, `login-2`, `lock`, `key`, `eye`, `eye-off`, `user-plus`, `users`, `circle-check`, `circle-x`. If a name does not exist, a near one is reported to Z before it is fetched.
- **Method:** as for R-009 to R-012: the SVG files are used only to draw a comparison image in the agent's scratchpad, and none is copied into the repository.
- **Facts sought:** whether each icon exists, and how it is drawn.
- **Not read:** anything else in the repository.
- **Cleared:** 2026-10-11
- **Done:** 2026-10-11.
  - **What was read:** at commit `a4ce1404bc6d24d3c365afe7b258d6bf6f48d62d`, the same as R-010, the outline SVG of each of the ten names, and the filled SVG where one exists.
  - **What was found:** all ten exist in outline, drawn as in R-010. Four have no filled version: `login-2`, `eye-off`, `user-plus` and `users`.
  - **Where it went:** a rendering of the sign-in, sign-up, first-password and no-connection screens in the four themes, in the agent's scratchpad; `the-interface.md`; and `SOURCES.md`. No SVG file was copied into the repository.

## R-014: Nextcloud's brand and trademark pages

- **Named:** 2026-10-11
- **Task:** the *Sign in with Nextcloud* button, `.claude/development-notes/the-interface.md`: Z decided that it shows Nextcloud's logo. What Nextcloud says about showing its logo, and where its own logo file is.
- **Source:** two pages of Nextcloud's website, as they read on the day of the read: https://nextcloud.com/brand/ and https://nextcloud.com/trademarks/. Both answered HTTP 200 to a request for their headers on 2026-10-11; nothing in them was read. And the logo file the brand page offers, if it offers one.
- **Facts sought:**
  - which logo files Nextcloud offers, in which formats and colors;
  - how the logo may be shown: its colors on dark and light backgrounds, the space around it, its smallest size, and changes that are not allowed;
  - whether another project may show it to say that it signs in with Nextcloud, and on what terms.
- **Method:** the logo file, if fetched, is used only to draw the account screens in the agent's scratchpad, and is not copied into the repository until Z decides where it comes from.
- **Not read:** every other page of Nextcloud's website.
- **Cleared:** 2026-10-11
- **Done:** 2026-10-11.
  - **What was read:** both pages as they read on the day, fetched and read as text: on the brand page, its *Nextcloud marks guide* and *Logo guide*, and the list of its colors; on the trademarks page, the passages on what the marks cover, on links and logos, and on *Apps, product and service names and compatibility references*. And the two logo files the brand page links to: `https://nextcloud.com/c/uploads/2022/11/logo_nextcloud_blue.svg` and `logo_nextcloud_white.svg`, in the same folder. The brand page's *Logo resources* link leads to the press page, which this entry does not cover, and was not followed.
  - **What was found:**
    - **The files:** the brand page links two SVG files, the logo in blue and in white. Both are the full logo, the mark with the word "Nextcloud" beneath it. The guide says logos without the text exist, and that the mark alone is *"Only to be used when there is no space for text due to size"*; those files are behind the press page's link.
    - **How it may be shown:** blue `#0082C9` on white, white on blue or on images; a clear space of half the mark's height on all sides; a minimum width of 50 pixels on the web; *"Do NOT alter or overlap the logo with other logos."*
    - **Fair use:** *"We acknowledge and support your right to make "fair use" of the Nextcloud marks, and do not mean to suggest with these guidelines that our permission is required in such cases."*
    - **Compatibility:** under *Apps, product and service names and compatibility references*, a project must not put a Nextcloud mark in its own name, and *"We also recognize that the Nextcloud Community needs some way to identify projects, products, and services that are compatible with Nextcloud. This is only allowed for non-commercial purposes."* Elsewhere the page asks that no use imply endorsement by the Nextcloud community.
  - **Where it went:** `the-interface.md` and `SOURCES.md`; the logo files only into a rendering in the agent's scratchpad.

## R-015: Font Awesome's Nextcloud icon

- **Named:** 2026-10-11
- **Task:** the same as R-014: Z asked whether Font Awesome's drawing of the Nextcloud logo could be used instead.
- **Source:** github.com/FortAwesome/Font-Awesome, on its default branch `7.x` at the commit current on the day of the read, recorded under *Done*: `LICENSE.txt`, and `svgs/brands/nextcloud.svg`. Both answered HTTP 200 to a request for their headers on 2026-10-11; nothing in them was read. GitHub's own reading of the repository's license is *"NOASSERTION"*, so the license file is the source for it.
- **Facts sought:** the license that covers the icon, and what it requires, attribution among it; anything the license file says about brand icons and their owners' trademarks; and how the icon is drawn.
- **Method:** the SVG file is used only to draw the account screens in the agent's scratchpad, and is not copied into the repository.
- **Not read:** any other file of the repository.
- **Cleared:** 2026-10-11
- **Done:** 2026-10-11.
  - **What was read:** at commit `14c65a3747d0f3b751f15831fc719236aea8729d` (committed 2026-07-15) on `7.x`, fetched raw: `LICENSE.txt`, whole, and `svgs/brands/nextcloud.svg`.
  - **What was found:** the license file is Font Awesome Free's. Icons packaged as SVG are under CC BY 4.0, fonts under the SIL Open Font License 1.1, and the code under MIT. Attribution is required, and the files carry it in an embedded comment that Font Awesome asks not to be removed. On brand icons: *"All brand icons are trademarks of their respective owners. [...] Please do not use brand logos for any purpose except to represent the company, product, or service to which they refer."* The icon is drawn in `currentColor` on a 640 by 512 grid, carries the attribution comment for Font Awesome Free 7.3.1, and is the full logo, the mark with the word "Nextcloud", like Nextcloud's own files.
  - **Where it went:** `the-interface.md` and `SOURCES.md`; the icon only into a rendering in the agent's scratchpad.

## R-016: Nextcloud's logo resources on its press page

- **Named:** 2026-10-11
- **Task:** the *Sign in with Nextcloud* button: the logo without the word "Nextcloud", which R-014 found the brand guide mentions but does not link. At the size of a button, the full logo's word cannot be read.
- **Source:** the logo resources section of Nextcloud's press page, https://nextcloud.com/press/#logo-resources, which the brand page's *Logo resources* link leads to, as it reads on the day of the read; and the file of the mark alone, in blue and in white, if the section offers them.
- **Facts sought:** which logo files the section offers, the mark alone among them, and any terms it attaches to them.
- **Method:** a file fetched is used only to draw the account screens in the agent's scratchpad, and is not copied into the repository.
- **Not read:** the rest of the press page.
- **Cleared:** Not cleared. Not necessary.
- **Done:**

## R-017: Nextcloud's OAuth2 addresses, and `/index.php/`

- **Named:** 2026-10-12
- **Task:** the default sign-in addresses in `config.yml.template`, which are made from `nextcloud.instance_address`. Do the authorize and token paths need `/index.php/` in front of `/apps/oauth2/...` to work on every Nextcloud, or only on one whose web server does not rewrite addresses? The paths in the template came from Z's other project, where they work against Z's Nextcloud. The agent's belief that `/index.php/` matters is from memory, not from a read.
- **Source:** Nextcloud's administration manual, as it reads on the day of the read: the OAuth2 page, https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/oauth2.html, and the section on pretty URLs, https://docs.nextcloud.com/server/latest/admin_manual/installation/source_installation.html#pretty-urls. If either has moved, the new address is reported to Z before anything is read.
- **Facts sought:** the authorize and token addresses as the OAuth2 page gives them; whether an address without `/index.php/` works only where pretty URLs are set up; and whether an address with it works either way.
- **Not read:** the rest of the manual; Nextcloud's source code; anything on the profile address, `/ocs/v2.php/cloud/user`, which has its own entry point and waits until Nextcloud sign-in is built.
- **Cleared:** 2026-10-12
- **Done:** 2026-10-12.
  - **What was read:** both addresses answered HTTP 200 to a request for their headers, so neither had moved. Both pages were fetched and turned into text. The OAuth2 page was read whole; its title names the *Nextcloud 36 Administration Manual*. Of the installation page, its headings were listed to find the section, and only *Pretty URLs* was read.
  - **What was found:**
    - **The addresses:** the OAuth2 page gives *"Authorization endpoint: https://cloud.example.org/apps/oauth2/authorize"* and *"Token endpoint: https://cloud.example.org/apps/oauth2/api/v1/token"*, without `/index.php/`, and then: *"Note that you must include index.php if pretty URL is not configured - i.e. https://cloud.example.org/index.php/apps/oauth2/api/v1/token."* The agent had remembered the page as giving the addresses with `/index.php/`; it gives them without, and the note covers the other case.
    - **Pretty URLs:** *"Pretty URLs remove the index.php-part in all Nextcloud URLs"*. They need the web server's `mod_env` and `mod_rewrite`, two settings in Nextcloud's `config.php` (`overwrite.cli.url` and `htaccess.RewriteBase`), and an `occ` command that updates `.htaccess`.
    - **Left open:** neither section says whether an address with `/index.php/` still works where pretty URLs are configured. The third fact sought is not in what was cleared. It goes to Z.
    - **Also on the OAuth2 page**, for when Nextcloud sign-in is built: *"Nextcloud supports only confidential clients."* A token *"has full access to the complete account including read and write permission to the stored files"*, since scopes are not supported, and the page says: *"Without scopes and restrictable access it is not recommended to use a Nextcloud instance as a user authentication service."* Apache strips the `Authorization` header by default, so a Nextcloud behind Apache needs `mod_headers`, `mod_rewrite` and `mod_env` for a bearer token to reach it. And a trusted application can skip the confirmation shown before login, through `occ config:app:set oauth2 skipAuthPickerApplications`.
  - **Where it went:** this entry and `SOURCES.md`. The template's default addresses are unchanged until Z decides.

## R-018: Ollama's documentation, for the gaps the connections and chat need

- **Named:** 2026-10-12
- **Task:** the backend's connections and chat, for Ollama's own API: gaps 1, 3 and 4 in `.claude/development-notes/the-backbone.md`, and a check of what R-002 found against the documentation Ollama now publishes, since `docs/api.md` said its API docs were moving.
- **Source:** docs.ollama.com, as it reads on the day of the read: the API's introduction, https://docs.ollama.com/api/introduction; its pages on chat, https://docs.ollama.com/api/chat, streaming, https://docs.ollama.com/api/streaming, and errors, https://docs.ollama.com/api/errors; the page on a model's details, at the address the introduction's list of pages gives; and https://docs.ollama.com/context-length. On 2026-10-12 only the headers of these addresses were requested: each answered HTTP 200, `/api` redirected to the introduction, and `/api/show` was not found.
- **Facts sought:** the context window a model runs with when the request does not set `num_ctx` (gap 1); how the objects of a stream are separated, and how an error is reported, in a stream and outside one (gap 3); the values a model's `capabilities` can take (gap 4); and what the chat endpoint takes for images and for the output limit, and what the model list and a model's details give, to check against R-002.
- **Not read:** the rest of the site; Ollama's source code.
- **Cleared:** 2026-10-12
- **Done:** 2026-10-12.
  - **What was read:** the introduction, chat, streaming, errors and context-length pages, fetched and turned into text. The chat page folds the parts of its request and reply under *Show child attributes*, which the text did not contain; they are in the page's own data, and were read there, for the fields named below. The introduction's list of the API's pages has no page for a model's details, so that page was not read; the model list has a page, `/api/tags`, which the entry did not name, so it was not read either.
  - **What was found:**
    - **Streams:** *"These responses are provided in the newline-delimited JSON format (i.e. the application/x-ndjson content type)"*, one object per line; the last has `"done": true` and a `done_reason`. With `"stream": false` the reply is one `application/json` object.
    - **Errors:** a JSON body `{"error": "..."}`, with the status codes 400, 404 (*"model doesn't exist, etc."*), 429, 500 and 502. *"If an error occurs mid-stream, the error will be returned as an object in the application/x-ndjson format with an error property. Since the response has already started, the status code of the response will not be changed."*
    - **The context window (gap 1):** *"Ollama defaults to the following context lengths based on VRAM: < 24 GiB VRAM: 4k context; 24-48 GiB VRAM: 32k context; >= 48 GiB VRAM: 256k context"*. The server's owner can set it with `OLLAMA_CONTEXT_LENGTH`, and `ollama ps` shows the context allocated to a loaded model. A request can set it with `options.num_ctx`, *"Context length size (number of tokens)"*. So the window in use is the server's, unknown to a client from these pages, unless the request sets it.
    - **Chat:** roles `system`, `user`, `assistant` and `tool`; a message's `images` is *"Optional list of inline images for multimodal models"*, each *"Base64-encoded image content"*; the output limit is `options.num_predict`, *"Maximum number of tokens to generate"*. A reply's `message` has `role` (*"Always assistant"*), `content`, `thinking` (*"Optional deliberate thinking trace when think is enabled"*) and `images`; the reply carries `done`, `done_reason`, `prompt_eval_count`, `prompt_eval_cached_count`, `eval_count` and durations in nanoseconds. `think` takes true, false, null, or a name the model defines, which *"/api/show"* lists.
    - **Also, from the introduction:** a local Ollama server also serves the OpenAI-compatible API, at `http://localhost:11434/v1`.
    - **Left open:** the values of `capabilities` (gap 4), since no page for a model's details is listed; and what the model list gives now, since its page was not named.
  - **Where it went:** `.claude/development-notes/the-backbone.md` and `SOURCES.md`.

## R-019: llama.cpp's server README, on the context window and its slots

- **Named:** 2026-10-12
- **Task:** the backend's connections and chat, for llama.cpp: gap 2 in `.claude/development-notes/the-backbone.md`, what the `n_ctx` a server reports means for one request; and a check of the fields R-003 found, at the current commit.
- **Source:** `tools/server/README.md` in github.com/ggml-org/llama.cpp, on `master` on the day of the read, with the commit recorded under *Done*: the rows of its table of options for the context size (`--ctx-size`), the number of slots (`--parallel`) and a unified cache (`--kv-unified`), if the table has them; and its sections on `GET /props`, `GET /slots`, `GET /v1/models` and `POST /v1/chat/completions/input_tokens`. On 2026-10-12 only the headers of the file's address were requested: HTTP 200.
- **Facts sought:** the window one request gets, and how several slots share the context; whether `/props` or `/slots` gives the window per slot; and the fields of the model list and of `/props` that R-003 found.
- **Not read:** the rest of the README; the server's source code.
- **Cleared:** 2026-10-12
- **Done:** 2026-10-12.
  - **What was read:** `tools/server/README.md` at commit `358a420ec4ed59b6b0be08b1d1f71dd478b99a99` (committed 2026-10-12), fetched raw: its headings, to find the sections; the three option rows; and the sections on `GET /props`, `GET /slots`, `GET /v1/models` and `POST /v1/chat/completions/input_tokens`.
  - **Two slips:** the search for the option `--kv-unified` also printed the row below it, `--kv-unified-per-slot`, which was not named; and the lines printed for `GET /slots` ran on into the next section, `GET /metrics`, its heading, its two opening sentences and its table of metrics. Neither was cleared. Both were reported to Z, and nothing in them is used until Z rules.
  - **What was found:**
    - **The options:** `-c, --ctx-size N`, *"size of the prompt context (default: 0, 0 = loaded from model)"*; `-np, --parallel N`, *"number of server slots (default: -1, -1 = auto)"*; `-kvu, --kv-unified`, *"use single unified KV buffer shared across all sequences (default: enabled if number of slots is auto)"*.
    - **`GET /slots`** lists each slot with its `id`, `n_ctx`, `is_processing` and `params` (`n_predict`, `max_tokens` among them); the example has two slots of `n_ctx` 65536 each. It is on by default, `--no-slots` turns it off, and `?fail_on_no_slot=1` makes it answer 503 when no slot is free.
    - **`GET /props`** gives `default_generation_settings`, which has a slot's fields, `id` and `n_ctx` (1024 in the example) among them, and is *"the default generation settings for the /completion endpoint"*; `total_slots`, *"defined by --parallel option"*; `modalities`, `{"vision": false}` in the example; `model_path`, `chat_template` and `is_sleeping`.
    - **The window (gap 2):** one request runs in a slot, and each slot reports its own `n_ctx`. The sections read do not say how `--ctx-size` and `--parallel` make a slot's `n_ctx`.
    - **`GET /v1/models`:** *"The returned list always has one single element. The meta field can be null (for example, while the model is still loading)."* `architecture.input_modalities` *"always has text, plus each media type that the model supports"*. `output_modalities` is `["text"]` by default, and *"This default is for compatibility only. It does not mean that the model can generate text."*; `decisions` in it marks *"a native decision model"*, served at `/v1/systemone`. Older servers can leave `architecture` out. The router gives the same `architecture` at `GET /models`. The `id` is the model file's path unless `--alias` sets one. `meta` has `vocab_type`, `n_vocab`, `n_ctx_train`, `n_embd`, `n_params` and `size`.
    - **`POST /v1/chat/completions/input_tokens`** takes a chat completion's body and answers `{"object": "response.input_tokens", "input_tokens": 11}`; *"This is not an official OAI endpoint"*.
  - **Where it went:** `.claude/development-notes/the-backbone.md` and `SOURCES.md`.

## R-020: OpenAI's guide to its error codes

- **Named:** 2026-10-12
- **Task:** the backend's chat, for the OpenAI-compatible protocol: gap 5 in `.claude/development-notes/the-backbone.md`, how a server reports an error, so that the conversation can show it.
- **Source:** the guide *Error codes*, https://developers.openai.com/api/docs/guides/error-codes, as it reads on the day of the read. Its old address, https://platform.openai.com/docs/guides/error-codes, answers with a permanent redirect (HTTP 301) to it; on 2026-10-12 only headers were requested.
- **Facts sought:** the shape of an error response's body, and of an error that arrives within a stream, where the guide gives them.
- **Not read:** the rest of the guide's site.
- **Cleared:** 2026-10-12
- **Done:** 2026-10-12.
  - **What was read:** the page, fetched and turned into text. It carries the whole site's navigation; only the guide's own text was read, from its opening sentence to its end.
  - **What was found:** the guide lists errors by HTTP status, 400, 401, 403, 429, 500 and 503, with causes, and refers to an error's fields by name: `error.message`, `error.type` (such as `invalid_request_error`, `rate_limit_error`, `service_unavailable_error`), `error.code` (such as `slow_down`, `server_is_overloaded`) and `error.param`. It advises following a `Retry-After` header when there is one.
  - **Left open:** the guide does not show an error's body whole, and says nothing of an error that arrives within a stream. Gap 5 is answered only as far as the fields' names.
  - **Where it went:** `.claude/development-notes/the-backbone.md` and `SOURCES.md`.

## R-021: Ollama's API description, on models

- **Named:** 2026-10-12
- **Task:** the backend's connections, for Ollama: gap 4 in `.claude/development-notes/the-backbone.md`, the values a model's `capabilities` can take, which R-018 left open; with what the model list and the list of loaded models give, the second for the window a loaded model runs with, which bears on gap 1.
- **Source:** `docs/openapi.yaml` in github.com/ollama/ollama at commit `04730395aff8ec47287977d50a631671d0e636d5`, `main` on 2026-10-12, the description of Ollama's API that docs.ollama.com is built from: its entries for `/api/show`, `/api/tags` and `/api/ps`, and the schemas those entries name. If it does not list the values of `capabilities`, then the section *Show Model Information* of `docs/api.md` at the same commit. On 2026-10-12 only GitHub's list of the names in `docs/` and the headers of the two files' addresses were requested; both answered HTTP 200.
- **Facts sought:** the values of `capabilities`; where a model's context length appears in its details; the fields of the model list; and whether the list of loaded models gives the context a loaded model runs with.
- **Not read:** the rest of `docs/openapi.yaml` and `docs/api.md`; Ollama's source code.
- **Cleared:** 2026-10-12
- **Done:** 2026-10-12.
  - **What was read:** `docs/openapi.yaml` at the commit named, fetched raw: the entries for `/api/tags`, `/api/ps` and `/api/show`, each printed from its first line to the line before the next entry, found first; and the four schemas they name, `ListResponse`, `PsResponse`, `ShowRequest` and `ShowResponse`, printed the same way. The schemas these name in turn, `ModelSummary`, `Ps` and `Thinking`, were not read. Since the description does not list the values of `capabilities`, the section *Show Model Information* of `docs/api.md` at the same commit was searched for them, within its own bounds, found first.
  - **What was found:**
    - **`capabilities`** is `type: array`, `items: type: string`, *"List of supported features"*, with no list of values. The description's example has `completion`, `thinking` and `vision`; `docs/api.md`'s has `completion` and `vision`.
    - **A model's details** (`/api/show`, a POST with `model`, and `verbose` for *"large verbose fields"*) give `capabilities`, `parameters` (*"Model parameter settings serialized as text"*, `"temperature 0.7\nnum_ctx 2048"` in the example), `model_info` (*"Additional model metadata"*, with `gemma4.context_length: 131072` beside `general.architecture: "gemma4"` in the example), `details`, `template`, `license`, `modified_at`, and `thinking`, which in the example has `values: [false, true]` and `default: true`.
    - **The model list** (`/api/tags`, a GET) gives `models`, each, in the example, with `name`, `model`, `modified_at`, `size`, `digest` and `details` (`format`, `family`, `families`, `parameter_size`, `quantization_level`), as R-002 found.
    - **The running models** (`/api/ps`, a GET, *"Models currently loaded into memory"*) give, in the example, each model's `name`, `model`, `size`, `digest`, `details`, `expires_at`, `size_vram` and `context_length`, 4096 there. So a loaded model's window is known; a model not loaded is not in the list.
    - **Left open:** the full set of values `capabilities` can take (gap 4). Three are known: `completion`, `thinking` and `vision`.
  - **Where it went:** `.claude/development-notes/the-backbone.md` and `SOURCES.md`.

## R-022: llama.cpp's server README, on chat completions

- **Named:** 2026-10-12
- **Task:** the backend's chat, for llama.cpp: which field of a chat request limits the length of the reply, since the OpenAI reference (R-006) names `max_completion_tokens` and calls `max_tokens` deprecated; and how a streamed reply carries a model's reasoning, which the OpenAI reference does not give and the interface shows apart from the answer.
- **Source:** `tools/server/README.md` in github.com/ggml-org/llama.cpp, on `master` on the day of the read, with the commit recorded under *Done* (`master` was at `cbe28bb3cb0758f0c566a9a3561766821aeb0748` when this entry was written): the section on `POST /v1/chat/completions`, found by its heading and printed only to its own end.
- **Facts sought:** the fields that limit a reply's length, and which of them the server takes; the field a streamed chunk carries a model's reasoning in, and any option that controls it; and how an error is reported, in a stream and outside one, if the section says.
- **Not read:** the rest of the README; the server's source code.
- **Cleared:** 2026-10-12
- **Done:** 2026-10-12.
  - **What was read:** `tools/server/README.md` at commit `cbe28bb3cb0758f0c566a9a3561766821aeb0748`, `master` on 2026-10-12 and the same commit as when the entry was written, fetched raw. A script found the section's heading and the next heading of the same level, outside code blocks, and printed only those two lines, 1338 and 1471; the section was then printed from line 1338 to 1470, its own end, and nothing else of the file was printed.
  - **What was found:**
    - **The length of a reply:** the section names no field for it. For its options it points to OpenAI's Chat Completions documentation, and says that llama.cpp's own `/completion` features, *"such as `mirostat`"*, are also supported, without listing them.
    - **Reasoning:** *"The server supports parsing and returning reasoning via the `reasoning_content` field, similar to Deepseek API."* The section does not say where in a streamed chunk the field sits. Four options bear on it: `reasoning_format`, *"If set to `none`, it will output the raw generated text."*; `reasoning_effort`, *"If `none`, reasoning/thinking is disabled. Otherwise, the value is made available to the jinja template."*; `chat_template_kwargs`, with `{"enable_thinking": false}` as its example; and `reasoning_control`, which arms ending the reasoning early through `/v1/chat/completions/control`, off by default. Reasoning sent back in the history is supported *"by some specific templates"*.
    - **Errors:** the section says nothing of them.
    - **Also in the section, not sought, and not used:** a response carries a `timings` object (`cache_n`, `prompt_n`, `predicted_n`, and durations) and a standard `usage` object (`completion_tokens`, `prompt_tokens`, `total_tokens`, and `prompt_tokens_details.cached_tokens`), and *"The total number of tokens in context is equal to `prompt_n + cache_n + predicted_n`"*. The multimodal input R-003 read now also lists `input_video`.
  - **Left open:** whether llama.cpp takes `max_completion_tokens`, the field the OpenAI reference (R-006) names; where `reasoning_content` sits in a streamed chunk; and how an error is reported.
  - **Where it went:** `.claude/development-notes/the-backbone.md`, `.claude/development-notes/the-backend.md` and `SOURCES.md`.
