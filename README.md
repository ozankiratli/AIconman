# AIconman

AI Connection Manager: a web interface for the language models you run on your own network, with an account and chats of their own for every person in your household.

**AIconman is for a local network or a VPN, and nothing else.** Do not expose it, or the model servers it talks to, to the internet.

It is being built. The manual, [docs/manual.md](docs/manual.md), explains how to set it up, step by step, as far as AIconman goes so far.

## How it is built

AIconman is written with an AI agent, under written rules, and the record of how is published with the code:

- [`CLAUDE.md`](CLAUDE.md) -- the rules the agent works under.
- [`.claude/development-notes/`](.claude/development-notes/) -- why AIconman is built the way it is, and a log of every step taken.
- [`dev/READING-LOG.md`](dev/READING-LOG.md) -- every outside source read, named before it was opened and cleared by the maintainer.
- [`SOURCES.md`](SOURCES.md) -- every source, and what was learned from it.

## License

Free software under the [GNU General Public License, version 3](LICENSE).
