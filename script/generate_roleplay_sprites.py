#!/usr/bin/env python3
from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
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
FILLED_HEAD_CHARACTERS = {"Blue", "Green", "Purple", "Red", "Yellow"}


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
    "RoleTradePlace": ["role_trade_place01.png", "role_trade_place02.png"],
    "RolePlayChaseLead": ["role_play_chase_lead01.png", "role_play_chase_lead02.png"],
    "RolePlayChaseFollow": ["role_play_chase_follow01.png", "role_play_chase_follow02.png"],
    "RoleSparAttack": ["role_spar_attack01.png", "role_spar_attack02.png"],
    "RoleSparBlock": ["role_spar_block01.png", "role_spar_block02.png"],
    "RoleTease": ["role_tease01.png", "role_tease02.png"],
    "RoleTeaseReaction": ["role_tease_reaction01.png", "role_tease_reaction02.png"],
    "RoleCelebrate": ["role_celebrate01.png", "role_celebrate02.png"],
    "RoleObserve": ["role_observe01.png", "role_observe02.png"],
    "RoleRescueGive": ["role_rescue_give01.png", "role_rescue_give02.png"],
    "RoleRescueReceive": ["role_rescue_receive01.png", "role_rescue_receive02.png"],
}


@dataclass(frozen=True)
class CharacterStyle:
    character: str
    color: tuple[int, int, int, int]
    center_x: float
    x_scale: float
    limb_width: int
    head_radius: float
    head_width: int
    head_y_shift: float
    filled_head: bool
    hand_cuffs: bool = False


ACTIVE_STYLE: CharacterStyle | None = None


def scaled(points: list[tuple[float, float]]) -> list[tuple[int, int]]:
    return [(int(x * SCALE), int(y * SCALE)) for x, y in transformed(points)]


def transformed(points: list[tuple[float, float]]) -> list[tuple[float, float]]:
    return [transform_point(point) for point in points]


def transform_point(point: tuple[float, float], *, head: bool = False) -> tuple[float, float]:
    if ACTIVE_STYLE is None:
        return point

    x, y = point
    return (
        ACTIVE_STYLE.center_x + ((x - 64) * ACTIVE_STYLE.x_scale),
        y + (ACTIVE_STYLE.head_y_shift if head else 0),
    )


def scaled_width(width: int) -> int:
    if ACTIVE_STYLE is None:
        return width * SCALE
    adjusted = ACTIVE_STYLE.limb_width if width == 7 else max(1, round(width * ACTIVE_STYLE.limb_width / 7))
    return adjusted * SCALE


def color_for(directory: Path) -> tuple[int, int, int, int]:
    stand = Image.open(directory / "stand01.png").convert("RGBA")
    pixels = [(r, g, b, a) for r, g, b, a in stand.getdata() if a > 24]
    if not pixels:
        return (255, 255, 255, 255)

    r, g, b = Counter((r, g, b) for r, g, b, _ in pixels).most_common(1)[0][0]
    return (r, g, b, 255)


def style_for(character: str, directory: Path) -> CharacterStyle:
    color = color_for(directory)
    if character in FILLED_HEAD_CHARACTERS:
        return CharacterStyle(
            character=character,
            color=color,
            center_x=60,
            x_scale=0.72,
            limb_width=5,
            head_radius=12,
            head_width=5,
            head_y_shift=0,
            filled_head=True,
        )

    return CharacterStyle(
        character=character,
        color=color,
        center_x=67 if character == "victim" else 58,
        x_scale=0.84,
        limb_width=6 if character != "victim" else 7,
        head_radius=17,
        head_width=6 if character != "victim" else 7,
        head_y_shift=-6,
        filled_head=False,
        hand_cuffs=character == "TDL",
    )


def new_canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def line(draw: ImageDraw.ImageDraw, color: tuple[int, int, int, int], points: list[tuple[float, float]], width: int = 7) -> None:
    draw.line(scaled(points), fill=color, width=scaled_width(width), joint="curve")
    radius = max(2, scaled_width(width) // 2)
    for x, y in scaled(points):
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)


