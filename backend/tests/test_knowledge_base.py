from app.core.config import Settings
from app.services.knowledge_base import BedrockKnowledgeBaseService


class FakeClient:
    def __init__(self):
        self.retrieve_request = None
        self.query_request = None

    def retrieve(self, **kwargs):
        self.retrieve_request = kwargs
        return {
            "retrievalResults": [
                {
                    "content": {"text": "KYC records must be retained."},
                    "score": 0.92,
                    "location": {"s3Location": {"uri": "s3://bucket/doc.txt"}},
                    "metadata": {"regulator": "TEST"},
                }
            ]
        }

    def retrieve_and_generate(self, **kwargs):
        self.query_request = kwargs
        return {
            "output": {"text": "The test policy requires record retention."},
            "sessionId": "session-1",
            "citations": [
                {
                    "generatedResponsePart": {
                        "textResponsePart": {
                            "text": "requires record retention",
                            "span": {"start": 16, "end": 41},
                        }
                    },
                    "retrievedReferences": [
                        {
                            "content": {"text": "KYC records must be retained."},
                            "location": {"s3Location": {"uri": "s3://bucket/doc.txt"}},
                            "metadata": {"regulator": "TEST"},
                        }
                    ],
                }
            ],
        }


def settings() -> Settings:
    return Settings(
        bedrock_knowledge_base_id="KB12345678",
        bedrock_rag_model_arn=(
            "arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-lite-v1:0"
        ),
    )


def test_retrieve_builds_hybrid_filter_and_parses_source():
    client = FakeClient()
    service = BedrockKnowledgeBaseService(settings(), client=client)

    result = service.retrieve(
        query="What does the policy say?",
        number_of_results=5,
        search_type="HYBRID",
        filters={"regulator": "TEST", "jurisdiction": "India"},
    )

    vector_config = client.retrieve_request["retrievalConfiguration"][
        "vectorSearchConfiguration"
    ]
    assert vector_config["overrideSearchType"] == "HYBRID"
    assert vector_config["numberOfResults"] == 5
    assert "andAll" in vector_config["filter"]
    assert result.results[0]["source_uri"] == "s3://bucket/doc.txt"
    assert result.results[0]["score"] == 0.92


def test_query_parses_citations_and_session():
    client = FakeClient()
    service = BedrockKnowledgeBaseService(settings(), client=client)

    result = service.query(
        question="What does the policy require?",
        number_of_results=8,
        search_type="HYBRID",
        filters={"regulator": "TEST"},
    )

    assert result.session_id == "session-1"
    assert len(result.citations) == 1
    assert result.citations[0]["source_uri"] == "s3://bucket/doc.txt"
    assert result.citations[0]["span_start"] == 16
    assert client.query_request["retrieveAndGenerateConfiguration"]["type"] == "KNOWLEDGE_BASE"
