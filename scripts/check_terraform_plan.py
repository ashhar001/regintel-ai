#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description="Block destructive Terraform changes by default.")
    parser.add_argument("plan_json")
    parser.add_argument("--allow-destroy", action="store_true")
    args = parser.parse_args()

    plan = json.loads(Path(args.plan_json).read_text(encoding="utf-8"))
    destructive = []
    changed = []

    for item in plan.get("resource_changes", []):
        actions = item.get("change", {}).get("actions", [])
        address = item.get("address", "unknown")
        if actions != ["no-op"]:
            changed.append((address, actions))
        if "delete" in actions:
            destructive.append((address, actions))

    print("## Terraform plan gate")
    print(f"Changed resources: {len(changed)}")
    print(f"Destructive resources: {len(destructive)}")
    for address, actions in destructive:
        print(f"- {address}: {actions}")

    if destructive and not args.allow_destroy:
        raise SystemExit("destructive Terraform change detected; release blocked")


if __name__ == "__main__":
    main()
