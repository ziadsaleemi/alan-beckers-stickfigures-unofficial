#!/usr/bin/env python3
from __future__ import annotations

from collections import Counter
from pathlib import Path
from xml.sax.saxutils import escape

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
IMG_ROOT = ROOT / "img"
CHARACTERS = ["Blue", "Green", "Orange", "Purple", "Red", "TCO", "TDL", "victim", "Yellow"]
SIZE = 128
SCALE = 4
W = SIZE * SCALE
ANCHOR = "64,128"
MARKER_BEGIN = "\t\t<!-- BEGIN ABS_ROLEPLAY_SPRITES -->"
MARKER_END = "\t\t<!-- END ABS_ROLEPLAY_SPRITES -->"


CLIPS: dict[str, list[str]] = {
    "RoleFollow": ["role_follow01.png", "role_follow02.png"],
    "RoleCopy": ["role_copy01.png", "role_copy02.png"],
    "RoleGuard": ["role_guard01.png", "role_guard02.png"],
    "RoleAmbush": ["role_ambush01.png", "role_ambush02.png"],
    "RoleHugGive": ["role_hug_give01.png", "role_hug_give02.png"],
    "RoleHugReceive": ["role_hug_receive01.png", "role_hug_receive02.png"],
    "RoleTugPull": ["role_tug_pull01.png", "role_tug_pull02.png"],
    "RoleTugPulled": ["role_tug_pulled01.png", "role_tug_pulled02.png"],
    "RoleHighFive": ["role_highfive01.png", "role_highfive02.png"],
    "RoleArgument": ["role_argument01.png", "role_argument02.png"],
    "RoleComfortGive": ["role_comfort_give01.png", "role_comfort_give02.png"],
    "RoleComfortReceive": ["role_comfort_receive01.png", "role_comfort_receive02.png"],
    "RoleTeamPose": ["role_team_pose01.png", "role_team_pose02.png"],
    "RoleBuildTogether": ["role_build_together01.png", "role_build_together02.png"],
    "RoleVictimTrap": ["role_victim_trap01.png", "role_victim_trap02.png"],
    "RoleTrapReaction": ["role_trap_reaction01.png", "role_trap_reaction02.png"],
    "RolePatrol": ["role_patrol01.png", "role_patrol02.png"],
}


def scaled(points: list[tuple[float, float]]) -> list[tuple[int, int]]:
    return [(int(x * SCALE), int(y * SCALE)) for x, y in points]


