from __future__ import annotations

import importlib.util
import json
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[1] / "check_terraform_plan.py"
SPEC = importlib.util.spec_from_file_location("check_terraform_plan", MODULE_PATH)
assert SPEC is not None
check_terraform_plan = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(check_terraform_plan)


def _container(
    *,
    image: str = "repo:before",
    environment: list[dict[str, str]] | None = None,
) -> dict[str, object]:
    return {
        "name": "regintel-api",
        "image": image,
        "essential": True,
        "environment": environment or [{"name": "APP_ENV", "value": "dev"}],
        "portMappings": [{"containerPort": 8000, "hostPort": 8000, "protocol": "tcp"}],
        "mountPoints": [],
        "systemControls": [],
        "volumesFrom": [],
    }


def _resource_change(
    *,
    resource_type: str,
    actions: list[str],
    before: dict[str, object] | None = None,
    after: dict[str, object] | None = None,
    replace_paths: list[list[str]] | None = None,
) -> dict[str, object]:
    return {
        "address": f"{resource_type}.example",
        "type": resource_type,
        "change": {
            "actions": actions,
            "before": before or {},
            "after": after or {},
            "replace_paths": replace_paths or [],
        },
    }


def _ecs_replacement(
    before_container: dict[str, object],
    after_container: dict[str, object],
) -> dict[str, object]:
    return _resource_change(
        resource_type="aws_ecs_task_definition",
        actions=["delete", "create"],
        before={"container_definitions": json.dumps([before_container])},
        after={"container_definitions": json.dumps([after_container])},
        replace_paths=[["container_definitions"]],
    )


def test_create_and_update_changes_are_not_destructive() -> None:
    plan = {
        "resource_changes": [
            _resource_change(resource_type="aws_s3_bucket", actions=["create"]),
            _resource_change(resource_type="aws_iam_role", actions=["update"]),
        ]
    }

    changed, destructive, allowed = check_terraform_plan.classify_changes(plan)

    assert len(changed) == 2
    assert destructive == []
    assert allowed == []


def test_real_delete_is_destructive() -> None:
    plan = {
        "resource_changes": [
            _resource_change(resource_type="aws_s3_bucket", actions=["delete"])
        ]
    }

    _, destructive, allowed = check_terraform_plan.classify_changes(plan)

    assert destructive == [("aws_s3_bucket.example", ["delete"])]
    assert allowed == []


def test_ecs_task_definition_image_only_replacement_is_allowed() -> None:
    before = _container(image="repo:stage5b-v2")
    after = _container(image="repo:stage5b-v1")
    for field in check_terraform_plan.EMPTY_CONTAINER_FIELDS:
        after.pop(field)
    plan = {"resource_changes": [_ecs_replacement(before, after)]}

    _, destructive, allowed = check_terraform_plan.classify_changes(plan)

    assert destructive == []
    assert allowed == [("aws_ecs_task_definition.example", ["delete", "create"])]


def test_ecs_task_definition_environment_replacement_is_destructive() -> None:
    before = _container(image="repo:stage5b-v2")
    after = _container(
        image="repo:stage5b-v1",
        environment=[{"name": "APP_ENV", "value": "prod"}],
    )
    plan = {"resource_changes": [_ecs_replacement(before, after)]}

    _, destructive, allowed = check_terraform_plan.classify_changes(plan)

    assert destructive == [("aws_ecs_task_definition.example", ["delete", "create"])]
    assert allowed == []


def test_ecs_task_definition_role_replacement_is_destructive() -> None:
    before = _container(image="repo:stage5b-v2")
    after = _container(image="repo:stage5b-v1")
    plan = {
        "resource_changes": [
            _resource_change(
                resource_type="aws_ecs_task_definition",
                actions=["delete", "create"],
                before={
                    "task_role_arn": "arn:aws:iam::123:role/before",
                    "container_definitions": json.dumps([before]),
                },
                after={
                    "task_role_arn": "arn:aws:iam::123:role/after",
                    "container_definitions": json.dumps([after]),
                },
                replace_paths=[["task_role_arn"], ["container_definitions"]],
            )
        ]
    }

    _, destructive, allowed = check_terraform_plan.classify_changes(plan)

    assert destructive == [("aws_ecs_task_definition.example", ["delete", "create"])]
    assert allowed == []
