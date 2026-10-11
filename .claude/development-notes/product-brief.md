# The product brief

**Written 2026-10-11, against the tree at `b8de0d5`**, the initial commit. Nothing had been built, and no design had been made.

## The brief as Z gave it

Z, 2026-10-11:

> See the files I put here. We will develop a project, to be published puclicly that explains setting up LLMs and agents on different machines and connecting them through a web interface (and maybe an android app later), and using them as chatbots for various purposes. First to be deployed on my network.
>
> The plan is kind of simple. We build something that works on my network, and build the framework for everybody. Make it accessible and private. The interface we develop should be independent of what is built on user's ends. It should work as long as it is reachable from their own network.
>
> The user should be selecting a few things,
> ip+port to reach the LLM server
> API key or other authentication. (we might just limit to API key)
> what type of server "ollama, etc." (Not even sure this is needed)
>
> Once these are added, the interface should allow the user to choose between their served models to the extent their servers allow.
>
> There will not be user management for this project, we will make it clear that this is only for LAN/VPN applications. The user should make sure that nothing is exposed to internet.
>
> The website should have dark/light modes dark default. It should be mobile friendly.
>
> For color theme I pasted my theme settings for my website. However, for this project I want to create a new palette, incorporating orange, coral, lilac, pink, and turquoise I added. Some colors at the top can be replaced.

The files were Z's own and are untracked in `.tmp/`: an OpenAI-compatible gateway Z wrote for a Hailo-10H NPU on a Raspberry Pi, with its manual, environment file, systemd unit and smoke test, and the SCSS theme of Z's website. The five colors Z added to that theme are orange `#F57900`, coral `#ff7e7e`, lilac `#c98fff`, pink `#ff139d` and turquoise `#40e0d0`.

## What the agent raised, and what Z settled

**Where requests go.** The agent's first point was that a page in the browser cannot call most self-hosted servers directly. Z's own gateway sends no CORS headers, so a browser refuses a page on another origin; it also serves plain HTTP, and a browser blocks plain-HTTP requests from a page served over HTTPS. The agent recommended a small backend that serves the interface and relays requests to the servers, and pointed out that such a backend holds every key. Z answered with a question that the design will settle: *"How about setting reverse proxy? I already have apache reverse proxy setup."*

**Several services on one machine.** The agent suggested a base URL in place of an IP address and a port, since the scheme and the path prefix differ between servers. Z: *"Base url + port would not work for multiple setups on the same server, I already have an ollama server serving qwen3-4b + phi4-mini on pi on two separate ports alongside with openai models served. This is going to be very similar for a lot of people if they want to mix things up a little."* So a machine running several model servers, each on its own port, is the normal case and not an edge case. How a connection is described is for the design.

**Speech models.** The agent pointed out that a server's list of models does not say what each one can do, and gave as an example a speech-to-text model listed beside the chat models. Z: *"User can reach to whisper models too, they can speak or upload a file etc. Why not?"* So speech-to-text models are part of what AIconman offers: speaking to a model, and uploading a recording.

**The API key is optional.** The agent pointed out that some servers have no key of their own. Z: *"API optional correct."*

**A server's limits.** The agent raised the long waits and small context window of Z's gateway as things the interface would have to handle. Z: *"The time is not an issue here. People running their own servers will know their own limitations. Do not raise this further."* The same answer took up one part of the point: *"Setting a context window calculator is a good idea."*

**The palette.** The agent measured the contrast of the five new colors with the WCAG 2 formula, against the darkest background of Z's website theme, `#252a34`, and against white. Any contrast checker reproduces the numbers.

| | on `#252a34` | on `#ffffff` |
|---|---|---|
| orange `#F57900` | 5.22 | 2.76 |
| coral `#ff7e7e` | 5.85 | 2.46 |
| lilac `#c98fff` | 6.07 | 2.37 |
| pink `#ff139d` | 4.00 | 3.60 |
| turquoise `#40e0d0` | 8.76 | 1.64 |

WCAG asks for 4.5 for body text. The agent's point was that on a light background none of the five is readable as text. Z: *"For design. Not all colors need to be text, we can use some of them as shadows highlights borders etc. We can create."*

**The defaults.** The agent proposed four, for Z to object to any: a Python backend on FastAPI, which matches Z's gateway and the repository's `.gitignore`; a plain HTML, CSS and JavaScript frontend with no build step; chat history kept in the browser; and an installable web app first, ahead of a native Android app. Z: *"I agree with the defaults."*

**What drew no answer.** The agent also suggested that the server type default to the OpenAI-compatible protocol, with types added only where one unlocks something; that the backend be locked with one access passphrase; that Z's gateway add each model's capabilities to its own list of models; and that Z's gateway manual be cleaned of Z's network details before anything from it is published. Z did not answer these.

## Added later on 2026-10-11, against `f94a72f`

After the working rules were drafted, Z answered three of those points.

**No protocol is the default.** Z: *"A few points I know I haven't answered defaulting to OpenAI compatible protocol. I think we should not default to any of them it should be permissive."*

**Access control comes last, with options; for now a login screen that lets everyone in.** Z: *"Backend password not sure we will think about something there. I use Nextcloud to authenticate my forgejo and jupyterhub instances. We can build a few options for whoever wants what. Sounds like the last task. But at the moment we should build a permissive login screen where a button let's the user access the interface or something if you want."*

**The gateway manual is not published as it is.** Z: *"The manual cannot go as it is, that's clear. We will have to rewrite the manual anyway, this is just a starting point for you to understand what I did."*
