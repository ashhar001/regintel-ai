#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

EMPTY_CONTAINER_FIELDS = ("mountPoints", "systemControls", "volumesFrom")


def _load_container_definitions(raw: object) -> list[dict[str, object]] | None:
    if not isinstance(raw, str):
        return None

    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        return None

    if not isinstance(parsed, list):
        return None

    return [item for item in parsed if isinstance(item, dict)]


def _normalize_container_definitions(raw: object) -> list[dict[str, object]] | None:
    loaded = _load_container_definitions(raw)
    if not loaded:
        return None

    containers = []
    for item in loaded:
        container = dict(item)
        container.pop("image", None)
        for field in EMPTY_CONTAINER_FIELDS:
            if container.get(field) == []:
                container.pop(field)
        containers.append(container)
    return containers


def is_cd_owned_ecs_image_replacement(item: dict[str, object]) -> bool:
    if item.get("type") != "aws_ecs_task_definition":
        return False

    change = item.get("change", {})
    if not isinstance(change, dict):
        return False

    if change.get("actions") != ["delete", "create"]:
        return False

    if change.get("replace_paths") != [["container_definitions"]]:
        return False

    before = change.get("before", {})
    after = change.get("after", {})
    if not isinstance(before, dict) or not isinstance(after, dict):
        return False

    before_containers = _normalize_container_definitions(before.get("container_definitions"))
    after_containers = _normalize_container_definitions(after.get("container_definitions"))
    return before_containers is not None and before_containers == after_containers


def classify_changes(plan: dict[str, object]) -> tuple[list[tuple[str, list[str]]], list[tuple[str, list[str]]], list[tuple[str, list[str]]]]:
    destructive = []
    changed = []
    allowed = []

    for item in plan.get("resource_changes", []):
        if not isinstance(item, dict):
            continue

        change = item.get("change", {})
        if not isinstance(change, dict):
            continue

        actions = change.get("actions", [])
        if not isinstance(actions, list):
            actions = []

        normalized_actions = [str(action) for action in actions]
        address = str(item.get("address", "unknown"))
        if normalized_actions != ["no-op"]:
            changed.append((address, normalized_actions))
        if "delete" in normalized_actions:
            if is_cd_owned_ecs_image_replacement(item):
                allowed.append((address, normalized_actions))
            else:
                destructive.append((address, normalized_actions))

    return changed, destructive, allowed


def main() -> None:
    parser = argparse.ArgumentParser(description="Block destructive Terraform changes by default.")
    parser.add_argument("plan_json")
    parser.add_argument("--allow-destroy", action="store_true")
    args = parser.parse_args()

    plan = json.loads(Path(args.plan_json).read_text(encoding="utf-8"))
    changed, destructive, allowed = classify_changes(plan)

    print("## Terraform plan gate")
    print(f"Changed resources: {len(changed)}")
    print(f"Allowed CD-owned replacements: {len(allowed)}")
    for address, actions in allowed:
        print(f"- {address}: {actions}")
    print(f"Destructive resources: {len(destructive)}")
    for address, actions in destructive:
        print(f"- {address}: {actions}")

    if destructive and not args.allow_destroy:
        raise SystemExit("destructive Terraform change detected; release blocked")


if __name__ == "__main__":
    main()
