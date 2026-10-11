# How the ground rules were set

**Written 2026-10-11, against the tree at `b8de0d5`**, the initial commit. `CLAUDE.md`, these notes, `dev/READING-LOG.md` and `SOURCES.md` were uncommitted and under review. No code had been written. The defaults for the stack had been agreed earlier the same day, in `product-brief.md`.

Z asked for the ground rules before any work on the project itself, and for them to come first: *"One change I want to make for this project is to start with ground rules in CLAUDE.md. Including the use of subagents."* So `CLAUDE.md` opens with the rules on transparency, subagents, other people's code, acting, privacy and review, before anything about the code.

This note records what each ground rule is for, in Z's words where there are any, and which parts of it were the agent's. Where the rules came from is in `00-initialization-of-the-project.md`.

## Transparency

Z: *"I want to be transparent about the development process. It is one of the core values all my projects share."* It heads the ground rules, and it says what it does not cover: Z's network and anyone's conversations. Those have a rule of their own, below.

## Subagents

Z: *"You should always ask before deploying subagents. When doing that you should tell me about the extent of the work and number of agents proposed. Subagents should not start subagents themselves. All agents should run as Sonnet unless we decide something else is needed. And the hard cap for the agents is 5 at a given time."*

The agent added two clauses that it reads as following from Z's words; Z's review of the draft decides them. The rule covers every way an agent gets started, including a workflow and a skill that runs in a subagent or coordinates subagents, since otherwise a skill could start agents without the ask. The model is set explicitly on each agent, since a default is something that can change without anyone deciding it.

## Other people's code

Z: *"We need rules about reading code from other projects. However, this rule applies to only projects developed by other people."* So Z's own work is outside it. Three things in the rule are the agent's, for Z to confirm or correct:

- **Documentation is not harnessed.** Documentation a project publishes for its users, such as an API reference, is read without a log entry but listed in `SOURCES.md`; the harness is for code. That is the agent's reading of Z's words, "reading code", and of the rule's own preference for a published specification as the source. Z may want every outside source harnessed instead.
- **Where reads are logged.** `dev/READING-LOG.md`. Z's general rule says to ask where, when a project has no log. The agent created the file with this draft so the rule would have a place to work, and raised the location with Z in the same turn.
- **Who the likely authorities are.** The agent named them: other chat interfaces for self-hosted models, and the servers AIconman talks to. These do what AIconman does, which is how another project becomes the authority without anyone deciding it.

## Rules the agent proposed

Z did not ask for these; the agent proposed them in the first draft. They are in `CLAUDE.md` under *What stays out of the agent's context and the repository*, and one is in *Ask before acting*:

- **No real secret in the conversation.** An API key the agent reads goes to Anthropic's servers with everything else it reads.
- **Z's network out of the repository.** The private material Z brought into `.tmp/` describes machines, host names and a domain on Z's network, and the repository is to be public.
- **Conversations with real models out of the repository**, unless Z approves an item by name.
- **A request to one of Z's model servers is asked for first.** It can load a different model for everyone else using that server.

The command that shows what `CLAUDE.md` says at any later tree, to hold against this note: `git show <hash>:CLAUDE.md`.