def circle(draw: ImageDraw.ImageDraw, color: tuple[int, int, int, int], center: tuple[float, float], radius: float, width: int = 7) -> None:
    is_head = width == 7 and radius == 16 and ACTIVE_STYLE is not None
    x, y = transform_point(center, head=is_head)
    draw_radius = ACTIVE_STYLE.head_radius if is_head else radius
    draw_width = ACTIVE_STYLE.head_width if is_head else width
    box = tuple(int(v * SCALE) for v in (x - draw_radius, y - draw_radius, x + draw_radius, y + draw_radius))
    if is_head and ACTIVE_STYLE.filled_head:
        draw.ellipse(box, fill=color)
    else:
        draw.ellipse(box, outline=color, width=draw_width * SCALE)


def small_fill_circle(draw: ImageDraw.ImageDraw, color: tuple[int, int, int, int], center: tuple[float, float], radius: float) -> None:
    x, y = transform_point(center)
    if ACTIVE_STYLE is not None:
        radius = max(1.0, radius * ACTIVE_STYLE.x_scale)
    box = tuple(int(v * SCALE) for v in (x - radius, y - radius, x + radius, y + radius))
    draw.ellipse(box, fill=color)


def rect(draw: ImageDraw.ImageDraw, color: tuple[int, int, int, int], box: tuple[float, float, float, float], width: int = 4) -> None:
    x1, y1 = transform_point((box[0], box[1]))
    x2, y2 = transform_point((box[2], box[3]))
    draw.rectangle(
        tuple(int(v * SCALE) for v in (min(x1, x2), min(y1, y2), max(x1, x2), max(y1, y2))),
        outline=color,
        width=scaled_width(width),
    )


def ellipse(draw: ImageDraw.ImageDraw, color: tuple[int, int, int, int], box: tuple[float, float, float, float], width: int = 4) -> None:
    x1, y1 = transform_point((box[0], box[1]))
    x2, y2 = transform_point((box[2], box[3]))
    draw.ellipse(
        tuple(int(v * SCALE) for v in (min(x1, x2), min(y1, y2), max(x1, x2), max(y1, y2))),
        outline=color,
        width=scaled_width(width),
    )


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
    if ACTIVE_STYLE is not None and ACTIVE_STYLE.hand_cuffs:
        for hand in (left_arm[-1], right_arm[-1]):
            small_fill_circle(draw, (0, 0, 0, 255), hand, 4.5)


