from types import SimpleNamespace

import pytest

from app.services.knowledge_base import BedrockKnowledgeBaseError, BedrockKnowledgeBaseService


def settings(model_arn: str | None = "arn:aws:bedrock:us-east-1::foundation-model/cohere.rerank-v3-5:0"):
    return SimpleNamespace(
        aws_region="us-east-1",
        bedrock_knowledge_base_id="KB123",
        bedrock_rag_model_arn="arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-lite-v1:0",
        bedrock_rerank_model_arn=model_arn,
        bedrock_max_tokens=700,
        bedrock_temperature=0.1,
        bedrock_top_p=0.9,
    )


def test_vector_config_adds_reranker():
    service=BedrockKnowledgeBaseService(settings(), client=object())
    config=service._vector_search_configuration(20,"HYBRID",{"topic":"AML"},True,5)
    rerank=config["rerankingConfiguration"]["bedrockRerankingConfiguration"]
    assert config["numberOfResults"] == 20
    assert rerank["numberOfRerankedResults"] == 5
    assert rerank["modelConfiguration"]["modelArn"].endswith("cohere.rerank-v3-5:0")


def test_rerank_requires_model_arn():
    service=BedrockKnowledgeBaseService(settings(None), client=object())
    with pytest.raises(BedrockKnowledgeBaseError):
        service._vector_search_configuration(20,"HYBRID",{},True,5)
