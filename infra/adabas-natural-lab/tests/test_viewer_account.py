"""Guard the non-administrative credential.

The viewer exists so somebody can be shown the legacy system without being
able to change it. Two things carry that promise, and both are easy to break
without noticing:

* Caddy refuses the viewer /admin, and routes its green screen to a container
  started with a Natural session pinned to one query program. Lose the pin and
  the account silently gains the Natural command line, which can start the
  registration and batch programs and can SCRATCH a catalogued object.
* Those directives are rendered into a YAML block scalar. A line that begins
  with a tab is not valid YAML indentation, so an otherwise correct Caddy
  fragment can take the whole cloud-init document down with it - which is
  exactly what the first version of this did.
"""

from __future__ import annotations

import re

from conftest import LAB

MAIN_TF = (LAB / "main.tf").read_text(encoding="utf-8")
VARIABLES_TF = (LAB / "variables.tf").read_text(encoding="utf-8")
CLOUD_INIT = (LAB / "cloud-init.yaml").read_text(encoding="utf-8")


def viewer_session_script() -> str:
    start = CLOUD_INIT.index("- path: /opt/sifap/viewer-session.sh")
    return CLOUD_INIT[start : CLOUD_INIT.index("- path:", start + 1)]


def test_should_indent_rendered_caddy_lines_with_spaces_not_tabs() -> None:
    # cloud-init.yaml carries the Caddyfile in a block scalar, so every rendered
    # line needs that block's indentation. A tab cannot provide it.
    line = re.search(r"caddy_viewer_credential\s*=\s*(.+)", MAIN_TF).group(1)

    assert "\\n      \\t" in line, (
        "The rendered credential must start its line with the six spaces the "
        f"YAML block scalar expects. Got: {line}"
    )
    assert "\\n\\t" not in line, (
        "A rendered line starting with a tab is invalid YAML indentation and "
        "fails the whole cloud-init document, not just this directive."
    )


def test_should_indent_the_rendered_compose_service_under_services() -> None:
    # Eight spaces: six for the block scalar, two to sit under `services:`.
    # Compose indentation is structural, so this decides whether the container
    # is a service at all.
    block = MAIN_TF.split("compose_viewer_service = ", 1)[1].split("]) : \"\"", 1)[0]

    assert '"        ${line}"' in block, block


def test_should_place_the_viewer_routes_before_the_ones_they_override() -> None:
    # handle blocks are mutually exclusive and fire in written order, so the
    # viewer's /admin and /terminal handlers only win if they come first.
    caddy = CLOUD_INIT[CLOUD_INIT.index("- path: /opt/sifap/Caddyfile") :]
    caddy = caddy[: caddy.index("- path: /opt/sifap/docker-compose.yml")]

    assert caddy.index("${caddy_viewer_routes}") < caddy.index("handle /terminal*")
    assert caddy.index("${caddy_viewer_routes}") < caddy.index("handle /admin {")


def test_should_never_drop_the_viewer_into_a_shell() -> None:
    # The operator's session script falls back to a shell inside natural-ce when
    # it cannot find the session driver. Here that would hand the viewer more
    # access than the account it signed in with.
    script = viewer_session_script()

    assert "/bin/bash" not in script
    assert "exec docker exec -it \"$CONTAINER\" sh -lc \"$VIEWER_CMD\"" in script


def test_should_require_the_stack_to_end_the_session() -> None:
    # Without a trailing FIN the session falls through to the Natural command
    # line once the program ends, and the viewer can run anything catalogued.
    assert 'STACK=(LOGON SIFAPPRD;CONSBENF;FIN)' in VARIABLES_TF
    assert 'can(regex(";FIN\\\\)", var.viewer_terminal_command))' in VARIABLES_TF


def test_should_let_the_vm_read_the_viewer_secret() -> None:
    # read-secret.sh only accepts names on its allowlist; a secret that is not
    # on it cannot be fetched even though the identity may read it.
    assert "demo-viewer-password" in CLOUD_INIT.split("read-secret.sh")[1][:600]
