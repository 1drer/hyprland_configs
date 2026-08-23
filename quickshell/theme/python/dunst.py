import os
import re
import sys


BLOCK_PATTERN = re.compile(
    r"# (THEME_[A-Z0-9_]+_BEGIN)"
    r".*?"
    r"# (THEME_[A-Z0-9_]+_END)",
    re.DOTALL,
)


def apply_dunst(
    template_path,
    target_path,
    colors,
):
    if not os.path.isfile(template_path):
        return

    if not os.path.isfile(target_path):
        print(
            f"warning: {target_path} not found, skipping",
            file=sys.stderr,
        )
        return

    from .renderer import render

    rendered = render(
        template_path,
        colors,
    )

    with open(
        target_path,
        "r",
        encoding="utf-8",
    ) as f:
        content = f.read()

    rendered_blocks = {}

    for match in BLOCK_PATTERN.finditer(
        rendered
    ):
        begin = match.group(1)
        end = match.group(2)

        expected_end = begin.replace(
            "_BEGIN",
            "_END",
        )

        if end != expected_end:
            print(
                f"warning: mismatched Dunst markers: "
                f"{begin} / {end}",
                file=sys.stderr,
            )
            continue

        rendered_blocks[begin] = match.group(0)

    replaced = set()

    def replace(match):
        begin = match.group(1)
        end = match.group(2)

        expected_end = begin.replace(
            "_BEGIN",
            "_END",
        )

        if end != expected_end:
            return match.group(0)

        replacement = rendered_blocks.get(begin)

        if replacement is None:
            return match.group(0)

        replaced.add(begin)

        return replacement

    content = BLOCK_PATTERN.sub(
        replace,
        content,
    )

    for begin in rendered_blocks:
        if begin not in replaced:
            print(
                f"warning: Dunst block not found in dunstrc: "
                f"{begin}",
                file=sys.stderr,
            )

    with open(
        target_path,
        "w",
        encoding="utf-8",
    ) as f:
        f.write(content)
