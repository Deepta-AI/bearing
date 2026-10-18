# autopilot: stages before the build

Read at step 6: the design, repos, ux, contract and test-cases stages in lean and full scope.

6. Before the build, in lean scope: the design note, then test-cases
(the risk register and the case table only). In full scope:
architecture-diagram writes the C4 file; design
runs high-level-design, then deployment-architecture when the profile
says deploy and genai-design when it says llm;
repos runs new-repo once for each entry of
docs/architecture/repo-plan.json, in `<parent>/<Name>` beside this
repository (an entry named like this repository is this repository
and is not created again); for a
UI, ux runs ux-flows, then design-directions --unattended (three
directions as token themes over the real screens, scored, the highest
chosen into approved.json; any reference look the statement names is
the brief; an attended run with impeccable installed records its one
pick over its challengers instead, and the gate accepts either),
design-system from the chosen direction (the shadcn
variables, one UI face and a mono), motion-design (docs/design/motion.md)
and screen-design (on react-shadcn every screen a *.screen.tsx in
the design gallery, composed from src/components/ui, every state from
fixtures, responsive at 375, 768 and 1440), which also writes each
feature's docs/design/screens/<feature>/data-needs.md: what every
screen shows and what every action asks the server (the contract gate
wants one for every feature whose flows list screens, checked against
its newest flows file, flows-v<n>.md by number); the build wires
those same components to data. Then contract runs data-model and
openapi-spec as the profile names, from those data needs, then
threat-model (it needs the entry points and stored fields those
wrote). Then lld runs low-level-design once for each
component the HLD's "What gets built" table says this run builds,
after the contract, because a front-end component's design names the
screens and a server component's design needs the API and data model.
test-cases writes the TC-nnnn table. The ux, contract
and test_cases gates run the skills' own checkers (flows_check,
contrast, gallery_check or states_check, design-lint, model_check
--needs, states_check --needs, api_doc.py needs, threats_check,
cases_check).
The repos gate reads each sibling: a git repository whose `make check`
records a pass and has passed. Headless, the sandbox lets the run
write only inside this repository: run `brg-autopilot repos-request`
and end your turn; the launcher scaffolds the missing entries with
`brg-scaffold --check` outside it and resumes the session with what it
made. The siblings stay as scaffolded: the build, the tests and the
MR are this repository's.
