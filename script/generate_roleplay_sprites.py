#!/usr/bin/env python3
from __future__ import annotations

import shutil
from pathlib import Path
from xml.etree import ElementTree as ET
from xml.sax.saxutils import escape


ROOT = Path(__file__).resolve().parents[1]
IMG_ROOT = ROOT / "img"
CHARACTERS = ["Blue", "Green", "Orange", "Purple", "Red", "TCO", "TDL", "victim", "Yellow"]
DEFAULT_ANCHOR = "64,128"
MARKER_BEGIN = "\t\t<!-- BEGIN ABS_ROLEPLAY_SPRITES -->"
MARKER_END = "\t\t<!-- END ABS_ROLEPLAY_SPRITES -->"
XML_NS = "{http://www.group-finity.com/Mascot}"


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


# Each role frame is copied from existing shipped artwork. Candidate order matters:
# the first file that exists for a character wins, keeping dimensions, style, and
# source frame semantics aligned with the original image set.
ROLE_SOURCE_CANDIDATES: dict[str, list[list[str]]] = {
    "RoleFollow": [
        ["walk01.png", "run01.png", "stand01.png"],
        ["walk02.png", "run02.png", "walk01.png", "stand01.png"],
    ],
    "RoleCopy": [
        ["stand01.png"],
        ["dance20.png", "dance01.png", "sit_up01.png", "stand01.png"],
    ],
    "RoleGuard": [
        ["stand01.png"],
        ["sit_up01.png", "walk01.png", "stand01.png"],
    ],
    "RoleAmbush": [
        ["run01.png", "walk01.png", "stand01.png"],
        ["run02.png", "run01.png", "walk02.png", "stand01.png"],
    ],
    "RoleHugGive": [
        ["hugging_solid01.png", "stand01.png"],
        ["hugging_solid02.png", "hugging_solid01.png", "stand01.png"],
    ],
    "RoleHugReceive": [
        ["hugged_solid01.png", "stand01.png"],
        ["hugged_solid02.png", "hugged_solid01.png", "stand01.png"],
    ],
    "RoleTugPull": [
        ["pinch04.png", "hugging_solid01.png", "run01.png", "stand01.png"],
        ["pinch05.png", "pinch04.png", "hugging_solid02.png", "run02.png", "stand01.png"],
    ],
    "RoleTugPulled": [
        ["pinch01.png", "hugged_solid01.png", "trip01.png", "stand01.png"],
        ["pinch02.png", "hugged_solid02.png", "trip02.png", "stand01.png"],
    ],
    "RoleHighFive": [
        ["dance20.png", "dance01.png", "stand01.png"],
        ["dance21.png", "dance02.png", "stand01.png"],
    ],
    "RoleArgument": [
        ["stand01.png"],
        ["run01.png", "walk01.png", "stand01.png"],
    ],
    "RoleComfortGive": [
        ["hugging_solid01.png", "stand01.png"],
        ["hugging_solid02.png", "sit_up01.png", "stand01.png"],
    ],
    "RoleComfortReceive": [
        ["hugged_solid01.png", "sit01.png", "stand01.png"],
        ["hugged_solid02.png", "lay01.png", "stand01.png"],
    ],
    "RoleTeamPose": [
        ["stand01.png"],
        ["dance20.png", "dance01.png", "stand01.png"],
    ],
    "RoleBuildTogether": [
        ["sit_up01.png", "stand01.png"],
        ["sit01.png", "stand01.png"],
    ],
    "RoleVictimTrap": [
        ["lassospin01.png", "stab01.png", "cursorsetup02.png", "run01.png", "stand01.png"],
        ["lassospin02.png", "stab02.png", "cursorsetup01.png", "run02.png", "stand01.png"],
    ],
    "RoleTrapReaction": [
        ["trip01.png", "lay01.png", "stand01.png"],
        ["trip02.png", "lay02.png", "lay01.png", "stand01.png"],
    ],
    "RolePatrol": [
        ["walk01.png", "stand01.png"],
        ["walk02.png", "walk01.png", "stand01.png"],
    ],
    "RoleTradePlace": [
        ["run01.png", "walk01.png", "stand01.png"],
        ["run02.png", "walk02.png", "stand01.png"],
    ],
    "RolePlayChaseLead": [
        ["run01.png", "walk01.png", "stand01.png"],
        ["run02.png", "walk02.png", "stand01.png"],
    ],
    "RolePlayChaseFollow": [
        ["run03.png", "run01.png", "walk01.png", "stand01.png"],
        ["run04.png", "run02.png", "walk02.png", "stand01.png"],
    ],
    "RoleSparAttack": [
        ["stab01.png", "run01.png", "walk01.png", "stand01.png"],
        ["stab02.png", "run02.png", "walk02.png", "stand01.png"],
    ],
    "RoleSparBlock": [
        ["trip01.png", "stand01.png"],
        ["trip02.png", "stand01.png"],
    ],
    "RoleTease": [
        ["cursorsetup02.png", "dance20.png", "dance01.png", "run01.png", "stand01.png"],
        ["cursorsetup01.png", "dance21.png", "dance02.png", "run02.png", "stand01.png"],
    ],
    "RoleTeaseReaction": [
        ["trip01.png", "sit_up01.png", "stand01.png"],
        ["trip02.png", "sit01.png", "stand01.png"],
    ],
    "RoleCelebrate": [
        ["dance20.png", "bounce01.png", "stand01.png"],
        ["dance21.png", "bounce02.png", "stand01.png"],
    ],
    "RoleObserve": [
        ["sit_up01.png", "stand01.png"],
        ["sit01.png", "stand01.png"],
    ],
    "RoleRescueGive": [
        ["hugging_solid01.png", "stand01.png"],
        ["hugging_solid02.png", "stand01.png"],
    ],
    "RoleRescueReceive": [
        ["hugged_solid01.png", "lay01.png", "stand01.png"],
        ["hugged_solid02.png", "lay02.png", "stand01.png"],
    ],
}