def color_for(directory: Path) -> tuple[int, int, int, int]:
    stand = Image.open(directory / "stand01.png").convert("RGBA")
    pixels = [
        (r, g, b, a)
        for r, g, b, a in stand.getdata()
        if a > 24 and max(r, g, b) - min(r, g, b) > 16
    ]
    if not pixels:
        return (255, 255, 255, 255)

    quantized = Counter((r // 8 * 8, g // 8 * 8, b // 8 * 8) for r, g, b, _ in pixels)
    r, g, b = quantized.most_common(1)[0][0]
    return (min(255, r + 4), min(255, g + 4), min(255, b + 4), 255)


def new_canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def line(draw: ImageDraw.ImageDraw, color: tuple[int, int, int, int], points: list[tuple[float, float]], width: int = 7) -> None:
    draw.line(scaled(points), fill=color, width=width * SCALE, joint="curve")
    radius = max(2, width // 2) * SCALE
    for x, y in scaled(points):
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)


def circle(draw: ImageDraw.ImageDraw, color: tuple[int, int, int, int], center: tuple[float, float], radius: float, width: int = 7) -> None:
    x, y = center
    box = tuple(int(v * SCALE) for v in (x - radius, y - radius, x + radius, y + radius))
    draw.ellipse(box, outline=color, width=width * SCALE)


def small_fill_circle(draw: ImageDraw.ImageDraw, color: tuple[int, int, int, int], center: tuple[float, float], radius: float) -> None:
    x, y = center
    box = tuple(int(v * SCALE) for v in (x - radius, y - radius, x + radius, y + radius))
    draw.ellipse(box, fill=color)


def rect(draw: ImageDraw.ImageDraw, color: tuple[int, int, int, int], box: tuple[float, float, float, float], width: int = 4) -> None:
    draw.rectangle(tuple(int(v * SCALE) for v in box), outline=color, width=width * SCALE)


def base_stick(
    draw: ImageDraw.ImageDraw,
    color: tuple[int, int, int, int],
    *,
    head: tuple[float, float] = (62, 28),
    body: list[tuple[float, float]] | None = None,
    left_arm: list[tuple[float, float]] | None = None,
    right_arm: list[tuple[float, float]] | None = None,
    left_leg: list[tuple[float, float]] | None = None,
    right_leg: list[tuple[float, float]] | None = None,
) -> None:
    body = body or [(62, 43), (62, 78), (56, 103)]
    left_arm = left_arm or [(62, 55), (42, 72)]
    right_arm = right_arm or [(62, 55), (82, 72)]
    left_leg = left_leg or [(56, 103), (42, 125)]
    right_leg = right_leg or [(56, 103), (74, 124)]
    circle(draw, color, head, 16)
    line(draw, color, body)
    line(draw, color, left_arm)
    line(draw, color, right_arm)
    line(draw, color, left_leg)
    line(draw, color, right_leg)


def draw_role(role: str, frame: int, color: tuple[int, int, int, int], character: str) -> Image.Image:
    image, draw = new_canvas()
    accent = (min(255, color[0] + 40), min(255, color[1] + 40), min(255, color[2] + 40), 220)
    dark = (max(0, color[0] - 40), max(0, color[1] - 40), max(0, color[2] - 40), 220)
    phase = -2 if frame == 1 else 2

    if role == "RoleFollow":
        base_stick(
            draw, color,
            head=(55 + phase, 30),
            body=[(56 + phase, 45), (62, 79), (58, 105)],
            left_arm=[(59, 57), (42, 66)],
            right_arm=[(61, 57), (80, 67)],
            left_leg=[(58, 105), (42 + phase, 125)],
            right_leg=[(58, 105), (78 - phase, 124)],
        )
    elif role == "RoleCopy":
        base_stick(
            draw, color,
            head=(64, 29),
            body=[(64, 45), (64, 77), (64, 104)],
            left_arm=[(64, 55), (44, 49 + phase), (36, 42 + phase)],
            right_arm=[(64, 55), (84, 49 - phase), (92, 42 - phase)],
            left_leg=[(64, 104), (48, 125)],
            right_leg=[(64, 104), (80, 125)],
        )
    elif role == "RoleGuard":
        base_stick(
            draw, color,
            head=(63, 30),
            body=[(63, 46), (61, 78), (58, 106)],
            left_arm=[(62, 56), (36, 58), (28, 68)],
            right_arm=[(63, 57), (84, 62)],
            left_leg=[(58, 106), (44, 126)],
            right_leg=[(58, 106), (76, 125)],
        )
        line(draw, accent, [(31, 53), (31, 91)], width=4)
    elif role == "RoleAmbush":
        base_stick(
            draw, color,
            head=(50 + phase, 31),
            body=[(54 + phase, 46), (64, 78), (68, 104)],
            left_arm=[(60, 55), (42, 48), (28, 42)],
            right_arm=[(62, 56), (84, 62), (98, 68)],
            left_leg=[(68, 104), (52, 126)],
            right_leg=[(68, 104), (92, 118)],
        )
        line(draw, accent, [(20, 38), (28, 42), (20, 46)], width=3)
    elif role == "RoleHugGive":
        base_stick(
            draw, color,
            head=(50, 31),
            body=[(54, 47), (62, 78), (66, 105)],
            left_arm=[(59, 56), (28, 57 + phase)],
            right_arm=[(61, 62), (30, 76 - phase)],
            left_leg=[(66, 105), (50, 126)],
            right_leg=[(66, 105), (82, 124)],
        )
    elif role == "RoleHugReceive":
        base_stick(
            draw, color,
            head=(75, 31),
            body=[(72, 47), (66, 78), (62, 105)],
            left_arm=[(69, 58), (96, 58 - phase)],
            right_arm=[(67, 64), (94, 76 + phase)],
            left_leg=[(62, 105), (46, 124)],
            right_leg=[(62, 105), (78, 126)],
        )
    elif role == "RoleTugPull":
        base_stick(
            draw, color,
            head=(48, 31),
            body=[(53, 46), (67, 78), (72, 105)],
            left_arm=[(61, 56), (31, 58)],
            right_arm=[(64, 64), (31, 66)],
            left_leg=[(72, 105), (51, 125)],
            right_leg=[(72, 105), (93, 121)],
        )
        line(draw, dark, [(8, 62), (33, 62)], width=3)
    elif role == "RoleTugPulled":
        base_stick(
            draw, color,
            head=(78, 31),
            body=[(72, 46), (61, 78), (56, 105)],
            left_arm=[(64, 56), (96, 58)],
            right_arm=[(62, 64), (96, 66)],
            left_leg=[(56, 105), (38, 122)],
            right_leg=[(56, 105), (78, 125)],
        )
        line(draw, dark, [(95, 62), (120, 62)], width=3)
    elif role == "RoleHighFive":
        base_stick(
            draw, color,
            head=(62, 30),
            body=[(62, 46), (62, 80), (60, 105)],
            left_arm=[(62, 55), (40, 69)],
            right_arm=[(63, 55), (84, 35 + phase), (96, 26 + phase)],
            left_leg=[(60, 105), (45, 126)],
            right_leg=[(60, 105), (78, 124)],
        )
        small_fill_circle(draw, accent, (98, 25 + phase), 4)
    elif role == "RoleArgument":
        base_stick(
            draw, color,
            head=(63, 30),
            body=[(63, 46), (61, 79), (60, 105)],
            left_arm=[(62, 56), (38, 48 + phase)],
            right_arm=[(62, 56), (88, 48 - phase)],
            left_leg=[(60, 105), (45, 126)],
            right_leg=[(60, 105), (78, 125)],
        )
        line(draw, accent, [(92, 22), (101, 13)], width=3)
        line(draw, accent, [(99, 28), (111, 25)], width=3)
    elif role == "RoleComfortGive":
        base_stick(
            draw, color,
            head=(55, 31),
            body=[(57, 47), (62, 79), (62, 105)],
            left_arm=[(60, 58), (35, 71)],
            right_arm=[(61, 58), (91, 58 + phase)],
            left_leg=[(62, 105), (48, 126)],
            right_leg=[(62, 105), (78, 125)],
        )
    elif role == "RoleComfortReceive":
        base_stick(
            draw, color,
            head=(70, 35),
            body=[(67, 50), (62, 82), (60, 106)],
            left_arm=[(63, 62), (43, 80)],
            right_arm=[(63, 62), (82, 82)],
            left_leg=[(60, 106), (46, 126)],
            right_leg=[(60, 106), (76, 126)],
        )
    elif role == "RoleTeamPose":
        base_stick(
            draw, color,
            head=(64, 28),
            body=[(64, 44), (64, 77), (64, 103)],
            left_arm=[(64, 54), (43, 37 + phase)],
            right_arm=[(64, 54), (85, 37 - phase)],
            left_leg=[(64, 103), (46, 125)],
            right_leg=[(64, 103), (82, 125)],
        )
    elif role == "RoleBuildTogether":
        base_stick(
            draw, color,
            head=(61, 35),
            body=[(61, 50), (62, 79), (58, 103)],
            left_arm=[(61, 60), (41, 75 + phase)],
            right_arm=[(62, 60), (82, 75 - phase)],
            left_leg=[(58, 103), (45, 126)],
            right_leg=[(58, 103), (78, 126)],
        )
        rect(draw, accent, (42, 76, 86, 102), width=3)
        line(draw, dark, [(50, 84), (78, 84)], width=2)
    elif role == "RoleVictimTrap":
        base_stick(
            draw, color,
            head=(58, 31),
            body=[(58, 47), (62, 78), (64, 105)],
            left_arm=[(61, 57), (37, 55)],
            right_arm=[(62, 57), (88, 50), (105, 45)],
            left_leg=[(64, 105), (48, 126)],
            right_leg=[(64, 105), (84, 123)],
        )
        draw.ellipse(tuple(int(v * SCALE) for v in (87, 29, 121, 63)), outline=accent, width=4 * SCALE)
        line(draw, accent, [(85, 51), (104, 75)], width=3)
    elif role == "RoleTrapReaction":
        base_stick(
            draw, color,
            head=(68, 35),
            body=[(66, 50), (58, 83), (52, 108)],
            left_arm=[(61, 63), (34, 58)],
            right_arm=[(61, 63), (88, 70)],
            left_leg=[(52, 108), (32, 122)],
            right_leg=[(52, 108), (75, 126)],
        )
        draw.ellipse(tuple(int(v * SCALE) for v in (31, 30, 100, 108)), outline=accent, width=3 * SCALE)
    elif role == "RolePatrol":
        base_stick(
            draw, color,
            head=(58 + phase, 30),
            body=[(59 + phase, 46), (63, 78), (60, 105)],
            left_arm=[(61, 56), (42, 65)],
            right_arm=[(61, 55), (79, 44), (91, 44)],
            left_leg=[(60, 105), (42 + phase, 126)],
            right_leg=[(60, 105), (82 - phase, 124)],
        )
        line(draw, accent, [(88, 40), (104, 40)], width=3)
    else:
        base_stick(draw, color)

    return image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def action_block() -> str:
    blocks: list[str] = [MARKER_BEGIN]
    for clip_name, frames in CLIPS.items():
        blocks.append(f'\t\t<Action Name="{escape(clip_name)}" Type="Animate" BorderType="Floor">')
        blocks.append("\t\t\t<Animation>")
        for frame in frames:
            blocks.append(f'\t\t\t\t<Pose Image="/{escape(frame)}" ImageAnchor="{ANCHOR}" Velocity="0,0" Duration="8" />')
        blocks.append("\t\t\t</Animation>")
        blocks.append("\t\t</Action>")
        blocks.append("")
    if blocks[-1] == "":
        blocks.pop()
    blocks.append(MARKER_END)
    return "\n".join(blocks)


def update_actions_xml(path: Path) -> None:
    raw = path.read_text(encoding="utf-8-sig")
    block = action_block()
    if MARKER_BEGIN in raw and MARKER_END in raw:
        start = raw.index(MARKER_BEGIN)
        end = raw.index(MARKER_END) + len(MARKER_END)
        raw = raw[:start] + block + raw[end:]
    else:
        closing = "\n\t</ActionList>"
        if closing not in raw:
            raise RuntimeError(f"Could not find ActionList closing in {path}")
        raw = raw.replace(closing, "\n" + block + closing, 1)
    path.write_text(raw, encoding="utf-8")


def main() -> None:
    for character in CHARACTERS:
        directory = IMG_ROOT / character
        color = color_for(directory)
        for clip_name, frames in CLIPS.items():
            for idx, frame in enumerate(frames, start=1):
                image = draw_role(clip_name, idx, color, character)
                image.save(directory / frame)
        update_actions_xml(directory / "conf" / "actions.xml")


if __name__ == "__main__":
    main()
