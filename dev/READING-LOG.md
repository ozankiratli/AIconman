# Reading log

Every read of another person's code is made the same way: named, recorded, cleared and done, in that order. The rule, and what it covers, are in `CLAUDE.md` under *Other people's code*.

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
- **Cleared:**
- **Done:**
