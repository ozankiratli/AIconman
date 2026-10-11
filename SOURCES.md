# Sources

Everything AIconman knows about the servers it talks to, the protocols they speak and the platform it runs on came from somewhere, and this file says where.

**No code from another person's project is in AIconman.** What is taken is knowledge. The rules for that are in `CLAUDE.md`, under *Other people's code*. Libraries Z has approved by name are the one exception: other people's code, carried whole under their own licenses, and each is listed here with its license once it is in use.

Each entry says what the source is, its license if it is software, and what was learned from it. A read of another person's code also has an entry in `dev/READING-LOG.md`, which the source here cites.

## OpenAI

- **API reference:** [developers.openai.com/api/reference](https://developers.openai.com/api/reference/overview), read 2026-10-11 under `dev/READING-LOG.md`, R-006. Its old address, platform.openai.com/docs/api-reference, redirects there (R-001). It is OpenAI's description of its own service, whose protocol most self-hosted servers imitate. Read: the overview's *Authentication*, and the sections on listing models, creating a chat completion with its streaming events, and creating a transcription. What was learned: how a key is sent, the fields of the model list, the shape of a chat request, its reply and its stream, and the shape of a transcription request and its reply.

## Ollama

- **API documentation:** `docs/api.md` in [github.com/ollama/ollama](https://github.com/ollama/ollama), MIT license (as GitHub reports it for the repository), read at commit `eab97e9f92b9a25c2d52d2cc6c1b1c99bd9fae21` (2026-10-09) under `dev/READING-LOG.md`, R-002. The file says Ollama's API docs are moving to [docs.ollama.com/api](https://docs.ollama.com/api). What was learned: how Ollama lists its models, where it reports what a model can do and the length it was trained for, how its chat requests and streamed replies are shaped and what counts they carry, and that its version endpoint needs no model. Also that it has no endpoint for counting the tokens of a text, and none for transcription.

## llama.cpp

- **Server README:** `tools/server/README.md` in [github.com/ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp), MIT license (as GitHub reports it for the repository), read at commit `5c8854fd88319125125dc4b836c98b1b215b0f23` (2026-10-11) under `dev/READING-LOG.md`, R-003. What was learned: which OpenAI-compatible endpoints the server offers; what its model list adds to the OpenAI fields, the media a model reads and the length it was trained for; where it reports the context it runs with; its two ways of counting tokens; how a key is set and sent; its public health endpoint; and how a server started without a model lists and routes many models.

## Tabler Icons

- **The icon library:** [github.com/tabler/tabler-icons](https://github.com/tabler/tabler-icons), MIT license, read at commit `a4ce1404bc6d24d3c365afe7b258d6bf6f48d62d` (2026-10-05) under `dev/READING-LOG.md`, R-010: its license, and the outline and filled SVG files of the icons AIconman needs. What was learned: which of those icons exist and which have filled versions, and how they are drawn. Approved by Z on 2026-10-11 for the interface; not yet in use.

## Fonts

- **Targa MS Hand**, by Studio Kmzero (2002): the end-user license stored in the font file itself, read 2026-10-11 from the copy installed on Z's machine. What was learned: the font is licensed for personal, non-commercial use only, and copies of it may not be distributed, alone or as part of another product. So AIconman cannot bundle or serve it.
- **Source Serif Pro**, by Adobe: the license stored in the font file itself, read 2026-10-11 from the Bold Italic copy installed on Z's machine. What was learned: it is licensed under the SIL Open Font License 1.1, with "Source" as a Reserved Font Name. Approved by Z on 2026-10-11 for the title; not yet in use.

## The browser

- **MDN Web Docs:** *Features restricted to secure contexts* and *Secure contexts*, both now under [developer.mozilla.org/en-US/docs/Web/Security/Defenses/Secure_Contexts](https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Secure_Contexts), and [*Making PWAs installable*](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Making_PWAs_installable), read 2026-10-11 under `dev/READING-LOG.md`, R-008. What was learned: that the microphone and service workers need a secure context, what counts as one, and what a browser needs before it offers to install a web app.
