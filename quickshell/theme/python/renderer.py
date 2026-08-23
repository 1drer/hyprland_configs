import re


VARIABLE_PATTERN = re.compile(
    r"\{\{(\w+)\}\}"
)


def render(template_path, resolved):
    with open(
        template_path,
        "r",
        encoding="utf-8",
    ) as f:
        text = f.read()

    def replace(match):
        key = match.group(1)

        if key.endswith("_rgb"):
            base = key[:-4]

            return resolved.get(
                base,
                "#808080",
            ).lstrip("#")

        return resolved.get(
            key,
            "#808080",
        )

    return VARIABLE_PATTERN.sub(
        replace,
        text,
    )
