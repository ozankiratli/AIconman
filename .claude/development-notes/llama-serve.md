# llama-serve

**Written 2026-10-12, against the tree at `4915cd3`**, which Z committed as *"API work: conversations"*. Nothing of llama-serve exists yet: `.tmp/llama-serve`, where it is to be built, is empty.

## Z's decision

Z answered yes to the agent's two questions after the context meter: one request to a llama.cpp server of Z's, to settle gaps 1 and 2 of R-022 (`the-backbone.md`), and a server on port 8644 for the check of a browser going away (`the-backend.md`). Z then asked: *"Do you know where the servers are?"* The agent's answer: it does not. Nothing in the repository or the notes names them, by the rule on Z's network in `CLAUDE.md`, and the agent did not go looking. Z went on:

> *"I discussed the issue with [Z's other project] where we created the tools and decided to keep running instances sandboxed. Because they don't have api keys etc and running within a project. Here's what we're going to do. We will create a new instance [on one of Z's machines, at a port of its own] to serve models to network."*

> *"We just need to build a framework like hailo-gw. (Actually it is good. We can put those together in two separate gists and add links to the manual when we're done.)"*

> *"That will be the next thing we will be building, before we can continue here."*

The bracketed parts replace the name of Z's other project, and the machine and the port, which are Z's network and stay out of the repository. So:

- **The llama.cpp instances that [Z's other project] runs stay within it.** They have no keys, and AIconman's work does not use them; the request Z allowed waits for the new instance.
- **A new llama.cpp instance serves models to the network**, set up by **llama-serve**, a framework like the one around the Hailo gateway (`hailo-gw`), Z's own gateway for a Hailo NPU (`product-brief.md`).
- **Both are to be published as gists of their own**, linked from the manual, once done. The gateway's manual is rewritten before it goes anywhere (Z, 2026-10-11, `product-brief.md`).
- **llama-serve is built next**, in `.tmp/llama-serve`, and AIconman's work waits for it. The agent takes the check on port 8644 to come after it too.
- **The build Z runs** reports `version: 0.4.1-dev (build 11058, commit f072b1037)`, built for Linux on aarch64.

## What was read of the gateway

The gateway is Z's own work, outside the rule on other people's code, and Z asked for llama-serve to be built like it. Z moved its five files into `.tmp/hailo-gw`: the gateway (`hailo_gw.py`), its environment file, its systemd unit, its manual, and a smoke test.

Read on 2026-10-12: the systemd unit, whole; the manual's headings, its section on the gateway, and its section on files and sources. The environment file holds a value for the gateway's key, so only the names of its settings and the lengths of their values were read. A script found that value once in the manual and nowhere in the other three files, and printed the manual with it masked, so the value never reached the agent's context; the manual calls it the template's key. The gateway's code and its smoke test were not read.

The shape it gives:

- **The program in a directory of its own**, read-only to the service; its settings in an environment file under `/etc`, which systemd reads; its state in a directory under `/var/lib`; and a system user of its own.
- **A systemd unit** that starts the program after the network, restarts it on failure, gives a model's load time to finish, and hardens it: no new privileges, the system read-only except its state, no home directories, a private `/tmp`, only the device it needs, and only the address families it uses.
- **A manual**: the architecture, the current state, measured limits, the machine's base setup, installing, the program and its settings as a table, the unit, operations, troubleshooting, rollback, open items, and files and sources.
- **A smoke test.**

## The agent's proposal, for Z

llama.cpp's server is already the program, so llama-serve is what runs it as a service and documents it. Four files, written new, in AIconman's house style:

1. **`llama-serve.env`**, the settings: the address and port, the models, the key's file, the context size, the slots and the threads. It ships with no key, and the manual says how to make one.
2. **`llama-serve.service`**, the systemd unit, hardened like the gateway's: a user of its own, the models read-only, and the key in a file only that user can read. Whether a small launcher script has to turn the settings into the server's options depends on R-023: if each option has an environment variable, the environment file sets them directly.
3. **`smoke_test.py`**, on Python's standard library alone, run from any machine on the network: the health check without a key; the model list with the key, and refused without it; a streamed chat with a small output limit, to a model that reasons, which settles gaps 1 and 2 of R-022 with data; and a token count. It prints what it measured -- statuses, counts, lengths and field names -- and nothing the model wrote.
4. **`Manual.md`**, for a reader of AIconman's manual who runs their own server: what llama-serve is, what it needs, installing it, its settings, running it, troubleshooting, and its files and sources.

The options' names, defaults and environment variables come from **R-023** in `dev/READING-LOG.md`, llama.cpp's server README at the commit Z's build reports, for Z to clear.

**Asked of Z:**

1. **One model, or several loaded on demand?** A server started without a model loads models on demand and routes each request by its `model` (R-003). The answer changes the settings and the unit.
2. **Is `.tmp/llama-serve` to be a git repository of its own?** AIconman's repository ignores `.tmp/`, so llama-serve's changes would not show in the IDE's diff view. A gist is itself a git repository, so a history begun now could carry over.
