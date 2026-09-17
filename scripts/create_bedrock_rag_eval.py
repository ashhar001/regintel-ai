#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone

import boto3

RETRIEVE_METRICS = ["Builtin.ContextRelevance", "Builtin.ContextCoverage"]
RAG_METRICS = [
    "Builtin.Correctness",
    "Builtin.Completeness",
    "Builtin.Helpfulness",
    "Builtin.LogicalCoherence",
    "Builtin.Faithfulness",
]


def foundation_model_arn(region: str, model_id: str) -> str:
    return f"arn:aws:bedrock:{region}::foundation-model/{model_id}"


def main() -> None:
    parser = argparse.ArgumentParser(description="Create a managed Amazon Bedrock RAG evaluation job.")
    parser.add_argument("--mode", choices=["retrieve", "rag"], required=True)
    parser.add_argument("--knowledge-base-id", required=True)
    parser.add_argument("--dataset-s3-uri", required=True)
    parser.add_argument("--output-s3-uri", required=True)
    parser.add_argument("--role-arn", required=True)
    parser.add_argument("--generator-model-arn", default=None)
    parser.add_argument("--evaluator-model-id", default="amazon.nova-pro-v1:0")
    parser.add_argument("--search-type", choices=["HYBRID", "SEMANTIC"], default="HYBRID")
    parser.add_argument("--number-of-results", type=int, default=5)
    parser.add_argument("--profile", default=None)
    parser.add_argument("--region", default="us-east-1")
    parser.add_argument("--job-name", default=None)
    args = parser.parse_args()

    if args.mode == "rag" and not args.generator_model_arn:
        raise SystemExit("--generator-model-arn is required for --mode rag")

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    job_name = args.job_name or f"regintel-{args.mode}-{args.search_type.lower()}-{timestamp}"
    evaluator_arn = foundation_model_arn(args.region, args.evaluator_model_id)

    vector_search = {
        "numberOfResults": args.number_of_results,
        "overrideSearchType": args.search_type,
    }

    if args.mode == "retrieve":
        kb_config = {
            "retrieveConfig": {
                "knowledgeBaseId": args.knowledge_base_id,
                "knowledgeBaseRetrievalConfiguration": {
                    "vectorSearchConfiguration": vector_search
                },
            }
        }
        metrics = RETRIEVE_METRICS
    else:
        kb_config = {
            "retrieveAndGenerateConfig": {
                "type": "KNOWLEDGE_BASE",
                "knowledgeBaseConfiguration": {
                    "knowledgeBaseId": args.knowledge_base_id,
                    "modelArn": args.generator_model_arn,
                    "retrievalConfiguration": {
                        "vectorSearchConfiguration": vector_search
                    },
                },
            }
        }
        metrics = RAG_METRICS

    session = boto3.Session(profile_name=args.profile, region_name=args.region)
    client = session.client("bedrock")
    response = client.create_evaluation_job(
        jobName=job_name,
        jobDescription="RegIntel Stage 4 managed RAG quality evaluation",
        roleArn=args.role_arn,
        applicationType="RagEvaluation",
        evaluationConfig={
            "automated": {
                "datasetMetricConfigs": [
                    {
                        "taskType": "QuestionAndAnswer",
                        "dataset": {
                            "name": "RegIntelGold",
                            "datasetLocation": {"s3Uri": args.dataset_s3_uri},
                        },
                        "metricNames": metrics,
                    }
                ],
                "evaluatorModelConfig": {
                    "bedrockEvaluatorModels": [{"modelIdentifier": evaluator_arn}]
                },
            }
        },
        inferenceConfig={"ragConfigs": [{"knowledgeBaseConfig": kb_config}]},
        outputDataConfig={"s3Uri": args.output_s3_uri.rstrip("/") + "/"},
        jobTags=[
            {"key": "Project", "value": "regintel-ai"},
            {"key": "Stage", "value": "4-evaluation"},
        ],
    )

    print(json.dumps({"jobName": job_name, **response}, indent=2))


if __name__ == "__main__":
    main()
