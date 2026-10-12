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

- **The icon library:** [github.com/tabler/tabler-icons](https://github.com/tabler/tabler-icons), MIT license, read at commit `a4ce1404bc6d24d3c365afe7b258d6bf6f48d62d` (2026-10-05) under `dev/READING-LOG.md`, R-010 and R-013: its license, and the outline and filled SVG files of the icons AIconman's chat and account screens need. What was learned: which of those icons exist and which have filled versions, and how they are drawn. Approved by Z on 2026-10-11 for the interface; not yet in use.

## Fonts

- **Targa MS Hand**, by Studio Kmzero (2002): the end-user license stored in the font file itself, read 2026-10-11 from the copy installed on Z's machine. What was learned: the font is licensed for personal, non-commercial use only, and copies of it may not be distributed, alone or as part of another product. So AIconman cannot bundle or serve it.
- **Source Serif Pro**, by Adobe: the license stored in the font file itself, read 2026-10-11 from the Bold Italic copy installed on Z's machine. What was learned: it is licensed under the SIL Open Font License 1.1, with "Source" as a Reserved Font Name. Approved by Z on 2026-10-11 for the title; not yet in use.

## Nextcloud's marks

- **Nextcloud's brand and trademark pages:** [nextcloud.com/brand](https://nextcloud.com/brand/) and [nextcloud.com/trademarks](https://nextcloud.com/trademarks/), and the two logo files the brand page links, read 2026-10-11 under `dev/READING-LOG.md`, R-014. What was learned: the logo's files, colors, clear space and smallest size, that it may not be altered, that fair use is acknowledged, and that identifying a project as compatible with Nextcloud is allowed for non-commercial purposes.
- **Font Awesome's Nextcloud icon:** [github.com/FortAwesome/Font-Awesome](https://github.com/FortAwesome/Font-Awesome), Font Awesome Free (icons CC BY 4.0, fonts SIL OFL 1.1, code MIT), read at commit `14c65a3747d0f3b751f15831fc719236aea8729d` (2026-07-15) under R-015: its license file and `svgs/brands/nextcloud.svg`. What was learned: the licenses and their attribution, Font Awesome's terms for brand icons, and that its Nextcloud icon is the full logo with the word.

## Nextcloud's sign-in

- **Nextcloud Administration Manual:** the *OAuth2* page, [docs.nextcloud.com/server/latest/admin_manual/configuration_server/oauth2.html](https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/oauth2.html), whose title named version 36 on the day, and the *Pretty URLs* section of [the installation page](https://docs.nextcloud.com/server/latest/admin_manual/installation/source_installation.html#pretty-urls), read 2026-10-12 under `dev/READING-LOG.md`, R-017. What was learned: Nextcloud's authorize and token addresses, that they need `index.php` before `/apps/` where pretty URLs are not configured, what pretty URLs need, and what the page says about tokens, confidential clients and the confirmation before login.

## Libraries in use

- **PyYAML** 6.0.3, MIT license (as its package metadata states), [pyyaml.org](https://pyyaml.org/): reads `config/config.yml`. Approved by Z on 2026-10-11, installed into `.venv` from `install/requirements.txt`.
- **ShellCheck** 0.11.0, GNU General Public License version 3 (as `shellcheck --version` states), [shellcheck.net](https://www.shellcheck.net): lints the shell scripts in `install/`; a development tool, not part of what AIconman runs. It is installed as the binary inside **shellcheck-py** 0.11.0.1, MIT license (as its package metadata states), [github.com/ryanrhee/shellcheck-py](https://github.com/ryanrhee/shellcheck-py). Approved by Z on 2026-10-12, installed into `dev/.venv` from `dev/requirements.txt`.

Added on 2026-10-12 for the backend, at Z's word and for Z's review, and installed into `.venv` from `install/requirements.txt`. Each license is as the package's own metadata states it, and each address is the one that metadata gives.

- **FastAPI** 0.143.0, MIT license, [github.com/fastapi/fastapi](https://github.com/fastapi/fastapi): the web framework. Approved by Z on 2026-10-11.
- **Uvicorn** 0.54.0, BSD-3-Clause, [uvicorn.dev](https://uvicorn.dev/): the server that runs it.
- **python-multipart** 0.0.32, Apache-2.0, [github.com/Kludex/python-multipart](https://github.com/Kludex/python-multipart): form fields and uploaded files, for FastAPI.
- **HTTPX** 0.28.1, BSD license, [python-httpx.org](https://www.python-httpx.org): requests to the model servers.
- **psycopg** 3.3.6, with **psycopg-binary** 3.3.6, LGPL-3.0-only, [psycopg.org](https://psycopg.org/): PostgreSQL.
- **cryptography** 50.0.2, Apache-2.0 OR BSD-3-Clause, [cryptography.io](https://cryptography.io/): encrypts the connections' keys.
- **What they bring with them:** annotated-doc 0.0.5, annotated-types 0.8.0, anyio 4.15.1, cffi 2.1.1 (MIT-0), h11 0.16.0, pydantic 2.14.1, pydantic_core 2.50.1 and typing-inspection 0.4.4, MIT; click 8.5.0, httpcore 1.0.9, idna 3.20, pycparser 3.11 and starlette 1.7.0, BSD-3-Clause; certifi 2026.7.22, MPL-2.0; typing_extensions 4.16.0, PSF-2.0; and opentelemetry-api 1.45.1, Apache-2.0, [github.com/open-telemetry/opentelemetry-python](https://github.com/open-telemetry/opentelemetry-python/tree/main/opentelemetry-api), which FastAPI requires.

## The browser

- **MDN Web Docs:** *Features restricted to secure contexts* and *Secure contexts*, both now under [developer.mozilla.org/en-US/docs/Web/Security/Defenses/Secure_Contexts](https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Secure_Contexts), and [*Making PWAs installable*](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Making_PWAs_installable), read 2026-10-11 under `dev/READING-LOG.md`, R-008. What was learned: that the microphone and service workers need a secure context, what counts as one, and what a browser needs before it offers to install a web app.