CHARACTER_ROLE_OVERRIDES: dict[str, dict[str, list[list[str]]]] = {
    "victim": {
        "RoleCopy": [["stand01.png"], ["walk01.png", "stand01.png"]],
        "RoleGuard": [["stand01.png"], ["walk01.png", "stand01.png"]],
        "RoleBuildTogether": [["stand01.png"], ["walk01.png", "stand01.png"]],
        "RoleObserve": [["stand01.png"], ["walk01.png", "stand01.png"]],
        "RoleSparAttack": [["run01.png", "stand01.png"], ["run02.png", "run01.png", "stand01.png"]],
        "RoleTease": [["run01.png", "stand01.png"], ["run02.png", "run01.png", "stand01.png"]],
        "RoleCelebrate": [["stand01.png"], ["walk01.png", "stand01.png"]],
    },
    "TDL": {
        "RoleHugGive": [["stand01.png"], ["walk01.png", "stand01.png"]],
        "RoleHugReceive": [["stand01.png"], ["walk01.png", "stand01.png"]],
        "RoleTugPull": [["run01.png", "stand01.png"], ["run02.png", "run01.png", "stand01.png"]],
        "RoleTugPulled": [["trip01.png", "stand01.png"], ["trip02.png", "trip01.png", "stand01.png"]],
        "RoleComfortGive": [["stand01.png"], ["walk01.png", "stand01.png"]],
        "RoleComfortReceive": [["stand01.png"], ["trip01.png", "stand01.png"]],
        "RoleCelebrate": [["stand01.png"], ["walk01.png", "stand01.png"]],
        "RoleRescueGive": [["stand01.png"], ["walk01.png", "stand01.png"]],
        "RoleRescueReceive": [["stand01.png"], ["trip01.png", "stand01.png"]],
    },
    "TCO": {
        "RoleTugPull": [["run01.png", "stand01.png"], ["run02.png", "run01.png", "stand01.png"]],
        "RoleTugPulled": [["trip01.png", "stand01.png"], ["trip02.png", "trip01.png", "stand01.png"]],
        "RoleCelebrate": [["stand01.png"], ["walk01.png", "stand01.png"]],
    },
    "Purple": {
        "RoleCelebrate": [["stand01.png"], ["walk01.png", "stand01.png"]],
    },
}


def source_anchors(actions_xml: Path) -> dict[str, str]:
    anchors: dict[str, str] = {}
    root = ET.parse(actions_xml).getroot()
    for pose in root.iter(f"{XML_NS}Pose"):
        image = pose.attrib.get("Image", "").lstrip("/")
        if not image or image.startswith("role_"):
            continue
        anchors.setdefault(image, pose.attrib.get("ImageAnchor", DEFAULT_ANCHOR))
    return anchors


def choose_source(directory: Path, candidates: list[str]) -> str:
    for candidate in candidates:
        if (directory / candidate).exists():
            return candidate
    raise FileNotFoundError(f"No candidate source frame exists in {directory}: {candidates}")


def generate_role_frames(character: str, directory: Path) -> dict[str, str]:
    anchors = source_anchors(directory / "conf" / "actions.xml")
    role_anchors: dict[str, str] = {}
    overrides = CHARACTER_ROLE_OVERRIDES.get(character, {})

    for clip_name, role_frames in CLIPS.items():
        source_candidates = overrides.get(clip_name, ROLE_SOURCE_CANDIDATES[clip_name])
        for index, role_frame in enumerate(role_frames):
            source_name = choose_source(directory, source_candidates[index])
            shutil.copyfile(directory / source_name, directory / role_frame)
            role_anchors[role_frame] = anchors.get(source_name, DEFAULT_ANCHOR)

    return role_anchors


def action_block(role_anchors: dict[str, str]) -> str:
    blocks: list[str] = [MARKER_BEGIN]
    for clip_name, frames in CLIPS.items():
        blocks.append(f'\t\t<Action Name="{escape(clip_name)}" Type="Animate" BorderType="Floor">')
        blocks.append("\t\t\t<Animation>")
        for frame in frames:
            anchor = role_anchors.get(frame, DEFAULT_ANCHOR)
            blocks.append(f'\t\t\t\t<Pose Image="/{escape(frame)}" ImageAnchor="{escape(anchor)}" Velocity="0,0" Duration="8" />')
        blocks.append("\t\t\t</Animation>")
        blocks.append("\t\t</Action>")
        blocks.append("")
    if blocks[-1] == "":
        blocks.pop()
    blocks.append(MARKER_END)
    return "\n".join(blocks)


def update_actions_xml(path: Path, role_anchors: dict[str, str]) -> None:
    raw = path.read_text(encoding="utf-8-sig")
    block = action_block(role_anchors)
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
        role_anchors = generate_role_frames(character, directory)
        update_actions_xml(directory / "conf" / "actions.xml", role_anchors)


if __name__ == "__main__":
    main()
