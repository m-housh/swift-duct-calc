# DuctCalc

[DuctCalc](https://ductcalc.pro) is a residential HVAC duct design web application. It is based on
ACCA Manual-D speed-sheet (spreadsheet).

## Why DuctCalc?

This extends the capabilities of the modified speed-sheet that I had used for years and built
workflows around.

1. Web-based (available everywhere);
1. It includes easy ways to import room loads from CoolCalc;
1. It is self-hostable;
1. It is source-available;
1. It has a quick duct calculator (ductulator alternative);
1. It has a fitting reference guide for TEL's (total equivalent lengths);
1. It includes path templates for common duct paths used in a user's designs;

## Notes from Michael

I like ambitious ideas, simple systems, and software that feels obvious. Do not preserve complexity
just because it already exists. Do not introduce machinery because it looks architecturally
impressive. Understand the real constraint, then fight for the smallest model that makes the correct
behavior unsurprising.

Channel both "measure twice, cut once" and "yagni". Fight scope creep. Try to honor the dev's intent
in both a minimal and realistic fashion.

The rest of this document is meant to help you navigate the codebase and make changes effectively.
Think of these instructions less as "hard rules", more as "good defaults". The developer's
preferences should be able to override anything here.

Of note: Most contributions are often through coding agents that are controlled remotely. This means
you should be careful about accessing data, killing dev servers, and other things that may damage
the instance that the contributor is using.

## A small glossary

We need to be on the same page with terminology. When communicating, use this language:

- **you** means the agent reading this file and changing DuctCalc.
- **we, us, and maintainers** mean Michael and the people building DuctCalc. These are who you are
  talking to now.
- **user** means the person using DuctCalc to direct coding agents.
- **project** means an environment-local workspace record rooted at a directory.
- **thread** means the durable conversation and work history for a project.
- **turn** means one user-to-agent cycle, including follow-up work such as checkpointing.

## Dev Servers

Run development servers using podman (if available) and docker if not. You should build the image
and start services using the files in the `docker/` directory.

Choose a random port for a given worktree and use that for all work inside that worktree.

## Documentation

Most code changes do not need an internal documentation change. Agents can read the code.

- `docs/internals/` is for architectural decisions and their reasons, constraints that span
  components, and implementation traps that are hard to discover from the source. Before adding a
  paragraph, ask what a maintainer would get wrong without it. If reading the relevant code answers
  the question, leave it out.
- Do not document every feature, enumerate fields or methods, narrate control flow, maintain file
  catalogs, or append PR summaries. Types, tests, and code already record the implementation. The
  glossary defines shared vocabulary; it is not a feature index.
- Keep a local implementation explanation in a nearby code comment. Use an internal doc when the
  reasoning crosses boundaries or needs context the code cannot carry well. Link to the relevant
  source instead of copying it.
- When a documented decision or constraint changes, rewrite or remove the affected text. Do not
  append another account of the new behavior. A new internal page needs a distinct, durable reason
  to exist.
- `docs/user/` helps users accomplish tasks. Give each major feature a concise section explaining
  what it does, how to start, and anything unintuitive. A settings path is useful; descriptions of
  visible buttons, icons, layouts, animations, or every UI state are not. Before adding text, ask
  what task or decision it helps the user with.
- Keep user docs in the shipped product's voice, without implementation details or contributor
  tooling. Update the relevant feature section when how to use it changes. A UI tweak does not need
  a documentation entry, and a new control does not need its own page.

## Plans and work artifacts

- Do not commit implementation plans, research notes, or agent scratch files. Keep temporary working
  material outside the worktree. `.plans/` is gitignored only as a safety net for legacy tooling.
- Track active maintainer work in the GitHub issue or project item that owns it. External proposals
  follow `CONTRIBUTING.md` and belong in Ideas discussions.
- A merged PR is the implementation record. Close or update its tracking item when the work lands;
  do not preserve a second checklist in the repository.

## Code Structure

The layout of the repository and guidance:

1. `Sources/`: The swift / vapor application
1. `Public/`: The static / public files served by the web application
1. `Tests/`: The test suite
1. `docker/`: Docker / container related files
1. `docs/`: Documentation about the project, decisions, guidance, etc.
1. `scripts/`: Development helper scripts
1. `justfile`: Command runner, useful for commonly used scripts that we run repeatedly
1. `README.md`: Keep this file about the project, how to develop (start dev servers). Do **NOT**
   stuff everything into the README, it should generally go in the `docs/` somewhere.

## Taste

- Shared types should live in the `ManualDCore` module.
- Prefer dependency injection, using `live`, `preview`, and `test` dependencies.
- Shared UI elements should live in the `Styleguide` module.
- UI pages, views, etc. should live in the `ViewController` module.
- Complexity belongs at the adapter / dependency boundary. Orchestration stays pure, UI stays dumb.
- Comments describe how a thing is used, and move when the code moves. To be used mostly to describe
  functions, not to annotate every line of behavior.
- If a rule here fights the task in front of you, say so loudly and get a human sign-off before
  breaking it.