def draw_role(role: str, frame: int, style: CharacterStyle) -> Image.Image:
    global ACTIVE_STYLE
    previous_style = ACTIVE_STYLE
    ACTIVE_STYLE = style
    color = style.color
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
        ellipse(draw, accent, (87, 29, 121, 63), width=4)
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
        ellipse(draw, accent, (31, 30, 100, 108), width=3)
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
    elif role == "RoleTradePlace":
        base_stick(
            draw, color,
            head=(58 + phase, 30),
            body=[(59 + phase, 45), (64, 78), (61, 104)],
            left_arm=[(61, 56), (43, 55 - phase)],
            right_arm=[(62, 56), (83, 48 + phase), (93, 45 + phase)],
            left_leg=[(61, 104), (44 + phase, 126)],
            right_leg=[(61, 104), (82 - phase, 123)],
        )
        line(draw, accent, [(89, 39 + phase), (99, 35 + phase)], width=2)
    elif role == "RolePlayChaseLead":
        base_stick(
            draw, color,
            head=(53 + phase, 35),
            body=[(57 + phase, 49), (69, 76), (75, 100)],
            left_arm=[(64, 56), (44, 55), (35, 51)],
            right_arm=[(65, 58), (87, 64)],
            left_leg=[(75, 100), (55 + phase, 126)],
            right_leg=[(75, 100), (99, 112)],
        )
        line(draw, accent, [(39, 42), (31, 38)], width=2)
    elif role == "RolePlayChaseFollow":
        base_stick(
            draw, color,
            head=(61 + phase, 35),
            body=[(62 + phase, 49), (70, 77), (72, 102)],
            left_arm=[(66, 58), (41, 64), (31, 67)],
            right_arm=[(66, 58), (91, 56), (103, 53)],
            left_leg=[(72, 102), (51 - phase, 126)],
            right_leg=[(72, 102), (96, 119)],
        )
        line(draw, accent, [(98, 48), (108, 45)], width=2)
    elif role == "RoleSparAttack":
        base_stick(
            draw, color,
            head=(55 + phase, 32),
            body=[(58 + phase, 47), (67, 77), (70, 103)],
            left_arm=[(63, 57), (42, 66)],
            right_arm=[(64, 57), (87, 48), (104, 43 + phase)],
            left_leg=[(70, 103), (50, 126)],
            right_leg=[(70, 103), (94, 118)],
        )
        line(draw, accent, [(104, 39 + phase), (113, 35 + phase)], width=2)
    elif role == "RoleSparBlock":
        base_stick(
            draw, color,
            head=(66, 32),
            body=[(65, 47), (61, 78), (58, 105)],
            left_arm=[(63, 58), (42, 50), (34, 43)],
            right_arm=[(63, 58), (84, 50), (94, 42)],
            left_leg=[(58, 105), (43, 126)],
            right_leg=[(58, 105), (77, 125)],
        )
        line(draw, accent, [(37, 37), (91, 37)], width=2)
    elif role == "RoleTease":
        base_stick(
            draw, color,
            head=(63, 30),
            body=[(63, 46), (63, 78), (62, 105)],
            left_arm=[(63, 57), (42, 66)],
            right_arm=[(64, 56), (88, 44 + phase), (103, 39 + phase)],
            left_leg=[(62, 105), (46, 126)],
            right_leg=[(62, 105), (80, 125)],
        )
        line(draw, accent, [(45, 24), (38, 18)], width=2)
        line(draw, accent, [(49, 21), (46, 13)], width=2)
    elif role == "RoleTeaseReaction":
        base_stick(
            draw, color,
            head=(66 - phase, 31),
            body=[(65 - phase, 47), (59, 80), (57, 105)],
            left_arm=[(61, 59), (38, 47), (30, 40)],
            right_arm=[(61, 59), (86, 47), (94, 40)],
            left_leg=[(57, 105), (40, 124)],
            right_leg=[(57, 105), (77, 126)],
        )
        line(draw, accent, [(96, 21), (103, 13)], width=2)
        line(draw, accent, [(101, 29), (111, 26)], width=2)
    elif role == "RoleCelebrate":
        base_stick(
            draw, color,
            head=(64, 27 + phase),
            body=[(64, 43 + phase), (64, 76), (64, 102)],
            left_arm=[(64, 54), (45, 35 + phase), (39, 27 + phase)],
            right_arm=[(64, 54), (83, 35 + phase), (89, 27 + phase)],
            left_leg=[(64, 102), (48, 124)],
            right_leg=[(64, 102), (80, 124)],
        )
        small_fill_circle(draw, accent, (36, 24 + phase), 3)
        small_fill_circle(draw, accent, (92, 24 + phase), 3)
    elif role == "RoleObserve":
        base_stick(
            draw, color,
            head=(68 + phase, 35),
            body=[(66 + phase, 50), (58, 80), (54, 104)],
            left_arm=[(61, 61), (39, 70), (31, 78)],
            right_arm=[(61, 61), (86, 55), (98, 53)],
            left_leg=[(54, 104), (39, 124)],
            right_leg=[(54, 104), (75, 123)],
        )
        line(draw, accent, [(96, 47), (109, 47)], width=2)
    elif role == "RoleRescueGive":
        base_stick(
            draw, color,
            head=(55, 32),
            body=[(57, 48), (62, 80), (62, 105)],
            left_arm=[(60, 59), (39, 68)],
            right_arm=[(61, 59), (88, 69 + phase), (101, 74 + phase)],
            left_leg=[(62, 105), (47, 126)],
            right_leg=[(62, 105), (80, 124)],
        )
        small_fill_circle(draw, accent, (103, 75 + phase), 3)
    elif role == "RoleRescueReceive":
        base_stick(
            draw, color,
            head=(75, 39),
            body=[(71, 54), (61, 84), (55, 106)],
            left_arm=[(64, 66), (42, 78), (32, 84)],
            right_arm=[(64, 66), (88, 68 + phase), (101, 74 + phase)],
            left_leg=[(55, 106), (38, 124)],
            right_leg=[(55, 106), (76, 126)],
        )
        small_fill_circle(draw, accent, (103, 75 + phase), 3)
    else:
        base_stick(draw, color)

    result = image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    ACTIVE_STYLE = previous_style
    return result


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
        style = style_for(character, directory)
        for clip_name, frames in CLIPS.items():
            for idx, frame in enumerate(frames, start=1):
                image = draw_role(clip_name, idx, style)
                image.save(directory / frame)
        update_actions_xml(directory / "conf" / "actions.xml")


if __name__ == "__main__":
    main()
