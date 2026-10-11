# The backbone

**Written 2026-10-11, against the tree at `f94a72f`**, which added the working rules and the first notes. Nothing had been built.

This is the first part of the design: what talks to what, what a connection is, and how models are found. The agent proposed it in nine points, with four questions; this note records the proposal as the agent's and Z's answers in Z's words. The interface and the palette are later parts of the design.

## The proposal

These are the agent's points as proposed. Points 2, 5 and 6 rest on facts the agent gave from memory; those wait on the reads under *Waiting on reads*.

1. **What talks to what.** The browser talks to the AIconman backend, and the backend talks to the model servers. The browser keeps chat history, as agreed in `product-brief.md`. The backend keeps the connections and their keys, forwards every request, and streams replies back as they arrive. Only the backend has to reach the model servers, and Apache or another reverse proxy may stand in front of it.
2. **HTTPS.** Browsers allow microphone access and installing a web app only on a secure page, so a phone opening the interface over plain HTTP on a local address gets neither; uploading a recording still works. The documentation explains TLS, and the interface says why the microphone is unavailable rather than hiding the button.
3. **A connection** is a name, a base URL, an optional key and a protocol, with any number of connections on one machine. A saved key is never sent back to the browser: it can be replaced, not read.
4. **The protocol** starts empty, on no protocol. Left empty, the backend tries each protocol it knows against the URL, uses the one that answers, and shows what it found. The first version knows the OpenAI-compatible protocol and Ollama's own API; others are added when someone needs one.
5. **Models and what they can do.** The backend merges every connection's models into one list, each marked with its connection. What a model can do (chat, images, speech-to-text) and its context window come from the server where the server reports them; where it does not, the user sets them per model.
6. **The context window calculator** shows how much of the model's window the conversation and the draft use. The count is exact where the server can count tokens, and an estimate, labeled as one, where it cannot.
7. **Speech** comes in two ways. A microphone button in the chat box puts the transcript in the input, to be edited before it is sent. A file upload shows the transcript, which can then be sent into a chat.
8. **Login.** A screen with one button that lets the user in, as Z asked (`product-brief.md`). The backend has a single place where an access check goes, open for now, so that the options Z will choose from later go there without touching the rest.
9. **Storage.** The connections live in one JSON file in a data folder that only the service user can read.

The agent also proposed an optional machine label for grouping connections. Z declined it, below.

## Z's answers

**Detection, and a choice.** Asked whether an empty protocol should be detected or the user should always pick one: *"auto-detect would be the best. user can select the protocol too, I don't think it is an issue for a user to choose protocol for the server they set up."* So the protocol is detected when it is left empty, and the user can set it.

**Two protocols first.** Asked whether the OpenAI-compatible protocol and Ollama's own API are enough for the first version: *"I think so."*

**No machine label.** *"No"*.

**The reads go through the log.** Asked for a go-ahead to read four servers' published API documentation, which the rule as drafted would have let the agent read without a log entry: *"Create reading log for me to edit and clear."* The agent wrote R-001 to R-004 in `dev/READING-LOG.md`, and R-005 for the HTTPS point, which it had also given from memory.

## Waiting on reads

| Point | Rests on | Read |
|---|---|---|
| 2, HTTPS | what a page over plain HTTP cannot do | R-005 |
| 4, detection | what each protocol answers without a model being named | R-001, R-002, R-003 |
| 5, capabilities and context windows | what each server reports about its models | R-001 to R-004 |
| 6, the calculator | which servers count tokens | R-002, R-003, R-004 |
| 7, speech | which servers transcribe, and the transcription endpoint | R-001 to R-004 |

Until a read is cleared and done, its facts are the agent's recollection and nothing is built on them. What each read found is appended here, dated, when it is done.
